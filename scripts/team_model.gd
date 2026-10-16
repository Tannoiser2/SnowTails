class_name TeamModel
extends Node3D
## Muta low-poly costruita in codice: due husky, slitta e conducente.
## Guarda verso -Z. Unità: 1 = circa una casella.

var legs: Array = []      # [pivot, fase]
var tails: Array = []
var heads: Array = []
var run := 0.0            # 0 = fermo, 1 = di corsa
var _shake := 0.0
var _t := 0.0
var _glb: Node3D = null   # modello importato (assets/models/team.glb), se presente
const GLB_PATH := "res://assets/models/team.glb"
## Versione animata: slitta e cani separati (sled.glb + husky.glb con scheletro).
const SLED_PATH := "res://assets/models/sled.glb"
const DOG_PATH := "res://assets/models/husky.glb"
const DOG_SPOTS := [Vector3(-0.088, 0, -0.285), Vector3(0.088, 0, -0.30)]
const TOW := Vector3(0.0, 0.1, 0.062)      # attacco della linea di traino sulla slitta
const STRAP := Vector3(0.0, 0.1, 0.165)    # fine delle cinghie del cane (sul cane)
var _rig: Node3D = null    # contenitore di slitta + cani
var _sled_node: Node3D = null
var _dogs: Array = []      # [nodo, AnimationPlayer, fase]
var _ropes: Array = []
var _bump := 0.0           # sobbalzo in corso della slitta
var _bump_t := 0.0
var _next_bump := 0.4
static var _mats := {}

static func mat(c: Color, rough := 0.85, emissive := false) -> StandardMaterial3D:
	var key := c.to_html() + str(rough) + str(emissive)
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emissive:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[key] = m
	return m

func _part(mesh: Mesh, c: Color, pos: Vector3, rot := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(c)
	mi.position = pos
	mi.rotation = rot
	(parent if parent else self).add_child(mi)
	return mi

static func box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b

static func caps(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 12
	c.rings = 4
	return c

static func sph(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	s.radial_segments = 12
	s.rings = 6
	return s

static func cyl(r_top: float, r_bot: float, h: float, seg := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	return c

func build(team: Color) -> void:
	if ResourceLoader.exists(SLED_PATH) and ResourceLoader.exists(DOG_PATH):
		_build_animated(team)
		return
	if ResourceLoader.exists(GLB_PATH):
		var ps = load(GLB_PATH)
		if ps is PackedScene:
			_glb = (ps as PackedScene).instantiate()
			_glb.scale = Vector3.ONE * 0.9
			add_child(_glb)
			_base(team)
			return
	var dogs := [[-0.07, Color("5d6875"), 0.0], [0.07, Color("3f4853"), PI * 0.5]]
	for d in dogs:
		_dog(Vector3(d[0], 0, -0.25), d[1], team, d[2])
	# linee di traino
	_part(box(0.006, 0.006, 0.16), Color("3b3b3b"), Vector3(-0.07, 0.09, -0.06))
	_part(box(0.006, 0.006, 0.16), Color("3b3b3b"), Vector3(0.07, 0.09, -0.06))
	_sled(team)
	scale = Vector3.ONE * 1.05

func _dog(at: Vector3, fur: Color, team: Color, phase: float) -> void:
	var root := Node3D.new()
	root.position = at
	root.scale = Vector3.ONE * 1.4
	add_child(root)
	var white := Color("eef1f4")
	_part(caps(0.036, 0.17), fur, Vector3(0, 0.075, 0), Vector3(PI * 0.5, 0, 0), root)
	_part(caps(0.03, 0.12), white, Vector3(0, 0.062, -0.005), Vector3(PI * 0.5, 0, 0), root)
	_part(caps(0.039, 0.06), team, Vector3(0, 0.078, -0.035), Vector3(PI * 0.5, 0, 0), root)
	var head := Node3D.new()
	head.position = Vector3(0, 0.11, -0.095)
	root.add_child(head)
	heads.append([head, phase])
	_part(sph(0.031), fur, Vector3.ZERO, Vector3.ZERO, head)
	_part(box(0.026, 0.022, 0.042), white, Vector3(0, -0.008, -0.03), Vector3.ZERO, head)
	_part(sph(0.007), Color("1b1b1b"), Vector3(0, -0.001, -0.052), Vector3.ZERO, head)
	for sx in [-1, 1]:
		_part(cyl(0.0, 0.011, 0.034), fur, Vector3(0.016 * sx, 0.033, 0.004), Vector3(0, 0, -0.25 * sx), head)
		_part(sph(0.0045), Color("1b1b1b"), Vector3(0.012 * sx, 0.01, -0.024), Vector3.ZERO, head)
	for lz in [-0.055, 0.055]:
		for sx in [-1, 1]:
			var pivot := Node3D.new()
			pivot.position = Vector3(0.02 * sx, 0.07, lz)
			root.add_child(pivot)
			_part(cyl(0.009, 0.008, 0.07), fur if lz > 0 else white, Vector3(0, -0.035, 0), Vector3.ZERO, pivot)
			var ph: float = phase + (0.0 if sx < 0 else PI) + (0.0 if lz < 0 else PI * 0.5)
			legs.append([pivot, ph])
	var tail := Node3D.new()
	tail.position = Vector3(0, 0.1, 0.09)
	root.add_child(tail)
	var tm := TorusMesh.new()
	tm.inner_radius = 0.007
	tm.outer_radius = 0.024
	tm.rings = 10
	tm.ring_segments = 6
	_part(tm, fur, Vector3(0, 0.015, 0), Vector3(0, 0, PI * 0.5), tail)
	tails.append([tail, phase])

func _sled(team: Color) -> void:
	var wood := Color("a8774e")
	var dark := Color("2e3b4a")
	for sx in [-1, 1]:
		_part(box(0.012, 0.012, 0.44), dark, Vector3(0.075 * sx, 0.006, 0.2))
		_part(box(0.012, 0.012, 0.06), dark, Vector3(0.075 * sx, 0.025, -0.035), Vector3(-0.7, 0, 0))
		for z in [0.06, 0.2, 0.33]:
			_part(box(0.01, 0.05, 0.01), wood, Vector3(0.075 * sx, 0.035, z))
		_part(box(0.012, 0.035, 0.27), team, Vector3(0.085 * sx, 0.075, 0.18))
		_part(box(0.01, 0.15, 0.01), wood, Vector3(0.07 * sx, 0.115, 0.34), Vector3(-0.25, 0, 0))
	_part(box(0.17, 0.016, 0.28), wood, Vector3(0, 0.06, 0.18))
	_part(box(0.13, 0.06, 0.15), team.darkened(0.2), Vector3(0, 0.098, 0.15))
	_part(box(0.16, 0.012, 0.012), dark, Vector3(0, 0.185, 0.36))
	# conducente sui pattini
	var musher := Node3D.new()
	musher.position = Vector3(0, 0, 0.43)
	add_child(musher)
	_part(caps(0.036, 0.15), team, Vector3(0, 0.15, 0), Vector3(-0.15, 0, 0), musher)
	_part(sph(0.03), Color("f1c9a5"), Vector3(0, 0.245, -0.012), Vector3.ZERO, musher)
	_part(sph(0.033), team.darkened(0.35), Vector3(0, 0.258, -0.004), Vector3.ZERO, musher)
	for sx in [-1, 1]:
		_part(caps(0.012, 0.09), team.darkened(0.15), Vector3(0.045 * sx, 0.18, -0.045), Vector3(-1.1, 0, 0), musher)

func _build_animated(team: Color) -> void:
	_rig = Node3D.new()
	_rig.scale = Vector3.ONE * 0.9
	add_child(_rig)
	_sled_node = (load(SLED_PATH) as PackedScene).instantiate()
	_rig.add_child(_sled_node)
	_tint_sled(_sled_node, team)
	var dog_scene := load(DOG_PATH) as PackedScene
	var rope_mat := mat(Color("d9d4c7"), 0.9)
	for i in DOG_SPOTS.size():
		var d: Node3D = dog_scene.instantiate()
		d.position = DOG_SPOTS[i]
		_rig.add_child(d)
		var ap := d.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			for n in ["run", "idle"]:
				if ap.has_animation(n):
					ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
			ap.play("idle")
			ap.seek(randf() * 1.5, true)
		_dogs.append([d, ap, 0.13 * i + randf() * 0.05])
		var rope := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0045
		cm.bottom_radius = 0.0045
		cm.height = 1.0
		cm.radial_segments = 5
		cm.rings = 1
		rope.mesh = cm
		rope.material_override = rope_mat
		rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_rig.add_child(rope)
		_ropes.append(rope)

## Colore della squadra sul conducente e sul pacco: si tingono le parti chiare e grigie della
## texture (giaccone, pantaloni chiari, telo del carico); legno, pelle, pelliccia e cinghie
## scure restano come sono.
const TINT_SHADER := """
shader_type spatial;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec3 team : source_color;
void fragment() {
	vec3 c = texture(tex, UV).rgb;
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = (mx - mn) / max(mx, 0.0001);
	float m = (1.0 - smoothstep(0.10, 0.22, sat)) * smoothstep(0.30, 0.50, mx);
	vec3 tinted = team * (0.18 + 0.82 * mx);
	ALBEDO = mix(c, tinted, m * 0.92);
	ROUGHNESS = 0.85;
}
"""
static var _tint_shader: Shader = null

func _tint_sled(root: Node, team: Color) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var base := m.mesh.surface_get_material(0) as BaseMaterial3D if m.mesh and m.mesh.get_surface_count() > 0 else null
		if base == null or base.albedo_texture == null:
			continue
		if _tint_shader == null:
			_tint_shader = Shader.new()
			_tint_shader.code = TINT_SHADER
		var sm := ShaderMaterial.new()
		sm.shader = _tint_shader
		sm.set_shader_parameter("tex", base.albedo_texture)
		sm.set_shader_parameter("team", team)
		m.material_override = sm

## Linea di traino: un cilindro sottile tra la slitta e la fine delle cinghie del cane.
func _update_ropes() -> void:
	var a: Vector3 = _sled_node.position + _sled_node.basis * TOW
	for i in _ropes.size():
		var d: Node3D = _dogs[i][0]
		var b: Vector3 = d.position + STRAP
		var r: MeshInstance3D = _ropes[i]
		var v := b - a
		var l := v.length()
		r.position = (a + b) * 0.5
		var y := v / l
		var x := y.cross(Vector3.FORWARD).normalized()
		if x.length() < 0.5:
			x = Vector3.RIGHT
		r.basis = Basis(x, y * l, x.cross(y))

func _process_animated(delta: float) -> void:
	# cani: galoppo quando la slitta corre, fermi e scodinzolanti quando è ferma
	for dd in _dogs:
		var d: Node3D = dd[0]
		var ap: AnimationPlayer = dd[1]
		var ph: float = dd[2]
		if ap:
			var want := "run" if run > 0.15 else "idle"
			if ap.current_animation != want:
				ap.play(want, 0.25)
				if want == "run":
					ap.seek(ph, true)
			ap.speed_scale = (0.75 + run * 0.6) if want == "run" else 1.0
		# il corpo sale e scende due volte per falcata (12 fotogrammi a 24 fps = 0,5 s)
		var gal := _t * TAU * 2.0 * (0.75 + run * 0.6) + ph * TAU * 2.0
		d.position.y = DOG_SPOTS[_dogs.find(dd)].y + abs(sin(gal)) * 0.012 * run
	# slitta: piccole vibrazioni continue + sobbalzi a intervalli casuali, più forti in corsa
	_bump_t += delta
	if run > 0.2 and _bump_t >= _next_bump:
		_bump_t = 0.0
		_next_bump = randf_range(0.25, 0.7)
		_bump = max(_bump, randf_range(0.5, 1.0) * run)
	_bump = max(0.0, _bump - delta * 3.5)
	var jitter := (sin(_t * 23.0) * 0.6 + sin(_t * 37.0 + 1.3) * 0.4) * run
	var hop := sin(min(1.0, 1.0 - _bump) * PI) * _bump
	_sled_node.position.y = abs(jitter) * 0.004 + hop * 0.02
	_sled_node.rotation.x = jitter * 0.012 + hop * 0.07
	_sled_node.rotation.z = sin(_t * 9.0) * 0.012 * run + (sin(_t * 41.0) * 0.05 * hop)
	_update_ropes()

## Basetta ovale nel colore della squadra, come per le miniature da tavolo.
func _base(team: Color) -> void:
	var rim := MeshInstance3D.new()
	rim.mesh = cyl(0.2, 0.21, 0.018, 32)
	rim.material_override = mat(Color("f4f6f8"))
	rim.scale = Vector3(1.05, 1, 2.55)
	rim.position.y = 0.009
	add_child(rim)
	var top := MeshInstance3D.new()
	top.mesh = cyl(0.19, 0.19, 0.022, 32)
	top.material_override = mat(team, 0.6)
	top.scale = Vector3(1.0, 1, 2.5)
	top.position.y = 0.012
	add_child(top)
	if _glb:
		_glb.position.y = 0.023

func shake(amount: float) -> void:
	_shake = max(_shake, amount)
	_bump = max(_bump, amount)

func _process(delta: float) -> void:
	_t += delta
	if _shake > 0.0:
		_shake = max(0.0, _shake - delta * 1.6)
		rotation.z = sin(_t * 47.0) * 0.16 * _shake
		rotation.x = sin(_t * 31.0 + 1.0) * 0.1 * _shake
	elif rotation.z != 0.0 or rotation.x != 0.0:
		rotation.z = 0.0
		rotation.x = 0.0
	if _rig:
		_process_animated(delta)
		return
	if _glb:
		var sp2 := 14.0
		_glb.position.y = 0.023 + abs(sin(_t * sp2)) * 0.012 * run
		_glb.rotation.x = sin(_t * sp2) * 0.025 * run
		_glb.rotation.z = sin(_t * sp2 * 0.5) * 0.015 * run
		return
	var sp := 14.0
	for l in legs:
		(l[0] as Node3D).rotation.x = sin(_t * sp + l[1]) * 0.7 * run
	for h in heads:
		(h[0] as Node3D).position.y = 0.11 + sin(_t * sp * 0.5 + h[1]) * 0.006 * run + sin(_t * 1.7 + h[1]) * 0.002
	for tl in tails:
		(tl[0] as Node3D).rotation.y = sin(_t * (9.0 if run > 0.3 else 3.0) + tl[1]) * 0.35
