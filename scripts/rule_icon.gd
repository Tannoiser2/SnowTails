class_name RuleIcon
extends Control
## Disegnini per la legenda delle regole: destinazione, percorso, deriva, ammaccature.

var kind := ""

func _init(k: String) -> void:
	kind = k
	custom_minimum_size = Vector2(84, 64)

func _draw() -> void:
	var c := Color("2a9ac0")
	var bg := Color("e8eef4")
	draw_rect(Rect2(Vector2.ZERO, size), bg)
	var m := size * 0.5
	match kind:
		"dest":
			draw_circle(m, 20, Color(c, 0.28))
			draw_arc(m, 21, 0, TAU, 40, c, 4.0, true)
		"path":
			var a := Vector2(10, size.y - 12)
			var b := Vector2(size.x - 10, 12)
			draw_line(a, b, Color(c, 0.85), 3.0, true)
			for k in 4:
				draw_circle(a.lerp(b, k / 3.0), 4.5, c.darkened(0.15))
		"drift":
			var a := Vector2(12, size.y - 12)
			var b := Vector2(size.x - 12, 14)
			draw_line(a, b, Color.WHITE, 12.0, true)
			draw_line(a, b, c.lightened(0.35), 7.0, true)
		"dent":
			draw_circle(m + Vector2(0, 8), 16, Color(c, 0.22))
			draw_arc(m + Vector2(0, 8), 17, 0, TAU, 40, c, 3.0, true)
			var f := UIKit.font(UIKit.F_BOLD)
			draw_string(f, Vector2(m.x - 16, 26), "−2", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("d23a3a"))
