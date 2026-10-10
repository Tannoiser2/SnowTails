extends SceneTree
func _init() -> void:
	var c := Course.new()
	c.load_file("res://data/courses/prova.json")
	var b := BoardView3D.new()
	root.add_child(b)
	var g := SledGame.new()
	g.setup(c, [true, true, true])
	for p in g.players:
		g.take_slot(p, g.free_slots()[0])
	g.players[1].cell = c.cells[g.players[1].cell]["fwd"][0]
	b.setup(c, g)
	b.current_id = 0
	b.redraw()
	b.focus_cell(g.players[1].cell)
	b.target = b.target_goal; b.yaw = b.yaw_goal + 0.6; b.yaw_goal = b.yaw
	b.pitch = deg_to_rad(28); b.dist_goal = 1.6; b.dist = 1.6
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png("/tmp/shots/team.png")
	b.pitch = deg_to_rad(45); b.dist_goal = 4.0; b.dist = 4.0; b.yaw = b.yaw_goal - 0.6; b.yaw_goal = b.yaw
	await create_timer(0.5).timeout
	root.get_texture().get_image().save_png("/tmp/shots/team2.png")
	quit()
