extends SceneTree
func _init() -> void:
	var c := Course.new()
	c.load_file("res://data/courses/prova.json")
	var b := BoardView3D.new()
	root.add_child(b)
	var g := SledGame.new()
	g.setup(c, [true, true])
	for p in g.players: g.take_slot(p, g.free_slots()[0])
	# un alberello qualsiasi e la casella prima
	var sap: int = c.saplings[3]
	var before: int = c.cells[sap]["bwd"][0]
	g.players[0].cell = c.start_cells[4]
	g.players[1].cell = c.cells[c.start_cells[2]]["fwd"][0]
	b.setup(c, g)
	b.focus(c.cells[sap]["pos"])
	b.target = b.target_goal; b.pitch = deg_to_rad(35); b.dist = 2.6; b.dist_goal = 2.6
	b.yaw = 0.5; b.yaw_goal = 0.5
	await create_timer(0.8).timeout
	b.knock_sapling(sap, (c.cells[sap]["pos"] - c.cells[before]["pos"]).normalized())
	g.saplings.erase(sap)
	b.redraw()
	await create_timer(0.2).timeout
	root.get_texture().get_image().save_png("/tmp/shots/fx1.png")
	await create_timer(0.4).timeout
	root.get_texture().get_image().save_png("/tmp/shots/fx2.png")
	# urto contro il bordo
	var edge: int = c.start_cells[0]
	b.focus(c.cells[edge]["pos"])
	g.players[1].cell = edge
	b.redraw()
	await create_timer(1.2).timeout
	b.crash_fx(edge, Vector2(-1, -1).normalized(), 1)
	await create_timer(0.25).timeout
	root.get_texture().get_image().save_png("/tmp/shots/fx3.png")
	quit()
