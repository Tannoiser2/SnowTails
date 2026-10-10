extends SceneTree
## Vista d'insieme in 3D del percorso indicato (richiede le facce mappate).
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var c := Course.new()
	c.load_file("res://data/courses/nutcracker.json" if args.is_empty() else args[0])
	var b := BoardView3D.new()
	root.add_child(b)
	var g := SledGame.new()
	g.setup(c, [true, true, true, true])
	for p in g.players:
		g.take_slot(p, g.free_slots()[0])
	b.setup(c, g)
	var mn := Vector2(INF, INF); var mx := -mn
	for cell in c.cells:
		mn = mn.min(cell["pos"]); mx = mx.max(cell["pos"])
	b.focus((mn + mx) * 0.5)
	b.pitch = deg_to_rad(88)
	b.dist_goal = (mx - mn).length() * 0.012
	b.dist = b.dist_goal
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png("/tmp/shots/course_" + (args[0].get_file().get_basename() if args.size() > 0 else "nutcracker") + ".png")
	quit()
