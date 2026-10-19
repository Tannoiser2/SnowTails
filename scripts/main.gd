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
## Variante personale: programmazione e movimento simultanei (solo partite su questo dispositivo).
var sim_variant := false
signal sim_step
var sim_progs := {}
var course_files: Array = []
var course_idx := 0

## Partita online in corso: {role: "host"/"guest", code, seat, n (prossima mossa), names, away, backlog}.
## Vuoto se si gioca sul dispositivo.
var online := {}
var net: Net
## Cambia a ogni nuova partita: i cicli d'attesa di una partita vecchia si fermano da soli.
var race_id := 0
var disc_buf: Array = []
var _on_name: LineEdit
var _on_code: LineEdit
var _on_lbl: Label

static var _window_set := false

func _ready() -> void:
	randomize()
	# sul computer, alla prima apertura la finestra occupa lo schermo
	if not _window_set and not OS.has_feature("mobile") and not OS.has_feature("editor_hint"):
		_window_set = true
		if DisplayServer.get_name() != "headless" and get_window().mode == Window.MODE_WINDOWED:
			get_window().mode = Window.MODE_MAXIMIZED
	_apply_ui_scale()
	get_tree().root.theme = UIKit.make_theme()
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
	side_panel = UIKit.panel(Color(UIKit.PANEL, 0.96), 0)
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
	get_viewport().size_changed.connect(func(): if _modal_panel: _fit_modal.call_deferred())
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
		(top_panel as PanelContainer).add_theme_stylebox_override("panel", UIKit.box(Color(UIKit.PANEL, 0.95), 0, Color(0, 0, 0, 0), 0, 18))
		(bottom_panel as PanelContainer).add_theme_stylebox_override("panel", UIKit.box(Color(UIKit.PANEL, 0.98), 26, Color(0, 0, 0, 0), 0, 18))
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
	dim.color = Color(0.04, 0.12, 0.22, 0.30 if cover else 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_root.add_child(dim)
	# nevicata dietro la finestra
	var vsz := get_viewport().get_visible_rect().size
	modal_root.add_child(SnowFx.snowfall(vsz, 160 if cover else 90))
	var p := UIKit.frost_panel(26)
	(p.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_top = 30
	modal_root.add_child(p)
	_modal_cap = SnowFx.SnowCap.new()
	modal_root.add_child(_modal_cap)
	p.add_child(content)
	p.modulate.a = 0.0      # compare solo quando è già della misura giusta
	_modal_panel = p
	_modal_w = max_w
	_fit_modal()

var _modal_panel: Control = null
var _modal_cap: Control = null
var _modal_w := 700.0
var _fit_gen := 0

## La finestra deve stare tutta nello schermo: se il contenuto è più alto, prima la si allarga
## (il testo va a capo meno), poi la si rimpicciolisce in proporzione. Niente scorrimento.
func _fit_modal() -> void:
	if _modal_panel == null:
		return
	_fit_gen += 1
	var gen := _fit_gen
	var p := _modal_panel
	var sc := 1.0
	for it in 4:
		if not is_instance_valid(p) or p != _modal_panel or gen != _fit_gen:
			return
		var vs := get_viewport().get_visible_rect().size
		var avail := vs - Vector2(28, 28)
		var w: float = min(_modal_w, avail.x)
		if sc < 1.0:
			w = min(_modal_w * 1.35, avail.x / sc)
		p.size = Vector2(w, 0)
		await get_tree().process_frame
		if not is_instance_valid(p) or p != _modal_panel or gen != _fit_gen:
			return
		var h: float = p.get_combined_minimum_size().y
		p.size = Vector2(w, h)
		var s2: float = clamp(min(avail.y / h, avail.x / w), 0.4, 1.0)
		p.scale = Vector2(s2, s2)
		p.position = ((vs - Vector2(w, h) * s2) * 0.5).floor()
		p.modulate.a = 1.0
		if is_instance_valid(_modal_cap):
			# il cumulo di neve segue il bordo superiore della finestra
			_modal_cap.w = w
			_modal_cap.scale = Vector2(s2, s2)
			_modal_cap.position = p.position + Vector2(0, 3) * s2
			_modal_cap.queue_redraw()
		if abs(s2 - sc) < 0.01:
			break
		sc = s2

func _close_modal() -> void:
	_modal_panel = null
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
var rnd_fan := false
var _last_listed := 0
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
	left.add_child(UIKit.title("Snow Tails", 58))
	left.add_child(UIKit.label("Corsa di slitte con le tessere della tua copia. Uso personale.", 20, UIKit.MUTED))
	left.add_child(UIKit.heading("Percorso"))
	# scelta ben visibile: un percorso della lista o una pista casuale
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	for opt in [[false, "Dalla lista"], [true, "Pista casuale"]]:
		var mb := UIKit.button(opt[1], _is_random() == opt[0])
		mb.custom_minimum_size = Vector2(0, 48)
		mb.pressed.connect(func():
			if opt[0] and not _is_random():
				_last_listed = course_idx
				_menu_pick_course(course_files.size())
			elif not opt[0] and _is_random():
				_menu_pick_course(clamp(_last_listed, 0, max(course_files.size() - 1, 0)))
			show_menu())
		mode_row.add_child(mb)
	left.add_child(mode_row)
	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(0, 60)
	ob.add_theme_font_size_override("font_size", 22)
	UIKit.style_option(ob)
	for i in course_files.size():
		var c := Course.new()
		var ok := c.load_file(course_files[i])
		var nm := c.title if c.title != "" else String(course_files[i]).get_file()
		var tag := "  ✎" if String(course_files[i]).begins_with("user://") else ""
		ob.add_item(nm + tag + ("" if ok else "  (da completare)"), i)
	ob.selected = min(course_idx, course_files.size() - 1)
	ob.item_selected.connect(_menu_pick_course)
	ob.visible = not _is_random()
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
	right.add_child(UIKit.heading("Slitte"))
	_menu_count = HBoxContainer.new()
	_menu_count.add_theme_constant_override("separation", 8)
	right.add_child(_menu_count)
	_menu_rows = VBoxContainer.new()
	_menu_rows.add_theme_constant_override("separation", 6)
	right.add_child(_menu_rows)
	# variante personale: programmazione e movimento simultanei
	var vrow := HBoxContainer.new()
	vrow.add_theme_constant_override("separation", 8)
	var vl := UIKit.heading("Movimento")
	vl.autowrap_mode = TextServer.AUTOWRAP_OFF
	vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vrow.add_child(vl)
	for opt in [[false, "A turni"], [true, "Simultaneo"]]:
		var vb2 := UIKit.button(opt[1], sim_variant == opt[0])
		vb2.custom_minimum_size = Vector2(130, 48)
		vb2.size_flags_horizontal = 0
		vb2.pressed.connect(func():
			sim_variant = opt[0]
			show_menu())
		vrow.add_child(vb2)
	right.add_child(vrow)
	if sim_variant:
		right.add_child(UIKit.label("Variante: tutti programmano la mossa, poi le slitte partono insieme. Se due slitte non possono evitarsi, passa la più veloce e l'altra si ferma con mezza ammaccatura. Solo per le partite su questo dispositivo.", 16, UIKit.MUTED))
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
	_menu_start = UIKit.cta("Inizia la gara")
	_menu_start.pressed.connect(_menu_start_pressed)
	acts.add_child(_menu_start)
	var online_box := _online_box()
	var root_box: BoxContainer
	if land:
		# in orizzontale l'online va a sinistra, sotto i pulsanti: le due colonne restano equilibrate
		_menu_preview.custom_minimum_size = Vector2(0, 230)
		root_box = HBoxContainer.new()
		root_box.add_theme_constant_override("separation", 36)
		root_box.add_child(left)
		root_box.add_child(right)
		right.add_child(_menu_preview)
		right.move_child(_menu_preview, 0)
		left.add_child(acts)
		left.add_child(online_box)
	else:
		right.add_child(online_box)
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
	_menu_refit()

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
	var fr := HBoxContainer.new()
	fr.add_theme_constant_override("separation", 8)
	var fl := UIKit.label("Fanmade", 20)
	fl.autowrap_mode = TextServer.AUTOWRAP_OFF
	fl.custom_minimum_size = Vector2(120, 0)
	fl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fr.add_child(fl)
	for opt in [[false, "no"], [true, "sì: pendii, vento, ghiaccio…"]]:
		var bf := UIKit.button(opt[1], rnd_fan == opt[0])
		bf.custom_minimum_size = Vector2(0, 52)
		bf.pressed.connect(func():
			rnd_fan = opt[0]
			rnd_def = {}
			_menu_build_random()
			_menu_refresh_info()
			_menu_refit())
		fr.add_child(bf)
	_menu_random_box.add_child(fr)
	var again := UIKit.button("Genera un'altra pista")
	again.pressed.connect(func():
		rnd_def = {}
		_menu_refresh_info())
	_menu_random_box.add_child(again)

## Dopo un cambiamento nel menu la finestra si riadatta allo schermo.
func _menu_refit() -> void:
	if _modal_panel:
		_fit_modal.call_deferred()

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
	_menu_refit()
	if _is_random():
		if rnd_def.is_empty() or int(rnd_def.get("difficulty", -1)) != rnd_diff or int(rnd_def.get("length", -1)) != rnd_len or bool(rnd_def.get("fan", false)) != rnd_fan:
			var gen := CourseGen.new()
			rnd_def = gen.generate(rnd_diff, rnd_len, 0, rnd_fan)
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
	_menu_refit()

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
	vb.add_child(UIKit.title("Come si gioca", 42))
	var r := UIKit.rich(21)
	r.add_theme_color_override("default_color", UIKit.INK)
	r.text = ("""[b]La slitta.[/b] Due cani e un freno, tutti a 3 all'inizio. Velocità = cane sinistro + cane destro − freno. Deriva = differenza fra i cani: ti sposti in diagonale verso il cane più forte (mai più della velocità), nei passi che scegli tu.

[b]Il turno.[/b] Giochi da 1 a 3 carte dello stesso valore, al massimo una per spazio. Le carte sui cani restano; quella sul freno lo imposta e va negli scarti. Poi torni a 5 carte. Le ammaccature occupano posto in mano e non si scartano.

[b]Equilibrio.[/b] Con i cani uguali puoi aggiungere un bonus pari alla tua posizione, tutto dritto, a fine movimento. Non al primo turno.

[b]Pericoli.[/b] Entrare in una curva oltre il limite: un'ammaccatura per punto di troppo (il bonus conta). Leap of Death: la spaccatura va saltata a velocità 5 o più, altrimenti un'ammaccatura per ogni punto che manca; chi si ferma sulle caselle della spaccatura non pesca. Bordo: ti fermi e prendi un'ammaccatura. Tamponamento: ti fermi dietro e non peschi. Alla quinta ammaccatura la slitta è distrutta.

[b]Fine.[/b] Si corre finché tutte le slitte hanno tagliato il traguardo; chi è arrivato smette di muovere. In classifica conta prima il giro in cui si taglia il traguardo, poi, a parità di giro, chi è andato più lontano oltre la linea.

[b]Segmenti fanmade.[/b] Salita: chi ci passa fa al massimo %d punti di movimento. Discesa: chi parte in discesa va almeno a %d, anche frenando. Neve fresca: ogni casella coi cumuli costa 2 punti; la prima slitta che ci passa la spazza via. Ghiaccio: chi entra derivando continua a derivare finché è sul ghiaccio, e a fine movimento scivola avanti di una casella. Vento: ogni 2 caselle percorse sulla tessera ti sposta di una corsia nel verso della manica a vento; contro il bordo è un'ammaccatura. Baita: chi si ferma sulla casella accanto alla baita ripara metà dei danni (arrotondando a suo favore), ma non pesca. Bivio: un'isola di abeti divide la pista; da una parte neve fresca, dall'altra alberelli.

[b]Variante simultanea.[/b] Se nel menu scegli «Simultaneo», a ogni giro tutti programmano la mossa (carte e casella d'arrivo) senza vedere quella degli altri, poi le slitte partono insieme. Partono e arrivano tutte insieme, quindi chi ha più caselle da fare va più veloce. Due slitte non entrano mai nella stessa casella nello stesso momento: se possono, scelgono una rotta equivalente che evita il contatto; se non possono, entra chi va più veloce (a parità, chi era più avanti a inizio giro) e l'altra si ferma prima e prende mezza ammaccatura (due mezze fanno un'ammaccatura). Il bonus di equilibrio si calcola sulle posizioni di inizio giro.

[b]Comandi.[/b] Un dito trascina la pista; due dita: avvicini o allontani, ruoti la vista e, spostandole insieme in su o in giù, cambi l'inclinazione. Col mouse: rotellina per lo zoom, tasto destro per ruotare e inclinare. «Segui» fa girare la telecamera nel senso di marcia della slitta di turno.

[b]Tastiera.[/b] 1–5 sceglie una carta di quel valore; A, S, D (o frecce sinistra, giù, destra) la mettono su cane sinistro, freno, cane destro; Invio muove; Backspace riprende le carte; Esc torna indietro o apre il menu. Tocca una carta e poi uno spazio della plancia; poi «Muovi» e tocca la destinazione.""") % [SledGame.UP_MAX, SledGame.DOWN_MIN]
	if _is_landscape():
		# in orizzontale due colonne: il testo sta tutto nella finestra senza rimpicciolirsi troppo
		var paras: PackedStringArray = r.text.split("\n\n")
		var half := int(ceil(paras.size() / 2.0))
		var cols := HBoxContainer.new()
		cols.add_theme_constant_override("separation", 28)
		for part in [paras.slice(0, half), paras.slice(half)]:
			var rc := UIKit.rich(21)
			rc.add_theme_color_override("default_color", UIKit.INK)
			rc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rc.text = "\n\n".join(part)
			cols.add_child(rc)
		vb.add_child(cols)
	else:
		vb.add_child(r)
	var b := UIKit.button("Chiudi", true)
	b.pressed.connect(_close_modal)
	vb.add_child(b)
	_modal(vb, 1180.0 if _is_landscape() else 700.0)

# ======================= PARTITA =======================
func start_game() -> void:
	online = {}
	var def := _menu_course_def()
	if def.is_empty():
		return
	_begin_race(def, setup_ai.slice(0, setup_n), 0)

## Definizione del percorso scelto nel menu (la stessa che, online, viaggia agli altri dispositivi).
func _menu_course_def() -> Dictionary:
	if _is_random():
		return rnd_def
	if course_files.is_empty():
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(course_files[course_idx]))
	return d if d is Dictionary else {}

## Avvia la gara: in locale con seme qualunque, online con il seme e le slitte decisi da chi ha creato la stanza.
func _begin_race(def: Dictionary, ai_flags: Array, seed_value: int, names := {}) -> void:
	course = Course.new()
	if not course.build(def):
		_toast("Percorso non valido: " + course.error)
		return
	race_id += 1
	_close_modal()
	game = SledGame.new()
	game.setup(course, ai_flags, seed_value)
	game.simultaneous = sim_variant and online.is_empty()
	for k in names:
		var idx := int(k)
		if idx < game.players.size():
			game.players[idx].name = "%s (%s)" % [SledGame.NAMES[idx], names[k]]
	board.setup(course, game)
	slot_order = game.players.duplicate()
	game.shuffle(slot_order)
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
	var ctl := await _ctl(cur)
	if await _take_backlog():
		return
	if ctl == "cpu":
		phase = "slotsAI"
		game.log_text = "[b]%s[/b] sceglie la partenza…" % cur.name
		_refresh()
		await _pause(0.45)
		var pick: int = free[0] if randf() < 0.5 else free[randi() % free.size()]
		_do_act({"k": "slot", "v": pick})
	elif ctl == "me":
		phase = "slots"
		game.log_text = "[b]%s[/b], tocca la casella di partenza sulla pista" % cur.name
		_refresh()
	else:
		phase = "wait"
		game.log_text = "[b]%s[/b] sceglie la partenza…" % cur.name
		_refresh()
		_wait_act("slot")

func _take_slot(k: int) -> void:
	game.take_slot(cur, k)
	si += 1
	_next_slot()

func _begin_round() -> void:
	if game.simultaneous:
		_sim_round()
		return
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
			await _pause(0.9)
			_next_turn()
			return
		game.draw_up(cur)
	board.focus_cell(cur.cell)
	var ctl := await _ctl(cur)
	if await _take_backlog():
		return
	if ctl == "cpu":
		phase = "ai"
		_refresh()
		await _pause(0.75)
		var ch := game.ai_choose(cur)
		_do_act(_move_act(ch["pend"], ch["o"]), ch["o"])
	elif ctl == "me":
		phase = "cards"
		_refresh()
	else:
		phase = "wait"
		_refresh()
		_wait_act("move")

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
	await _pause(0.15)
	var full := [start_cell]
	full.append_array(o["path"])
	await _drive([{"p": p, "full": full, "n": max(full.size() - 1, 1), "sap": o.get("sap", [])}], (full.size() - 1) * BoardView3D.STEP_T, true)
	game.last_fx = _fx_of(p, o)
	if _play_fx(game.last_fx):
		await _pause(0.45)
	var need_discard := game.after_move(p, o)
	game.record(p, start_cell, o["path"], o.get("sap", []))
	if need_discard:
		var ctl := await _ctl(p)
		if await _take_backlog():
			return
		if ctl == "me":
			phase = "discard"
			disc_buf = []
			_refresh()
		elif ctl == "cpu":
			_do_act({"k": "disc", "v": game.ai_discard_values(p)})
		else:
			phase = "wait"
			_refresh()
			_wait_act("disc")
		return
	_end_turn()

func _end_turn() -> void:
	game.oi += 1
	_refresh()
	await _pause(0.35)
	_next_turn()

func _show_results() -> void:
	phase = "over"
	if not online.is_empty() and not online.get("over", false):
		online["over"] = true
		if online["role"] == "host":
			net.set_status(online["code"], "over")
		net.remember_room("")
	var r0 = game.results[0] if game.results.size() > 0 else null
	game.log_text = ("[b]%s[/b] vince la corsa!" % r0["p"].name) if r0 and String(r0["st"]).begins_with("arrivata") else "Corsa finita."
	_refresh()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.add_child(UIKit.title("Classifica", 48))
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
		var nm := UIKit.label(r["p"].name + ("  (tu)" if _is_mine(r["p"]) else ""), 26)
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
	var b2 := UIKit.cta("Nuova gara")
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
	if (crash == "edge" or crash == "sled" or crash == "bump") and fx.has("dir"):
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
	var final_snow: Dictionary = game.fresh.duplicate()
	game.fresh = game.initial_fresh.duplicate()
	board.reset_snow()
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
		# la telecamera segue da sola il gruppo in movimento (board._track_moving), senza scatti fra i giri
		var dur := 2.8
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
				board.replay[mv["pid"]]["dir"] = _facing(int(mv["path"][k - 1]), int(mv["path"][k]), u, dv)
				board.replay[mv["pid"]]["run"] = 1.0
		# fine del giro: urti, alberelli travolti, posizioni, ammaccature, distruzioni
		for mv in moves:
			_play_fx(mv.get("fx", {}))
			var pth: Array = mv["path"]
			for sn in mv.get("snow", []):
				var ks := pth.find(sn)
				var dvs := Vector2(0, -1)
				if ks > 0:
					dvs = (course.cells[sn]["pos"] - course.cells[pth[ks - 1]]["pos"]).normalized()
				board.sweep_snow(int(sn), dvs)
				game.fresh.erase(sn)
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
	game.fresh = final_snow
	board.reset_snow()
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
	if modal_root or game == null or cur == null or phase not in ["cards", "dest", "discard", "slots"]:
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
			_do_act({"k": "slot", "v": best})
	elif phase == "dest":
		for i in outs.size():
			var d: float = w.distance_to(course.cells[outs[i]["end"]]["pos"])
			if d < bd:
				bd = d
				best = i
		if best >= 0:
			_submit_move(pending, outs[best])

func _tap_card(i: int) -> void:
	if phase == "discard":
		disc_buf.append(cur.hand[i])
		cur.discard.append(cur.hand[i])
		cur.hand.remove_at(i)
		if game.hand_size(cur) <= 5 or cur.hand.is_empty():
			_do_act({"k": "disc", "v": disc_buf.duplicate()}, null, true)
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
	# una sola casella d'arrivo possibile (tipico nei rettilinei): si parte subito, senza chiedere
	if outs.size() == 1:
		_submit_move(pending, outs[0])
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

## La mossa scelta da una persona: nel gioco normale parte subito, nella variante simultanea
## resta in attesa finché tutti hanno programmato.
func _submit_move(pend: Array, o: Dictionary) -> void:
	if game.simultaneous:
		sim_progs[cur.id] = {"pend": pend.duplicate(true), "o": o}
		pending = []
		sel = -1
		outs = []
		board.destinations = []
		phase = "simwait"
		_refresh()
		sim_step.emit()
		return
	_do_act(_move_act(pend, o), o)

## Movimento fluido lungo i percorsi, senza soste fra una casella e l'altra.
## items: [{p, full: [partenza, ...caselle], n, sap}]: la slitta raggiunge full[k] al tempo k/n
## della durata (con n maggiore delle caselle fatte si ferma prima e aspetta).
## follow: la telecamera segue la slitta (movimento singolo).
func _drive(items: Array, dur: float, follow: bool) -> void:
	var my := race_id
	for it in items:
		var pts := []
		for c in it["full"]:
			pts.append(BoardView3D.to3(course.cells[c]["pos"], 0.004))
		it["pts"] = pts
		it["last"] = 0
		var p = it["p"]
		var h: Vector2 = course.heading(int(it["full"][0]))
		board.replay[p.id] = {"pos": pts[0], "dir": h, "run": 0.0}
	if dur > 0.0 and not online.get("catchup", false):
		var t := 0.0
		while t < dur:
			await get_tree().process_frame
			if my != race_id:
				return
			t += get_process_delta_time()
			var f: float = min(t / dur, 1.0)
			for it in items:
				var pts: Array = it["pts"]
				var kmax: int = pts.size() - 1
				var p = it["p"]
				if kmax <= 0:
					continue
				var x: float = min(f * float(it["n"]), float(kmax))
				var k: int = min(int(floor(x)), kmax - 1)
				var u: float = x - k
				var a: Vector3 = pts[k]
				var b: Vector3 = pts[k + 1]
				var dv := b - a
				var fd := _facing(int(it["full"][k]), int(it["full"][k + 1]), u, dv)
				board.replay[p.id] = {"pos": a.lerp(b, u), "dir": fd, "run": 1.0 if x < float(kmax) else 0.0}
				var reach := int(floor(x + 0.0001))
				while int(it["last"]) < reach:
					it["last"] = int(it["last"]) + 1
					_drive_cell(it, follow)
	for it in items:
		while int(it["last"]) < (it["full"] as Array).size() - 1:
			it["last"] = int(it["last"]) + 1
			_drive_cell(it, follow)
		board.replay.erase(it["p"].id)
	board.redraw()

## Dove guarda la slitta mentre va da una casella all'altra: sempre lungo la pista, con appena
## un accenno verso lo spostamento. Così nelle derive e nelle spinte del vento scivola di lato
## invece di girarsi di traverso.
func _facing(from_id: int, to_id: int, u: float, dv: Vector3) -> Vector2:
	var h: Vector2 = course.heading(from_id).lerp(course.heading(to_id), u)
	if h.length() < 0.01:
		h = course.heading(to_id)
	h = h.normalized()
	var mv := Vector2(dv.x, dv.z)
	if mv.length() > 0.0001 and mv.normalized().dot(h) > -0.2:
		h = (h + mv.normalized() * 0.18).normalized()
	return h

## La slitta è arrivata in una casella del percorso: posizione di gioco, alberelli, telecamera.
func _drive_cell(it: Dictionary, follow: bool) -> void:
	var k: int = it["last"]
	var t: int = it["full"][k]
	var p = it["p"]
	p.cell = t
	if k > 0 and game.fresh.has(t):
		board.sweep_snow(t, (course.cells[t]["pos"] - course.cells[it["full"][k - 1]]["pos"]).normalized())
	if (it["sap"] as Array).has(t) and game.saplings.has(t):
		board.knock_sapling(t, (course.cells[t]["pos"] - course.cells[it["full"][k - 1]]["pos"]).normalized())
		game.saplings.erase(t)
	if follow:
		board.focus_cell(t)
	board.redraw()

# ======================= VARIANTE SIMULTANEA =======================
## Un giro: tutti programmano (le CPU subito, le persone una alla volta), poi si muove insieme.
func _sim_round() -> void:
	var my := race_id
	game.order = game.race_order()
	sim_progs = {}
	var humans := 0
	for p in game.order:
		if game.racing(p) and not p.ai:
			humans += 1
	for p in game.order.duplicate():
		if my != race_id or game.over:
			return
		if not game.racing(p):
			continue
		cur = p
		pending = []
		sel = -1
		outs = []
		board.destinations = []
		if p.hand.is_empty():
			var c0: int = p.cell
			game.add_dent(p, 1)
			game.record(p, c0, [], [])
			game.log_text = "[b]%s[/b] non ha carte cane: prende un'ammaccatura" % p.name
			if p.wrecked:
				_refresh()
				await _pause(0.9)
				continue
			game.draw_up(p)
		if p.ai:
			var ch := game.ai_choose(p)
			sim_progs[p.id] = {"pend": ch["pend"], "o": ch["o"]}
			continue
		if humans > 1:
			await _sim_curtain(p)
			if my != race_id:
				return
		board.focus_cell(p.cell)
		phase = "cards"
		_refresh()
		await sim_step
		if my != race_id:
			return
	await _sim_resolve(my)

## Più persone sullo stesso dispositivo: una copertina fra un giocatore e l'altro, così nessuno sbircia.
func _sim_curtain(p) -> void:
	cur = p
	phase = "simwait"
	_refresh()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.add_child(UIKit.title("Tocca a %s" % p.name, 48, p.color.lightened(0.15)))
	vb.add_child(UIKit.label("Programma la tua mossa. Gli altri non guardino: le mosse si scoprono quando le slitte partono.", 21, UIKit.MUTED))
	var b := UIKit.cta("Sono pronto")
	b.pressed.connect(func():
		_close_modal()
		sim_step.emit())
	vb.add_child(b)
	_modal(vb, 620, true)
	await sim_step

## Tutte le slitte si muovono insieme, una casella per volta; poi urti, ammaccature e carte.
func _sim_resolve(my: int) -> void:
	cur = null
	phase = "anim"
	var plan := game.resolve_simultaneous(sim_progs)
	sim_progs = {}
	var lines := []
	for x in plan:
		var p = x["p"]
		if (x["pend"] as Array).is_empty():
			lines.append("[b]%s[/b] resta ferma" % p.name)
		else:
			lines.append("[b]%s[/b]: %s" % [p.name, game.describe(x["pend"], x["o"], game.mat_after(p, x["pend"]))])
		game.commit_play(p, x["pend"])
	game.log_text = "Si parte tutti insieme!"
	board.current_id = -1
	board.destinations = []
	var pts := []
	for x in plan:
		var pth: Array = x["o"]["path"]
		pts.append(course.cells[x["start"]]["pos"])
		for t in pth:
			pts.append(course.cells[t]["pos"])
	board.frame(pts)
	_refresh()
	await _pause(0.3)
	# tutti partono e arrivano insieme: chi ha più caselle da fare va più veloce
	var items := []
	var maxn := 0
	for x in plan:
		var full := [x["start"]]
		full.append_array(x["o"]["path"])
		items.append({"p": x["p"], "full": full, "n": int(x["o"]["n"]), "sap": x["o"]["sap"]})
		maxn = max(maxn, int(x["o"]["n"]) if not (x["o"]["path"] as Array).is_empty() or x["o"]["half"] else 0)
	await _drive(items, maxn * BoardView3D.STEP_T, false)
	if my != race_id:
		return
	var any_fx := false
	for x in plan:
		x["fx"] = _fx_of(x["p"], x["o"])
		if _play_fx(x["fx"]):
			any_fx = true
	if any_fx:
		await _pause(0.6)
	# esiti nell'ordine di gara di inizio giro
	var need := []
	for i in plan.size():
		var x: Dictionary = plan[i]
		game.log_text = ""
		game.last_fx = x["fx"]
		if game.after_move(x["p"], x["o"]):
			need.append(x["p"])
		game.record(x["p"], x["start"], x["o"]["path"], x["o"].get("sap", []))
		lines[i] += game.log_text
	game.log_text = "  ·  ".join(lines)
	board.redraw()
	_refresh()
	for p in need:
		cur = p
		phase = "discard"
		disc_buf = []
		_refresh()
		await sim_step
		if my != race_id:
			return
	await _pause(0.6)
	if my != race_id:
		return
	if game.check_round_end():
		_show_results()
	else:
		_begin_round()

# ======================= RENDER =======================
func _refresh() -> void:
	board.current_id = cur.id if cur != null and phase != "over" else -1
	board.preview = []
	var sig := ""
	if show_paths and phase == "cards" and cur != null and pending.size() > 0:
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
		var who := UIKit.label("·  tocca a %s%s" % [cur.name, " (tu)" if _is_mine(cur) else ""], 16, cur.color.darkened(0.25))
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
		if p.half:
			t += "▫"
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
	if course.slope_of(cur.cell) == "down":
		speed = max(speed, SledGame.DOWN_MIN)
	var d: int = m["R"] - m["L"]
	var c: Dictionary = course.cells[cur.cell]
	g.add_child(_tile("Velocità", str(speed)))
	g.add_child(_tile("Deriva", "0" if d == 0 else "%d %s" % [min(abs(d), speed), "→" if d > 0 else "←"]))
	var bonus := "—"
	if d == 0 and cur.moves > 0 and speed > 0:
		bonus = "+%d" % game.rank_of(cur)
	g.add_child(_tile("Bonus", bonus))
	g.add_child(_tile("Ammacc.", "%d%s / 4" % [cur.dents, "½" if cur.half else ""], cur.dents >= 3))
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
	# caratteristiche fanmade qui o poco più avanti (al massimo due riquadri)
	var sg := _seg_ahead(cur.cell, max(speed, 1) + 3)
	if not sg.is_empty():
		var when := "qui" if int(sg["dist"]) == 0 else "fra %d" % int(sg["dist"])
		var shown := 0
		for ft in sg["feats"]:
			if shown >= 2:
				break
			var it: Array = {"up": ["Salita", "max %d" % SledGame.UP_MAX], "down": ["Discesa", "min %d" % SledGame.DOWN_MIN],
				"windR": ["Vento →", "di lato"], "windL": ["Vento ←", "di lato"], "ice": ["Ghiaccio", "scivola"],
				"fresh": ["Neve fresca", "costa 2"], "hut": ["Baita", "ripara 1"], "fork": ["Bivio", "scegli"]}.get(ft, [ft, ""])
			g.add_child(_tile(it[0], "%s: %s" % [when, it[1]], ft == "up" and speed > SledGame.UP_MAX))
			shown += 1
	g.add_child(_tile("Mazzo", str(cur.deck.size())))
	g.add_child(_tile("Scarti", str(cur.discard.size() + cur.used.size())))
	if _is_mine(cur):
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

## Prima tessera con caratteristiche fanmade sulla strada (casella attuale compresa) entro n
## caselle in avanti: distanza ed elenco delle caratteristiche.
func _seg_ahead(start: int, n: int) -> Dictionary:
	var id := start
	for k in n + 1:
		var feats := []
		var sl := course.slope_of(id)
		if sl != "":
			feats.append(sl)
		var w := course.wind_of(id)
		if w != 0:
			feats.append("windR" if w > 0 else "windL")
		for key in ["ice", "fresh", "hut"]:
			if course.has_mod(id, key):
				feats.append(key)
		if String(course.pieces[int(course.cells[id]["piece"])]["face"].get("type", "")) == "fork":
			feats.append("fork")
		if not feats.is_empty():
			return {"feats": feats, "dist": k}
		var fw: Array = course.cells[id]["fwd"]
		if fw.is_empty():
			break
		id = fw[0]
	return {}

func _action_text() -> String:
	match phase:
		"slots":
			return "Tocca un cerchio sulla pista per scegliere la partenza (4ª e 5ª: carte in più)."
		"slotsAI":
			return "Le slitte si schierano…"
		"cards":
			if game.simultaneous and cur != null:
				return "[b]%s[/b], programma la mossa: quando tutti hanno scelto, le slitte partono insieme." % cur.name
		"dest":
			return "Tocca sulla pista la casella d'arrivo ([b]−n[/b] ammaccature, [b]+B[/b] bonus)."
		"discard":
			if cur != null:
				return "Scarta [b]%d[/b] carta/e dalla mano." % (game.hand_size(cur) - 5)
		"ai":
			if cur != null:
				return "[b]%s[/b] (CPU) sta guidando…" % cur.name
		"wait":
			if cur != null:
				var t := "Aspetta: tocca a [b]%s[/b]." % cur.name
				if online.get("catchup", false):
					t = "Riprendo la gara dal punto in cui era…"
				elif online.get("slow", false):
					t += " Sta pensando da più di un minuto."
				return t
		"posting":
			return "Invio la mossa…"
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
	bottom_box.add_child(_mat(m, phase == "cards"))
	if phase in ["ai", "wait", "posting"]:
		var me = null
		for q in game.players:
			if _is_mine(q) and not q.wrecked:
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
		var b2 := UIKit.cta("Programma" if game.simultaneous else "Muovi la slitta")
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


# ======================= GIOCO ONLINE =======================
# Lockstep: la partita è un registro di mosse numerate nel database. Chi deve muovere (o, per la CPU
# e per chi si è scollegato, il dispositivo di chi ha creato la stanza) scrive la mossa; tutti la
# applicano nello stesso ordine. Con lo stesso seme i mazzi sono identici, quindi viaggiano solo
# le scelte: partenza, carte giocate con la casella d'arrivo, carte scartate.

func _net() -> Net:
	if net == null:
		net = Net.new()
		add_child(net)
	return net

## La slitta è guidata da questo dispositivo con una persona davanti?
func _is_mine(p) -> bool:
	if online.is_empty():
		return not p.ai
	return p.id == int(online["seat"])

## Chi decide la prossima mossa di p: "me" (la persona davanti a questo dispositivo),
## "cpu" (il computer, su questo dispositivo) oppure "wait" (un altro dispositivo).
func _ctl(p) -> String:
	if online.is_empty() or online.get("over", false):
		return "cpu" if p.ai else "me"
	if p.id == int(online["seat"]):
		return "me"
	if online["role"] != "host":
		return "wait"
	if p.ai:
		return "cpu"
	if (online["away"] as Dictionary).has(p.id):
		# è rientrato?
		var st := await net.seat(online["code"], p.id)
		if not st.is_empty() and not st.get("away", false):
			online["away"].erase(p.id)
			return "wait"
		return "cpu"
	return "wait"

## Pausa delle animazioni; mentre si recuperano le mosse di una partita in corso non si aspetta.
func _pause(t: float) -> void:
	if online.get("catchup", false):
		await get_tree().process_frame
		return
	await get_tree().create_timer(t).timeout

func _move_act(pend: Array, o: Dictionary) -> Dictionary:
	var cs := []
	var sl := []
	for x in pend:
		cs.append(int(x["v"]))
		sl.append(String(x["slot"]))
	return {"k": "move", "c": cs, "sl": sl, "e": int(o["end"])}

## Chi rientra in una partita: le mosse già giocate si applicano subito, una dopo l'altra.
func _take_backlog() -> bool:
	if online.is_empty():
		return false
	var bl: Array = online.get("backlog", [])
	var n := int(online["n"])
	if n < bl.size():
		_apply_act(bl[n])
		return true
	if online.get("catchup", false):
		online["catchup"] = false
		_refresh()
	if _is_mine(cur) and not online.get("over", false):
		_watch_mine()
	return false

## Una mossa decisa su questo dispositivo: online prima si pubblica, poi si applica.
## o: l'esito già calcolato (per non ricalcolarlo); local_done: le carte scartate sono già state tolte.
func _do_act(a: Dictionary, o = null, local_done := false) -> void:
	if online.is_empty() or online.get("over", false):
		_apply_act(a, o, local_done)
		return
	var my := race_id
	a["s"] = cur.id
	var n := int(online["n"])
	phase = "posting"
	_refresh()
	while true:
		var ok := await net.post_act(online["code"], n, a)
		if my != race_id or online.is_empty():
			return
		if ok:
			break
		# la mossa c'è già (per esempio l'ha giocata il computer mentre eri via) oppure la rete è giù
		var ex := await net.get_act(online["code"], n)
		if my != race_id or online.is_empty():
			return
		if not ex.is_empty() and not ex.has("_err"):
			if local_done:
				_undo_discard()
			pending = []
			sel = -1
			outs = []
			board.destinations = []
			_apply_act(ex)
			return
		game.log_text = "Rete non raggiungibile, riprovo… (%s)" % net.last_error
		_refresh()
		await get_tree().create_timer(2.0).timeout
		if my != race_id or online.is_empty():
			return
	_apply_act(a, o, local_done)

## Applica una mossa (decisa qui o arrivata dal database) alla slitta di turno.
func _apply_act(a: Dictionary, o = null, local_done := false) -> void:
	if not online.is_empty() and not online.get("over", false):
		online["n"] = int(online["n"]) + 1
		if a.has("s") and int(a["s"]) != cur.id:
			push_warning("Mossa fuori turno: %s (di turno %d)" % [str(a), cur.id])
	match String(a.get("k", "")):
		"slot":
			_take_slot(int(a["v"]))
		"move":
			var pend := []
			var cs: Array = a.get("c", [])
			var sl: Array = a.get("sl", [])
			for i in cs.size():
				pend.append({"v": int(cs[i]), "slot": String(sl[i])})
			if o == null:
				var cands := game.compute_outs(cur, game.mat_after(cur, pend))
				o = cands[0]
				for c in cands:
					if int(c["end"]) == int(a.get("e", -1)):
						o = c
						break
			_apply_choice(pend, o)
		"disc":
			if not local_done:
				for v in a.get("v", []):
					var vi := int(v)
					if cur.hand.has(vi):
						cur.hand.erase(vi)
						cur.discard.append(vi)
			disc_buf = []
			if game.simultaneous:
				sim_step.emit()
			else:
				_end_turn()

## Rimette in mano le carte scartate a metà (se nel frattempo la mossa l'ha fatta il computer).
func _undo_discard() -> void:
	for i in disc_buf.size():
		cur.hand.append(cur.discard.pop_back())
	cur.hand.sort()
	disc_buf = []

## Aspetta la mossa di un altro dispositivo. Chi ha creato la stanza controlla anche che il
## giocatore sia ancora collegato: se tace da un minuto, al suo posto guida il computer.
func _wait_act(kind: String) -> void:
	var my := race_id
	var n := int(online["n"])
	var who: int = cur.id
	var t0 := Time.get_ticks_msec()
	var last_seen = null
	var seen_t := t0
	var polls := 0
	online["slow"] = false
	while my == race_id and not online.is_empty() and int(online["n"]) == n:
		var a := await net.get_act(online["code"], n)
		if my != race_id or online.is_empty() or int(online["n"]) != n:
			return
		if not a.is_empty() and not a.has("_err"):
			online["slow"] = false
			_apply_act(a)
			return
		var now := Time.get_ticks_msec()
		if online["role"] == "host" and not game.players[who].ai and polls % 4 == 0:
			var st := await net.seat(online["code"], who)
			if my != race_id or online.is_empty() or int(online["n"]) != n:
				return
			if not st.is_empty():
				var seen = st.get("seen", null)
				if seen != last_seen:
					last_seen = seen
					seen_t = now
				if st.get("away", false) or (now - seen_t > 45000 and now - t0 > 60000):
					await net.set_away(online["code"], who, true)
					if my != race_id or online.is_empty() or int(online["n"]) != n:
						return
					online["away"][who] = true
					game.log_text = "[b]%s[/b] non risponde: per ora guida il computer." % cur.name
					_substitute(kind)
					return
		var slow := now - t0 > 60000
		if slow != bool(online.get("slow", false)):
			online["slow"] = slow
			_refresh()
		polls += 1
		await get_tree().create_timer(1.2).timeout

## Il computer gioca al posto di un giocatore scollegato (solo sul dispositivo di chi ha creato la stanza).
func _substitute(kind: String) -> void:
	match kind:
		"slot":
			var free := game.free_slots()
			_do_act({"k": "slot", "v": free[0]})
		"move":
			var ch := game.ai_choose(cur)
			_do_act(_move_act(ch["pend"], ch["o"]), ch["o"])
		"disc":
			_do_act({"k": "disc", "v": game.ai_discard_values(cur)})

## Mentre tocca a te: se sei stato via e il computer ha già mosso al tuo posto, la mossa arriva qui.
func _watch_mine() -> void:
	var my := race_id
	var n := int(online["n"])
	while my == race_id and not online.is_empty() and int(online["n"]) == n:
		await get_tree().create_timer(3.0).timeout
		if my != race_id or online.is_empty() or int(online["n"]) != n or phase == "posting":
			return
		var a := await net.get_act(online["code"], n)
		if my != race_id or online.is_empty() or int(online["n"]) != n or phase == "posting":
			return
		if not a.is_empty() and not a.has("_err"):
			if phase == "discard":
				_undo_discard()
			pending = []
			sel = -1
			outs = []
			board.destinations = []
			game.log_text = "Eri via: il computer ha mosso al tuo posto."
			_apply_act(a)
			return

## Segnale di presenza per chi ha creato la stanza, ogni 5 secondi.
func _heartbeat(my: int) -> void:
	while my == race_id and not online.is_empty() and not online.get("over", false):
		net.heartbeat(online["code"], int(online["seat"]))
		await get_tree().create_timer(5.0).timeout

# ---------- menu online ----------
func _online_box() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(UIKit.heading("Online"))
	var ses := _net().load_session()
	_on_name = _line_edit("il tuo nome", 20)
	_on_name.text = str(ses.get("name", ""))
	v.add_child(_on_name)
	var bc := UIKit.button("Crea una stanza")
	bc.pressed.connect(_online_create)
	v.add_child(bc)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_on_code = _line_edit("codice", 4)
	_on_code.custom_minimum_size.x = 130
	_on_code.size_flags_horizontal = 0
	_on_code.text_changed.connect(func(t):
		_on_code.text = t.to_upper()
		_on_code.caret_column = t.length())
	row.add_child(_on_code)
	var bj := UIKit.button("Entra")
	bj.pressed.connect(_online_join)
	row.add_child(bj)
	v.add_child(row)
	_on_lbl = UIKit.label("Chi crea la stanza sceglie percorso e slitte: le slitte su «Persona» diventano i posti per gli amici, che entrano con il codice. I posti rimasti liberi li guida la CPU.", 17, UIKit.MUTED)
	v.add_child(_on_lbl)
	if not online.is_empty() and online.get("lobby", false):
		_on_code.text = online["code"]
		_on_lbl.text = "Stanza [ %s ]…" % online["code"]
	elif str(ses.get("room", "")) != "":
		_on_code.text = str(ses["room"])
		_on_lbl.text = "Eri nella stanza %s: premi «Entra» per rientrare." % ses["room"]
	return v

func _line_edit(ph: String, maxlen: int) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = ph
	le.max_length = maxlen
	le.custom_minimum_size = Vector2(0, 56)
	le.add_theme_font_size_override("font_size", 22)
	le.add_theme_stylebox_override("normal", UIKit.box(UIKit.SOFT, 12, UIKit.LINE, 2, 12))
	le.add_theme_stylebox_override("focus", UIKit.box(Color.WHITE, 12, UIKit.ACCENT, 2, 12))
	le.add_theme_color_override("font_color", UIKit.INK)
	le.add_theme_color_override("font_placeholder_color", UIKit.MUTED)
	return le

func _on_text(t: String) -> void:
	if is_instance_valid(_on_lbl):
		_on_lbl.text = t

func _toast(t: String) -> void:
	_on_text(t)
	push_warning(t)

func _player_name() -> String:
	return _on_name.text.strip_edges() if is_instance_valid(_on_name) else ""

func _menu_start_pressed() -> void:
	if online.get("lobby", false):
		if online["role"] == "host":
			_online_start()
		else:
			_on_text("Aspetta che chi ha creato la stanza avvii la gara.")
		return
	start_game()

func _seats_text(room: Dictionary) -> String:
	var seats := Net._as_dict(room.get("seats", {}))
	var parts := []
	for idx in room.get("open", []):
		var k := str(int(idx))
		var who := str(seats[k].get("name", "?")) if seats.has(k) and seats[k] is Dictionary else "libero"
		parts.append("%s: %s" % [SledGame.NAMES[int(idx)], who])
	return ", ".join(parts)

func _online_create() -> void:
	var nm := _player_name()
	if nm == "":
		_on_text("Scrivi il tuo nome.")
		return
	var seats := []
	for i in setup_n:
		if not setup_ai[i]:
			seats.append(i)
	if seats.size() < 2:
		_on_text("Metti su «Persona» almeno due slitte: la prima è la tua, le altre sono i posti per gli amici.")
		return
	_on_text("Creo la stanza…")
	var code := await _net().create_room(nm, seats)
	if code == "":
		_on_text("Non riesco a creare la stanza.\n%s" % net.last_error)
		return
	online = {"role": "host", "code": code, "seat": seats[0], "n": 0, "away": {}, "lobby": true}
	net.remember_room(code, seats[0])
	net._save({"name": nm})
	if is_instance_valid(_on_code):
		_on_code.text = code
	_online_lobby_poll(code)

func _online_join() -> void:
	var code := _on_code.text.strip_edges().to_upper() if is_instance_valid(_on_code) else ""
	var nm := _player_name()
	if nm == "" or code.length() != 4:
		_on_text("Scrivi il tuo nome e il codice di 4 lettere.")
		return
	_on_text("Entro nella stanza %s…" % code)
	var seat := await _net().join_room(code, nm)
	if seat == -2:
		_on_text("Stanza %s non trovata, oppure la gara è già partita.%s" % [code, ("\n" + net.last_error) if net.last_error != "" else ""])
		return
	if seat == -1:
		_on_text("Nella stanza %s non ci sono posti liberi." % code)
		return
	var room: Dictionary = net.last_room
	online = {"role": "host" if room.get("host", "") == net.uid else "guest", "code": code, "seat": seat, "n": 0, "away": {}, "lobby": true}
	net.remember_room(code, seat)
	net._save({"name": nm})
	if room.get("status", "") == "playing" and room.has("game"):
		_on_text("Rientro nella gara della stanza %s…" % code)
		_online_begin(room["game"], true)
		return
	_online_lobby_poll(code)

func _online_lobby_poll(code: String) -> void:
	while online.get("code", "") == code and online.get("lobby", false):
		var room := await net.room(code)
		if online.get("code", "") != code or not online.get("lobby", false):
			return
		if room.is_empty():
			_on_text("La stanza %s non esiste più." % code)
			online = {}
			return
		if online["role"] == "host":
			_on_text("Stanza [ %s ]: dai il codice ai tuoi amici.\nPosti: %s.\nQuando ci siete tutti premi «Inizia la gara»: i posti liberi li guida la CPU." % [code, _seats_text(room)])
		else:
			if room.get("status", "") == "playing" and room.has("game"):
				_online_begin(room["game"], false)
				return
			_on_text("Sei nella stanza [ %s ] con la slitta %s.\nPosti: %s.\nAspetta che chi l'ha creata avvii la gara." % [code, SledGame.NAMES[int(online["seat"])], _seats_text(room)])
		await get_tree().create_timer(2.0).timeout

## Chi ha creato la stanza avvia la gara: percorso, seme e slitte valgono per tutti.
func _online_start() -> void:
	var code: String = online["code"]
	var def := _menu_course_def()
	if def.is_empty():
		_on_text("Scegli un percorso valido.")
		return
	var room := await net.room(code)
	if room.is_empty():
		_on_text("La stanza %s non esiste più." % code)
		online = {}
		return
	var seats := Net._as_dict(room.get("seats", {}))
	if int(online["seat"]) >= setup_n or not seats.has(str(int(online["seat"]))):
		_on_text("Hai cambiato le slitte dopo aver creato la stanza: creane una nuova.")
		return
	var ai := []
	var names := {}
	for i in setup_n:
		var k := str(i)
		if seats.has(k) and seats[k] is Dictionary:
			ai.append(false)
			names[k] = str(seats[k].get("name", ""))
		else:
			ai.append(true)
	var g := {"seed": 1 + randi() % 2000000000, "def": JSON.stringify(def), "ai": ai, "names": names}
	if not await net.start_room(code, g):
		_on_text("Non riesco ad avviare la gara (%s)." % net.last_error)
		return
	_online_begin(g, false)

## Avvio della gara online (per tutti), oppure rientro in una gara già iniziata.
func _online_begin(g: Dictionary, rejoin: bool) -> void:
	online["lobby"] = false
	online["n"] = 0
	online["away"] = {}
	online["over"] = false
	var backlog: Array = []
	if rejoin:
		backlog = await net.get_acts(online["code"])
		net.set_away(online["code"], int(online["seat"]), false)
	online["backlog"] = backlog
	online["catchup"] = not backlog.is_empty()
	var def = JSON.parse_string(str(g.get("def", ""))) if g.get("def") is String else g.get("def", {})
	var ai := []
	for x in g.get("ai", []):
		ai.append(bool(x))
	var names: Dictionary = g.get("names", {}) if g.get("names") is Dictionary else Net._as_dict(g.get("names", {}))
	_begin_race(def if def is Dictionary else {}, ai, int(g.get("seed", 1)), names)
	if online["role"] != "host":
		_heartbeat(race_id)
