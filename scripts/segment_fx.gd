class_name SegmentFx
extends RefCounted
## Effetti 3D dei segmenti fanmade: vento (scie e neve sollevata), neve fresca (nevicata e
## cumuli), ghiaccio (lucido che riflette il sole), baita (con il fumo dal camino),
## e le fiancate di neve sotto le tessere rialzate da salite e discese.

const HUT_GLB := "res://assets/models/hut.glb"
static var _mats := {}

## Riferimento di una tessera: centro, direzione di marcia, lato destro, lunghezza, mezza larghezza.
static func frame(c: Course, pi: int) -> Dictionary:
	var pc: Dictionary = c.pieces[pi]
	var a: Vector2 = pc["entry_mid"]
	var b: Vector2 = pc["exit_mid"]
	var d := (b - a).normalized()
	return {"a": a, "b": b, "mid": (a + b) * 0.5, "dir": d, "right": Vector2(-d.y, d.x),
		"len": (b - a).length(), "half": c.lane_w * 2.5}

## Nodo orientato sulla tessera: X locale = senso di marcia, Z locale = destra.
static func anchor(c: Course, pi: int, at: Vector2, y_off := 0.0) -> Node3D:
	var f := frame(c, pi)
	var n := Node3D.new()
	n.position = BoardView3D.to3(at, y_off)
	var d: Vector2 = f["dir"]
	n.rotation.y = atan2(-d.y, d.x)
	return n

static func build(parent: Node3D, c: Course) -> void:
	for pi in c.pieces.size():
		var pc: Dictionary = c.pieces[pi]
		if max(float(pc["h0"]), float(pc["h1"])) > 0.01:
			parent.add_child(_skirt(c, pi))
		match String(pc["seg"]):
			"wind":
				_wind(parent, c, pi)
			"fresh":
				_fresh(parent, c, pi)
			"ice":
				_ice(parent, c, pi)
			"hut":
				_hut(parent, c, pi)

# ---------- materiali ----------
static func _flake_mat(alpha := 0.9) -> StandardMaterial3D:
	var key := "flake%f" % alpha
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = SnowFx.flake_texture()
	m.albedo_color = Color(1, 1, 1, alpha)
	_mats[key] = m
	return m

static func _fade_ramp(peak := 1.0) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.add_point(0.2, Color(1, 1, 1, peak))
	g.add_point(0.75, Color(1, 1, 1, peak))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	return g

# ---------- vento ----------
static func _wind(parent: Node3D, c: Course, pi: int) -> void:
	var f := frame(c, pi)
	var side := 1.0 if String(c.pieces[pi]["wind"]) != "L" else -1.0
	var L: float = f["len"] * BoardView3D.S
	var W: float = f["half"] * 2.0 * BoardView3D.S
	var root := anchor(c, pi, f["mid"], 0.0)
	parent.add_child(root)
	# scie bianche veloci, di traverso alla pista
	var streak := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.018, 0.018, 0.55)
	streak.mesh = bm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.vertex_color_use_as_albedo = true
	sm.albedo_color = Color(1, 1, 1, 0.75)
	streak.material_override = sm
	streak.amount = 70
	streak.lifetime = 1.1
	streak.preprocess = 2.0
	streak.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	streak.emission_box_extents = Vector3(L * 0.5, 0.22, W * 0.35)
	streak.position = Vector3(0, 0.35, -side * W * 0.45)
	streak.direction = Vector3(0, 0, side)
	streak.spread = 6.0
	streak.gravity = Vector3.ZERO
	streak.initial_velocity_min = 3.2
	streak.initial_velocity_max = 4.6
	streak.color_ramp = _fade_ramp(0.8)
	streak.local_coords = true
	root.add_child(streak)
	# neve sollevata: sbuffi bassi che corrono sulla pista
	var dust := CPUParticles3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.22, 0.22)
	dust.mesh = qm
	dust.material_override = _flake_mat(0.6)
	dust.amount = 110
	dust.lifetime = 2.2
	dust.preprocess = 3.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(L * 0.5, 0.04, W * 0.6)
	dust.position = Vector3(0, 0.06, 0)
	dust.direction = Vector3(0, 0.35, side)
	dust.spread = 18.0
	dust.gravity = Vector3(0, -0.4, 0)
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 2.0
	dust.scale_amount_min = 0.4
	dust.scale_amount_max = 1.4
	dust.color_ramp = _fade_ramp(0.7)
	dust.local_coords = true
	root.add_child(dust)
	# manica a vento sul lato da cui soffia, gonfia e svolazzante verso dove va il vento
	var at: Vector2 = f["mid"] + f["dir"] * f["len"] * 0.3 - f["right"] * side * (f["half"] + c.lane_w * 1.1)
	var holder := anchor(c, pi, at, 0.0)
	parent.add_child(holder)
	var sock := Windsock.new()
	sock.side = side
	sock.scale = Vector3.ONE * 1.6
	holder.add_child(sock)

# ---------- neve fresca ----------
static func _fresh(parent: Node3D, c: Course, pi: int) -> void:
	var f := frame(c, pi)
	var L: float = f["len"] * BoardView3D.S
	var W: float = f["half"] * 2.0 * BoardView3D.S
	var root := anchor(c, pi, f["mid"], 0.0)
	parent.add_child(root)
	var fall := CPUParticles3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.07, 0.07)
	fall.mesh = qm
	fall.material_override = _flake_mat(0.95)
	fall.amount = 420
	fall.lifetime = 4.5
	fall.preprocess = 5.0
	fall.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fall.emission_box_extents = Vector3(L * 0.55, 0.2, W * 0.75)
	fall.position = Vector3(0, 2.6, 0)
	fall.direction = Vector3(0.15, -1, 0.1)
	fall.spread = 12.0
	fall.gravity = Vector3(0, -0.25, 0)
	fall.initial_velocity_min = 0.45
	fall.initial_velocity_max = 0.8
	fall.scale_amount_min = 0.5
	fall.scale_amount_max = 1.3
	fall.tangential_accel_min = -0.3
	fall.tangential_accel_max = 0.3
	fall.color_ramp = _fade_ramp(1.0)
	fall.local_coords = true
	root.add_child(fall)
	# cumuli di neve fresca sulle caselle segnate: piccoli rilievi morbidi che sfumano nella pista
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 1.0
	# la pista è disegnata senza luci: il cumulo, illuminato, va un po' scurito per non abbagliare
	m.albedo_color = Color(0.74, 0.79, 0.86)
	var rng := RandomNumberGenerator.new()
	rng.seed = pi * 31 + 7
	var d3 := Vector3(f["dir"].x, 0, f["dir"].y)
	var r3 := Vector3(f["right"].x, 0, f["right"].y)
	var cl: float = c.cell_len * BoardView3D.S
	var lw: float = c.lane_w * BoardView3D.S
	for id in c.pieces[pi]["cells"]:
		if not c.fresh.has(id):
			continue
		var base: Vector3 = BoardView3D.to3(c.cells[id]["pos"], 0.006)
		var bumps := []
		for k in 3:
			bumps.append([rng.randf_range(-0.35, 0.35), rng.randf_range(-0.3, 0.3), rng.randf_range(0.25, 0.4), rng.randf_range(0.08, 0.13)])
		var n := 12
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var grid := []
		for j in n + 1:
			var row := []
			for i in n + 1:
				var u := float(i) / n * 2.0 - 1.0
				var v := float(j) / n * 2.0 - 1.0
				var h := 0.0
				for bp in bumps:
					var du: float = (u - bp[0]) / bp[2] * 0.5
					var dv: float = (v - bp[1]) / bp[2] * 0.5
					h += bp[3] * exp(-(du * du + dv * dv) * 1.6)
				var rr := sqrt(u * u + v * v)
				var edge: float = smoothstep(1.0, 0.35, rr)
				var pos := base + d3 * u * cl * 0.62 + r3 * v * lw * 0.62 + Vector3.UP * h * edge
				row.append([pos, Color(1, 1, 1, clamp(edge * 1.6, 0.0, 1.0))])
			grid.append(row)
		for j in n:
			for i in n:
				for q in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j], [i + 1, j + 1], [i, j + 1]]:
					var vv: Array = grid[q[1]][q[0]]
					st.set_color(vv[1])
					st.add_vertex(vv[0])
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = m
		parent.add_child(mi)

# ---------- ghiaccio ----------
static func _ice(parent: Node3D, c: Course, pi: int) -> void:
	var f := frame(c, pi)
	var root := anchor(c, pi, f["mid"], 0.014)
	parent.add_child(root)
	var pm := PlaneMesh.new()
	pm.size = Vector2(f["len"] * BoardView3D.S, f["half"] * 2.0 * BoardView3D.S)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.8, 0.92, 1.0, 0.16)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.06
	m.metallic_specular = 1.0
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	m.clearcoat_roughness = 0.05
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	# luccichii che compaiono e svaniscono sul ghiaccio
	var gl := CPUParticles3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.08, 0.08)
	gl.mesh = qm
	gl.material_override = _flake_mat(1.0)
	gl.amount = 26
	gl.lifetime = 1.4
	gl.preprocess = 1.5
	gl.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	gl.emission_box_extents = Vector3(pm.size.x * 0.5, 0.0, pm.size.y * 0.5)
	gl.position = Vector3(0, 0.02, 0)
	gl.gravity = Vector3.ZERO
	gl.initial_velocity_max = 0.0
	gl.scale_amount_min = 0.3
	gl.scale_amount_max = 1.0
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.add_point(0.5, Color(1, 1, 1, 1))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	gl.color_ramp = g
	gl.local_coords = true
	root.add_child(gl)

# ---------- baita ----------
static func _hut(parent: Node3D, c: Course, pi: int) -> void:
	var f := frame(c, pi)
	for id in c.pieces[pi]["cells"]:
		if not c.huts.has(id):
			continue
		var cp: Vector2 = c.cells[id]["pos"]
		var out: Vector2 = f["right"] if (cp - f["mid"]).dot(f["right"]) > 0 else -f["right"]
		var at: Vector2 = cp + out * c.lane_w * 2.2
		var holder := anchor(c, pi, at, 0.0)
		parent.add_child(holder)
		var hut := _prop(HUT_GLB, 1.0)
		if hut:
			holder.add_child(hut)
			# la porta verso la pista
			hut.rotation.y = atan2(out.x, out.y) - holder.rotation.y + PI
		# fumo dal camino
		var sm := CPUParticles3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.16, 0.16)
		sm.mesh = qm
		var mat := _flake_mat(0.55).duplicate() as StandardMaterial3D
		mat.albedo_color = Color(0.82, 0.85, 0.9, 0.5)
		sm.material_override = mat
		sm.amount = 24
		sm.lifetime = 3.0
		sm.preprocess = 3.0
		sm.position = Vector3(0, 0.95, 0)
		sm.direction = Vector3(0.15, 1, 0)
		sm.spread = 10.0
		sm.gravity = Vector3(0.12, 0.1, 0)
		sm.initial_velocity_min = 0.2
		sm.initial_velocity_max = 0.35
		sm.scale_amount_min = 0.6
		sm.scale_amount_max = 1.0
		var sc := Curve.new()
		sc.add_point(Vector2(0, 0.4))
		sc.add_point(Vector2(1, 1.8))
		sm.scale_amount_curve = sc
		sm.color_ramp = _fade_ramp(0.9)
		holder.add_child(sm)
		holder.set_meta("smoke", sm)

static func _prop(path: String, height: float) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var ps = load(path)
	if not (ps is PackedScene):
		return null
	var n: Node3D = (ps as PackedScene).instantiate()
	var root := Node3D.new()
	root.add_child(n)
	# i modelli sono già ridotti, centrati e appoggiati a terra con altezza 1
	root.scale = Vector3.ONE * height
	return root

# ---------- fiancate di neve sotto le tessere rialzate ----------
static func _skirt(c: Course, pi: int) -> MeshInstance3D:
	var pc: Dictionary = c.pieces[pi]
	var f := frame(c, pi)
	var half: float = f["half"] + c.lane_w * 1.2
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 12
	var top_c := Color("f4f8fc")
	var bot_c := Color("a9bfd3")
	for sgn in [-1.0, 1.0]:
		for i in n:
			var t0 := float(i) / n
			var t1 := float(i + 1) / n
			var p0: Vector2 = f["a"] + (f["b"] - f["a"]) * t0 + f["right"] * sgn * half
			var p1: Vector2 = f["a"] + (f["b"] - f["a"]) * t1 + f["right"] * sgn * half
			var h0: float = c.piece_height(pi, p0) - 0.004
			var h1: float = c.piece_height(pi, p1) - 0.004
			var a := Vector3(p0.x * BoardView3D.S, h0, p0.y * BoardView3D.S)
			var b := Vector3(p1.x * BoardView3D.S, h1, p1.y * BoardView3D.S)
			var a2 := Vector3(a.x, -0.03, a.z)
			var b2 := Vector3(b.x, -0.03, b.z)
			var nrm := Vector3(f["right"].x * sgn, 0.25, f["right"].y * sgn).normalized()
			for v in [[a, top_c], [b, top_c], [b2, bot_c], [a, top_c], [b2, bot_c], [a2, bot_c]]:
				st.set_normal(nrm)
				st.set_color(v[1])
				st.add_vertex(v[0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	return mi


## Manica a vento: palo di legno e cono a strisce arancioni e bianche che sbatte nel vento.
class Windsock:
	extends Node3D
	var side := 1.0
	var _segs: Array = []
	var _t := 0.0
	func _ready() -> void:
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color("7b5232")
		wood.roughness = 0.9
		var pole := MeshInstance3D.new()
		var pc := CylinderMesh.new()
		pc.top_radius = 0.018
		pc.bottom_radius = 0.024
		pc.height = 0.9
		pc.radial_segments = 8
		pole.mesh = pc
		pole.material_override = wood
		pole.position.y = 0.45
		add_child(pole)
		var orange := StandardMaterial3D.new()
		orange.albedo_color = Color("ef6b1f")
		orange.roughness = 0.8
		var white := StandardMaterial3D.new()
		white.albedo_color = Color("f4f4f2")
		white.roughness = 0.8
		var pivot := Node3D.new()
		pivot.position = Vector3(0, 0.86, 0)
		add_child(pivot)
		var r := 0.075
		var prev := pivot
		for i in 5:
			var seg := Node3D.new()
			seg.position = Vector3(0, 0, 0) if i == 0 else Vector3(0, 0, 0.11 * side)
			prev.add_child(seg)
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = r
			cm.bottom_radius = r * 0.86
			cm.height = 0.11
			cm.radial_segments = 12
			cm.cap_top = false
			cm.cap_bottom = false
			mi.mesh = cm
			mi.material_override = orange if i % 2 == 0 else white
			# il cilindro è verticale: lo stendiamo lungo Z (verso dove soffia il vento)
			mi.rotation.x = PI * 0.5 * side
			mi.position = Vector3(0, 0, 0.055 * side)
			seg.add_child(mi)
			_segs.append(seg)
			prev = seg
			r *= 0.86
	func _process(delta: float) -> void:
		_t += delta
		for i in _segs.size():
			var sg: Node3D = _segs[i]
			var k := float(i + 1)
			sg.rotation.y = sin(_t * 7.0 - k * 0.9) * 0.06 * k
			sg.rotation.x = -0.05 * k * 0.5 + sin(_t * 5.0 - k * 1.2) * 0.03 * k
