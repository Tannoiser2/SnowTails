class_name CourseEditor
extends Control
## Editor dei percorsi: a destra una tavolozza compatta dei pezzi e la sequenza, a sinistra
## l'anteprima in 3D (con salite, discese e terreno). Ai rettilinei si possono sommare le
## caratteristiche fanmade: pendenza, vento, ghiaccio, neve fresca, baita.

const USER_DIR := "user://courses/"
var _net: Net = null
static var start_from := ""          # percorso da cui partire (impostato dal menu)

const PALETTE := [
	["Partenza ←", "start_p21"], ["Partenza →", "start_p22"], ["Rettilineo", "@straight"], ["Alberelli", "@saplings"],
	["Cumulo", "@snowdrift"], ["Crepaccio", "@chasm"], ["Leap", "leap_p22a"], ["Bivio ★", "fan_fork"],
	["Curva ←", "corner_L_p07"], ["Curva →", "corner_R_p08"], ["Inv. ←", "uturn_L_p01"], ["Inv. →", "uturn_R_p02"],
	["Arrivo", "finish_p21"],
]
const POOLS := {
	"@straight": ["straight_p16a", "straight_p14a", "straight_p18b", "straight_p16b", "straight_p14b", "straight_p18a", "straight_p13a", "straight_p20b", "straight_p19b", "straight_p20a"],
	"@saplings": ["saplings_p13b", "saplings_p17a"],
	"@snowdrift": ["snowdrift_p15a", "snowdrift_p15b"],
	"@chasm": ["chasm_p17b", "chasm_p19a"],
}

var pieces: Array = []               # nomi di tessera o {"id", "mods"}
var board: BoardView3D
var list: ItemList
var status: RichTextLabel
var name_edit: LineEdit
var start_pick: OptionButton
var mods_box: VBoxContainer
var _files: Array = []
var _gen := CourseGen.new()
var _bad := {}
var _rebuild_at := -1.0
var _course: Course = null

func _ready() -> void:
	UIKit.setup_fonts()
	get_tree().root.theme = UIKit.make_theme()
	var bg := ColorRect.new()
	bg.color = Color("dfe7ee")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 0)
	add_child(hb)
	# anteprima 3D: la stessa vista del gioco, si ruota e si avvicina come in partita
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.handle_input_locally = true
	svc.add_child(sv)
	board = BoardView3D.new()
	sv.add_child(board)
	# pannello compatto
	var side := UIKit.panel(Color(UIKit.PANEL, 0.98), 0)
	side.custom_minimum_size = Vector2(380, 0)
	hb.add_child(side)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	side.add_child(col)
	var top := HBoxContainer.new()
	var title := UIKit.title("Crea percorso", 30)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var back := _small("Menu")
	back.size_flags_horizontal = 0
	back.custom_minimum_size = Vector2(90, 36)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	top.add_child(back)
	col.add_child(top)
	var nr := HBoxContainer.new()
	nr.add_theme_constant_override("separation", 6)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Nome del percorso"
	name_edit.add_theme_font_size_override("font_size", 16)
	name_edit.custom_minimum_size = Vector2(0, 36)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIKit.touch_text(name_edit, "Nome del percorso")
	nr.add_child(name_edit)
	start_pick = OptionButton.new()
	start_pick.custom_minimum_size = Vector2(150, 36)
	start_pick.add_theme_font_size_override("font_size", 14)
	start_pick.tooltip_text = "Parti da un percorso esistente"
	UIKit.style_option(start_pick)
	start_pick.item_selected.connect(_load_from)
	col.add_child(nr)
	start_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sr := HBoxContainer.new()
	sr.add_theme_constant_override("separation", 6)
	var sl := UIKit.label("Parti da", 14, UIKit.MUTED)
	sl.autowrap_mode = TextServer.AUTOWRAP_OFF
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sr.add_child(sl)
	sr.add_child(start_pick)
	col.add_child(sr)
	col.add_child(UIKit.heading("Pezzi", 14))
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	for it in PALETTE:
		var b := _small(it[0])
		b.pressed.connect(_add.bind(it[1]))
		g.add_child(b)
	col.add_child(g)
	# caratteristiche del rettilineo selezionato
	mods_box = VBoxContainer.new()
	mods_box.add_theme_constant_override("separation", 4)
	col.add_child(mods_box)
	col.add_child(UIKit.heading("Sequenza", 14))
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.custom_minimum_size = Vector2(0, 120)
	list.add_theme_font_size_override("font_size", 14)
	list.item_selected.connect(func(i):
		_refresh_mods()
		_focus_piece(i))
	col.add_child(list)
	var er := HBoxContainer.new()
	er.add_theme_constant_override("separation", 4)
	for spec in [["Togli", _remove_selected], ["Togli ultimo", _remove_last], ["Svuota", _clear]]:
		var b2 := _small(spec[0])
		b2.pressed.connect(spec[1])
		er.add_child(b2)
	col.add_child(er)
	status = UIKit.rich(13)
	col.add_child(status)
	var save := UIKit.cta("Salva percorso")
	save.custom_minimum_size = Vector2(0, 44)
	save.pressed.connect(_save)
	col.add_child(save)
	# percorsi esistenti da cui partire
	start_pick.add_item("Pista vuota")
	_files = [""]
	for dir in ["res://data/courses/", USER_DIR]:
		var da := DirAccess.open(dir)
		if da == null:
			continue
		var fs := []
		for f in da.get_files():
			if f.ends_with(".json"):
				fs.append(dir + f)
		fs.sort()
		for f in fs:
			var d = JSON.parse_string(FileAccess.get_file_as_string(f))
			if d is Dictionary:
				start_pick.add_item(String(d.get("name", f.get_file())) + ("  ✎" if dir == USER_DIR else ""))
				_files.append(f)
	var k := _files.find(start_from)
	if k > 0:
		start_pick.selected = k
		_load_from(k)
	else:
		_refresh()

func _small(text: String) -> Button:
	var b := UIKit.button(text)
	b.custom_minimum_size = Vector2(0, 36)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 13)
	b.clip_text = true
	return b

func _load_from(i: int) -> void:
	if i <= 0:
		pieces = []
		name_edit.text = ""
	else:
		var d = JSON.parse_string(FileAccess.get_file_as_string(_files[i]))
		if d is Dictionary:
			pieces = (d.get("pieces", []) as Array).duplicate(true)
			var nm := String(d.get("name", ""))
			name_edit.text = nm if _files[i].begins_with(USER_DIR) else nm + " (variante)"
	list.deselect_all()
	_refresh()

func _ids() -> Array:
	var out := []
	for it in pieces:
		out.append(Course.item_id(it))
	return out

func _pick(token: String) -> String:
	if not POOLS.has(token):
		return token
	var pool: Array = POOLS[token]
	var used := _ids()
	for f in pool:
		if not used.has(f):
			return f
	return pool[pieces.size() % pool.size()]

func _add(token: String) -> void:
	var fid := _pick(token)
	if fid.begins_with("start"):
		if not pieces.is_empty() and Course.item_id(pieces[0]).begins_with("start"):
			pieces[0] = fid
		else:
			pieces.insert(0, fid)
		_refresh()
		return
	if pieces.is_empty():
		pieces.append("start_p21")
	var sel := list.get_selected_items()
	if sel.size() > 0:
		var at: int = sel[0] + 1
		pieces.insert(at, fid)
		_refresh()
		list.select(at)
	else:
		pieces.append(fid)
		_refresh()
		list.select(pieces.size() - 1)
	_refresh_mods()

func _remove_selected() -> void:
	var sel := list.get_selected_items()
	if sel.size() > 0:
		pieces.remove_at(sel[0])
		list.deselect_all()
		_refresh()

func _remove_last() -> void:
	if not pieces.is_empty():
		pieces.pop_back()
		_refresh()

func _clear() -> void:
	pieces = []
	_refresh()

const MOD_NAMES := {"up": "salita", "down": "discesa", "L": "vento ←", "R": "vento →", "ice": "ghiaccio", "fresh": "neve fresca", "hut": "baita"}

func _label_of(item) -> String:
	var fid := Course.item_id(item)
	var f := FaceDB.load_face(fid)
	var t := String(f.get("type", ""))
	var base := "Rettilineo"
	match t:
		"start": base = "Partenza" + (" (1° a destra)" if fid.ends_with("p22") else " (1° a sinistra)")
		"finish": base = "Arrivo"
		"corner": base = "Curva " + ("a sinistra" if String(f.get("turn", "")) == "L" else "a destra")
		"uturn": base = "Inversione " + ("a sinistra" if String(f.get("turn", "")) == "L" else "a destra")
		"fork": base = "Bivio ★"
		_:
			match String(f.get("special", "")):
				"saplings": base = "Alberelli"
				"snowdrift": base = "Cumulo di neve"
				"chasm": base = "Crepaccio"
				"leap": base = "Leap of Death"
	var m := Course.item_mods(item)
	var tags := []
	if m.has("slope"): tags.append(MOD_NAMES[m["slope"]])
	if m.has("wind"): tags.append(MOD_NAMES[m["wind"]])
	for k in ["ice", "fresh", "hut"]:
		if m.get(k, false): tags.append(MOD_NAMES[k])
	return base + ("  ★ " + ", ".join(tags) if not tags.is_empty() else "")

## Pannello delle caratteristiche: compare quando è selezionato un rettilineo.
func _refresh_mods() -> void:
	UIKit.clear(mods_box)
	var sel := list.get_selected_items()
	if sel.is_empty() or sel[0] >= pieces.size():
		return
	var i: int = sel[0]
	var f := FaceDB.load_face(Course.item_id(pieces[i]))
	if not Course.can_mod(f):
		return
	var m := Course.item_mods(pieces[i])
	mods_box.add_child(UIKit.heading("Caratteristiche del pezzo %d ★" % (i + 1), 14))
	for row in [["Pendenza", "slope", [["piano", ""], ["salita", "up"], ["discesa", "down"]]],
			["Vento", "wind", [["no", ""], ["←", "L"], ["→", "R"]]]]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		var l := UIKit.label(row[0], 14, UIKit.MUTED)
		l.custom_minimum_size = Vector2(76, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
		for opt in row[2]:
			var on: bool = String(m.get(row[1], "")) == opt[1]
			var b := UIKit.button(opt[0], on)
			b.custom_minimum_size = Vector2(0, 32)
			b.add_theme_font_size_override("font_size", 13)
			b.pressed.connect(_set_mod.bind(i, row[1], opt[1]))
			h.add_child(b)
		mods_box.add_child(h)
	var t := HBoxContainer.new()
	t.add_theme_constant_override("separation", 4)
	for spec in [["Ghiaccio", "ice"], ["Neve fresca", "fresh"], ["Baita", "hut"]]:
		var on2: bool = m.get(spec[1], false)
		var b2 := UIKit.button(("✓ " if on2 else "") + spec[0], on2)
		b2.custom_minimum_size = Vector2(0, 32)
		b2.add_theme_font_size_override("font_size", 13)
		b2.pressed.connect(_set_mod.bind(i, spec[1], not on2))
		t.add_child(b2)
	mods_box.add_child(t)

func _set_mod(i: int, key: String, value) -> void:
	var m := Course.item_mods(pieces[i])
	if value is bool and not value or value is String and value == "":
		m.erase(key)
	else:
		m[key] = value
	pieces[i] = Course.item_id(pieces[i]) if m.is_empty() else {"id": Course.item_id(pieces[i]), "mods": m}
	_refresh()
	list.select(i)
	_refresh_mods()

## Selezionando un pezzo, la telecamera lo inquadra.
func _focus_piece(i: int) -> void:
	if _course == null or i >= _course.pieces.size():
		return
	var pc: Dictionary = _course.pieces[i]
	board.set_follow(true)
	board.frame([pc["entry_mid"], pc["exit_mid"]], 4.5, true)

func _process(_d: float) -> void:
	if _rebuild_at >= 0.0 and Time.get_ticks_msec() / 1000.0 >= _rebuild_at:
		_rebuild_at = -1.0
		_rebuild_3d()

## Ricostruisce l'anteprima 3D (con un piccolo ritardo, così più clic di fila costano una volta sola).
func _rebuild_3d() -> void:
	var c := Course.new()
	c.build({"name": "anteprima", "pieces": pieces.duplicate(true)})
	if c.pieces.is_empty() or c.cells.is_empty():
		_course = null
		return
	_course = c
	var g := SledGame.new()
	g.setup(c, [])
	board.setup(c, g)
	board.current_id = -1
	var pts := []
	for cc in c.cells:
		pts.append(cc["pos"])
	var keep_dist := board.dist
	board.frame(pts, 4.0, true)
	if keep_dist > 0.5 and board.dist_goal > keep_dist * 1.5:
		board.dist = keep_dist

func _refresh() -> void:
	var sel := list.get_selected_items()
	list.clear()
	# posa dei pezzi e sovrapposizioni
	var placed := []
	_bad = {}
	var mid := Vector2.ZERO
	var dir := Vector2(0, -1)
	for i in pieces.size():
		var pl := _gen._place(Course.item_id(pieces[i]), i - 1 if i > 0 else -1, mid, dir)
		if pl.is_empty():
			_bad[i] = true
			continue
		if i > 0 and _gen._collides(pl["cells"], placed):
			_bad[i] = true
		placed.append(pl["cells"])
		mid = pl["mid"]
		dir = pl["dir"]
	for i in pieces.size():
		list.add_item("%2d. %s%s" % [i + 1, _label_of(pieces[i]), "   ⚠ si sovrappone" if _bad.has(i) else ""])
	if sel.size() > 0 and sel[0] < pieces.size():
		list.select(sel[0])
	_rebuild_at = Time.get_ticks_msec() / 1000.0 + 0.25
	# riepilogo
	var n := {"straight": 0, "corner": 0, "uturn": 0, "leap": 0}
	var has_finish := false
	for it in pieces:
		var f := FaceDB.load_face(Course.item_id(it))
		var t := String(f.get("type", ""))
		if t == "finish": has_finish = true
		elif String(f.get("special", "")) == "leap": n["leap"] += 1
		elif n.has(t): n[t] += 1
	var msgs := []
	msgs.append("Rettilinei [b]%d[/b]/8 · curve [b]%d[/b]/4 · inversioni [b]%d[/b]/2%s" % [n["straight"], n["corner"], n["uturn"], " · Leap of Death" if n["leap"] > 0 else ""])
	if n["straight"] > 8 or n["corner"] > 4 or n["uturn"] > 2:
		msgs.append("[color=#c9900f]Più pezzi di quelli della scatola: in digitale si può.[/color]")
	if not _bad.is_empty():
		msgs.append("[color=#c93636]Alcuni pezzi si sovrappongono.[/color]")
	if pieces.is_empty():
		msgs.append("Scegli la partenza e aggiungi i pezzi. Seleziona un rettilineo per sommargli salita, vento, ghiaccio…")
	elif not has_finish:
		msgs.append("Manca l'[b]arrivo[/b]: aggiungilo, poi almeno un rettilineo dopo.")
	elif Course.item_id(pieces[pieces.size() - 1]).begins_with("finish"):
		msgs.append("Dopo l'arrivo serve almeno un rettilineo.")
	status.text = "\n".join(msgs)
	_refresh_mods()

func _save() -> void:
	var nm := name_edit.text.strip_edges()
	if nm == "":
		status.text = "[color=#c93636]Dai un nome al percorso.[/color]"
		return
	var def := {"name": nm, "note": "Percorso creato con l'editor.", "pieces": pieces.duplicate(true),
		"saved_at": Time.get_datetime_string_from_system(true)}
	var c := Course.new()
	if not c.build(def):
		status.text = "[color=#c93636]Non si può salvare: %s[/color]" % c.error
		return
	if not _gen._finish_reachable(c):
		status.text = "[color=#c93636]Non si può salvare: il traguardo non si raggiunge.[/color]"
		return
	if not DirAccess.dir_exists_absolute(USER_DIR):
		DirAccess.make_dir_recursive_absolute(USER_DIR)
	var slug := nm.to_lower().replace(" ", "_")
	var ok_chars := "abcdefghijklmnopqrstuvwxyz0123456789_-"
	var clean := ""
	for ch in slug:
		if ok_chars.contains(ch): clean += ch
	if clean == "": clean = "percorso"
	var path := USER_DIR + clean + ".json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		status.text = "[color=#c93636]Salvataggio non riuscito.[/color]"
		return
	f.store_string(JSON.stringify(def, " "))
	f.close()
	status.text = "Salvato: «%s». Lo trovi nel menu dei percorsi con il simbolo ✎." % nm
	if _net == null:
		_net = Net.new()
		add_child(_net)
	if CourseLibrary.linked(_net):
		status.text += "\nCarico nella libreria online…"
		var ok := await CourseLibrary.upload(_net, clean, def)
		status.text = status.text.replace("Carico nella libreria online…", "Salvato anche nella libreria online." if ok else "[color=#c93636]Libreria online non raggiungibile: la pista è salvata qui e si caricherà alla prossima sincronizzazione.[/color]")
	if not _bad.is_empty():
		status.text += "\n[color=#c9900f]Attenzione: alcuni pezzi si sovrappongono.[/color]"
