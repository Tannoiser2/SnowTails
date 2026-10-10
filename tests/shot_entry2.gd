extends SceneTree
func _init() -> void:
	var c := Course.new()
	c.load_file("res://data/courses/nutcracker.json")
	var b := BoardView3D.new()
	root.add_child(b)
	var g := SledGame.new()
	g.setup(c, [true, true, true])
	for p in g.players: g.take_slot(p, g.free_slots()[0])
	b.setup(c, g)
	var ids: Array = c.pieces[3]["cells"]
	b.focus(c.pieces[3]["entry_mid"])
	b.target = b.target_goal; b.pitch = deg_to_rad(42); b.dist = 3.0; b.dist_goal = 3.0
	b.yaw = -0.4; b.yaw_goal = -0.4
	await create_timer(1.2).timeout
	root.get_texture().get_image().save_png("/tmp/shots/curve_entry.png")
	quit()
