extends SceneTree
## Fotogrammi della muta animata: a sinistra ferma, a destra di corsa.
func _init() -> void:
	var w := Node3D.new()
	root.add_child(w)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("e8eef4")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.72, 0.75)
	w.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(30), 0)
	w.add_child(sun)
	var a := TeamModel.new(); a.build(Color("c0392b")); a.position = Vector3(-0.35, 0, 0); w.add_child(a)
	var b := TeamModel.new(); b.build(Color("2e6fd0")); b.position = Vector3(0.35, 0, 0); b.run = 1.0; w.add_child(b)
	var cam := Camera3D.new()
	cam.transform = Transform3D(Basis(), Vector3(1.3, 0.75, -0.9)).looking_at(Vector3(0, 0.08, -0.05), Vector3.UP)
	w.add_child(cam)
	cam.current = true
	cam.fov = 40
	await create_timer(0.8).timeout
	for i in 6:
		await create_timer(0.07).timeout
		root.get_texture().get_image().save_png("/tmp/shots/anim_%d.png" % i)
	b.shake(1.0)
	for i in 3:
		await create_timer(0.08).timeout
		root.get_texture().get_image().save_png("/tmp/shots/bump_%d.png" % i)
	quit()
