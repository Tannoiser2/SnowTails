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

func _process(delta: float) -> void:
	_t += delta
	if _shake > 0.0:
		_shake = max(0.0, _shake - delta * 1.6)
		rotation.z = sin(_t * 47.0) * 0.16 * _shake
		rotation.x = sin(_t * 31.0 + 1.0) * 0.1 * _shake
	elif rotation.z != 0.0 or rotation.x != 0.0:
		rotation.z = 0.0
		rotation.x = 0.0
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
