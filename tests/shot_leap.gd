extends SceneTree
func _init() -> void:
	var c := Course.new()
	c.load_file("res://data/courses/salto.json")
	var b := BoardView3D.new()
	root.add_child(b)
	var g := SledGame.new()
	g.setup(c, [true, true, true])
	for p in g.players: g.take_slot(p, g.free_slots()[0])
	b.setup(c, g)
	var ids: Array = c.pieces[3]["cells"]
	b.focus(c.cells[ids[ids.size() / 2]]["pos"])
	b.target = b.target_goal; b.pitch = deg_to_rad(42); b.dist = 5.5; b.dist_goal = 5.5
	b.yaw = 0.0; b.yaw_goal = 0.0
	await create_timer(1.2).timeout
	root.get_texture().get_image().save_png("/tmp/shots/leap.png")
	quit()
