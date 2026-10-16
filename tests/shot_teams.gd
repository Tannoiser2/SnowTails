extends SceneTree
## Le cinque slitte affiancate, per controllare i colori di conducente e pacco.
func _init() -> void:
	var w := Node3D.new(); root.add_child(w)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color("eef3f8")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.72, 0.74, 0.78)
	w.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(30), 0); sun.shadow_enabled = true; w.add_child(sun)
	for i in 5:
		var b := TeamModel.new(); b.build(SledGame.COLORS[i]); b.position = Vector3((i - 2) * 0.42, 0, 0); w.add_child(b)
	var cam := Camera3D.new(); cam.fov = 38
	cam.transform = Transform3D(Basis(), Vector3(0.9, 0.85, 1.25)).looking_at(Vector3(0, 0.05, 0.0), Vector3.UP)
	w.add_child(cam); cam.current = true
	await create_timer(0.8).timeout
	root.get_texture().get_image().save_png("/tmp/shots/teams.png")
	quit()
