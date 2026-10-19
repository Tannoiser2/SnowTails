extends SceneTree
## Simboli dell'interfaccia senza i font di sistema (come nel browser): devono vedersi tutti.
func _init() -> void:
	UIKit.setup_fonts()
	for p in [UIKit.F_BODY, UIKit.F_BOLD, UIKit.F_BLACK, UIKit.F_TITLE, UIKit.F_SYMBOLS, UIKit.F_MATH]:
		var f = load(p)
		if f is FontFile:
			f.allow_system_fallback = false
	var bg := ColorRect.new(); bg.color = Color.WHITE; bg.size = Vector2(900, 200); root.add_child(bg)
	var l := Label.new()
	l.text = "Curva ← → ★ ✓ ✎ ⚠ ✕ ▪▫ • … — − ½ « » ° 1° 4ª ×2"
	l.add_theme_font_override("font", UIKit.font(UIKit.F_BOLD))
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", Color.BLACK)
	l.position = Vector2(20, 30)
	root.add_child(l)
	var l2 := Label.new()
	l2.text = "Fanmade ★ salita, vento →   Inv. ←   ✓ Ghiaccio"
	l2.add_theme_font_size_override("font_size", 26)
	l2.add_theme_color_override("font_color", Color.BLACK)
	l2.position = Vector2(20, 100)
	root.add_child(l2)
	await create_timer(0.5).timeout
	root.get_texture().get_image().save_png("/tmp/shots/glyphs.png")
	quit()
