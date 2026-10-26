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

var setup_on := [true, true, true, true, false]   # colori in gara (il "no" del menu)
var _preview_sig := ""
var show_paths := false        # anteprima dei percorsi mentre si scelgono le carte
var setup_ai := [false, true, true, true, true]
## Variante personale: programmazione e movimento simultanei (solo partite su questo dispositivo).
var sim_variant := false
signal sim_step
var sim_progs := {}
var sim_racers: Array = []     # online simultaneo: slitte che programmano in questo giro (in ordine)
var sim_base := 0              # online simultaneo: numero della prima mossa del giro
var _posting_prog := false
var _join_want := -1           # colore scelto dal telefono che entra nella stanza
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
	UIKit.setup_fonts()
	get_tree().root.theme = UIKit.make_theme()
	board = BoardView3D.new()
	add_child(board)
	board.tapped.connect(_on_board_tap)
	_build_hud()
	_scan_courses()
	show_menu()
	_library_autosync()
	# telefono aperto dal QR dello schermo condiviso: indirizzo con ?r=CODICE
	var rc := OS.get_environment("ST_JOIN")
	if OS.has_feature("web"):
		var v = JavaScriptBridge.eval("new URLSearchParams(location.search).get('r') || ''")
		if v != null:
			rc = str(v)
	rc = rc.strip_edges().to_upper()
	if rc.length() == 4:
		_phone_join(rc)

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
	bh.pressed.connect(show_help.bind(false))
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
## Piste di prova: restano nei file (per i test) ma non nella lista del menu.
const HIDDEN_COURSES := ["salto.json", "prova.json", "fanmade.json"]

func _scan_courses() -> void:
	course_files.clear()
	var da := DirAccess.open(COURSE_DIR)
	if da:
		for f in da.get_files():
			if f.ends_with(".json") and not f in HIDDEN_COURSES:
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
	course_idx = 0
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

var menu_tab := ""             # "list", "editor" o "random"
var _menu_tab_box: VBoxContainer
var _menu_tabs: HBoxContainer
var _menu_sim_row: HBoxContainer
var _menu_sim_lbl: Label
var _menu_thumbs: Array = []
var tour_mode := false         # «Gran Tour» scelto nella lista
var tour_sel: Array = []       # piste del Gran Tour (percorsi dei file)
var _tour_sel_init := false
var tour := {}                 # Gran Tour in corso: files, i, flags, tot, races, names
var _menu_tour_box: ScrollContainer
var _del_armed := ""
var MENU_TAB_H := 270.0        # altezza fissa delle schede: la finestra non cambia misura

## Numero di slitte in gara (i colori non su «no»).
var setup_n: int:
	get:
		return setup_on.count(true)
	set(v):
		for i in setup_on.size():
			setup_on[i] = i < v

## Un valore per colore: -1 non in gara, 0 persona, 1 CPU.
func _seat_flags() -> Array:
	var out := []
	for i in setup_on.size():
		out.append(-1 if not setup_on[i] else (1 if setup_ai[i] else 0))
	return out

func show_menu() -> void:
	var land := _is_landscape()
	if menu_tab == "":
		menu_tab = "random" if _is_random() else "list"
	_del_armed = ""
	_menu_thumbs = []
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# titolo in un riquadro basso: la riga del carattere è molto alta e sprecherebbe spazio
	var th := Control.new()
	th.custom_minimum_size = Vector2(0, 62)
	var tl := UIKit.title("Snow Tails", 58)
	tl.autowrap_mode = TextServer.AUTOWRAP_OFF
	tl.position = Vector2(0, -12)
	th.add_child(tl)
	var trow := HBoxContainer.new()
	th.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trow.add_child(th)
	var brul := UIKit.button("Regole")
	brul.custom_minimum_size = Vector2(130, 48)
	brul.size_flags_horizontal = 0
	brul.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brul.pressed.connect(show_help.bind(false))
	trow.add_child(brul)
	left.add_child(trow)
	left.add_child(UIKit.heading("Percorso"))
	# tre schede: percorsi della lista, editor, pista casuale
	_menu_tabs = HBoxContainer.new()
	_menu_tabs.add_theme_constant_override("separation", 8)
	left.add_child(_menu_tabs)
	_menu_tab_box = VBoxContainer.new()
	_menu_tab_box.add_theme_constant_override("separation", 8)
	_menu_tab_box.custom_minimum_size = Vector2(0, MENU_TAB_H)
	# la scheda prende lo spazio che avanza (la colonna di destra è più alta): lista più lunga,
	# anteprima in fondo
	_menu_tab_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_menu_tab_box)
	_menu_random_box = VBoxContainer.new()
	_menu_random_box.add_theme_constant_override("separation", 8)
	_menu_info = UIKit.label("", 18, UIKit.MUTED)
	_menu_info.custom_minimum_size = Vector2(0, 52)
	_menu_info.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	left.add_child(_menu_info)
	_menu_preview = CoursePreview.new()
	_menu_preview.custom_minimum_size = Vector2(0, 230 if land else 250)
	left.add_child(_menu_preview)
	_menu_tour_box = ScrollContainer.new()
	_menu_tour_box.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_menu_tour_box.custom_minimum_size = _menu_preview.custom_minimum_size
	_menu_tour_box.visible = false
	left.add_child(_menu_tour_box)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_count = HBoxContainer.new()
	_menu_count.add_theme_constant_override("separation", 8)
	right.add_child(_menu_count)
	_menu_rows = VBoxContainer.new()
	_menu_rows.add_theme_constant_override("separation", 6)
	right.add_child(_menu_rows)
	# variante personale: programmazione e movimento simultanei
	_menu_sim_row = HBoxContainer.new()
	_menu_sim_row.add_theme_constant_override("separation", 8)
	right.add_child(_menu_sim_row)
	_menu_sim_lbl = UIKit.label("", 16, UIKit.MUTED)
	_menu_sim_lbl.custom_minimum_size = Vector2(0, 96)
	_menu_sim_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	right.add_child(_menu_sim_lbl)
	right.add_child(_online_box())
	# in fondo: schermo intero e partenza
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 10)
	if game != null and not game.over and phase != "menu":
		var back := UIKit.button("Torna alla gara")
		back.pressed.connect(_close_modal)
		acts.add_child(back)
	if not OS.has_feature("mobile"):
		var fs := UIKit.button("Finestra" if get_window().mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN] else "Schermo intero")
		fs.pressed.connect(_toggle_fullscreen)
		acts.add_child(fs)
	_menu_start = UIKit.cta("Inizia la gara")
	_menu_start.pressed.connect(_menu_start_pressed)
	acts.add_child(_menu_start)
	var cols: BoxContainer
	if land:
		cols = HBoxContainer.new()
		cols.add_theme_constant_override("separation", 36)
	else:
		cols = VBoxContainer.new()
		cols.add_theme_constant_override("separation", 14)
	cols.add_child(left)
	cols.add_child(right)
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 16)
	root_box.add_child(cols)
	root_box.add_child(acts)
	_menu_build_tabs()
	_menu_build_tab()
	_menu_build_sim()
	_menu_rebuild_players()
	_menu_refresh_info()
	_modal(root_box, 1080 if land else 700, true)

func _is_random() -> bool:
	return course_idx >= course_files.size()

func _menu_build_tabs() -> void:
	UIKit.clear(_menu_tabs)
	for opt in [["list", "Dalla lista"], ["editor", "Editor"], ["random", "Pista casuale"]]:
		var mb := UIKit.button(opt[1], menu_tab == opt[0])
		mb.custom_minimum_size = Vector2(0, 50)
		mb.pressed.connect(_menu_set_tab.bind(opt[0]))
		_menu_tabs.add_child(mb)

## Cambio scheda: si rifà solo il contenuto, la finestra resta ferma.
func _menu_set_tab(t: String) -> void:
	if t == "random" and not _is_random():
		_last_listed = course_idx
		course_idx = course_files.size()
	elif t != "random" and _is_random():
		course_idx = clamp(_last_listed, 0, max(course_files.size() - 1, 0))
	menu_tab = t
	_del_armed = ""
	_menu_build_tabs()
	_menu_build_tab()
	_menu_refresh_info()

func _menu_build_sim() -> void:
	UIKit.clear(_menu_sim_row)
	var vl := UIKit.heading("Movimento")
	vl.autowrap_mode = TextServer.AUTOWRAP_OFF
	vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_menu_sim_row.add_child(vl)
	for opt in [[false, "A turni"], [true, "Simultaneo"]]:
		var vb2 := UIKit.button(opt[1], sim_variant == opt[0])
		vb2.custom_minimum_size = Vector2(130, 48)
		vb2.size_flags_horizontal = 0
		vb2.pressed.connect(func():
			sim_variant = opt[0]
			_menu_build_sim())
		_menu_sim_row.add_child(vb2)
	_menu_sim_lbl.text = ("Variante: tutti programmano la mossa, poi le slitte partono insieme. Se due slitte non possono evitarsi, passa la più veloce e l'altra si ferma con mezza ammaccatura. Solo per le partite su questo dispositivo."
		if sim_variant else "Regolamento: le slitte muovono una alla volta, dalla prima all'ultima in classifica.")

func _menu_pick_course(i: int) -> void:
	course_idx = i
	tour_mode = false
	_menu_build_tab()
	_menu_refresh_info()

func _course_name(path: String) -> String:
	var c := Course.new()
	var ok := c.load_file(path)
	var nm := c.title if c.title != "" else path.get_file().get_basename()
	return nm + ("" if ok else "  (da completare)")

func _list_scroll(h: float) -> Array:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, h)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(vb)
	return [sc, vb]

## Contenuto della scheda scelta (altezza fissa).
func _menu_build_tab() -> void:
	if _menu_tab_box == null:
		return
	for ch in _menu_tab_box.get_children():
		_menu_tab_box.remove_child(ch)
		if ch != _menu_random_box:
			ch.queue_free()
	if menu_tab == "random":
		_menu_tab_box.add_child(_menu_random_box)
		_menu_build_random()
	elif menu_tab == "list":
		var l := _list_scroll(MENU_TAB_H)
		var sc: ScrollContainer = l[0]
		var vb: VBoxContainer = l[1]
		var mine := false
		var bt := UIKit.button("Gran Tour: più piste, classifica a punti", tour_mode)
		bt.custom_minimum_size = Vector2(0, 46)
		bt.alignment = HORIZONTAL_ALIGNMENT_LEFT
		bt.pressed.connect(func():
			tour_mode = true
			_menu_build_tab()
			_menu_refresh_info())
		vb.add_child(bt)
		vb.add_child(UIKit.label("Ufficiali", 18, UIKit.MUTED))
		for i in course_files.size():
			if String(course_files[i]).begins_with("user://") and not mine:
				mine = true
				vb.add_child(UIKit.label("Create da te", 18, UIKit.MUTED))
			var b := UIKit.button(_course_name(course_files[i]), i == course_idx and not tour_mode)
			b.custom_minimum_size = Vector2(0, 46)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.pressed.connect(_menu_pick_course.bind(i))
			vb.add_child(b)
			if i == course_idx and not tour_mode:
				_scroll_to(sc, b)
		if not mine:
			vb.add_child(UIKit.label("Create da te", 18, UIKit.MUTED))
			vb.add_child(UIKit.label("Nessuna: creane una nella scheda Editor.", 17, UIKit.MUTED))
		_menu_tab_box.add_child(sc)
	else:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var bed := UIKit.button("Crea percorso")
		bed.custom_minimum_size = Vector2(0, 50)
		bed.pressed.connect(func():
			CourseEditor.start_from = course_files[course_idx] if course_idx < course_files.size() else ""
			get_tree().change_scene_to_file("res://scenes/course_editor.tscn"))
		row.add_child(bed)
		var bmap := UIKit.button("Mappa le tessere")
		bmap.custom_minimum_size = Vector2(0, 50)
		bmap.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/mapper.tscn"))
		row.add_child(bmap)
		_menu_tab_box.add_child(row)
		var lt := UIKit.label("Le tue piste", 18, UIKit.MUTED)
		lt.custom_minimum_size = Vector2(0, 22)
		_menu_tab_box.add_child(lt)
		var l := _list_scroll(MENU_TAB_H - 50 - 22 - 16 - 12 - 54)
		var vb: VBoxContainer = l[1]
		var n := 0
		for i in course_files.size():
			var path := String(course_files[i])
			if not path.begins_with("user://"):
				continue
			n += 1
			var r := HBoxContainer.new()
			r.add_theme_constant_override("separation", 6)
			var b := UIKit.button(_course_name(path), i == course_idx)
			b.custom_minimum_size = Vector2(0, 46)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.clip_text = true
			b.pressed.connect(_menu_pick_course.bind(i))
			r.add_child(b)
			var be := UIKit.button("Modifica")
			be.custom_minimum_size = Vector2(110, 46)
			be.size_flags_horizontal = 0
			be.pressed.connect(func():
				CourseEditor.start_from = path
				get_tree().change_scene_to_file("res://scenes/course_editor.tscn"))
			r.add_child(be)
			var bd := UIKit.button("Sicuro?" if _del_armed == path else "Elimina")
			bd.custom_minimum_size = Vector2(110, 46)
			bd.size_flags_horizontal = 0
			if _del_armed == path:
				bd.add_theme_color_override("font_color", Color(0.75, 0.12, 0.1))
			bd.pressed.connect(_menu_delete.bind(path))
			r.add_child(bd)
			vb.add_child(r)
		if n == 0:
			vb.add_child(UIKit.label("Non hai ancora creato piste. Premi «Crea percorso».", 17, UIKit.MUTED))
		_menu_tab_box.add_child(l[0])
		var lw := CourseLibrary.word(_net())
		var blib := UIKit.button("Libreria online: " + ("collegata, sincronizza" if lw != "" else "non collegata"))
		blib.custom_minimum_size = Vector2(0, 46)
		blib.pressed.connect(_library_dialog)
		_menu_tab_box.add_child(blib)

## Libreria online delle piste: parola segreta, sincronizzazione.
func _library_dialog() -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.add_child(UIKit.title("Libreria online", 44))
	vb.add_child(UIKit.label("Le piste che crei con l'editor si salvano anche online. Scegli una parola segreta: su ogni dispositivo (computer, iPad, telefono) dove la scrivi ritrovi le stesse piste. Chi non la conosce non le vede.", 18, UIKit.MUTED))
	var le := _line_edit("parola segreta", 40)
	le.text = CourseLibrary.word(_net())
	vb.add_child(le)
	var info := UIKit.label("", 18, UIKit.INK)
	vb.add_child(info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var bx := UIKit.button("Chiudi")
	bx.pressed.connect(show_menu)
	row.add_child(bx)
	if CourseLibrary.linked(net):
		var bu := UIKit.button("Scollega")
		bu.pressed.connect(func():
			CourseLibrary.set_word(net, "")
			show_menu())
		row.add_child(bu)
	var bs := UIKit.cta("Collega e sincronizza")
	bs.pressed.connect(func():
		var w := le.text.strip_edges()
		if w.length() < 6:
			info.text = "Usa almeno 6 caratteri (meglio una frase che sai solo tu)."
			return
		CourseLibrary.set_word(net, w)
		info.text = "Sincronizzo…"
		var r := await CourseLibrary.sync(net)
		if not is_instance_valid(info):
			return
		info.text = _library_text(r))
	row.add_child(bs)
	vb.add_child(row)
	_modal(vb, 640, true)

func _library_text(r: Dictionary) -> String:
	if not r.get("ok", false):
		return "Non riesco a raggiungere la libreria: %s" % r.get("error", "")
	return "Libreria sincronizzata: %d scaricate, %d caricate, %d tolte." % [r["down"], r["up"], r["gone"]]

## All'apertura del menu le piste online si allineano in sottofondo.
var _lib_synced := false
func _library_autosync() -> void:
	if _lib_synced or not CourseLibrary.linked(_net()):
		return
	_lib_synced = true
	var r := await CourseLibrary.sync(net)
	if r.get("ok", false) and (int(r["down"]) > 0 or int(r["gone"]) > 0):
		var cur_path := String(course_files[course_idx]) if course_idx < course_files.size() else ""
		_scan_courses()
		var k := course_files.find(cur_path)
		if k >= 0:
			course_idx = k
		if phase == "menu" and _menu_tab_box != null and is_instance_valid(_menu_tab_box) and _menu_tab_box.is_inside_tree():
			_menu_build_tab()
			_menu_refresh_info()

## Porta in vista la pista scelta quando la lista è già impaginata.
func _scroll_to(sc: ScrollContainer, c: Control) -> void:
	for _i in 3:
		await get_tree().process_frame
	if is_instance_valid(sc) and is_instance_valid(c):
		# coordinate locali: la finestra può essere rimpicciolita per stare nello schermo
		var y := c.position.y + c.size.y * 0.5 - sc.size.y * 0.5
		sc.scroll_vertical = int(max(0.0, y))

## Elimina una pista creata dal giocatore (secondo tocco per confermare).
func _menu_delete(path: String) -> void:
	if _del_armed != path:
		_del_armed = path
		_menu_build_tab()
		return
	_del_armed = ""
	var cur_path := String(course_files[course_idx]) if course_idx < course_files.size() else ""
	DirAccess.remove_absolute(path)
	if CourseLibrary.linked(_net()):
		CourseLibrary.remove(net, path.get_file().get_basename())
	_scan_courses()
	var k := course_files.find(cur_path)
	if k >= 0:
		course_idx = k
	_menu_build_tab()
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

func _is_tour() -> bool:
	return menu_tab == "list" and tour_mode

func _menu_refresh_info() -> void:
	var tr := _is_tour()
	_menu_preview.visible = not tr
	_menu_tour_box.visible = tr
	if tr:
		_menu_build_tour()
		var pts := []
		for k in setup_n:
			pts.append("%d° %d" % [k + 1, setup_n - 1 - k])
		_menu_info.text = "Gran Tour: %d %s nell'ordine della lista. Punti a ogni gara: %s." % [tour_sel.size(), "pista" if tour_sel.size() == 1 else "piste", ", ".join(pts)]
		_menu_start.disabled = tour_sel.is_empty()
		return
	if _is_random():
		if rnd_def.is_empty() or int(rnd_def.get("difficulty", -1)) != rnd_diff or int(rnd_def.get("length", -1)) != rnd_len or bool(rnd_def.get("fan", false)) != rnd_fan:
			var gen := CourseGen.new()
			rnd_def = gen.generate(rnd_diff, rnd_len, 0, rnd_fan)
			if rnd_def.is_empty():
				_menu_info.text = gen.last_error
				_menu_start.disabled = true
				_menu_preview.show_message(gen.last_error)
				return
		_menu_start.disabled = false
		var rc := Course.new()
		if rc.build(rnd_def):
			_menu_info.text = rc.composition()
			_menu_preview.show_course(rc)
		return
	var c := Course.new()
	var ok := c.load_file(course_files[course_idx]) if course_files.size() > 0 else false
	_menu_info.text = c.composition() if ok else c.error + (". Usa «Mappa le tessere»." if not c.missing.is_empty() else "")
	_menu_start.disabled = not ok
	if ok:
		_menu_preview.show_course(c)
	else:
		_menu_preview.show_message("Anteprima non disponibile: " + c.error)

## Scelta delle piste del Gran Tour (al posto dell'anteprima).
func _menu_build_tour() -> void:
	var keep := _menu_tour_box.scroll_vertical
	UIKit.clear(_menu_tour_box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_tour_box.add_child(vb)
	var valid := []
	for f in course_files:
		var c := Course.new()
		if c.load_file(f):
			valid.append([f, c.title if c.title != "" else String(f).get_file().get_basename()])
	if not _tour_sel_init:
		_tour_sel_init = true
		for v in valid:
			if not String(v[0]).begins_with("user://"):
				tour_sel.append(v[0])
	var ok_paths := valid.map(func(v): return v[0])
	tour_sel = tour_sel.filter(func(f): return ok_paths.has(f))
	vb.add_child(UIKit.label("Piste del Gran Tour (tocca per includere o togliere)", 17, UIKit.MUTED))
	for v in valid:
		var on: bool = tour_sel.has(v[0])
		var b := UIKit.button(("✓  " if on else "     ") + String(v[1]) + ("  ✎" if String(v[0]).begins_with("user://") else ""), on)
		b.custom_minimum_size = Vector2(0, 44)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func():
			if tour_sel.has(v[0]):
				tour_sel.erase(v[0])
			else:
				tour_sel.append(v[0])
			_menu_refresh_info())
		vb.add_child(b)
	(func(): _menu_tour_box.scroll_vertical = keep).call_deferred()

## Ogni colore: «no» (non corre), «Persona» o «CPU». Servono almeno due slitte.
func _menu_set_seat(i: int, kind: String) -> void:
	if kind == "no":
		if setup_on[i] and setup_n <= 2:
			return
		setup_on[i] = false
	else:
		setup_on[i] = true
		setup_ai[i] = kind == "cpu"
	_menu_rebuild_players()
	if _is_tour():
		_menu_refresh_info()

func _menu_rebuild_players() -> void:
	UIKit.clear(_menu_count)
	var hd := UIKit.heading("Slitte")
	hd.autowrap_mode = TextServer.AUTOWRAP_OFF
	hd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hd.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_menu_count.add_child(hd)
	var humans := 0
	for i in setup_on.size():
		if setup_on[i] and not setup_ai[i]: humans += 1
	var summary := UIKit.label("%d in gara: %d %s, %d CPU" % [setup_n, humans, "persona" if humans == 1 else "persone", setup_n - humans], 18, UIKit.MUTED)
	summary.autowrap_mode = TextServer.AUTOWRAP_OFF
	summary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_menu_count.add_child(summary)
	# le miniature 3D restano le stesse: si staccano prima di rifare le righe
	for t in _menu_thumbs:
		if is_instance_valid(t) and t.get_parent():
			t.get_parent().remove_child(t)
	UIKit.clear(_menu_rows)
	for i in setup_on.size():
		var on: bool = setup_on[i]
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		if i >= _menu_thumbs.size() or not is_instance_valid(_menu_thumbs[i]):
			if i >= _menu_thumbs.size():
				_menu_thumbs.resize(i + 1)
			_menu_thumbs[i] = SledThumb.new(SledGame.COLORS[i])
		var th: SledThumb = _menu_thumbs[i]
		th.set_active(on)
		th.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		th.tooltip_text = SledGame.NAMES[i]
		r.add_child(th)
		for opt in [["no", "No", not on, 80], ["human", "Persona", on and not setup_ai[i], 130], ["cpu", "CPU", on and setup_ai[i], 100]]:
			var b := UIKit.button(opt[1], opt[2])
			b.custom_minimum_size = Vector2(opt[3], 52)
			b.size_flags_horizontal = 0
			b.pressed.connect(_menu_set_seat.bind(i, opt[0]))
			r.add_child(b)
		_menu_rows.add_child(r)

## Il percorso scelto (o in corso) usa segmenti fanmade?
func _uses_fan() -> bool:
	if phase != "menu" and course != null:
		return _course_has_fan(course)
	if _is_tour():
		for f in tour_sel:
			var c := Course.new()
			if c.load_file(f) and _course_has_fan(c):
				return true
		return false
	if _is_random():
		return rnd_fan
	var c := Course.new()
	return course_files.size() > 0 and c.load_file(course_files[course_idx]) and _course_has_fan(c)

func _course_has_fan(c: Course) -> bool:
	for pc in c.pieces:
		if not (pc["mods"] as Dictionary).is_empty() or String(pc["face"].get("type", "")) == "fork":
			return true
	return false

## Una voce delle regole: immagine (o disegno) a sinistra, titolo e spiegazione.
func _rule_item(icon: Control, title: String, text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	var box := CenterContainer.new()
	box.custom_minimum_size = Vector2(92, 72)
	box.add_child(icon)
	h.add_child(box)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	var t := UIKit.label(title, 20, UIKit.INK)
	t.add_theme_font_override("font", UIKit.font(UIKit.F_BOLD))
	col.add_child(t)
	col.add_child(UIKit.label(text, 17, UIKit.MUTED))
	h.add_child(col)
	return h

func _rule_img(path: String, w := 84.0, h := 64.0) -> Control:
	var tr := TextureRect.new()
	if ResourceLoader.exists(path):
		tr.texture = load(path)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(w, h)
	return tr

func _rule_text(t: String) -> RichTextLabel:
	var r := UIKit.rich(19)
	r.add_theme_color_override("default_color", UIKit.INK)
	r.text = t
	return r

var _help_fan := false

func show_help(force_fan := false) -> void:
	var from_menu := phase == "menu" or modal_root != null and _menu_tab_box != null and is_instance_valid(_menu_tab_box) and _menu_tab_box.is_inside_tree()
	var fan := force_fan or _uses_fan()
	var land := _is_landscape()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	var head := HBoxContainer.new()
	var tt := UIKit.title("Regole", 44)
	tt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tt)
	var close := UIKit.cta("Chiudi")
	close.custom_minimum_size = Vector2(150, 52)
	close.size_flags_horizontal = 0
	close.pressed.connect(func():
		if from_menu:
			show_menu()
		else:
			_close_modal())
	head.add_child(close)
	vb.add_child(head)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vh := get_viewport().get_visible_rect().size.y
	sc.custom_minimum_size = Vector2(0, max(360.0, vh * 0.74))
	vb.add_child(sc)
	var body: BoxContainer = HBoxContainer.new() if land else VBoxContainer.new()
	body.add_theme_constant_override("separation", 30)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
	var c1 := VBoxContainer.new()
	c1.add_theme_constant_override("separation", 10)
	c1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var c2 := VBoxContainer.new()
	c2.add_theme_constant_override("separation", 10)
	c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(c1)
	body.add_child(c2)
	# --- regolamento ---
	c1.add_child(UIKit.heading("Come si gioca"))
	c1.add_child(_rule_text("""[b]Lo scopo.[/b] Tagliare il traguardo per primi con la propria slitta, senza distruggerla.

[b]La slitta.[/b] Due cani e un freno, tutti a 3 all'inizio. Velocità = cane sinistro + cane destro − freno. Deriva = differenza fra i cani: ti sposti di lato verso il cane più forte (mai più della velocità), nei passi che scegli tu.

[b]Il turno.[/b] Giochi da 1 a 3 carte dello stesso valore, al massimo una per spazio. Le carte sui cani restano; quella sul freno lo imposta e va negli scarti. Poi muovi e torni a 5 carte. Le ammaccature occupano posto in mano e non si scartano.

[b]Ordine.[/b] Muove prima chi è in testa, poi gli altri in ordine di posizione.

[b]Equilibrio.[/b] Con i cani uguali puoi aggiungere un bonus pari alla tua posizione, tutto dritto, a fine movimento. Non al primo turno.

[b]Pericoli.[/b] Curva oltre il limite: un'ammaccatura per punto di troppo (il bonus conta). Bordo: ti fermi e prendi un'ammaccatura. Tamponamento: ti fermi dietro e non peschi. Alla quinta ammaccatura la slitta è distrutta.

[b]Fine.[/b] Si corre finché tutte le slitte hanno tagliato il traguardo. In classifica conta prima il giro in cui si taglia il traguardo, poi chi è andato più lontano oltre la linea."""))
	c1.add_child(UIKit.heading("Varianti"))
	c1.add_child(_rule_text("""[b]Simultaneo.[/b] Tutti programmano la mossa (carte e casella d'arrivo) senza vedere quella degli altri, poi le slitte partono insieme: chi ha più caselle da fare va più veloce. Due slitte non entrano mai nella stessa casella nello stesso momento: se possono la evitano, altrimenti entra la più veloce (a parità, chi era più avanti) e l'altra si ferma prima con mezza ammaccatura.

[b]Schermo condiviso.[/b] Uno schermo grande (TV, computer, tablet) crea la stanza e mostra codice e QR: ogni giocatore lo inquadra col telefono, sceglie la slitta e da lì gioca le carte e sceglie la casella. Sullo schermo grande si vede la pista e, nel simultaneo, chi ha già programmato e poi le slitte che partono insieme.

[b]Gran Tour.[/b] Più piste di fila con le stesse slitte. A ogni gara il primo prende tante punti quante sono le slitte meno una, poi a scalare; una slitta distrutta prende 0. Vince chi ha più punti alla fine."""))
	c1.add_child(UIKit.heading("Comandi"))
	c1.add_child(_rule_text("""Un dito trascina la pista; due dita avvicinano, ruotano e, spostate insieme in su o in giù, inclinano la vista. Col mouse: rotellina per lo zoom, tasto destro per ruotare. «Segui» fa girare la telecamera con la slitta di turno.
Tastiera: 1–5 sceglie una carta; A, S, D (o frecce) la mettono su cane sinistro, freno, cane destro; Invio muove; Backspace riprende le carte; Esc torna indietro o apre il menu."""))
	# --- icone ---
	c2.add_child(UIKit.heading("Sulla pista"))
	c2.add_child(_rule_item(_rule_img("res://assets/rules/limit.png"), "Limite della curva", "Il numero nel cerchio rosso, all'ingresso di curve e inversioni, è la velocità massima. Ogni punto in più (bonus compreso) è un'ammaccatura."))
	c2.add_child(_rule_item(_rule_img("res://assets/rules/leap_sign.png"), "Leap of Death", "La spaccatura fra i due cartelli va saltata a velocità 5 o più; per ogni punto che manca, un'ammaccatura. Chi si ferma sulle caselle della spaccatura non pesca."))
	c2.add_child(_rule_item(_rule_img("res://assets/rules/sapling.png"), "Alberelli", "Chi entra in una casella con un alberello lo travolge e prende un'ammaccatura per ogni alberello. Poi l'alberello sparisce."))
	c2.add_child(_rule_item(_rule_img("res://assets/tiles/snowdrift_p15a.webp", 92, 70), "Cumulo e crepaccio", "Il cumulo di neve e il crepaccio chiudono alcune corsie: sono come il bordo della pista, chi ci finisce contro si ferma e prende un'ammaccatura."))
	c2.add_child(_rule_item(_rule_img("res://assets/tiles/start_p21.webp", 70, 72), "Partenza e traguardo", "Si sceglie a turno la casella di partenza, numerate da 1 a 5. Il traguardo è la linea rossa: conta quanto si va oltre."))
	c2.add_child(UIKit.heading("Segni del gioco"))
	c2.add_child(_rule_item(RuleIcon.new("dest"), "Destinazioni", "Gli anelli che pulsano sono le caselle dove puoi arrivare: tocca quella che vuoi."))
	c2.add_child(_rule_item(RuleIcon.new("path"), "Percorso", "La linea sottile col puntino in ogni casella è la strada che farà la slitta."))
	c2.add_child(_rule_item(RuleIcon.new("drift"), "Deriva", "Il tratto largo e chiaro è uno spostamento di lato verso il cane più forte."))
	c2.add_child(_rule_item(RuleIcon.new("dent"), "Ammaccature", "Il numero rosso sopra una destinazione dice quante ammaccature prendi arrivando lì."))
	# --- fanmade ---
	if fan:
		c2.add_child(UIKit.heading("Segmenti fanmade"))
		c2.add_child(_rule_item(_rule_img("res://assets/fan/sign_up.png", 64, 64), "Salita", "Chi parte da una tessera in salita ha %d punti di velocità in meno, come un freno in più (non si va sotto zero)." % SledGame.UP_LOSS))
		c2.add_child(_rule_item(_rule_img("res://assets/fan/sign_down.png", 64, 64), "Discesa", "Chi parte da una tessera in discesa guadagna 1 punto di velocità ogni %d: a 3 va a 4, a 6 va a 8, a 9 va a 12." % SledGame.DOWN_PER))
		c2.add_child(_rule_item(_rule_img("res://assets/fan/sign_fresh.png", 64, 64), "Neve fresca", "Ogni casella coi cumuli costa 2 punti di movimento; la prima slitta che ci passa la spazza via."))
		c2.add_child(_rule_item(_rule_img("res://assets/fan/sign_ice.png", 64, 64), "Ghiaccio", "Chi entra derivando continua a derivare finché è sul ghiaccio; a fine movimento scivola avanti di una casella."))
		c2.add_child(_rule_item(_rule_img("res://assets/fan/sign_wind.png", 64, 64), "Vento", "Chi parte da una tessera col vento ha 1 di deriva in più nel verso della manica a vento: si somma a quella dei cani (o la riduce, se va dall'altra parte). Il bonus di equilibrio vale solo se la deriva totale è zero."))
		c2.add_child(_rule_item(_rule_img("res://assets/fan/sign_hut.png", 64, 64), "Baita", "Chi si ferma sulla casella accanto alla baita ripara metà delle ammaccature (arrotondando a suo favore), ma non pesca."))
		c2.add_child(_rule_item(_rule_img("res://assets/rules/fork_sign.png", 64, 64), "Bivio", "Un'isola di abeti divide la pista in due rami con un numero diverso di caselle: da una parte neve fresca, dall'altra alberelli."))
	else:
		var bf := UIKit.button("Mostra anche le regole fanmade")
		bf.custom_minimum_size = Vector2(0, 50)
		bf.pressed.connect(func(): show_help(true))
		c2.add_child(bf)
	_modal(vb, 1180.0 if land else 700.0, from_menu)

# ======================= PARTITA =======================
func start_game() -> void:
	online = {}
	tour = {}
	if _is_tour():
		var files := []
		for f in course_files:
			if tour_sel.has(f):
				files.append(f)
		if files.is_empty():
			return
		tour = {"files": files, "i": 0, "flags": _seat_flags(), "tot": {}, "races": [], "names": {}}
		_tour_race()
		return
	var def := _menu_course_def()
	if def.is_empty():
		return
	_begin_race(def, _seat_flags(), 0)

## Gran Tour: corre la pista numero tour.i con le stesse slitte.
func _tour_race() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(tour["files"][tour["i"]]))
	if not d is Dictionary:
		_toast("Percorso non valido")
		return
	_begin_race(d, tour["flags"], 0)
	game.log_text = "Gran Tour, gara %d di %d: [b]%s[/b]." % [int(tour["i"]) + 1, tour["files"].size(), course.title]
	_refresh()

## Punti della gara appena finita: in N slitte il primo prende N−1, poi a scalare; distrutta 0.
func _tour_score() -> void:
	if (tour["races"] as Array).size() > int(tour["i"]):
		return
	var n := game.players.size()
	var race := []
	var k := 0
	for r in game.results:
		var p = r["p"]
		var pts: int = 0 if String(r["st"]) == "distrutta" else max(0, n - 1 - k)
		race.append({"seat": p.seat, "pts": pts, "st": String(r["st"])})
		tour["tot"][p.seat] = int(tour["tot"].get(p.seat, 0)) + pts
		tour["names"][p.seat] = p.name
		k += 1
	tour["races"].append(race)

func _tour_row(pos: String, seat: int, name: String, value: String, sub := "", hi := false) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.box(Color("fff6d6") if hi else UIKit.SOFT, 14, SledGame.COLORS[seat] if hi else Color(0, 0, 0, 0), 2 if hi else 0, 10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var pl := UIKit.label(pos, 26)
	pl.autowrap_mode = TextServer.AUTOWRAP_OFF
	pl.custom_minimum_size = Vector2(34, 0)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pl)
	var dot := ColorRect.new()
	dot.color = SledGame.COLORS[seat]
	dot.custom_minimum_size = Vector2(10, 0)
	row.add_child(dot)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	var nm := UIKit.label(name, 21)
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	nm.clip_text = true
	col.add_child(nm)
	if sub != "":
		col.add_child(UIKit.label(sub, 15, UIKit.MUTED))
	row.add_child(col)
	var vl := UIKit.label(value, 26, UIKit.ACCENT_DARK)
	vl.autowrap_mode = TextServer.AUTOWRAP_OFF
	vl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(vl)
	return card

## Classifica di fine gara nel Gran Tour: la gara appena corsa e il totale.
func _tour_results() -> void:
	_tour_score()
	var i := int(tour["i"])
	var m: int = tour["files"].size()
	var last := i >= m - 1
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.add_child(UIKit.title("Gran Tour concluso" if last else "Gran Tour", 46))
	vb.add_child(UIKit.label("Gara %d di %d: %s, dopo %d giri" % [i + 1, m, course.title, game.round_n], 19, UIKit.MUTED))
	var cols: BoxContainer = HBoxContainer.new() if _is_landscape() else VBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	var a := VBoxContainer.new()
	a.add_theme_constant_override("separation", 6)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.add_child(UIKit.heading("Questa gara"))
	var race: Array = tour["races"][i]
	var k := 0
	for r in race:
		k += 1
		var dist: bool = r["st"] == "distrutta"
		a.add_child(_tour_row("✕" if dist else str(k), r["seat"], tour["names"][r["seat"]], "+%d" % r["pts"], r["st"], k == 1 and not dist))
	cols.add_child(a)
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", 6)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_child(UIKit.heading("Classifica generale"))
	# a parità di punti conta il piazzamento nell'ultima gara
	var order := []
	for r in race:
		order.append(int(r["seat"]))
	var seats := order.duplicate()
	seats.sort_custom(func(x, y):
		var tx := int(tour["tot"].get(x, 0))
		var ty := int(tour["tot"].get(y, 0))
		return tx > ty or (tx == ty and order.find(x) < order.find(y)))
	var pos := 0
	var prev := -1
	for j in seats.size():
		var t := int(tour["tot"].get(seats[j], 0))
		if t != prev:
			pos = j + 1
			prev = t
		b.add_child(_tour_row(str(pos), seats[j], tour["names"][seats[j]], "%d pt" % t, "", j == 0 and last))
	cols.add_child(b)
	vb.add_child(cols)
	if last:
		vb.add_child(UIKit.label("Vince il Gran Tour: %s" % tour["names"][seats[0]], 24, UIKit.INK))
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 10)
	var b0 := UIKit.button("Rivedi la gara")
	b0.pressed.connect(start_replay)
	b0.disabled = game.history.is_empty()
	acts.add_child(b0)
	var b1 := UIKit.button("Guarda la pista")
	b1.pressed.connect(_close_modal)
	acts.add_child(b1)
	if last:
		var b2 := UIKit.cta("Nuova gara")
		b2.pressed.connect(func():
			tour = {}
			show_menu())
		acts.add_child(b2)
	else:
		var nc := Course.new()
		nc.load_file(tour["files"][i + 1])
		var b3 := UIKit.cta("Prossima: " + nc.title)
		b3.pressed.connect(func():
			tour["i"] = i + 1
			_tour_race())
		acts.add_child(b3)
	vb.add_child(acts)
	_modal(vb, 1000 if _is_landscape() else 700)

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
	game.simultaneous = sim_variant if online.is_empty() else bool(online.get("sim", false))
	for k in names:
		for p in game.players:
			if p.seat == int(k):
				p.name = "%s (%s)" % [SledGame.NAMES[p.seat], names[k]]
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
	if not tour.is_empty() and online.is_empty():
		_tour_results()
		return
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
	elif phase == "cards" and show_paths and not pending.is_empty() and not board.preview.is_empty():
		# percorsi visibili: toccando un arrivo la slitta parte subito
		var end := -1
		for pv in board.preview:
			var d0: float = w.distance_to(course.cells[pv["end"]]["pos"])
			if d0 < bd:
				bd = d0
				end = int(pv["end"])
		if end >= 0:
			for o in game.compute_outs(cur, game.mat_after(cur, pending)):
				if int(o["end"]) == end:
					_submit_move(pending, o)
					return
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
			lbl = ("bordo −%d" if o["crash"] == "edge" else "−%d") % o["dents"]
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
	if game.simultaneous and not online.is_empty() and not online.get("over", false):
		var p = cur
		var k := sim_racers.find(p)
		pending = []
		sel = -1
		outs = []
		board.destinations = []
		phase = "simwait"
		cur = null
		_posting_prog = true
		_refresh()
		await _post_prog(sim_base + k, p, pend.duplicate(true), o)
		_posting_prog = false
		_refresh()
		return
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
	if not online.is_empty() and not online.get("over", false):
		await _sim_round_online(my)
		return
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
		disc_buf = []
		if online.is_empty() or online.get("over", false):
			phase = "discard"
			_refresh()
		else:
			var ctl := await _ctl(p)
			if my != race_id:
				return
			if ctl == "me":
				phase = "discard"
				_refresh()
			elif ctl == "cpu":
				_do_act({"k": "disc", "v": game.ai_discard_values(p)})
			else:
				phase = "wait"
				_refresh()
				_wait_act("disc")
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

# ---------- variante simultanea online (telefoni + schermo condiviso) ----------
## Ogni slitta in gara ha il suo numero di mossa nel giro (sim_base + posizione): ognuno scrive la
## propria programmazione, chi ha creato la stanza quella delle CPU e di chi non risponde.
## Quando ci sono tutte, ogni dispositivo risolve il giro allo stesso modo.
func _sim_round_online(my: int) -> void:
	game.order = game.race_order()
	sim_progs = {}
	sim_racers = []
	for p in game.order.duplicate():
		if not game.racing(p):
			continue
		if p.hand.is_empty():
			var c0: int = p.cell
			game.add_dent(p, 1)
			game.record(p, c0, [], [])
			game.log_text = "[b]%s[/b] non ha carte cane: prende un'ammaccatura" % p.name
			if p.wrecked:
				continue
			game.draw_up(p)
		sim_racers.append(p)
	sim_base = int(online["n"])
	var code: String = online["code"]
	var mine = null
	for p in sim_racers:
		if _is_mine(p):
			mine = p
	cur = null
	phase = "simwait"
	_refresh()
	if online["role"] == "host":
		for k in sim_racers.size():
			var p = sim_racers[k]
			if p.ai:
				var ch := game.ai_choose(p)
				await _post_prog(sim_base + k, p, ch["pend"], ch["o"])
				if my != race_id:
					return
		_refresh()
	if mine != null and not sim_progs.has(mine.id) and _backlog_at(sim_base + sim_racers.find(mine)).is_empty():
		cur = mine
		pending = []
		sel = -1
		outs = []
		board.destinations = []
		board.focus_cell(mine.cell)
		phase = "cards"
		_refresh()
	var t0 := Time.get_ticks_msec()
	var seen := {}
	var polls := 0
	while true:
		if my != race_id or online.is_empty():
			return
		var missing := 0
		for k in sim_racers.size():
			var p = sim_racers[k]
			if sim_progs.has(p.id):
				continue
			if p == mine and _posting_prog:
				missing += 1
				continue
			var a := _backlog_at(sim_base + k)
			if a.is_empty():
				a = await net.get_act(code, sim_base + k)
				if my != race_id or online.is_empty():
					return
			if sim_progs.has(p.id):
				continue
			if not a.is_empty() and not a.has("_err"):
				sim_progs[p.id] = _prog_from_act(p, a)
				if p == mine and phase in ["cards", "dest"]:
					pending = []
					sel = -1
					outs = []
					board.destinations = []
					cur = null
					phase = "simwait"
					game.log_text = "Eri via: il computer ha programmato al tuo posto."
				_refresh()
				continue
			missing += 1
			# chi ha creato la stanza: se un giocatore tace troppo, programma il computer al suo posto
			if online["role"] == "host" and not p.ai and p != mine and polls % 4 == 0:
				if await _sim_away(p, t0, seen):
					if my != race_id:
						return
					var ch := game.ai_choose(p)
					await _post_prog(sim_base + k, p, ch["pend"], ch["o"])
					if my != race_id:
						return
					_refresh()
		if missing == 0:
			break
		if online.get("catchup", false) and sim_base + sim_racers.size() > (online.get("backlog", []) as Array).size():
			online["catchup"] = false
			_refresh()
		polls += 1
		await _pause(1.2)
	online["n"] = sim_base + sim_racers.size()
	if online.get("catchup", false) and int(online["n"]) >= (online.get("backlog", []) as Array).size():
		online["catchup"] = false
	cur = null
	await _sim_resolve(my)

## Una mossa già registrata (per chi rientra in una gara), oppure {}.
func _backlog_at(n: int) -> Dictionary:
	var bl: Array = online.get("backlog", [])
	return bl[n] if n < bl.size() and bl[n] is Dictionary else {}

## Pubblica la programmazione di p al numero idx; se c'è già (scritta da altri), vale quella.
func _post_prog(idx: int, p, pend: Array, o: Dictionary) -> void:
	var my := race_id
	var a := _move_act(pend, o)
	a["k"] = "prog"
	a["s"] = p.seat
	while true:
		var ok := await net.post_act(online["code"], idx, a)
		if my != race_id or online.is_empty():
			return
		if ok:
			sim_progs[p.id] = {"pend": pend, "o": o}
			return
		var ex := await net.get_act(online["code"], idx)
		if my != race_id or online.is_empty():
			return
		if not ex.is_empty() and not ex.has("_err"):
			sim_progs[p.id] = _prog_from_act(p, ex)
			return
		game.log_text = "Rete non raggiungibile, riprovo… (%s)" % net.last_error
		_refresh()
		await get_tree().create_timer(2.0).timeout
		if my != race_id or online.is_empty():
			return

## Dalla mossa registrata alla programmazione: carte e casella d'arrivo (ricalcolate sulle posizioni di inizio giro).
func _prog_from_act(p, a: Dictionary) -> Dictionary:
	var pend := []
	var cs: Array = a.get("c", [])
	var sl: Array = a.get("sl", [])
	for i in cs.size():
		pend.append({"v": int(cs[i]), "slot": String(sl[i])})
	var cands := game.compute_outs(p, game.mat_after(p, pend))
	if cands.is_empty():
		return {"pend": [], "o": {"end": p.cell, "path": [], "n": 0, "sap": [], "half": false, "crash": "", "dents": 0, "bonus": false}}
	var o: Dictionary = cands[0]
	for c in cands:
		if int(c["end"]) == int(a.get("e", -1)):
			o = c
			break
	return {"pend": pend, "o": o}

## Chi ha creato la stanza controlla se p è ancora collegato (un minuto di silenzio = assente).
func _sim_away(p, t0: int, seen: Dictionary) -> bool:
	if (online["away"] as Dictionary).has(p.seat):
		var st0 := await net.seat(online["code"], p.seat)
		if not st0.is_empty() and not st0.get("away", false):
			online["away"].erase(p.seat)
			return false
		return true
	var st := await net.seat(online["code"], p.seat)
	if st.is_empty():
		return false
	var now := Time.get_ticks_msec()
	var sv = st.get("seen", null)
	if not seen.has(p.seat) or seen[p.seat][0] != sv:
		seen[p.seat] = [sv, now]
	if st.get("away", false) or (now - int(seen[p.seat][1]) > 45000 and now - t0 > 60000):
		await net.set_away(online["code"], p.seat, true)
		online["away"][p.seat] = true
		game.log_text = "[b]%s[/b] non risponde: per ora guida il computer." % p.name
		return true
	return false

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
			board.preview.append({"path": o["path"], "from": cur.cell, "end": o["end"], "dents": o["dents"], "color": cur.color, "crash": String(o["crash"])})
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
			t += " ✓"
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
	v.add_theme_constant_override("separation", -4)
	pc.add_child(v)
	var t := UIKit.label(title, 12, UIKit.MUTED)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(t)
	var val := _big(value, 26, UIKit.DANGER if warn else UIKit.INK)
	v.add_child(val)
	return pc

## Numero o valore grande, con il carattere dei titoli del menu.
func _big(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UIKit.font(UIKit.F_TITLE))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l

## Riga lunga: che cosa c'è davanti (curva, traguardo, salto, tratto fanmade) e quanto manca.
func _info_row(title: String, value: String, warn := false) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", UIKit.box(Color("fdecea") if warn else UIKit.SOFT, 8, UIKit.DANGER if warn else Color(0, 0, 0, 0), 2 if warn else 0, 4))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	pc.add_child(h)
	var t := UIKit.label(title, 15, UIKit.MUTED)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(t)
	h.add_child(_big(value, 22, UIKit.DANGER if warn else UIKit.INK))
	return pc

func _stat_grid() -> Control:
	var m := game.mat_after(cur, pending if (phase == "cards" or phase == "dest") else [])
	var speed: int = game.effective_speed(cur.cell, m)
	var d: int = game.effective_drift(cur.cell, m)
	var c: Dictionary = course.cells[cur.cell]
	var outer := HBoxContainer.new()
	outer.add_theme_constant_override("separation", 5)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(col)
	# 1. velocità, deriva, bonus
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 5)
	col.add_child(top)
	var sl := course.slope_of(cur.cell)
	top.add_child(_tile("Velocità" + (" (salita)" if sl == "up" else (" (discesa)" if sl == "down" else "")), str(speed)))
	top.add_child(_tile("Deriva" + (" (vento)" if course.wind_of(cur.cell) != 0 else ""), "0" if d == 0 else "%d %s" % [min(abs(d), speed), "→" if d > 0 else "←"]))
	var bonus := "—"
	if d == 0 and m["L"] == m["R"] and cur.moves > 0 and speed > 0:
		bonus = "+%d" % game.rank_of(cur)
	top.add_child(_tile("Bonus", bonus))
	# 2. che cosa c'è davanti: al massimo due righe
	var rows := []
	var nl := course.next_limit(float(c["s"]))
	if not nl.is_empty():
		var dist := int(round((float(nl["s"]) - float(c["s"])) / course.cell_len))
		rows.append(["Curva, limite %d" % nl["lim"], "fra %d" % max(dist, 0), speed > int(nl["lim"]) and dist <= speed])
	else:
		var df := int(round((course.finish_s - float(c["s"])) / course.cell_len))
		rows.append(["Traguardo", ("fra %d" % df) if df > 0 else "passato", false])
	var lp := course.next_leap(float(c["s"]))
	if not lp.is_empty() and (float(lp["s"]) - float(c["s"])) / course.cell_len <= 14:
		var dl := int(round((float(lp["s"]) - float(c["s"])) / course.cell_len))
		rows.append(["Salto, minimo %d" % lp["min"], "fra %d" % max(dl, 0), speed < int(lp["min"]) and dl <= speed])
	var sg := _seg_ahead(cur.cell, max(speed, 1) + 3)
	if not sg.is_empty():
		var when := "qui" if int(sg["dist"]) == 0 else "fra %d" % int(sg["dist"])
		for ft in sg["feats"]:
			var it: Array = {"up": ["Salita: −%d velocità" % SledGame.UP_LOSS], "down": ["Discesa: +1 ogni %d" % SledGame.DOWN_PER],
				"windR": ["Vento: deriva +1 →"], "windL": ["Vento: deriva +1 ←"], "ice": ["Ghiaccio: si scivola"],
				"fresh": ["Neve fresca: costa 2"], "hut": ["Baita: ripara metà"], "fork": ["Bivio: scegli il ramo"]}.get(ft, [ft])
			rows.append([it[0], when, false])
	for r in rows.slice(0, 2):
		col.add_child(_info_row(r[0], r[1], r[2]))
	if _is_mine(cur):
		var tb := Button.new()
		tb.toggle_mode = true
		tb.button_pressed = show_paths
		tb.text = "Percorsi\n%s" % ("sì" if show_paths else "no")
		tb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tb.add_theme_font_size_override("font_size", 13)
		tb.custom_minimum_size = Vector2(78, 0)
		var on_col: Color = cur.color
		UIKit.style_button(tb, on_col if show_paths else UIKit.SOFT, Color.WHITE if show_paths else UIKit.INK, on_col, 2, 10)
		tb.tooltip_text = "Mostra sulla pista tutti i percorsi possibili con le carte messe sulla plancia"
		tb.toggled.connect(func(on):
			show_paths = on
			_refresh())
		outer.add_child(tb)
	return outer

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
		"simwait":
			if not online.is_empty():
				if _posting_prog:
					return "Invio la tua mossa…"
				return "Si aspettano le mosse di tutti: quando ognuno ha programmato, le slitte partono insieme."
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
	if phase == "simwait" and not online.is_empty():
		bottom_box.add_child(_sim_ready_row())
		for q in game.players:
			if _is_mine(q) and not q.wrecked:
				bottom_box.add_child(UIKit.label("La tua mano", 15, UIKit.MUTED))
				bottom_box.add_child(_hand(q, false, true))
				break
		return
	if cur == null:
		return
	if cur.wrecked:
		bottom_box.add_child(_hint("[b]%s[/b]: la slitta è distrutta." % cur.name))
		return
	var use_pending := phase == "cards" or phase == "dest"
	var m := game.mat_after(cur, pending if use_pending else [])
	bottom_box.add_child(_mat_row(_mat(m, phase == "cards")))
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

## Chi ha già programmato la mossa (✓) e chi no, senza svelare niente.
func _sim_ready_row() -> HFlowContainer:
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 8)
	fl.add_theme_constant_override("v_separation", 6)
	for p in sim_racers:
		var ok: bool = sim_progs.has(p.id)
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", UIKit.box(Color(p.color, 0.18) if ok else UIKit.SOFT, 10, p.color, 2, 8))
		var l := UIKit.label(("✓ " if ok else "… ") + p.name, 20, UIKit.INK if ok else UIKit.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		pc.add_child(l)
		fl.add_child(pc)
	return fl

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

## Plancia con il mazzo a sinistra e gli scarti a destra.
func _mat_row(mv: MatView) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.size_flags_vertical = mv.size_flags_vertical
	mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tex := CardArt.mat(cur.id)
	if layout_mode != "land" and tex != null:
		# in verticale la plancia ha la sua larghezza: mazzo e scarti le stanno accanto
		var ts := tex.get_size()
		mv.custom_minimum_size.x = mv.custom_minimum_size.y * ts.x / ts.y
		mv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 14)
	h.add_child(_pile("Mazzo", cur.deck.size()))
	h.add_child(mv)
	h.add_child(_pile("Scarti", cur.discard.size() + cur.used.size()))
	return h

func _pile(title: String, n: int) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UIKit.box(UIKit.SOFT, 8, Color(0, 0, 0, 0), 0, 4))
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pc.custom_minimum_size = Vector2(58, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	pc.add_child(v)
	var t := UIKit.label(title, 12, UIKit.MUTED)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var b := _big(str(n), 26, UIKit.INK)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(b)
	return pc

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
	return p.seat == int(online["seat"])

## Chi decide la prossima mossa di p: "me" (la persona davanti a questo dispositivo),
## "cpu" (il computer, su questo dispositivo) oppure "wait" (un altro dispositivo).
func _ctl(p) -> String:
	if online.is_empty() or online.get("over", false):
		return "cpu" if p.ai else "me"
	if p.seat == int(online["seat"]):
		return "me"
	if online["role"] != "host":
		return "wait"
	if p.ai:
		return "cpu"
	if (online["away"] as Dictionary).has(p.seat):
		# è rientrato?
		var st := await net.seat(online["code"], p.seat)
		if not st.is_empty() and not st.get("away", false):
			online["away"].erase(p.seat)
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
	a["s"] = cur.seat
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
		if a.has("s") and int(a["s"]) != cur.seat:
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
	var who: int = cur.seat
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
		if online["role"] == "host" and not cur.ai and polls % 4 == 0:
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
	bc.pressed.connect(_online_create.bind(false))
	v.add_child(bc)
	var bt := UIKit.button("Schermo condiviso: si gioca col telefono")
	bt.pressed.connect(_online_create.bind(true))
	v.add_child(bt)
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
	_on_lbl = UIKit.label("Le slitte su «Persona» sono i posti per gli amici, che entrano col codice (i posti liberi li guida la CPU). Con «Schermo condiviso» qui si vede solo la gara e tutti giocano dal telefono.", 17, UIKit.MUTED)
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
	UIKit.touch_text(le, ph.capitalize())
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
	if online.get("lobby", false) and _is_tour():
		_on_text("Il Gran Tour è solo per le partite su questo dispositivo: scegli una pista singola.")
		return
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

## table: questo schermo non gioca, mostra la pista; le persone giocano dal proprio telefono.
func _online_create(table := false) -> void:
	if _is_tour():
		_on_text("Il Gran Tour è solo per le partite su questo dispositivo: scegli una pista singola.")
		return
	var nm := _player_name()
	if nm == "" and not table:
		_on_text("Scrivi il tuo nome.")
		return
	var seats := []
	for i in setup_on.size():
		if setup_on[i] and not setup_ai[i]:
			seats.append(i)
	if table and seats.is_empty():
		_on_text("Metti su «Persona» le slitte che guideranno i giocatori col telefono.")
		return
	if not table and seats.size() < 2:
		_on_text("Metti su «Persona» almeno due slitte: la prima è la tua, le altre sono i posti per gli amici.")
		return
	_on_text("Creo la stanza…")
	var code := await _net().create_room(nm if nm != "" else "Schermo", seats, table)
	if code == "":
		_on_text("Non riesco a creare la stanza.\n%s" % net.last_error)
		return
	var seat: int = -1 if table else seats[0]
	online = {"role": "host", "code": code, "seat": seat, "table": table, "n": 0, "away": {}, "lobby": true}
	net.remember_room(code, seat)
	if nm != "":
		net._save({"name": nm})
	if is_instance_valid(_on_code):
		_on_code.text = code
	if table:
		_table_lobby(code)
	else:
		_online_lobby_poll(code)

## Indirizzo del gioco con il codice della stanza: il telefono che lo apre entra direttamente.
func _join_url(code: String) -> String:
	var base := "https://tannoiser2.github.io/SnowTails/"
	if OS.has_feature("web"):
		var b = JavaScriptBridge.eval("location.origin + location.pathname")
		if b != null and str(b).begins_with("http"):
			base = str(b)
	return base + "?r=" + code

## Schermo condiviso in attesa dei giocatori: codice grande, QR e posti.
func _table_lobby(code: String) -> void:
	var land := _is_landscape()
	var root_box: BoxContainer = HBoxContainer.new() if land else VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 30)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(UIKit.title("Snow Tails", 50))
	left.add_child(UIKit.label("Inquadra il codice col telefono, oppure apri", 19, UIKit.MUTED))
	var url := _join_url(code)
	var ul := UIKit.label(url.replace("https://", ""), 19, UIKit.ACCENT_DARK)
	left.add_child(ul)
	left.add_child(UIKit.label("e scrivi il codice della stanza:", 19, UIKit.MUTED))
	var cl := UIKit.title(code, 92)
	left.add_child(cl)
	var seats_box := VBoxContainer.new()
	seats_box.add_theme_constant_override("separation", 6)
	left.add_child(UIKit.heading("Giocatori"))
	left.add_child(seats_box)
	var info := UIKit.label("Le slitte senza giocatore le guida la CPU. Movimento: %s." % ("simultaneo" if sim_variant else "a turni"), 17, UIKit.MUTED)
	left.add_child(info)
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 10)
	var bx := UIKit.button("Annulla")
	bx.pressed.connect(func():
		online = {}
		net.remember_room("")
		show_menu())
	acts.add_child(bx)
	var bs := UIKit.cta("Inizia la gara")
	bs.pressed.connect(_online_start)
	acts.add_child(bs)
	left.add_child(acts)
	root_box.add_child(left)
	var q := QR.make(url)
	if q != null:
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(q.image(10))
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(380, 380)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var cc := CenterContainer.new()
		cc.add_child(tr)
		root_box.add_child(cc)
	_modal(root_box, 1100 if land else 700, true)
	_on_lbl = info
	while online.get("code", "") == code and online.get("lobby", false):
		var room := await net.room(code)
		if online.get("code", "") != code or not online.get("lobby", false) or not is_instance_valid(seats_box):
			return
		UIKit.clear(seats_box)
		var st := Net._as_dict(room.get("seats", {}))
		for idx in room.get("open", []):
			var i := int(idx)
			var r := HBoxContainer.new()
			r.add_theme_constant_override("separation", 10)
			var dot := ColorRect.new()
			dot.color = SledGame.COLORS[i]
			dot.custom_minimum_size = Vector2(22, 22)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			r.add_child(dot)
			var k := str(i)
			var who := str(st[k].get("name", "?")) if st.has(k) and st[k] is Dictionary else "libero (CPU)"
			var wl := UIKit.label("%s: %s" % [SledGame.NAMES[i], who], 22, UIKit.INK if st.has(k) else UIKit.MUTED)
			wl.autowrap_mode = TextServer.AUTOWRAP_OFF
			r.add_child(wl)
			seats_box.add_child(r)
		await get_tree().create_timer(2.0).timeout

## Telefono aperto dal QR (?r=CODICE): nome, colore e via, senza il menu completo.
func _phone_join(code: String) -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.add_child(UIKit.title("Snow Tails", 50))
	vb.add_child(UIKit.label("Stanza %s" % code, 26, UIKit.INK))
	var ses := _net().load_session()
	_on_name = _line_edit("il tuo nome", 20)
	_on_name.text = str(ses.get("name", ""))
	vb.add_child(_on_name)
	_on_code = LineEdit.new()
	_on_code.text = code
	_on_code.visible = false
	vb.add_child(_on_code)
	vb.add_child(UIKit.label("Scegli la slitta:", 19, UIKit.MUTED))
	var colors := VBoxContainer.new()
	colors.add_theme_constant_override("separation", 8)
	vb.add_child(colors)
	_on_lbl = UIKit.label("Cerco la stanza…", 18, UIKit.MUTED)
	vb.add_child(_on_lbl)
	var bm := UIKit.button("Vai al menu")
	bm.pressed.connect(func():
		online = {}
		show_menu())
	vb.add_child(bm)
	_modal(vb, 560, true)
	if not await net.sign_in():
		_on_text("Rete non raggiungibile: %s" % net.last_error)
		return
	var room := await net.room(code)
	if room.is_empty():
		_on_text("La stanza %s non esiste (o è chiusa)." % code)
		return
	var st := Net._as_dict(room.get("seats", {}))
	for k in st:
		if st[k] is Dictionary and st[k].get("uid", "") == net.uid:
			_on_text("Rientro nella stanza…")
			_online_join()
			return
	var any := false
	for idx in room.get("open", []):
		var i := int(idx)
		if st.has(str(i)):
			continue
		any = true
		var b := UIKit.button(SledGame.NAMES[i])
		b.custom_minimum_size = Vector2(0, 60)
		UIKit.style_button(b, SledGame.COLORS[i], Color.WHITE, SledGame.COLORS[i].darkened(0.3), 2, 14, 4)
		b.pressed.connect(func():
			_join_want = i
			_online_join())
		colors.add_child(b)
	_on_text("" if any else ("La gara è già partita." if room.get("status", "") != "lobby" else "Non ci sono slitte libere."))

func _online_join() -> void:
	var code := _on_code.text.strip_edges().to_upper() if is_instance_valid(_on_code) else ""
	var nm := _player_name()
	if nm == "" or code.length() != 4:
		_on_text("Scrivi il tuo nome e il codice di 4 lettere.")
		return
	if not online.is_empty() and online.get("code", "") == code:
		return
	_on_text("Entro nella stanza %s…" % code)
	var seat := await _net().join_room(code, nm, _join_want)
	if seat == -3:
		# lo schermo condiviso che aveva creato la stanza la riapre
		var rm: Dictionary = net.last_room
		online = {"role": "host", "code": code, "seat": -1, "table": true, "n": 0, "away": {}, "lobby": true}
		net.remember_room(code, -1)
		if rm.get("status", "") == "playing" and rm.has("game"):
			_online_begin(rm["game"], true)
		else:
			_table_lobby(code)
		return
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
	if not online.get("table", false) and (not setup_on[int(online["seat"])] or not seats.has(str(int(online["seat"])))):
		_on_text("Hai cambiato le slitte dopo aver creato la stanza: creane una nuova.")
		return
	var ai := []
	var names := {}
	for i in setup_on.size():
		var k := str(i)
		if not setup_on[i]:
			ai.append(-1)
		elif seats.has(k) and seats[k] is Dictionary:
			ai.append(0)
			names[k] = str(seats[k].get("name", ""))
		else:
			ai.append(1)
	var g := {"seed": 1 + randi() % 2000000000, "def": JSON.stringify(def), "ai": ai, "names": names, "sim": sim_variant}
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
	online["sim"] = bool(g.get("sim", false))
	var backlog: Array = []
	if rejoin:
		backlog = await net.get_acts(online["code"])
		if int(online["seat"]) >= 0:
			net.set_away(online["code"], int(online["seat"]), false)
	online["backlog"] = backlog
	online["catchup"] = not backlog.is_empty()
	var def = JSON.parse_string(str(g.get("def", ""))) if g.get("def") is String else g.get("def", {})
	var ai := []
	for x in g.get("ai", []):
		ai.append(x if x is bool else int(x))
	var names: Dictionary = g.get("names", {}) if g.get("names") is Dictionary else Net._as_dict(g.get("names", {}))
	_begin_race(def if def is Dictionary else {}, ai, int(g.get("seed", 1)), names)
	if online["role"] != "host" and int(online["seat"]) >= 0:
		_heartbeat(race_id)
