class_name SnowFx
extends RefCounted
## Decorazioni invernali per l'interfaccia: neve che cade e cumuli di neve sui pannelli.

static var _flake: Texture2D = null

static func flake_texture() -> Texture2D:
	if _flake:
		return _flake
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.add_point(0.45, Color(1, 1, 1, 0.85))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	_flake = t
	return t

## Nevicata leggera su tutta l'area (da aggiungere a un Control a tutto schermo).
static func snowfall(area: Vector2, amount := 140) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = flake_texture()
	p.amount = amount
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(area.x * 0.6, 10)
	p.position = Vector2(area.x * 0.5, -20)
	p.direction = Vector2(0.15, 1)
	p.spread = 12.0
	p.gravity = Vector2(0, 8)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 90.0
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.42
	p.color = Color(1, 1, 1, 0.9)
	# ondeggiare dei fiocchi
	p.tangential_accel_min = -6.0
	p.tangential_accel_max = 6.0
	p.angular_velocity_min = -30.0
	p.angular_velocity_max = 30.0
	return p

## Cumulo di neve sul bordo superiore di un pannello largo w (disegnato in coordinate del pannello).
class SnowCap:
	extends Control
	var w := 400.0
	var seed_v := 7
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_v
		var r := 26.0
		var x := 16.0
		var shade := Color("cfe4f5")
		var bumps := []
		while x < w - 16.0:
			var rr := rng.randf_range(r * 0.55, r * 1.05)
			bumps.append([x, rr])
			x += rr * rng.randf_range(1.1, 1.6)
		# ombra azzurra sotto, poi la neve bianca
		for b in bumps:
			draw_circle(Vector2(b[0], 4.0), b[1] * 0.55 + 3.0, shade)
		for b in bumps:
			draw_circle(Vector2(b[0], 0.0), b[1] * 0.55, Color.WHITE)
		draw_rect(Rect2(14, -2, w - 28, 6), Color.WHITE)
		# qualche luccichio
		for i in 10:
			var px := rng.randf_range(24, w - 24)
			draw_circle(Vector2(px, rng.randf_range(-6, 2)), 1.6, Color("e9f6ff"))
