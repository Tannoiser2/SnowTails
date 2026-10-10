extends SceneTree
func _init() -> void:
	var c := Course.new()
	c.load_file("res://data/courses/prova.json")
	var b := BoardView3D.new()
	root.add_child(b)
	var g := SledGame.new()
	g.setup(c, [true, true])
	for p in g.players: g.take_slot(p, g.free_slots()[0])
	g.players[0].cell = c.pieces[3]["cells"][3]
	b.setup(c, g)
	b.focus(c.cells[c.pieces[3]["cells"][12]]["pos"])
	b.target = b.target_goal; b.pitch = deg_to_rad(40); b.dist = 4.5; b.dist_goal = 4.5
	b.yaw = 0.4; b.yaw_goal = 0.4
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png("/tmp/shots/sap.png")
	quit()
