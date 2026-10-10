class_name UIKit
extends RefCounted
## Piccoli aiuti per costruire l'interfaccia da codice.

const INK := Color("1e3550")
const MUTED := Color("5b6f86")
const PANEL := Color("ffffff")
const SOFT := Color("eef3f8")
const LINE := Color("cfdbe7")
const ACCENT := Color("147f7a")
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

static func style_button(b: Button, bg: Color, fg: Color, border := Color(0, 0, 0, 0), bw := 0, radius := 14) -> void:
	b.add_theme_stylebox_override("normal", box(bg, radius, border, bw))
	b.add_theme_stylebox_override("hover", box(bg.lightened(0.06), radius, border, bw))
	b.add_theme_stylebox_override("pressed", box(bg.darkened(0.08), radius, border, bw))
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
	if primary:
		style_button(b, ACCENT, Color.WHITE)
	else:
		style_button(b, SOFT, INK, LINE, 2)
	return b

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

static func panel(bg := PANEL, radius := 22) -> PanelContainer:
	var p := PanelContainer.new()
	var s := box(bg, radius, Color(0, 0, 0, 0), 0, 18)
	p.add_theme_stylebox_override("panel", s)
	return p

static func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()
