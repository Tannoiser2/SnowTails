extends Node
## Scena principale: menu, flusso dei turni, interfaccia.

const COURSE_DIR := "res://data/courses/"

var course: Course
var game: SledGame
var board: BoardView3D
var hud: CanvasLayer
var top_round: Label
var status_box: VBoxContainer
var chips: HBoxContainer
var log_lbl: RichTextLabel
var bottom_box: VBoxContainer
var modal_layer: CanvasLayer
var modal_root: Control
var top_panel: Control
var bottom_panel: Control
var layout_mode := ""
var portrait_box: VBoxContainer
var portrait_spacer: Control
var land_box: HBoxContainer
var side_panel: PanelContainer
var side_inner: VBoxContainer
var land_left: VBoxContainer
var land_top_holder: MarginContainer

var phase := "menu"
var cur = null          # SledGame.Player
var pending: Array = []
var sel := -1
var outs: Array = []
var slot_order: Array = []
var si := 0
var busy := false

var setup_n := 4
var _preview_sig := ""
var show_paths := false        # anteprima dei percorsi mentre si scelgono le carte
var setup_ai := [false, true, true, true, true]
var course_files: Array = []
var course_idx := 0

static var _window_set := false

func _ready() -> void:
	randomize()
	# sul computer, alla prima apertura la finestra occupa lo schermo
	if not _window_set and not OS.has_feature("mobile") and not OS.has_feature("editor_hint"):
		_window_set = true
		if DisplayServer.get_name() != "headless" and get_window().mode == Window.MODE_WINDOWED:
			get_window().mode = Window.MODE_MAXIMIZED
	_apply_ui_scale()
	board = BoardView3D.new()
	add_child(board)
	board.tapped.connect(_on_board_tap)
	_build_hud()
	_scan_courses()
	show_menu()

# ======================= HUD =======================
func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 1
	add_child(hud)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	# due disposizioni: verticale (pannelli sopra e sotto) e orizzontale (pannello a destra)
	portrait_box = VBoxContainer.new()
	portrait_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_box.add_theme_constant_override("separation", 0)
	root.add_child(portrait_box)
	land_box = HBoxContainer.new()
	land_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	land_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	land_box.add_theme_constant_override("separation", 0)
	root.add_child(land_box)
	# zona della pista: in alto a sinistra galleggia la barra con classifica e messaggi
	land_left = VBoxContainer.new()
	land_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	land_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	land_box.add_child(land_left)
	land_top_holder = MarginContainer.new()
	land_top_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right"]:
		land_top_holder.add_theme_constant_override("margin_" + side, 10)
	land_left.add_child(land_top_holder)
	var lsp := Control.new()
	lsp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lsp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	land_left.add_child(lsp)
	side_panel = UIKit.panel(Color(1, 1, 1, 0.97), 0)
	side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	land_box.add_child(side_panel)
	side_inner = VBoxContainer.new()
	side_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_inner.add_theme_constant_override("separation", 4)
	side_panel.add_child(side_inner)
	var vb := portrait_box
	# barra in alto
	var top := UIKit.panel(Color(1, 1, 1, 0.94), 0)
	top_panel = top
	vb.add_child(top)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 6)
	top.add_child(tv)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	tv.add_child(row)
	top_round = UIKit.label("", 18, UIKit.MUTED)
	var bv := UIKit.button("Segui")
	bv.custom_minimum_size = Vector2(0, 38)
	bv.add_theme_font_size_override("font_size", 17)
	bv.toggle_mode = true
	bv.button_pressed = true
	bv.toggled.connect(func(on):
		board.set_follow(on)
		if on and phase == "replay":
			var pts := []
			for p in game.players:
				if not p.wrecked and p.cell >= 0:
					pts.append(course.cells[p.cell]["pos"])
			board.frame(pts)
		elif on and cur != null and cur.cell >= 0:
			board.focus_cell(cur.cell))
	board.follow_changed.connect(func(on): bv.set_pressed_no_signal(on))
	row.add_child(bv)
	var bh := UIKit.button("Regole")
	bh.custom_minimum_size = Vector2(0, 38)
	bh.add_theme_font_size_override("font_size", 17)
	bh.pressed.connect(show_help)
	row.add_child(bh)
	var bm := UIKit.button("Menu")
	bm.custom_minimum_size = Vector2(0, 38)
	bm.add_theme_font_size_override("font_size", 17)
	bm.pressed.connect(show_menu)
	row.add_child(bm)
	status_box = VBoxContainer.new()
	status_box.add_theme_constant_override("separation", 4)
	tv.add_child(status_box)
	chips = HBoxContainer.new()
	log_lbl = UIKit.rich(16)
	# spazio libero per la pista
	portrait_spacer = Control.new()
	portrait_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(portrait_spacer)
	# pannello in basso
	var bottom := UIKit.panel(Color.WHITE, 26)
	bottom_panel = bottom
	vb.add_child(bottom)
	bottom_box = VBoxContainer.new()
	bottom_box.add_theme_constant_override("separation", 10)
	bottom.add_child(bottom_box)
	# finestre modali
	modal_layer = CanvasLayer.new()
	modal_layer.layer = 5
	add_child(modal_layer)
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()

## Telefono: interfaccia grande; tablet e computer: più compatta, così resta spazio per la pista.
func _apply_ui_scale() -> void:
	var win := get_window()
	var short_px: float = min(win.size.x, win.size.y)
	# sul computer l'interfaccia tiene la stessa grandezza fisica: su uno schermo grande
	# resta più spazio per la pista (sui Retina i pixel vanno divisi per il fattore di scala)
	var dens: float = max(1.0, DisplayServer.screen_get_scale(win.current_screen))
	var sdpi: float = DisplayServer.screen_get_dpi(win.current_screen)
	if sdpi > 150.0:
		dens = max(dens, sdpi / 110.0)
	var base := int(clamp(short_px / dens, 720.0, 900.0))
	if OS.has_feature("mobile"):
		var scr := DisplayServer.screen_get_size()
		var dpi: float = max(DisplayServer.screen_get_dpi(), 1)
		var short_in: float = min(scr.x, scr.y) / dpi
		base = 860 if short_in > 4.5 else 720
	if win.content_scale_size != Vector2i(base, base):
		win.content_scale_size = Vector2i(base, base)

func _toggle_fullscreen() -> void:
	var full := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	if full:
		# sul Mac l'uscita dallo schermo intero è un'animazione: prima finestra, poi ingrandita
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		await get_tree().create_timer(0.8).timeout
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	# ridisegna il menu con l'etichetta giusta dopo il cambio
	if modal_root:
		await get_tree().create_timer(0.3).timeout
		show_menu()

func _is_landscape() -> bool:
	var sz := get_viewport().get_visible_rect().size
	return sz.x > sz.y * 1.1

## Sposta i pannelli fra la disposizione verticale e quella orizzontale.
func _apply_layout() -> void:
	_apply_ui_scale()
	var land := _is_landscape()
	var want := "land" if land else "port"
	var sz := get_viewport().get_visible_rect().size
	side_panel.custom_minimum_size = Vector2(clamp(sz.x * 0.3, 340.0, 460.0), 0)
	if want == layout_mode:
		return
	layout_mode = want
	for p in [top_panel, bottom_panel]:
		if p.get_parent():
			p.get_parent().remove_child(p)
	if land:
		side_inner.add_child(top_panel)
		side_inner.add_child(bottom_panel)
		bottom_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		bottom_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		(top_panel as PanelContainer).add_theme_stylebox_override("panel", UIKit.box(Color(1, 1, 1, 0), 0, Color(0, 0, 0, 0), 0, 6))
		top_panel.size_flags_horizontal = Control.SIZE_FILL
		top_panel.custom_minimum_size = Vector2.ZERO
		(bottom_panel as PanelContainer).add_theme_stylebox_override("panel", UIKit.box(Color(1, 1, 1, 0), 0, Color(0, 0, 0, 0), 0, 6))
		portrait_box.visible = false
		land_box.visible = true
	else:
		top_panel.size_flags_horizontal = Control.SIZE_FILL
		top_panel.custom_minimum_size = Vector2.ZERO
		portrait_box.add_child(top_panel)
		portrait_box.move_child(top_panel, 0)
		portrait_box.add_child(bottom_panel)
		bottom_panel.size_flags_vertical = Control.SIZE_FILL
		bottom_box.size_flags_vertical = Control.SIZE_FILL
		(top_panel as PanelContainer).add_theme_stylebox_override("panel", UIKit.box(Color(1, 1, 1, 0.94), 0, Color(0, 0, 0, 0), 0, 18))
		(bottom_panel as PanelContainer).add_theme_stylebox_override("panel", UIKit.box(Color.WHITE, 26, Color(0, 0, 0, 0), 0, 18))
		land_box.visible = false
		portrait_box.visible = true
	if modal_root and (phase == "menu" or game == null):
		_close_modal()
		show_menu.call_deferred()

const COVER := "res://assets/ui/cover.webp"

func _modal(content: Control, max_w := 700.0, cover := false) -> void:
	_close_modal()
	modal_root = Control.new()
	modal_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(modal_root)
	if cover and ResourceLoader.exists(COVER):
		var tr := TextureRect.new()
		tr.texture = load(COVER)
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		modal_root.add_child(tr)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.07, 0.12, 0.35 if cover else 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_root.add_child(dim)
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal_root.add_child(sc)
	var center := MarginContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vw := get_viewport().get_visible_rect().size.x
	var mx := int(max(24.0, (vw - max_w) * 0.5))
	center.add_theme_constant_override("margin_left", mx)
	center.add_theme_constant_override("margin_right", mx)
	center.add_theme_constant_override("margin_top", 24)
	center.add_theme_constant_override("margin_bottom", 24)
	sc.add_child(center)
	var p := UIKit.panel(Color(1, 1, 1, 0.96), 26)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(p)
	p.add_child(content)

func _close_modal() -> void:
	if modal_root:
		modal_root.queue_free()
		modal_root = null

# ======================= MENU =======================
func _scan_courses() -> void:
	course_files.clear()
	var da := DirAccess.open(COURSE_DIR)
	if da:
		for f in da.get_files():
			if f.ends_with(".json"):
				course_files.append(COURSE_DIR + f)
	course_files.sort()
	var ud := DirAccess.open(CourseEditor.USER_DIR)
	if ud:
		var mine := []
		for f in ud.get_files():
			if f.ends_with(".json"):
				mine.append(CourseEditor.USER_DIR + f)
		mine.sort()
		course_files.append_array(mine)
	var nut := course_files.find(COURSE_DIR + "nutcracker.json")
	course_idx = max(0, course_files.find(COURSE_DIR + "prova.json"))
	var c := Course.new()
	if nut >= 0 and c.load_file(course_files[nut]):
		course_idx = nut

var rnd_diff := 1
var rnd_len := 1
var rnd_def := {}
var _menu_random_box: VBoxContainer
var _menu_preview: CoursePreview
var _menu_count: HBoxContainer
var _menu_rows: VBoxContainer
var _menu_info: Label
var _menu_start: Button

func show_menu() -> void:
	var land := _is_landscape()
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 14)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(UIKit.label("Snow Tails", 44))
	left.add_child(UIKit.label("Corsa di slitte con le tessere della tua copia. Uso personale.", 20, UIKit.MUTED))
	left.add_child(UIKit.label("Percorso", 24))
	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(0, 60)
	ob.add_theme_font_size_override("font_size", 22)
	for i in course_files.size():
		var c := Course.new()
		var ok := c.load_file(course_files[i])
		var nm := c.title if c.title != "" else String(course_files[i]).get_file()
		var tag := "  ✎" if String(course_files[i]).begins_with("user://") else ""
		ob.add_item(nm + tag + ("" if ok else "  (da completare)"), i)
	ob.add_item("Pista casuale", course_files.size())
	ob.selected = course_idx
	ob.item_selected.connect(_menu_pick_course)
	left.add_child(ob)
	_menu_random_box = VBoxContainer.new()
	_menu_random_box.add_theme_constant_override("separation", 8)
	left.add_child(_menu_random_box)
	_menu_build_random()
	_menu_info = UIKit.label("", 19, UIKit.MUTED)
	left.add_child(_menu_info)
	_menu_preview = CoursePreview.new()
	_menu_preview.custom_minimum_size = Vector2(0, 290 if land else 260)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(UIKit.label("Slitte", 24))
	_menu_count = HBoxContainer.new()
	_menu_count.add_theme_constant_override("separation", 8)
	right.add_child(_menu_count)
	_menu_rows = VBoxContainer.new()
	_menu_rows.add_theme_constant_override("separation", 6)
	right.add_child(_menu_rows)
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 10)
	var bmap := UIKit.button("Mappa le tessere")
	bmap.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/mapper.tscn"))
	acts.add_child(bmap)
	var bed := UIKit.button("Crea percorso")
	bed.pressed.connect(func():
		CourseEditor.start_from = course_files[course_idx] if course_idx < course_files.size() else ""
		get_tree().change_scene_to_file("res://scenes/course_editor.tscn"))
	acts.add_child(bed)
	_menu_start = UIKit.button("Inizia la gara", true)
	_menu_start.pressed.connect(start_game)
	acts.add_child(_menu_start)
	var root_box: BoxContainer
	if land:
		root_box = HBoxContainer.new()
		root_box.add_theme_constant_override("separation", 36)
		root_box.add_child(left)
		root_box.add_child(right)
		right.add_child(_menu_preview)
		right.move_child(_menu_preview, 0)
		left.add_child(acts)
	else:
		root_box = VBoxContainer.new()
		root_box.add_theme_constant_override("separation", 14)
		left.add_child(_menu_preview)
		root_box.add_child(left)
		root_box.add_child(right)
		root_box.add_child(acts)
	if game != null and not game.over and phase != "menu":
		var back := UIKit.button("Torna alla gara")
		back.pressed.connect(_close_modal)
		(left if land else root_box).add_child(back)
	if not OS.has_feature("mobile"):
		var fs := UIKit.button("Finestra" if get_window().mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN] else "Schermo intero")
		fs.pressed.connect(_toggle_fullscreen)
		(left if land else root_box).add_child(fs)
	_menu_rebuild_players()
	_menu_refresh_info()
	_modal(root_box, 1040 if land else 700, true)

func _is_random() -> bool:
	return course_idx >= course_files.size()

func _menu_pick_course(i: int) -> void:
	course_idx = i
	_menu_build_random()
	_menu_refresh_info()

func _menu_build_random() -> void:
	UIKit.clear(_menu_random_box)
	_menu_random_box.visible = _is_random()
	if not _is_random():
		return
	for row in [["Difficoltà", ["bassa", "media", "alta"], rnd_diff, "_menu_set_diff"], ["Lunghezza", ["corta", "media", "lunga"], rnd_len, "_menu_set_len"]]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var l := UIKit.label(row[0], 20)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.custom_minimum_size = Vector2(120, 0)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
		for k in 3:
			var b := UIKit.button(row[1][k], k == row[2])
			b.custom_minimum_size = Vector2(0, 52)
			b.pressed.connect(Callable(self, row[3]).bind(k))
			h.add_child(b)
		_menu_random_box.add_child(h)
	var again := UIKit.button("Genera un'altra pista")
	again.pressed.connect(func():
		rnd_def = {}
		_menu_refresh_info())
	_menu_random_box.add_child(again)

func _menu_set_diff(k: int) -> void:
	rnd_diff = k
	rnd_def = {}
	_menu_build_random()
	_menu_refresh_info()

func _menu_set_len(k: int) -> void:
	rnd_len = k
	rnd_def = {}
	_menu_build_random()
	_menu_refresh_info()

func _menu_refresh_info() -> void:
	if _is_random():
		if rnd_def.is_empty() or int(rnd_def.get("difficulty", -1)) != rnd_diff or int(rnd_def.get("length", -1)) != rnd_len:
			var gen := CourseGen.new()
			rnd_def = gen.generate(rnd_diff, rnd_len)
			if rnd_def.is_empty():
				_menu_info.text = gen.last_error
				_menu_start.disabled = true
				_menu_preview.show_message(gen.last_error)
				return
		_menu_info.text = String(rnd_def.get("note", ""))
		_menu_start.disabled = false
		var rc := Course.new()
		if rc.build(rnd_def):
			_menu_preview.show_course(rc)
		return
	var c := Course.new()
	var ok := c.load_file(course_files[course_idx]) if course_files.size() > 0 else false
	var t := c.note
	if not ok:
		t = c.error + (". Usa «Mappa le tessere»." if not c.missing.is_empty() else "")
	_menu_info.text = t
	_menu_start.disabled = not ok
	if ok:
		_menu_preview.show_course(c)
	else:
		_menu_preview.show_message("Anteprima non disponibile: " + c.error)

func _menu_set_n(n: int) -> void:
	setup_n = n
	_menu_rebuild_players()

func _menu_set_ai(i: int, v: bool) -> void:
	setup_ai[i] = v
	_menu_rebuild_players()

func _menu_rebuild_players() -> void:
	UIKit.clear(_menu_count)
	for n in [2, 3, 4, 5]:
		var b := UIKit.button(str(n), n == setup_n)
		b.custom_minimum_size = Vector2(70, 56)
		b.size_flags_horizontal = 0
		b.pressed.connect(_menu_set_n.bind(n))
		_menu_count.add_child(b)
	var humans := 0
	for i in setup_n:
		if not setup_ai[i]: humans += 1
	var summary := UIKit.label("%d %s, %d CPU" % [humans, "persona" if humans == 1 else "persone", setup_n - humans], 18, UIKit.MUTED)
	summary.autowrap_mode = TextServer.AUTOWRAP_OFF
	summary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_menu_count.add_child(summary)
	UIKit.clear(_menu_rows)
	for i in setup_n:
		var r := HBoxContainer.new()
		var dot := ColorRect.new()
		dot.color = SledGame.COLORS[i]
		dot.custom_minimum_size = Vector2(26, 26)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(dot)
		var nm := UIKit.label("  " + SledGame.NAMES[i], 24)
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(nm)
		var bp := UIKit.button("Persona", not setup_ai[i])
		bp.custom_minimum_size = Vector2(130, 52)
		bp.size_flags_horizontal = 0
		bp.pressed.connect(_menu_set_ai.bind(i, false))
		r.add_child(bp)
		var bc := UIKit.button("CPU", setup_ai[i])
		bc.custom_minimum_size = Vector2(100, 52)
		bc.size_flags_horizontal = 0
		bc.pressed.connect(_menu_set_ai.bind(i, true))
		r.add_child(bc)
		_menu_rows.add_child(r)

func show_help() -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.add_child(UIKit.label("Come si gioca", 36))
	var r := UIKit.rich(21)
	r.add_theme_color_override("default_color", UIKit.INK)
	r.text = """[b]La slitta.[/b] Due cani e un freno, tutti a 3 all'inizio. Velocità = cane sinistro + cane destro − freno. Deriva = differenza fra i cani: ti sposti in diagonale verso il cane più forte (mai più della velocità), nei passi che scegli tu.

[b]Il turno.[/b] Giochi da 1 a 3 carte dello stesso valore, al massimo una per spazio. Le carte sui cani restano; quella sul freno lo imposta e va negli scarti. Poi torni a 5 carte. Le ammaccature occupano posto in mano e non si scartano.

[b]Equilibrio.[/b] Con i cani uguali puoi aggiungere un bonus pari alla tua posizione, tutto dritto, a fine movimento. Non al primo turno.

[b]Pericoli.[/b] Entrare in una curva oltre il limite: un'ammaccatura per punto di troppo (il bonus conta). Leap of Death: la spaccatura va saltata a velocità 5 o più, altrimenti un'ammaccatura per ogni punto che manca; chi si ferma sulle caselle della spaccatura non pesca. Bordo: ti fermi e prendi un'ammaccatura. Tamponamento: ti fermi dietro e non peschi. Alla quinta ammaccatura la slitta è distrutta.

[b]Fine.[/b] Si corre finché tutte le slitte hanno tagliato il traguardo; chi è arrivato smette di muovere. In classifica conta prima il giro in cui si taglia il traguardo, poi, a parità di giro, chi è andato più lontano oltre la linea.

[b]Comandi.[/b] Un dito trascina la pista; due dita: avvicini o allontani, ruoti la vista e, spostandole insieme in su o in giù, cambi l'inclinazione. Col mouse: rotellina per lo zoom, tasto destro per ruotare e inclinare. «Segui» fa girare la telecamera nel senso di marcia della slitta di turno.

[b]Tastiera.[/b] 1–5 sceglie una carta di quel valore; A, S, D (o frecce sinistra, giù, destra) la mettono su cane sinistro, freno, cane destro; Invio muove; Backspace riprende le carte; Esc torna indietro o apre il menu. Tocca una carta e poi uno spazio della plancia; poi «Muovi» e tocca la destinazione."""
	vb.add_child(r)
	var b := UIKit.button("Chiudi", true)
	b.pressed.connect(_close_modal)
	vb.add_child(b)
	_modal(vb)

# ======================= PARTITA =======================
func start_game() -> void:
	course = Course.new()
	if _is_random():
		if rnd_def.is_empty() or not course.build(rnd_def):
			return
	elif not course.load_file(course_files[course_idx]):
		return
	_close_modal()
	game = SledGame.new()
	game.setup(course, setup_ai.slice(0, setup_n))
	board.setup(course, game)
	slot_order = game.players.duplicate()
	slot_order.shuffle()
	si = 0
	board.set_follow(true)
	board.focus_cell(course.start_cells[2], true)
	board.frame([course.cells[course.start_cells[0]]["pos"], course.cells[course.start_cells[4]]["pos"]], 5.5, true)
	_next_slot()

func _next_slot() -> void:
	if si >= slot_order.size():
		board.slot_markers = []
		game.deal_all()
		game.log_text = "Si parte! Al primo turno niente bonus di equilibrio."
		board.dist_goal = 3.6
		_begin_round()
		return
	cur = slot_order[si]
	var free := game.free_slots()
	board.slot_markers = []
	for k in free:
		var txt := str(k + 1) + ("+" + str(k - 2) if k >= 3 else "")
		board.slot_markers.append({"cell": course.start_cells[k], "text": txt, "color": cur.color})
	if cur.ai:
		phase = "slotsAI"
		game.log_text = "[b]%s[/b] sceglie la partenza…" % cur.name
		_refresh()
		await get_tree().create_timer(0.45).timeout
		var pick: int = free[0] if randf() < 0.5 else free[randi() % free.size()]
		_take_slot(pick)
	else:
		phase = "slots"
		game.log_text = "[b]%s[/b], tocca la casella di partenza sulla pista" % cur.name
		_refresh()

func _take_slot(k: int) -> void:
	game.take_slot(cur, k)
	si += 1
	_next_slot()

func _begin_round() -> void:
	game.order = game.race_order()
	game.oi = 0
	_next_turn()

func _next_turn() -> void:
	if game.over:
		return
	while game.oi < game.order.size() and not game.racing(game.order[game.oi]):
		game.oi += 1
	if game.oi >= game.order.size():
		if game.check_round_end():
			_show_results()
		else:
			_begin_round()
		return
	cur = game.order[game.oi]
	pending = []
	sel = -1
	outs = []
	board.destinations = []
	if cur.hand.is_empty():
		var c0: int = cur.cell
		game.add_dent(cur, 1)
		game.record(cur, c0, [], [])
		game.log_text = "[b]%s[/b] non ha carte cane: prende un'ammaccatura" % cur.name
		if cur.wrecked:
			game.oi += 1
			_refresh()
			await get_tree().create_timer(0.9).timeout
			_next_turn()
			return
		game.draw_up(cur)
	board.focus_cell(cur.cell)
	if cur.ai:
		phase = "ai"
		_refresh()
		await get_tree().create_timer(0.75).timeout
		var ch := game.ai_choose(cur)
		_apply_choice(ch["pend"], ch["o"])
	else:
		phase = "cards"
		_refresh()

func _apply_choice(pend: Array, o: Dictionary) -> void:
	var p = cur
	var start_cell: int = p.cell
	var m := game.mat_after(p, pend)
	game.log_text = "[b]%s[/b]: %s" % [p.name, game.describe(pend, o, m)]
	game.commit_play(p, pend)
	phase = "anim"
	pending = []
	sel = -1
	outs = []
	board.destinations = []
	_refresh()
	await get_tree().create_timer(0.15).timeout
	var sap_hit: Array = o.get("sap", [])
	var prev_c: int = start_cell
	for t in o["path"]:
		p.cell = t
		board.focus_cell(t)
		if sap_hit.has(t):
			board.knock_sapling(t, (course.cells[t]["pos"] - course.cells[prev_c]["pos"]).normalized())
			game.saplings.erase(t)
		board.redraw()
		prev_c = t
		await get_tree().create_timer(0.17).timeout
	game.last_fx = _fx_of(p, o)
	if _play_fx(game.last_fx):
		await get_tree().create_timer(0.45).timeout
	var need_discard := game.after_move(p, o)
	game.record(p, start_cell, o["path"], o.get("sap", []))
	if need_discard:
		phase = "discard"
		_refresh()
		return
	_end_turn()

func _end_turn() -> void:
	game.oi += 1
	_refresh()
	await get_tree().create_timer(0.35).timeout
	_next_turn()

func _show_results() -> void:
	phase = "over"
	var r0 = game.results[0] if game.results.size() > 0 else null
	game.log_text = ("[b]%s[/b] vince la corsa!" % r0["p"].name) if r0 and String(r0["st"]).begins_with("arrivata") else "Corsa finita."
	_refresh()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.add_child(UIKit.label("Classifica", 40))
	vb.add_child(UIKit.label("Dopo %d giri" % game.round_n, 20, UIKit.MUTED))
	var i := 0
	for r in game.results:
		i += 1
		var card := PanelContainer.new()
		var first: bool = i == 1 and String(r["st"]).begins_with("arrivata")
		card.add_theme_stylebox_override("panel", UIKit.box(Color("fff6d6") if first else UIKit.SOFT, 16, r["p"].color if first else Color(0, 0, 0, 0), 2 if first else 0, 14))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		card.add_child(row)
		var pos := UIKit.label("✕" if r["st"] == "distrutta" else str(i), 34, UIKit.INK)
		pos.autowrap_mode = TextServer.AUTOWRAP_OFF
		pos.custom_minimum_size = Vector2(40, 0)
		pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pos.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pos)
		var dot := ColorRect.new()
		dot.color = r["p"].color
		dot.custom_minimum_size = Vector2(12, 0)
		row.add_child(dot)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		row.add_child(col)
		var nm := UIKit.label(r["p"].name + ("" if r["p"].ai else "  (tu)"), 26)
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		col.add_child(nm)
		var dd: int = r["p"].dents
		var st := UIKit.label(String(r["st"]).capitalize() if false else String(r["st"]) + ("" if dd == 0 or r["st"] == "distrutta" else "  ·  %d ammaccatur%s" % [dd, "a" if dd == 1 else "e"]), 19, UIKit.MUTED)
		col.add_child(st)
		vb.add_child(card)
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 10)
	var b0 := UIKit.button("Rivedi la gara")
	b0.pressed.connect(start_replay)
	b0.disabled = game.history.is_empty()
	acts.add_child(b0)
	var b1 := UIKit.button("Guarda la pista")
	b1.pressed.connect(_close_modal)
	acts.add_child(b1)
	var b2 := UIKit.button("Nuova gara", true)
	b2.pressed.connect(show_menu)
	acts.add_child(b2)
	vb.add_child(acts)
	_modal(vb, 760)

## Effetti di fine mossa (urti e sbandate), registrati anche per il replay.
func _fx_of(p, o: Dictionary) -> Dictionary:
	var fx := {"pid": p.id, "cell": o["end"], "crash": String(o["crash"])}
	if o.has("hit_dir"):
		fx["dir"] = [o["hit_dir"].x, o["hit_dir"].y]
	if o.has("hit_cell"):
		var other := -1
		for q in game.players:
			if q != p and q.cell == int(o["hit_cell"]):
				other = q.id
		fx["other"] = other
	fx["skid"] = int(o.get("corner_dents", 0)) > 0
	return fx

func _play_fx(fx: Dictionary) -> bool:
	if fx.is_empty():
		return false
	var crash := String(fx.get("crash", ""))
	if (crash == "edge" or crash == "sled") and fx.has("dir"):
		board.crash_fx(int(fx["cell"]), Vector2(fx["dir"][0], fx["dir"][1]), int(fx["pid"]), int(fx.get("other", -1)))
		return true
	if fx.get("skid", false):
		board.skid_fx(int(fx["cell"]), int(fx["pid"]))
		return true
	return false

# ======================= REPLAY =======================
var replay_speed := 1.0
var replay_paused := false
var replay_stop := false
var replay_round := 0
var replay_carry := 0.0

## Rivede la gara giro per giro: in ogni giro tutte le slitte partono insieme dalla casella
## di partenza e arrivano insieme alla casella d'arrivo; chi fa più strada va più veloce.
func start_replay() -> void:
	if game == null or game.history.is_empty():
		return
	_close_modal()
	# stato finale da ripristinare alla fine
	var final := {}
	for p in game.players:
		final[p.id] = {"cell": p.cell, "dents": p.dents, "wrecked": p.wrecked}
	var final_saps: Dictionary = game.saplings.duplicate()
	# stato iniziale
	for p in game.players:
		p.cell = game.start_record.get(p.id, p.cell)
		p.dents = 0
		p.wrecked = false
	game.saplings = game.initial_saplings.duplicate()
	board.set_follow(true)
	replay_stop = false
	replay_paused = false
	phase = "replay"
	board.current_id = -1
	board.destinations = []
	board.redraw()
	for p in game.players:
		board.replay[p.id] = {"pos": BoardView3D.to3(course.cells[p.cell]["pos"], 0.004), "dir": course.heading(p.cell), "run": 0.0}
	var total := game.history.size()
	for r in total:
		if replay_stop:
			break
		replay_round = r + 1
		game.log_text = "[b]Replay[/b] — giro %d di %d" % [replay_round, total]
		_refresh()
		var moves: Array = game.history[r]
		# percorsi in coordinate 3D e lunghezze
		var paths := []
		var pts_all := []
		for mv in moves:
			var pts := []
			for id in mv["path"]:
				pts.append(BoardView3D.to3(course.cells[id]["pos"], 0.004))
				pts_all.append(course.cells[id]["pos"])
			var lens := [0.0]
			for k in range(1, pts.size()):
				lens.append(lens[k - 1] + (pts[k] as Vector3).distance_to(pts[k - 1]))
			paths.append({"mv": mv, "pts": pts, "lens": lens})
		board.frame(pts_all, 3.6)      # solo se «Segui» è attivo
		var dur := 1.8
		var t: float = max(replay_carry, 0.0)
		replay_carry = 0.0
		while t < dur:
			if replay_stop:
				break
			await get_tree().process_frame
			if replay_paused:
				continue
			t += get_process_delta_time() * replay_speed
			var f: float = clamp(t / dur, 0.0, 1.0)   # velocità costante: il giro dopo riparte subito
			for pa in paths:
				var mv: Dictionary = pa["mv"]
				var pts: Array = pa["pts"]
				var lens: Array = pa["lens"]
				var L: float = lens[lens.size() - 1]
				if pts.size() < 2 or L <= 0.0:
					board.replay[mv["pid"]]["run"] = 0.0
					continue
				var d: float = f * L
				var k := 1
				while k < lens.size() - 1 and lens[k] < d:
					k += 1
				var seg: float = max(lens[k] - lens[k - 1], 0.0001)
				var u: float = clamp((d - lens[k - 1]) / seg, 0.0, 1.0)
				var pos: Vector3 = (pts[k - 1] as Vector3).lerp(pts[k], u)
				var dv: Vector3 = (pts[k] as Vector3) - (pts[k - 1] as Vector3)
				board.replay[mv["pid"]]["pos"] = pos
				board.replay[mv["pid"]]["dir"] = Vector2(dv.x, dv.z).normalized()
				board.replay[mv["pid"]]["run"] = 1.0
		# fine del giro: urti, alberelli travolti, posizioni, ammaccature, distruzioni
		for mv in moves:
			_play_fx(mv.get("fx", {}))
			var pth: Array = mv["path"]
			for sp in mv["sap"]:
				var k := pth.find(sp)
				var dv := Vector2(0, -1)
				if k > 0:
					dv = (course.cells[sp]["pos"] - course.cells[pth[k - 1]]["pos"]).normalized()
				board.knock_sapling(int(sp), dv)
		for mv in moves:
			var p = game.players[mv["pid"]]
			p.cell = mv["end"] if not mv["wrecked"] else -1
			p.dents = mv["dents"]
			p.wrecked = mv["wrecked"]
			for sp in mv["sap"]:
				game.saplings.erase(sp)
		# il tempo avanzato oltre la fine del giro passa al giro successivo: nessuno scatto
		replay_carry = t - dur
		board.redraw()
		_refresh()
	# ripristina lo stato finale
	for p in game.players:
		board.replay[p.id]["run"] = 0.0
	for p in game.players:
		p.cell = final[p.id]["cell"]
		p.dents = final[p.id]["dents"]
		p.wrecked = final[p.id]["wrecked"]
	game.saplings = final_saps
	board.replay.clear()
	board.redraw()
	_show_results()

# ======================= INTERAZIONE =======================
## Tastiera (computer): 1-5 carta, A/S/D o frecce = cane sx/freno/cane dx,
## Invio = muovi, Backspace = riprendi le carte, Esc = indietro o menu.
func _unhandled_key_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	var k: int = ev.keycode
	if k == KEY_ESCAPE:
		if modal_root:
			if game != null and phase != "menu":
				_close_modal()
		elif phase == "replay":
			replay_stop = true
		elif phase == "dest":
			_back_to_cards()
		else:
			show_menu()
		return
	if modal_root or game == null or cur == null or cur.ai:
		return
	if k >= KEY_1 and k <= KEY_5:
		var v := k - KEY_0
		for i in cur.hand.size():
			if cur.hand[i] == v and not _reserved(i):
				_tap_card(i)
				return
	elif phase == "cards":
		match k:
			KEY_A, KEY_LEFT: _tap_slot("L")
			KEY_S, KEY_DOWN: _tap_slot("B")
			KEY_D, KEY_RIGHT: _tap_slot("R")
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: _confirm()
			KEY_BACKSPACE:
				pending = []
				sel = -1
				_refresh()
func _on_board_tap(w: Vector2) -> void:
	if modal_root != null or course == null or phase == "replay":
		return
	var best := -1
	var bd := course.lane_w * 0.95
	if phase == "slots":
		for k in game.free_slots():
			var d: float = w.distance_to(course.cells[course.start_cells[k]]["pos"])
			if d < bd:
				bd = d
				best = k
		if best >= 0:
			_take_slot(best)
	elif phase == "dest":
		for i in outs.size():
			var d: float = w.distance_to(course.cells[outs[i]["end"]]["pos"])
			if d < bd:
				bd = d
				best = i
		if best >= 0:
			_apply_choice(pending.duplicate(), outs[best])

func _tap_card(i: int) -> void:
	if phase == "discard":
		cur.discard.append(cur.hand[i])
		cur.hand.remove_at(i)
		if game.hand_size(cur) <= 5 or cur.hand.is_empty():
			_end_turn()
		else:
			_refresh()
		return
	if phase != "cards":
		return
	for j in pending.size():
		if pending[j]["hi"] == i:
			pending.remove_at(j)
			_refresh()
			return
	if pending.size() > 0 and cur.hand[i] != pending[0]["v"]:
		return
	sel = -1 if sel == i else i
	_refresh()

func _tap_slot(k: String) -> void:
	if phase != "cards":
		return
	for j in pending.size():
		if pending[j]["slot"] == k:
			pending.remove_at(j)
			sel = -1
			_refresh()
			return
	if sel < 0:
		if pending.size() > 0:
			var v: int = pending[0]["v"]
			for i in cur.hand.size():
				if cur.hand[i] == v and not _reserved(i):
					pending.append({"slot": k, "hi": i, "v": v})
					_refresh()
					return
		return
	pending.append({"slot": k, "hi": sel, "v": cur.hand[sel]})
	sel = -1
	_refresh()

func _reserved(i: int) -> bool:
	for x in pending:
		if x["hi"] == i:
			return true
	return false

func _confirm() -> void:
	if pending.is_empty():
		return
	var m := game.mat_after(cur, pending)
	outs = game.compute_outs(cur, m)
	if outs.size() == 1 and outs[0]["path"].is_empty() and outs[0]["dents"] == 0:
		_apply_choice(pending.duplicate(), outs[0])
		return
	phase = "dest"
	board.destinations = []
	var far := 0.0
	var far_pos: Vector2 = course.cells[cur.cell]["pos"]
	for o in outs:
		var lbl := ""
		var col := Color("147f7a")
		if o["dents"] > 0:
			lbl = "−%d" % o["dents"]
			col = Color("d23a3a")
		elif o["crash"] == "sled":
			lbl = "urto"
			col = Color("c9900f")
		if o["bonus"]:
			lbl += (" " if lbl != "" else "") + "+B"
		board.destinations.append({"cell": o["end"], "label": lbl, "color": col, "path": o["path"], "from": cur.cell})
		var s: float = course.cells[o["end"]]["s"]
		if s > far:
			far = s
			far_pos = course.cells[o["end"]]["pos"]
	var pts := [course.cells[cur.cell]["pos"]]
	for o in outs:
		pts.append(course.cells[o["end"]]["pos"])
	board.frame(pts)
	_refresh()

func _back_to_cards() -> void:
	phase = "cards"
	outs = []
	board.destinations = []
	_refresh()

# ======================= RENDER =======================
func _refresh() -> void:
	board.current_id = cur.id if cur != null and phase != "over" else -1
	board.preview = []
	var sig := ""
	if show_paths and phase == "cards" and cur != null and not cur.ai and pending.size() > 0:
		var m := game.mat_after(cur, pending)
		# tutti i percorsi distinti (non solo uno per casella d'arrivo)
		var seen := {}
		var pts := [course.cells[cur.cell]["pos"]]
		for o in game.compute_outs(cur, m, true):
			var key := str(o["path"])
			if seen.has(key) or seen.size() >= 60:
				continue
			seen[key] = true
			board.preview.append({"path": o["path"], "from": cur.cell, "end": o["end"], "dents": o["dents"], "color": cur.color})
			pts.append(course.cells[o["end"]]["pos"])
		sig = "%d|%s" % [cur.cell, str(m)]
		if sig != _preview_sig:
			board.frame(pts)
	_preview_sig = sig
	board.redraw()
	_render_top()
	_render_bottom()

func _process(_d: float) -> void:
	if board and top_panel and bottom_panel:
		if layout_mode == "land":
			board.hud_top = 0.0
			board.hud_bottom = 0.0
			board.hud_right = side_panel.size.x
		else:
			board.hud_top = top_panel.size.y
			board.hud_bottom = bottom_panel.size.y
			board.hud_right = 0.0

func _render_top() -> void:
	if game == null or status_box == null:
		return
	UIKit.clear(status_box)
	# 1. giro e turno
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var rnd := UIKit.label("Schieramento" if phase.begins_with("slots") else ("Replay %d/%d" % [replay_round, game.history.size()] if phase == "replay" else "Giro %d" % game.round_n), 16, UIKit.INK)
	rnd.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(rnd)
	if cur != null and phase != "over" and phase != "replay":
		var who := UIKit.label("·  tocca a %s%s" % [cur.name, "" if cur.ai else " (tu)"], 16, cur.color.darkened(0.25))
		who.autowrap_mode = TextServer.AUTOWRAP_OFF
		head.add_child(who)
	status_box.add_child(head)
	# 2. posizioni in gara
	var flow := HBoxContainer.new()
	flow.add_theme_constant_override("separation", 3)
	var order := game.race_order()
	var all := order.duplicate()
	for p in game.players:
		if p.wrecked:
			all.append(p)
	for p in all:
		var pc := PanelContainer.new()
		var border: Color = p.color if (cur != null and p == cur and phase != "over") else Color(0, 0, 0, 0)
		pc.add_theme_stylebox_override("panel", UIKit.box(UIKit.SOFT, 9, border, 2, 3))
		pc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var t: String = ("✕ " if p.wrecked else str(order.find(p) + 1) + " ") + p.name
		if p.dents > 0:
			t += "" + "▪".repeat(p.dents)
		if game.is_finished(p):
			t += " 🏁"
		var l := UIKit.label(t, 13, p.color.darkened(0.3))
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		pc.add_child(l)
		flow.add_child(pc)
	status_box.add_child(flow)
	# 3. numeri della slitta di turno (con le carte in attesa di conferma)
	if cur != null and not cur.wrecked and cur.cell >= 0 and phase not in ["over", "replay", "slots", "slotsAI"]:
		status_box.add_child(_stat_grid())
	# 4. che cosa fare adesso e ultima mossa: spazio fisso, così sotto non si muove niente
	status_box.add_child(_fixed_box(_action_text(), Color("e3f2f0"), UIKit.INK, 13))
	status_box.add_child(_fixed_box(game.log_text, UIKit.SOFT, UIKit.MUTED, 12))

## Riquadro di testo ad altezza fissa (due righe): il contenuto cambia, l'ingombro no.
func _fixed_box(text: String, bg: Color, col: Color, fsize: int) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UIKit.box(bg if text != "" else Color(bg, 0.45), 8, Color(0, 0, 0, 0), 0, 5))
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = false
	r.scroll_active = false
	r.clip_contents = true
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(0, int(fsize * 2.6))
	r.add_theme_font_size_override("normal_font_size", fsize)
	r.add_theme_font_size_override("bold_font_size", fsize)
	r.add_theme_color_override("default_color", col)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.text = text
	pc.add_child(r)
	return pc

func _tile(title: String, value: String, warn := false) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", UIKit.box(Color("fdecea") if warn else UIKit.SOFT, 8, UIKit.DANGER if warn else Color(0, 0, 0, 0), 2 if warn else 0, 4))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	pc.add_child(v)
	var t := UIKit.label(title, 11, UIKit.MUTED)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(t)
	var val := UIKit.label(value, 15, UIKit.DANGER if warn else UIKit.INK)
	val.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(val)
	return pc

func _stat_grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 5)
	g.add_theme_constant_override("v_separation", 5)
	var m := game.mat_after(cur, pending if (phase == "cards" or phase == "dest") else [])
	var speed: int = max(0, m["L"] + m["R"] - m["B"])
	var d: int = m["R"] - m["L"]
	var c: Dictionary = course.cells[cur.cell]
	g.add_child(_tile("Velocità", str(speed)))
	g.add_child(_tile("Deriva", "0" if d == 0 else "%d %s" % [min(abs(d), speed), "→" if d > 0 else "←"]))
	var bonus := "—"
	if d == 0 and cur.moves > 0 and speed > 0:
		bonus = "+%d" % game.rank_of(cur)
	g.add_child(_tile("Bonus", bonus))
	g.add_child(_tile("Ammacc.", "%d / 4" % cur.dents, cur.dents >= 3))
	var nl := course.next_limit(float(c["s"]))
	if not nl.is_empty():
		var dist := int(round((float(nl["s"]) - float(c["s"])) / course.cell_len))
		g.add_child(_tile("Curva lim. %d" % nl["lim"], "fra %d" % max(dist, 0), speed > int(nl["lim"]) and dist <= speed))
	else:
		var df := int(round((course.finish_s - float(c["s"])) / course.cell_len))
		g.add_child(_tile("Traguardo", ("fra %d" % df) if df > 0 else "passato"))
	var lp := course.next_leap(float(c["s"]))
	if not lp.is_empty() and (float(lp["s"]) - float(c["s"])) / course.cell_len <= 14:
		var dl := int(round((float(lp["s"]) - float(c["s"])) / course.cell_len))
		g.add_child(_tile("Salto min. %d" % lp["min"], "fra %d" % max(dl, 0), speed < int(lp["min"]) and dl <= speed))
	g.add_child(_tile("Mazzo", str(cur.deck.size())))
	g.add_child(_tile("Scarti", str(cur.discard.size() + cur.used.size())))
	if not cur.ai:
		var tb := Button.new()
		tb.toggle_mode = true
		tb.button_pressed = show_paths
		tb.text = "Percorsi\n%s" % ("sì" if show_paths else "no")
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.add_theme_font_size_override("font_size", 12)
		tb.custom_minimum_size = Vector2(0, 0)
		var on_col: Color = cur.color
		UIKit.style_button(tb, on_col if show_paths else UIKit.SOFT, Color.WHITE if show_paths else UIKit.INK, on_col, 2, 10)
		tb.tooltip_text = "Mostra sulla pista tutti i percorsi possibili con le carte messe sulla plancia"
		tb.toggled.connect(func(on):
			show_paths = on
			_refresh())
		g.add_child(tb)
	return g

func _action_text() -> String:
	match phase:
		"slots":
			return "Tocca un cerchio sulla pista per scegliere la partenza (4ª e 5ª: carte in più)."
		"slotsAI":
			return "Le slitte si schierano…"
		"dest":
			return "Tocca sulla pista la casella d'arrivo ([b]−n[/b] ammaccature, [b]+B[/b] bonus)."
		"discard":
			if cur != null:
				return "Scarta [b]%d[/b] carta/e dalla mano." % (game.hand_size(cur) - 5)
		"ai":
			if cur != null:
				return "[b]%s[/b] (CPU) sta guidando…" % cur.name
		"replay":
			return "Replay: le slitte si muovono insieme."
	return ""

func _render_bottom() -> void:
	UIKit.clear(bottom_box)
	if game == null:
		return
	match phase:
		"slots", "slotsAI":
			return
		"replay":
			var rr := HBoxContainer.new()
			rr.add_theme_constant_override("separation", 10)
			var bp := UIKit.button("Riprendi" if replay_paused else "Pausa")
			bp.pressed.connect(func():
				replay_paused = not replay_paused
				_refresh())
			rr.add_child(bp)
			var bs := UIKit.button("Velocità ×%d" % int(replay_speed))
			bs.pressed.connect(func():
				replay_speed = 1.0 if replay_speed >= 4.0 else replay_speed * 2.0
				_refresh())
			rr.add_child(bs)
			var bx := UIKit.button("Esci dal replay", true)
			bx.pressed.connect(func(): replay_stop = true)
			rr.add_child(bx)
			bottom_box.add_child(rr)
			return
		"over":
			bottom_box.add_child(_hint(game.log_text))
			var b := UIKit.button("Classifica", true)
			b.pressed.connect(_show_results)
			bottom_box.add_child(b)
			return
	if cur == null:
		return
	if cur.wrecked:
		bottom_box.add_child(_hint("[b]%s[/b]: la slitta è distrutta." % cur.name))
		return
	var use_pending := phase == "cards" or phase == "dest"
	var m := game.mat_after(cur, pending if use_pending else [])
	bottom_box.add_child(_mat(m, phase == "cards" and not cur.ai))
	if cur.ai:
		var me = null
		for q in game.players:
			if not q.ai and not q.wrecked:
				me = q
				break
		if me != null:
			var tl := UIKit.label("La tua mano", 15, UIKit.MUTED)
			bottom_box.add_child(tl)
			bottom_box.add_child(_hand(me, false, true))
		return
	bottom_box.add_child(_hand(cur, phase == "cards" or phase == "discard"))
	if phase == "cards":
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var b1 := UIKit.button("Riprendi le carte")
		b1.custom_minimum_size = Vector2(0, 44)
		b1.add_theme_font_size_override("font_size", 17)
		b1.disabled = pending.is_empty() and sel < 0
		b1.pressed.connect(func():
			pending = []
			sel = -1
			_refresh())
		row.add_child(b1)
		var b2 := UIKit.button("Muovi la slitta", true)
		b2.custom_minimum_size = Vector2(0, 44)
		b2.add_theme_font_size_override("font_size", 17)
		b2.disabled = pending.is_empty()
		b2.pressed.connect(_confirm)
		row.add_child(b2)
		bottom_box.add_child(row)
	elif phase == "dest":
		var b3 := UIKit.button("Cambia carte")
		b3.custom_minimum_size = Vector2(0, 44)
		b3.add_theme_font_size_override("font_size", 17)
		b3.pressed.connect(_back_to_cards)
		bottom_box.add_child(b3)

func _hint(t: String) -> RichTextLabel:
	var r := UIKit.rich(21)
	r.text = t
	return r

func _mat(_m: Dictionary, interactive: bool) -> MatView:
	var mv := MatView.new()
	var pend := []
	if phase == "cards" or phase == "dest":
		for x in pending:
			pend.append({"slot": x["slot"], "v": x["v"]})
	mv.custom_minimum_size = Vector2(0, 70 if layout_mode == "land" else 210)
	mv.size_flags_vertical = Control.SIZE_EXPAND_FILL if layout_mode == "land" else Control.SIZE_FILL
	mv.slot_tapped.connect(_tap_slot)
	mv.setup.call_deferred(cur, pend, interactive, interactive and sel >= 0)
	return mv

func _stats(m: Dictionary) -> RichTextLabel:
	var speed: int = m["L"] + m["R"] - m["B"]
	var d: int = m["R"] - m["L"]
	var t := "Velocità [b]%s[/b]" % (str(speed) if speed > 0 else "0, ferma")
	if d != 0:
		t += "   Deriva [b]%d %s[/b]" % [min(abs(d), max(speed, 0)), "a destra" if d > 0 else "a sinistra"]
	elif cur.moves == 0:
		t += "   In equilibrio, bonus dal secondo turno"
	else:
		t += "   In equilibrio, bonus [b]+%d[/b]" % game.rank_of(cur)
	var c: Dictionary = course.cells[cur.cell]
	var nl := course.next_limit(float(c["s"]))
	if not nl.is_empty():
		var dist := int(round((float(nl["s"]) - float(c["s"])) / course.cell_len))
		var warn: bool = speed > int(nl["lim"]) and dist <= speed
		t += "   %sCurva a [b]%d[/b], limite [b]%d[/b]%s" % ["[color=#c93636]" if warn else "", max(dist, 0), nl["lim"], "[/color]" if warn else ""]
	else:
		var dist2 := int(round((course.finish_s - float(c["s"])) / course.cell_len))
		if dist2 > 0:
			t += "   Traguardo a [b]%d[/b]" % dist2
	var lp := course.next_leap(float(c["s"]))
	if not lp.is_empty():
		var dl := int(round((float(lp["s"]) - float(c["s"])) / course.cell_len))
		if dl <= 12:
			var slow: bool = speed < int(lp["min"]) and dl <= speed
			t += "   %sSalto a [b]%d[/b], velocità minima [b]%d[/b]%s" % ["[color=#c93636]" if slow else "", max(dl, 0), lp["min"], "[/color]" if slow else ""]
	t += "   Ammaccature [b]%d/4[/b]" % cur.dents
	return _hint(t)

func _hand(p, interactive: bool, small := false) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var land := layout_mode == "land"
	var csz := Vector2(46, 74) if small else (Vector2(60, 98) if land else Vector2(70, 112))
	if land and not small:
		var colw: float = side_panel.custom_minimum_size.x - 30.0
		var cw: float = clamp((colw - 5.0) / 6.0, 50.0, 96.0)
		csz = Vector2(cw, cw * 1.6)
	sc.custom_minimum_size = Vector2(0, csz.y + 4)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 1 if land else 6)
	sc.add_child(row)
	for i in p.hand.size():
		var v: int = p.hand[i]
		var cv := CardView.new()
		cv.custom_minimum_size = csz
		var res := interactive and _reserved(i)
		var dis := not interactive
		if interactive and phase == "cards" and not res and pending.size() > 0 and v != pending[0]["v"]:
			dis = true
		cv.setup.call_deferred(v, interactive and sel == i, res, dis, p.id)
		cv.pressed.connect(_tap_card.bind(i))
		row.add_child(cv)
	for i in p.dents:
		var dv := CardView.new()
		dv.custom_minimum_size = csz
		dv.setup.call_deferred(0, false, false, true)
		row.add_child(dv)
	return sc
