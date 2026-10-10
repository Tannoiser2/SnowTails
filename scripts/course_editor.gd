class_name CourseEditor
extends Control
## Editor dei percorsi: scegli i pezzi uno alla volta e la pista cresce nell'anteprima.
## I percorsi si salvano in user://courses/ e compaiono nel menu con il simbolo ✎.

const USER_DIR := "user://courses/"
static var start_from := ""          # percorso da cui partire (impostato dal menu)

const PALETTE := [
	["Partenza", [["1° a sinistra", "start_p21"], ["1° a destra", "start_p22"]]],
	["Rettilinei", [["Rettilineo", "@straight"], ["Alberelli", "@saplings"], ["Cumulo", "@snowdrift"], ["Crepaccio", "@chasm"], ["Leap of Death", "leap_p22a"]]],
	["Curve", [["Curva sinistra", "corner_L_p07"], ["Curva destra", "corner_R_p08"]]],
	["Inversioni", [["Inversione sinistra", "uturn_L_p01"], ["Inversione destra", "uturn_R_p02"]]],
	["Arrivo", [["Arrivo", "finish_p21"]]],
]
const POOLS := {
	"@straight": ["straight_p16a", "straight_p14a", "straight_p18b", "straight_p16b", "straight_p14b", "straight_p18a", "straight_p13a", "straight_p20b", "straight_p19b", "straight_p20a"],
	"@saplings": ["saplings_p13b", "saplings_p17a"],
	"@snowdrift": ["snowdrift_p15a", "snowdrift_p15b"],
	"@chasm": ["chasm_p17b", "chasm_p19a"],
}

var pieces: Array = []
var preview: CoursePreview
var list: ItemList
var status: RichTextLabel
var name_edit: LineEdit
var start_pick: OptionButton
var _files: Array = []
var _gen := CourseGen.new()
var _bad := {}

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("dfe7ee")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 0)
	add_child(hb)
	var left := MarginContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "top", "right", "bottom"]:
		left.add_theme_constant_override("margin_" + side, 14)
	hb.add_child(left)
	preview = CoursePreview.new()
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(preview)
	var side_panel := UIKit.panel(Color(1, 1, 1, 0.97), 0)
	side_panel.custom_minimum_size = Vector2(420, 0)
	hb.add_child(side_panel)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_panel.add_child(sc)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	sc.add_child(col)
	var top := HBoxContainer.new()
	var title := UIKit.label("Crea percorso", 28)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var back := UIKit.button("Torna al menu")
	back.size_flags_horizontal = 0
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	top.add_child(back)
	col.add_child(top)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Nome del percorso"
	name_edit.add_theme_font_size_override("font_size", 20)
	name_edit.custom_minimum_size = Vector2(0, 48)
	col.add_child(name_edit)
	var sr := HBoxContainer.new()
	var sl := UIKit.label("Parti da", 18, UIKit.MUTED)
	sl.autowrap_mode = TextServer.AUTOWRAP_OFF
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sr.add_child(sl)
	start_pick = OptionButton.new()
	start_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_pick.add_theme_font_size_override("font_size", 17)
	start_pick.item_selected.connect(_load_from)
	sr.add_child(start_pick)
	col.add_child(sr)
	# tavolozza dei pezzi
	for group in PALETTE:
		col.add_child(UIKit.label(group[0], 16, UIKit.MUTED))
		var g := GridContainer.new()
		g.columns = 3 if (group[1] as Array).size() > 2 else 2
		g.add_theme_constant_override("h_separation", 6)
		g.add_theme_constant_override("v_separation", 6)
		for it in group[1]:
			var b := UIKit.button(it[0])
			b.custom_minimum_size = Vector2(0, 46)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.add_theme_font_size_override("font_size", 16)
			b.pressed.connect(_add.bind(it[1]))
			g.add_child(b)
		col.add_child(g)
	col.add_child(UIKit.label("Sequenza (tocca un pezzo per inserire dopo di lui o toglierlo)", 15, UIKit.MUTED))
	list = ItemList.new()
	list.custom_minimum_size = Vector2(0, 210)
	list.add_theme_font_size_override("font_size", 16)
	list.item_selected.connect(func(_i): _refresh())
	col.add_child(list)
	var er := HBoxContainer.new()
	er.add_theme_constant_override("separation", 6)
	for spec in [["Togli selezionato", _remove_selected], ["Togli ultimo", _remove_last], ["Svuota", _clear]]:
		var b2 := UIKit.button(spec[0])
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b2.add_theme_font_size_override("font_size", 15)
		b2.pressed.connect(spec[1])
		er.add_child(b2)
	col.add_child(er)
	status = UIKit.rich(16)
	col.add_child(status)
	var save := UIKit.button("Salva percorso", true)
	save.custom_minimum_size = Vector2(0, 54)
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

func _load_from(i: int) -> void:
	if i <= 0:
		pieces = []
		name_edit.text = ""
	else:
		var d = JSON.parse_string(FileAccess.get_file_as_string(_files[i]))
		if d is Dictionary:
			pieces = (d.get("pieces", []) as Array).duplicate()
			var nm := String(d.get("name", ""))
			name_edit.text = nm if _files[i].begins_with(USER_DIR) else nm + " (variante)"
	list.deselect_all()
	_refresh()

func _pick(token: String) -> String:
	if not POOLS.has(token):
		return token
	var pool: Array = POOLS[token]
	for f in pool:
		if not pieces.has(f):
			return f
	return pool[pieces.size() % pool.size()]

func _add(token: String) -> void:
	var fid := _pick(token)
	var is_start := fid.begins_with("start")
	if is_start:
		if not pieces.is_empty() and String(pieces[0]).begins_with("start"):
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
		list.select(at)
	else:
		pieces.append(fid)
	_refresh()

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

func _label_of(fid: String) -> String:
	var f := FaceDB.load_face(fid)
	var t := String(f.get("type", ""))
	match t:
		"start": return "Partenza" + (" (1° a destra)" if fid.ends_with("p22") else " (1° a sinistra)")
		"finish": return "Arrivo"
		"corner": return "Curva " + ("a sinistra" if String(f.get("turn", "")) == "L" else "a destra")
		"uturn": return "Inversione " + ("a sinistra" if String(f.get("turn", "")) == "L" else "a destra")
	match String(f.get("special", "")):
		"saplings": return "Alberelli"
		"snowdrift": return "Cumulo di neve"
		"chasm": return "Crepaccio"
		"leap": return "Leap of Death"
	return "Rettilineo"

func _refresh() -> void:
	var sel := list.get_selected_items()
	list.clear()
	# posa dei pezzi e sovrapposizioni
	var placed := []
	var draw := []
	_bad = {}
	var mid := Vector2.ZERO
	var dir := Vector2(0, -1)
	for i in pieces.size():
		var pl := _gen._place(String(pieces[i]), i - 1 if i > 0 else -1, mid, dir)
		if pl.is_empty():
			_bad[i] = true
			continue
		if i > 0 and _gen._collides(pl["cells"], placed):
			_bad[i] = true
		placed.append(pl["cells"])
		draw.append({"xf": pl["xf"], "face": pl["face"], "tex_path": String(pl["face"].get("image", "")), "bad": _bad.has(i)})
		mid = pl["mid"]
		dir = pl["dir"]
	for i in pieces.size():
		list.add_item("%2d. %s%s" % [i + 1, _label_of(String(pieces[i])), "   ⚠ si sovrappone" if _bad.has(i) else ""])
	if sel.size() > 0 and sel[0] < pieces.size():
		list.select(sel[0])
	if draw.is_empty():
		preview.show_message("Scegli la partenza e aggiungi i pezzi a destra.")
	else:
		preview.show_pieces(draw)
	# riepilogo
	var n := {"straight": 0, "corner": 0, "uturn": 0, "leap": 0}
	var has_finish := false
	for fid in pieces:
		var f := FaceDB.load_face(String(fid))
		var t := String(f.get("type", ""))
		if t == "finish": has_finish = true
		elif String(f.get("special", "")) == "leap": n["leap"] += 1
		elif n.has(t): n[t] += 1
	var msgs := []
	msgs.append("Rettilinei [b]%d[/b]/8 · curve [b]%d[/b]/4 · inversioni [b]%d[/b]/2%s" % [n["straight"], n["corner"], n["uturn"], " · Leap of Death" if n["leap"] > 0 else ""])
	if n["straight"] > 8 or n["corner"] > 4 or n["uturn"] > 2:
		msgs.append("[color=#c9900f]Usi più pezzi di quelli della scatola: in digitale si può, al tavolo no.[/color]")
	if not _bad.is_empty():
		msgs.append("[color=#c93636]Alcuni pezzi si sovrappongono (in rosso nell'anteprima).[/color]")
	if not has_finish:
		msgs.append("Manca l'[b]arrivo[/b]: aggiungilo, poi almeno un rettilineo dopo.")
	elif String(pieces[pieces.size() - 1]).begins_with("finish"):
		msgs.append("Dopo l'arrivo serve almeno un rettilineo.")
	status.text = "\n".join(msgs)

func _save() -> void:
	var nm := name_edit.text.strip_edges()
	if nm == "":
		status.text = "[color=#c93636]Dai un nome al percorso.[/color]"
		return
	var def := {"name": nm, "note": "Percorso creato con l'editor.", "pieces": pieces.duplicate()}
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
	if not _bad.is_empty():
		status.text += "\n[color=#c9900f]Attenzione: alcuni pezzi si sovrappongono.[/color]"
