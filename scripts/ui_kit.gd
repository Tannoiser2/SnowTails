class_name UIKit
extends RefCounted
## Piccoli aiuti per costruire l'interfaccia da codice.

## Tavolozza «ghiaccio e legno»: blu notte e azzurri glaciali, con il legno e il giallo
## del cartello della scatola per le azioni principali.
const INK := Color("17324d")
const MUTED := Color("4d6884")
const PANEL := Color("f3f8fd")
const SOFT := Color("e2eef8")
const LINE := Color("b6d2e9")
const ACCENT := Color("2a78b5")        # azzurro glaciale: scelte selezionate
const ACCENT_DARK := Color("1b5583")
const WOOD := Color("7b4a26")          # legno del cartello: azione principale
const WOOD_DARK := Color("4e2c12")
const SIGN_YELLOW := Color("ffd447")   # lettere gialle del logo
const FROST := Color("ffffff")

const F_BODY := "res://assets/fonts/Nunito-600.woff2"
const F_BOLD := "res://assets/fonts/Nunito-800.woff2"
const F_BLACK := "res://assets/fonts/Nunito-900.woff2"
const F_TITLE := "res://assets/fonts/LuckiestGuy.woff2"
static var _fonts := {}

const F_SYMBOLS := "res://assets/fonts/NotoSansSymbols2.woff2"   # ★ ✓ ✎ ⚠ ✕ ▪ ▫ •
const F_MATH := "res://assets/fonts/NotoSansMath.woff2"         # ← → e altri segni

static func font(path: String) -> Font:
	if not _fonts.has(path):
		var f: Font = load(path) if ResourceLoader.exists(path) else ThemeDB.fallback_font
		_add_fallbacks(f)
		_fonts[path] = f
	return _fonts[path]

## I font del testo hanno solo le lettere: frecce, stelle, spunte e simili si prendono dai font
## di simboli. Sul computer ci pensa il sistema, ma nel browser (iPad compreso) senza questi
## ripieghi comparirebbero i codici dei caratteri.
static func _add_fallbacks(f: Font) -> void:
	if not (f is FontFile):
		return
	var fb: Array[Font] = []
	for p in [F_SYMBOLS, F_MATH]:
		if ResourceLoader.exists(p):
			fb.append(load(p))
	if not fb.is_empty() and (f as FontFile).fallbacks.is_empty():
		(f as FontFile).fallbacks = fb

## Da chiamare all'avvio di ogni scena: aggiunge i ripieghi anche al font predefinito del
## progetto (quello di Label3D e dei controlli senza font proprio).
static func setup_fonts() -> void:
	for p in [F_BODY, F_BOLD, F_BLACK, F_TITLE]:
		font(p)
	var d := ThemeDB.fallback_font
	_add_fallbacks(d)

## Campo di testo su tablet e telefono nel browser: Safari apre la tastiera solo toccando un
## vero campo della pagina, quindi sopra il campo del gioco se ne mette uno HTML invisibile.
## Quello che si scrive lì compare nel campo del gioco; niente finestre in più.
static func touch_text(le: LineEdit, _title := "") -> void:
	if not OS.has_feature("web"):
		return
	le.add_child(WebTextField.new())

## Tema di tutto il gioco: font, campi di testo, menu a tendina, barre di scorrimento.
static func make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = font(F_BODY)
	th.default_font_size = 20
	th.set_font("bold_font", "RichTextLabel", font(F_BLACK))
	th.set_font("normal_font", "RichTextLabel", font(F_BODY))
	th.set_color("font_color", "Label", INK)
	# campi di testo: ghiaccio con bordo azzurro
	var le := box(Color("ffffff", 0.85), 12, LINE, 2, 12)
	var lef := box(Color("ffffff"), 12, ACCENT, 3, 12)
	th.set_stylebox("normal", "LineEdit", le)
	th.set_stylebox("focus", "LineEdit", lef)
	th.set_color("font_color", "LineEdit", INK)
	th.set_color("font_placeholder_color", "LineEdit", Color(MUTED, 0.7))
	th.set_color("caret_color", "LineEdit", ACCENT)
	# menu a tendina
	for st in ["normal", "hover", "pressed", "focus"]:
		var b := box(SOFT if st != "hover" else SOFT.lightened(0.35), 14, LINE if st != "focus" else ACCENT, 2 if st != "focus" else 3, 14)
		b.border_width_bottom = 4
		th.set_stylebox(st, "OptionButton", b)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		th.set_color(c, "OptionButton", INK)
	var pm := box(PANEL, 14, LINE, 2, 10)
	pm.shadow_color = Color(0.04, 0.16, 0.28, 0.35)
	pm.shadow_size = 14
	th.set_stylebox("panel", "PopupMenu", pm)
	th.set_stylebox("hover", "PopupMenu", box(Color(ACCENT, 0.18), 8))
	th.set_color("font_color", "PopupMenu", INK)
	th.set_color("font_hover_color", "PopupMenu", INK)
	th.set_font_size("font_size", "PopupMenu", 20)
	# barre di scorrimento sottili e azzurre
	th.set_stylebox("scroll", "HScrollBar", box(Color(LINE, 0.4), 6))
	th.set_stylebox("grabber", "HScrollBar", box(Color(ACCENT, 0.6), 6))
	th.set_stylebox("scroll", "VScrollBar", box(Color(LINE, 0.4), 6))
	th.set_stylebox("grabber", "VScrollBar", box(Color(ACCENT, 0.6), 6))
	# elenchi (sequenza dell'editor)
	th.set_stylebox("panel", "ItemList", box(Color(SOFT, 0.95), 12, LINE, 2, 6))
	th.set_stylebox("focus", "ItemList", box(Color(0, 0, 0, 0), 12, ACCENT, 2))
	th.set_stylebox("selected", "ItemList", box(Color(ACCENT, 0.25), 8))
	th.set_stylebox("selected_focus", "ItemList", box(Color(ACCENT, 0.32), 8))
	th.set_stylebox("hovered", "ItemList", box(Color(ACCENT, 0.1), 8))
	th.set_color("font_color", "ItemList", INK)
	th.set_color("font_selected_color", "ItemList", ACCENT_DARK)
	th.set_color("font_hovered_color", "ItemList", INK)
	th.set_color("guide_color", "ItemList", Color(LINE, 0.5))
	th.set_stylebox("panel", "TooltipPanel", box(INK, 8, Color(0, 0, 0, 0), 0, 10))
	th.set_color("font_color", "TooltipLabel", Color.WHITE)
	return th
const DANGER := Color("c93636")
const BAND := {1: Color("8cb9dc"), 2: Color("79c3a3"), 3: Color("e7c45a"), 4: Color("ea9355"), 5: Color("d65252")}

static func box(bg: Color, radius := 14, border := Color(0, 0, 0, 0), bw := 0, pad := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	return s

static func style_button(b: Button, bg: Color, fg: Color, border := Color(0, 0, 0, 0), bw := 0, radius := 14, depth := 0, depth_col := Color(0, 0, 0, 0)) -> void:
	var mk := func(c: Color, d: int) -> StyleBoxFlat:
		var st := box(c, radius, border if bw > 0 else depth_col, bw)
		if d > 0:
			# bordo inferiore più scuro: il pulsante sembra una tavoletta da premere
			st.border_color = depth_col if bw == 0 else border
			st.border_width_bottom = d
			if bw == 0:
				st.border_width_left = 0
				st.border_width_right = 0
				st.border_width_top = 0
		return st
	b.add_theme_stylebox_override("normal", mk.call(bg, depth))
	b.add_theme_stylebox_override("hover", mk.call(bg.lightened(0.07), depth))
	b.add_theme_stylebox_override("pressed", mk.call(bg.darkened(0.08), max(depth - 2, 0)))
	b.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), radius, ACCENT, 3))
	var dis := bg
	dis.a = 0.45
	b.add_theme_stylebox_override("disabled", box(dis, radius, border, bw))
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	var fd := fg
	fd.a = 0.5
	b.add_theme_color_override("font_disabled_color", fd)

static func button(text: String, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 64)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_font_override("font", font(F_BOLD))
	if primary:
		style_button(b, ACCENT, Color.WHITE, Color(0, 0, 0, 0), 0, 14, 4, ACCENT_DARK)
	else:
		style_button(b, Color(SOFT, 0.92), INK, LINE, 2, 14, 4)
	return b

## Menu a tendina nello stile ghiaccio (impostato sul controllo: vale anche dove il tema non arriva).
static func style_option(ob: OptionButton) -> void:
	for st in ["normal", "hover", "pressed", "focus", "normal_mirrored", "hover_mirrored", "pressed_mirrored"]:
		var b := box(Color("ffffff", 0.9) if st.begins_with("hover") else Color(SOFT, 0.95), 14, ACCENT if st == "focus" else LINE, 3 if st == "focus" else 2, 14)
		b.border_width_bottom = 4
		ob.add_theme_stylebox_override(st, b)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		ob.add_theme_color_override(c, INK)
	ob.add_theme_font_override("font", font(F_BOLD))
	ob.add_theme_color_override("icon_normal_color", ACCENT_DARK)

## Azione principale (parti, muovi, nuova gara): una tavola di legno con le lettere del cartello.
static func cta(text: String) -> Button:
	var b := button(text)
	b.add_theme_font_override("font", font(F_TITLE))
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_outline_color", WOOD_DARK)
	b.add_theme_constant_override("outline_size", 6)
	style_button(b, WOOD, SIGN_YELLOW, Color(0, 0, 0, 0), 0, 14, 5, WOOD_DARK)
	return b

## Titolo come il logo della scatola: lettere gialle massicce con il contorno di legno scuro.
static func title(text: String, size := 44, fill := SIGN_YELLOW) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(F_TITLE))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", fill)
	l.add_theme_color_override("font_outline_color", WOOD_DARK)
	l.add_theme_constant_override("outline_size", int(size * 0.28))
	l.add_theme_color_override("font_shadow_color", Color(0.05, 0.12, 0.2, 0.35))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", int(size * 0.08))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

## Intestazione di sezione: maiuscoletto azzurro ghiaccio.
static func heading(text: String, size := 17) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_override("font", font(F_BLACK))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", ACCENT_DARK)
	return l

static func label(text := "", size := 22, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func rich(size := 22) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_color_override("default_color", MUTED)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## Pannello «di ghiaccio»: chiaro e un po' trasparente, bordo bianco brinato e ombra fredda.
static func frost_panel(radius := 26) -> PanelContainer:
	var p := PanelContainer.new()
	var s := box(Color(PANEL, 0.93), radius, Color(FROST, 0.95), 3, 22)
	s.shadow_color = Color(0.03, 0.14, 0.26, 0.45)
	s.shadow_size = 22
	s.shadow_offset = Vector2(0, 6)
	p.add_theme_stylebox_override("panel", s)
	return p

static func panel(bg := PANEL, radius := 22) -> PanelContainer:
	var p := PanelContainer.new()
	var s := box(bg, radius, Color(0, 0, 0, 0), 0, 18)
	p.add_theme_stylebox_override("panel", s)
	return p

static func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()
