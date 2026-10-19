extends SceneTree
## Vista d'insieme di un percorso (per controllare il terreno attorno alla pista).
func _init() -> void:
	var path := OS.get_environment("COURSE") if OS.get_environment("COURSE") != "" else "res://data/courses/nutcracker.json"
	var c := Course.new()
	c.load_file(path)
	var b := BoardView3D.new()
	root.add_child(b)
	var g := SledGame.new()
	g.setup(c, [true, true])
	for p in g.players:
		g.take_slot(p, g.free_slots()[0])
	b.setup(c, g)
	var pts := []
	for cc in c.cells:
		pts.append(cc["pos"])
	b.frame(pts, 3.0, true)
	b.target = b.target_goal
	b.dist = b.dist_goal * 0.75
	b.dist_goal = b.dist
	b.pitch = deg_to_rad(40)
	b.yaw_goal = 0.6
	b.yaw = 0.6
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png("/tmp/shots/overview.png")
	quit()
