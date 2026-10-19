extends SceneTree
## Deriva e spinte del vento: la slitta deve scivolare di lato restando dritta lungo la pista.
func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.4).timeout
	main._close_modal()
	var c := Course.new()
	c.load_file("res://data/courses/fanmade.json")
	var g := SledGame.new()
	g.setup(c, [true])
	main.course = c
	main.game = g
	main.phase = "anim"
	var b: BoardView3D = main.board
	var p = g.players[0]
	var pi := 6
	var a0: int = c.grid_cell(pi, 0, 2)
	# un passo avanti, una deriva a sinistra, poi due spinte di lato
	var a1: int = c.grid_cell(pi, 1, 2)
	var a2: int = c.grid_cell(pi, 2, 1)
	var a3: int = c.cells[a2]["side_l"]
	var a4: int = c.cells[a3]["side_r"] if false else c.cells[a3]["side_l"]
	var full := [a0, a1, a2, a3]
	if a4 >= 0:
		full.append(a4)
	p.cell = a0
	b.setup(c, g)
	b.redraw()
	b.set_follow(false)
	b.focus_cell(a2, true)
	b.target = b.target_goal
	b.dist_goal = 3.8
	b.dist = 3.8
	b.pitch = deg_to_rad(55)
	await create_timer(0.6).timeout
	main._drive([{"p": p, "full": full, "n": full.size() - 1, "sap": []}], (full.size() - 1) * 0.5, false)
	for k in 46:
		await create_timer(0.05).timeout
		root.get_texture().get_image().save_png("/tmp/shots/drift_%02d.png" % k)
	quit()
