class_name SledThumb
extends SubViewportContainer
## Miniatura 3D della muta (cani che corrono, slitta che sobbalza) per il menu.

var model: TeamModel
var _vp: SubViewport
var _cam: Camera3D

func _init(team: Color, w := 220, h := 62) -> void:
	stretch = true
	custom_minimum_size = Vector2(w, h)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.size = Vector2i(w * 2, h * 2)
	add_child(_vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.82, 0.88, 0.95)
	e.ambient_light_energy = 0.75
	env.environment = e
	_vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.15
	_vp.add_child(sun)
	model = TeamModel.new()
	_vp.add_child(model)
	model.build(team)
	model.run = 1.0
	model.rotation.y = deg_to_rad(-90)   # di profilo, verso destra
	_cam = Camera3D.new()
	_cam.fov = 13
	var at := Vector3(0.1, 0.08, 0.0)
	var from := Vector3(0.1, 0.42, 1.45)
	_cam.transform = Transform3D(Basis.looking_at(at - from), from)   # fuori dall'albero: niente look_at
	_vp.add_child(_cam)

## Fuori gara: ferma e sbiadita.
func set_active(on: bool) -> void:
	model.run = 1.0 if on else 0.0
	modulate = Color(1, 1, 1, 1.0 if on else 0.35)
