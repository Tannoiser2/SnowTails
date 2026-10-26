extends Node2D
## Editor della rete di caselle di una faccia di tessera.
## Si disegnano "catene": tocchi le caselle una dopo l'altra nel senso di marcia,
## e ogni passo crea un collegamento in avanti (oltre una linea blu).
## Le catene possono incrociarsi e condividere caselle. Le derive le calcola il gioco.

var ids: Array = []
var face: Dictionary = {}
var cells: Array = []     # Vector2
var links: Array = []     # [a, b]
var drift_add: Array = []     # [a, b, "L"|"R"]
var drift_remove: Array = []  # [a, b, "L"|"R"]
var drift_from := -1
var hints: Array = []
var chain_last := -1
var mode := "chain"
var show_drift := false
var undo_stack: Array = []
var sprite: Sprite2D
var overlay: Node2D
var cam: Camera2D
var status: RichTextLabel
var picker: OptionButton
var mode_btns := {}
var fwd_btn: Button
var show_fwd := true
var drift_btn: Button
var dirty := false
var top_panel: PanelContainer
var bottom_panel: PanelContainer
var portrait_box: VBoxContainer
var land_box: HBoxContainer
var side_panel: PanelContainer
var side_inner: VBoxContainer
var layout_mode := ""
var _drift_cache: Array = []
var _auto_drift: Array = []
var _heads: Array = []
var _touches := {}
var _press := Vector2.ZERO
var _moved := false
var _pinch := 0.0

func _ready() -> void:
	UIKit.setup_fonts()
	sprite = Sprite2D.new()
	sprite.centered = false
	add_child(sprite)
	overlay = Node2D.new()
	overlay.z_index = 5
	add_child(overlay)
	overlay.draw.connect(_draw_overlay)
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	_build_ui()
	var first := []
	var rest := []
	for id in FaceDB.list_ids():
		var f := FaceDB.load_face(id)
		var t := String(f.get("type", ""))
		if t == "corner" or t == "uturn":
			first.append(id)
		else:
			rest.append(id)
	ids = first + rest
	for id in ids:
		var f := FaceDB.load_face(id)
		picker.add_item(("✎ " if f.get("user_edited", false) else ("✓ " if FaceDB.is_mapped(f) else "• ")) + String(f.get("label", id)))
	if ids.size() > 0:
		_load(0)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	portrait_box = root
	land_box = HBoxContainer.new()
	land_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	land_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(land_box)
	var hsp := Control.new()
	hsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	land_box.add_child(hsp)
	side_panel = UIKit.panel(Color(1, 1, 1, 0.97), 0)
	land_box.add_child(side_panel)
	var ssc := ScrollContainer.new()
	ssc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_panel.add_child(ssc)
	side_inner = VBoxContainer.new()
	side_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ssc.add_child(side_inner)
	var top := UIKit.panel(Color(1, 1, 1, 0.95), 0)
	top_panel = top
	root.add_child(top)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 8)
	top.add_child(tv)
	var row := HBoxContainer.new()
	tv.add_child(row)
	var title := UIKit.label("Mappa le tessere", 28)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var back := UIKit.button("Torna al gioco")
	back.size_flags_horizontal = 0
	back.custom_minimum_size = Vector2(200, 56)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	row.add_child(back)
	picker = OptionButton.new()
	picker.custom_minimum_size = Vector2(0, 56)
	picker.add_theme_font_size_override("font_size", 22)
	picker.item_selected.connect(_load)
	tv.add_child(picker)
	var help := UIKit.rich(17)
	help.text = "[b]Avanti[/b]: tocca due caselle, dalla prima alla seconda: se il passo in avanti c'è sparisce, se non c'è compare.\n[b]Deriva[/b]: lo stesso per le diagonali.\n[b]Caselle[/b]: tocca un punto vuoto per aggiungere una casella, una casella per toglierla."
	tv.add_child(help)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(spacer)
	var bottom := UIKit.panel(Color.WHITE, 24)
	bottom_panel = bottom
	root.add_child(bottom)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 8)
	bottom.add_child(bv)
	status = UIKit.rich(18)
	bv.add_child(status)
	# 1. che cosa sto modificando
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 8)
	bv.add_child(r1)
	for m in [["chain", "Avanti"], ["drift", "Deriva"], ["cells", "Caselle"]]:
		var b := UIKit.button(m[1])
		b.pressed.connect(func():
			mode = m[0]
			chain_last = -1
			drift_from = -1
			if mode == "drift":
				show_drift = true
			if mode == "chain":
				show_fwd = true
			_refresh())
		r1.add_child(b)
		mode_btns[m[0]] = b
	# 2. che cosa vedo
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 8)
	bv.add_child(r2)
	fwd_btn = UIKit.button("Mostra avanti")
	fwd_btn.pressed.connect(func():
		show_fwd = not show_fwd
		_refresh())
	r2.add_child(fwd_btn)
	drift_btn = UIKit.button("Mostra derive")
	drift_btn.pressed.connect(func():
		show_drift = not show_drift
		_refresh())
	r2.add_child(drift_btn)
	var undo := UIKit.button("Annulla")
	undo.pressed.connect(_undo)
	r2.add_child(undo)
	# 3. file
	var r3 := GridContainer.new()
	r3.columns = 2
	r3.add_theme_constant_override("h_separation", 8)
	r3.add_theme_constant_override("v_separation", 8)
	bv.add_child(r3)
	var save := UIKit.button("Salva", true)
	save.pressed.connect(_save)
	r3.add_child(save)
	var inc := UIKit.button("Incorpora nel progetto")
	inc.pressed.connect(_incorporate)
	r3.add_child(inc)
	var reset := UIKit.button("Ripristina originale")
	reset.pressed.connect(_reset_face)
	r3.add_child(reset)
	var folder := UIKit.button("Apri cartella correzioni")
	folder.pressed.connect(func(): OS.shell_open(FaceDB.user_dir_global()))
	r3.add_child(folder)
	for c in r3.get_children():
		(c as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()

func _apply_layout() -> void:
	var sz := get_viewport().get_visible_rect().size
	var land := sz.x > sz.y * 1.1
	side_panel.custom_minimum_size = Vector2(clamp(sz.x * 0.36, 380.0, 470.0), 0)
	var want := "land" if land else "port"
	if want == layout_mode:
		return
	layout_mode = want
	for p in [top_panel, bottom_panel]:
		if p.get_parent():
			p.get_parent().remove_child(p)
	if land:
		side_inner.add_child(top_panel)
		side_inner.add_child(bottom_panel)
		portrait_box.visible = false
		land_box.visible = true
	else:
		portrait_box.add_child(top_panel)
		portrait_box.move_child(top_panel, 0)
		portrait_box.add_child(bottom_panel)
		land_box.visible = false
		portrait_box.visible = true

func _process(_d: float) -> void:
	if cam == null or top_panel == null:
		return
	if layout_mode == "land":
		cam.offset = Vector2(side_panel.size.x * 0.5 / cam.zoom.x, 0)
	else:
		cam.offset = Vector2(0, (bottom_panel.size.y - top_panel.size.y) * 0.5 / cam.zoom.y)

func _load(i: int) -> void:
	face = FaceDB.load_face(ids[i])
	cells = []
	for pt in face.get("cells", []):
		cells.append(FaceDB.v2(pt))
	links = []
	for l in face.get("links", []):
		links.append([int(l[0]), int(l[1])])
	drift_add = []
	for e in face.get("drift_add", []):
		drift_add.append([int(e[0]), int(e[1]), String(e[2])])
	drift_remove = []
	for e in face.get("drift_remove", []):
		drift_remove.append([int(e[0]), int(e[1]), String(e[2])])
	drift_from = -1
	hints = []
	for pt in face.get("hints", []):
		hints.append(FaceDB.v2(pt))
	sprite.texture = FaceDB.load_texture(String(face.get("image", "")))
	var isc := float(face.get("img_scale", 1.0))
	sprite.scale = Vector2.ONE / isc
	chain_last = -1
	undo_stack = []
	dirty = false
	if sprite.texture:
		var sz := sprite.texture.get_size() / isc
		cam.position = sz * 0.5
		var vp := get_viewport_rect().size
		var z: float = min(vp.x / sz.x, (vp.y * 0.55) / sz.y)
		if layout_mode == "land":
			z = min((vp.x - side_panel.custom_minimum_size.x) / sz.x, vp.y / sz.y) * 0.95
		cam.zoom = Vector2(z, z)
	_refresh()

func _snapshot() -> void:
	undo_stack.append([cells.duplicate(), links.duplicate(true), chain_last, drift_add.duplicate(true), drift_remove.duplicate(true)])
	if undo_stack.size() > 200:
		undo_stack.pop_front()

func _undo() -> void:
	if undo_stack.is_empty():
		return
	var s: Array = undo_stack.pop_back()
	cells = s[0]
	links = s[1]
	chain_last = s[2]
	if s.size() > 4:
		drift_add = s[3]
		drift_remove = s[4]
	dirty = true
	_refresh()

func _incorporate() -> void:
	if face.is_empty():
		return
	if dirty:
		_save()
	var id := String(face["id"])
	if not OS.has_feature("editor"):
		# fuori dall'editor il progetto non si può scrivere: si esportano le correzioni in un file
		var where := FaceDB.export_corrections()
		if where == "":
			_refresh("[color=#c93636]Non ci sono correzioni salvate da esportare.[/color]")
		else:
			_refresh("Le correzioni sono salvate e valgono già in tutte le partite su questo dispositivo.\nPer metterle nel progetto (e su tutti i dispositivi) ho preparato il file «snowtails_correzioni.json» (%s): mandalo a Claude." % where)
		return
	var err := FaceDB.incorporate(id)
	var idx := ids.find(id)
	_load(idx)
	picker.set_item_text(idx, ("✎ " if face.get("user_edited", false) else ("✓ " if FaceDB.is_mapped(face) else "• ")) + String(face.get("label", id)))
	_refresh("[color=#c93636]%s[/color]" % err if err != "" else "Correzione incorporata nel progetto (data/faces/%s.json): ora è la versione di base, anche per le esportazioni su iPhone e iPad." % id)

func _reset_face() -> void:
	if face.is_empty():
		return
	var id := String(face["id"])
	FaceDB.reset_face(id)
	var idx := ids.find(id)
	_load(idx)
	picker.set_item_text(idx, ("✓ " if FaceDB.is_mapped(face) else "• ") + String(face.get("label", id)))
	_refresh("Ripristinata la versione automatica.")

func _save() -> void:
	var out := []
	for p in cells:
		out.append([snapped(p.x, 0.1), snapped(p.y, 0.1)])
	face["cells"] = out
	face["links"] = links.duplicate(true)
	face["drift_add"] = drift_add.duplicate(true)
	face["drift_remove"] = drift_remove.duplicate(true)
	face.erase("lanes")
	face.erase("doubts")
	face["mapped"] = FaceDB.is_mapped(face)
	var path := FaceDB.save_face(face)
	face["user_edited"] = true
	dirty = false
	var idx := ids.find(String(face["id"]))
	picker.set_item_text(idx, ("✓ " if face["mapped"] else "• ") + String(face.get("label", face["id"])))
	_refresh(("Correzione salvata, resta valida anche dopo gli aggiornamenti:\n" + path) if path != "" else "[color=#c93636]Salvataggio non riuscito[/color]")

func _isolated() -> Array:
	var used := {}
	for l in links:
		used[l[0]] = true
		used[l[1]] = true
	var out := []
	for i in cells.size():
		if not used.has(i):
			out.append(i)
	return out

func _refresh(msg := "") -> void:
	for k in mode_btns:
		var b: Button = mode_btns[k]
		var sel: bool = k == mode
		var acc := Color("8e4ec6") if k == "drift" else (Color("c9900f") if k == "cells" else UIKit.ACCENT)
		UIKit.style_button(b, acc if sel else UIKit.SOFT, Color.WHITE if sel else UIKit.INK, UIKit.LINE, 2)
	UIKit.style_button(drift_btn, Color("8e4ec6") if show_drift else UIKit.SOFT, Color.WHITE if show_drift else UIKit.INK, UIKit.LINE, 2)
	UIKit.style_button(fwd_btn, UIKit.ACCENT if show_fwd else UIKit.SOFT, Color.WHITE if show_fwd else UIKit.INK, UIKit.LINE, 2)
	var iso := _isolated().size()
	var t := "Caselle [b]%d[/b]   collegamenti [b]%d[/b]" % [cells.size(), links.size()]
	if face.get("user_edited", false) and not dirty:
		t += "   [color=#147f7a]modificata da te[/color]"
	elif face.get("auto", false) and face.has("doubts") and not dirty:
		t += "   [color=#f08c00]riconosciute in automatico, %d da verificare[/color]" % (face["doubts"] as Array).size()
	if iso > 0:
		t += "   [color=#c9900f]senza collegamenti: %d[/color]" % iso
	if dirty:
		t += "   [color=#c93636]non salvato[/color]"
	var tip := ""
	var mode_name: String = {"chain": "AVANTI (passi in avanti)", "drift": "DERIVA (diagonali)", "cells": "CASELLE"}.get(mode, mode)
	t = "[b]Modalità: %s[/b]\n" % mode_name + t
	match mode:
		"cells":
			tip = "Tocca un punto vuoto per aggiungere una casella, una casella per toglierla (con i suoi collegamenti)."
		"drift":
			tip = "Ora tocca la casella d'arrivo: se la diagonale c'è sparisce, se non c'è compare (la freccia punta sempre qui)." if drift_from >= 0 else "Tocca la casella di partenza della deriva, poi quella d'arrivo."
		_:
			tip = "Ora tocca la casella davanti: se il passo c'è sparisce, se non c'è compare." if chain_last >= 0 else "Tocca la casella da cui parte il passo in avanti."
	t += "\n" + tip
	if msg != "":
		t += "\n" + msg
	status.text = t
	_drift_cache = []
	if mode == "drift":
		show_drift = true
	if show_drift and cells.size() > 0:
		var fwd := []
		var bwd := []
		for i in cells.size():
			fwd.append([]); bwd.append([])
		for l in links:
			fwd[l[0]].append(l[1]); bwd[l[1]].append(l[0])
		var heads := []
		var fb := FaceDB.v2(face["entry"]["dir"]).normalized()
		for i in cells.size():
			heads.append(Course.heading_of(cells[i], fwd[i].map(func(j): return cells[j]), bwd[i].map(func(j): return cells[j]), fb))
		_drift_cache = Course.drift_targets(cells, fwd, heads, 97.4, float(face.get("lane_width", 53.8)))
		_auto_drift = [[], []]
		for side in 2:
			for i in cells.size():
				_auto_drift[side].append((_drift_cache[side][i] as Array).duplicate())
		for e in drift_remove:
			if e[0] < cells.size():
				(_drift_cache[0][e[0]] as Array).erase(e[1])
				(_drift_cache[1][e[0]] as Array).erase(e[1])
		for e in drift_add:
			if e[0] < cells.size():
				var sd := 0 if e[2] == "L" else 1
				if not (_drift_cache[sd][e[0]] as Array).has(e[1]):
					(_drift_cache[sd][e[0]] as Array).append(e[1])
		_heads = heads
	overlay.queue_redraw()

func _arrow(a: Vector2, b: Vector2, col: Color, w: float, dashed := false) -> void:
	var d := (b - a)
	var n := d.normalized()
	var a2 := a + n * 12
	var b2 := b - n * 14
	if dashed:
		overlay.draw_dashed_line(a2, b2, col, w, 8)
	else:
		overlay.draw_line(a2, b2, col, w)
	var side := Vector2(-n.y, n.x) * 7
	overlay.draw_colored_polygon(PackedVector2Array([b2 + n * 4, b2 - n * 10 + side, b2 - n * 10 - side]), col)

func _draw_overlay() -> void:
	if face.is_empty():
		return
	var font := ThemeDB.fallback_font
	for h in hints:
		overlay.draw_circle(h, 6, Color(0.3, 0.3, 0.35, 0.45))
	for e in [["entry", Color("30a46c")], ["exit", Color("e5484d")]]:
		var mid := FaceDB.v2(face[e[0]]["mid"])
		var dir := FaceDB.v2(face[e[0]]["dir"]).normalized()
		overlay.draw_line(mid, mid + dir * 70, e[1], 6)
		overlay.draw_circle(mid + dir * 70, 9, e[1])
	# derive: si vedono solo quelle che valgono (calcolate, meno le tolte, più le aggiunte)
	if show_drift and _drift_cache.size() == 2:
		for i in cells.size():
			for j in _drift_cache[0][i]:
				_arrow(cells[i], cells[j], Color(0.15, 0.45, 0.95, 0.85), 2.5, true)
			for j in _drift_cache[1][i]:
				_arrow(cells[i], cells[j], Color(0.56, 0.3, 0.78, 0.85), 2.5, true)
	if show_fwd:
		for l in links:
			_arrow(cells[l[0]], cells[l[1]], Color("147f7a"), 4)
	var iso := _isolated()
	var doubt := {}
	if not dirty:
		for d in face.get("doubts", []):
			doubt[int(d["cell"])] = true
	for i in cells.size():
		var p: Vector2 = cells[i]
		var col := Color("c9900f") if iso.has(i) else Color("1e3550")
		if doubt.has(i):
			overlay.draw_circle(p, 15, Color("f08c00"))
			overlay.draw_string(font, p + Vector2(-14, 6), str(i), HORIZONTAL_ALIGNMENT_CENTER, 28, 16, Color.WHITE)
			continue
		overlay.draw_circle(p, 10, Color.WHITE)
		overlay.draw_arc(p, 10, 0, TAU, 20, col, 3)
		if i == chain_last:
			overlay.draw_arc(p, 16, 0, TAU, 24, Color("30a46c"), 4)
		if i == drift_from:
			overlay.draw_arc(p, 17, 0, TAU, 24, Color("8e4ec6"), 5)
	if show_drift:
		overlay.draw_string(font, Vector2(10, -10), "derive: blu = a sinistra, viola = a destra", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("1e3550"))

func _find_cell(w: Vector2, r: float) -> int:
	var best := -1
	var bd := r
	for i in cells.size():
		var d := w.distance_to(cells[i])
		if d < bd:
			bd = d
			best = i
	return best

func _tap_drift(w: Vector2, r: float) -> void:
	var i := _find_cell(w, r)
	if i < 0:
		drift_from = -1
		_refresh()
		return
	if drift_from < 0 or drift_from == i:
		drift_from = -1 if drift_from == i else i
		_refresh()
		return
	var a := drift_from
	var b := i
	_snapshot()
	# lato: rispetto alla direzione di marcia della casella di partenza
	var h: Vector2 = _heads[a] if a < _heads.size() else Vector2(0, -1)
	var v: Vector2 = cells[b] - cells[a]
	var side := "R" if v.dot(Vector2(-h.y, h.x)) > 0 else "L"
	var auto_has: bool = _auto_drift.size() == 2 and ((_auto_drift[0][a] as Array).has(b) or (_auto_drift[1][a] as Array).has(b))
	var in_add := -1
	for k in drift_add.size():
		if drift_add[k][0] == a and drift_add[k][1] == b: in_add = k
	var in_rem := -1
	for k in drift_remove.size():
		if drift_remove[k][0] == a and drift_remove[k][1] == b: in_rem = k
	var shown_ab: bool = _drift_cache.size() == 2 and ((_drift_cache[0][a] as Array).has(b) or (_drift_cache[1][a] as Array).has(b))
	var shown_ba: bool = _drift_cache.size() == 2 and ((_drift_cache[0][b] as Array).has(a) or (_drift_cache[1][b] as Array).has(a))
	if not shown_ab and shown_ba:
		# c'è la diagonale al contrario: la tolgo, poi aggiungo quella nel verso indicato
		var rk := -1
		for k in drift_add.size():
			if drift_add[k][0] == b and drift_add[k][1] == a: rk = k
		if rk >= 0:
			drift_add.remove_at(rk)
		else:
			var hb: Vector2 = _heads[b] if b < _heads.size() else Vector2(0, -1)
			var vb: Vector2 = cells[a] - cells[b]
			drift_remove.append([b, a, "R" if vb.dot(Vector2(-hb.y, hb.x)) > 0 else "L"])
	if in_add >= 0:
		drift_add.remove_at(in_add)           # toglie una deriva aggiunta a mano
	elif in_rem >= 0:
		drift_remove.remove_at(in_rem)        # rimette una deriva calcolata
	elif auto_has:
		drift_remove.append([a, b, side])     # toglie una deriva calcolata
	else:
		drift_add.append([a, b, side])        # aggiunge una deriva nuova
	dirty = true
	drift_from = -1
	_refresh()

func _tap(w: Vector2) -> void:
	var r := 20.0 / cam.zoom.x
	match mode:
		"drift":
			_tap_drift(w, r)
		"cells":
			_tap_cells(w, r)
		_:
			_tap_forward(w, r)

## Avanti: la prima casella toccata è la partenza, la seconda quella davanti.
## Se il passo esiste (in un verso o nell'altro) sparisce, altrimenti compare.
func _tap_forward(w: Vector2, r: float) -> void:
	var i := _find_cell(w, r)
	if i < 0 or i == chain_last:
		chain_last = -1
		_refresh()
		return
	if chain_last < 0:
		chain_last = i
		_refresh()
		return
	var a := chain_last
	_snapshot()
	var k := links.find([a, i])
	if k < 0:
		k = links.find([i, a])
	if k >= 0:
		links.remove_at(k)
	else:
		links.append([a, i])
	chain_last = -1
	dirty = true
	_refresh()

## Caselle: un punto vuoto aggiunge una casella (agganciata al centro più vicino),
## una casella esistente viene tolta con i suoi collegamenti.
func _tap_cells(w: Vector2, r: float) -> void:
	var i := _find_cell(w, r)
	_snapshot()
	if i < 0:
		var p := w
		var bd := r * 2.0
		for h in hints:
			var d := w.distance_to(h)
			if d < bd:
				bd = d
				p = h
		cells.append(p)
	else:
		cells.remove_at(i)
		var nl := []
		for l in links:
			if l[0] == i or l[1] == i:
				continue
			nl.append([l[0] - (1 if l[0] > i else 0), l[1] - (1 if l[1] > i else 0)])
		links = nl
		for lst in [drift_add, drift_remove]:
			var keep := []
			for e in lst:
				if e[0] == i or e[1] == i:
					continue
				keep.append([e[0] - (1 if e[0] > i else 0), e[1] - (1 if e[1] > i else 0), e[2]])
			lst.clear()
			lst.append_array(keep)
	chain_last = -1
	drift_from = -1
	dirty = true
	_refresh()

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed:
			_touches[ev.index] = ev.position
			if _touches.size() == 1:
				_press = ev.position
				_moved = false
			elif _touches.size() == 2:
				var v: Array = _touches.values()
				_pinch = (v[0] as Vector2).distance_to(v[1])
		else:
			_touches.erase(ev.index)
			if _touches.is_empty() and not _moved:
				_tap(get_canvas_transform().affine_inverse() * ev.position)
	elif ev is InputEventScreenDrag:
		_touches[ev.index] = ev.position
		if _touches.size() == 1:
			if ev.position.distance_to(_press) > 12:
				_moved = true
			if _moved:
				cam.position -= ev.relative / cam.zoom
		elif _touches.size() == 2:
			_moved = true
			var v: Array = _touches.values()
			var d := (v[0] as Vector2).distance_to(v[1])
			if _pinch > 0:
				_zoom(d / _pinch)
			_pinch = d
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(1.1)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.0 / 1.1)

func _zoom(f: float) -> void:
	var z: float = clamp(cam.zoom.x * f, 0.15, 4.0)
	cam.zoom = Vector2(z, z)
