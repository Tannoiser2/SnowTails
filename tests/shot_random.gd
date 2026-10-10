extends SceneTree
func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main._menu_pick_course(main.course_files.size())
	main._menu_set_diff(2)
	main._menu_set_len(1)
	await create_timer(0.4).timeout
	root.get_texture().get_image().save_png("/tmp/shots/rnd_menu.png")
	print(main.rnd_def.get("note", ""), " ", main.rnd_def.get("pieces", []))
	# vista d'insieme della pista generata
	var c := Course.new()
	c.build(main.rnd_def)
	var b: BoardView3D = main.board
	var g := SledGame.new()
	g.setup(c, [true, true, true, true])
	for p in g.players: g.take_slot(p, g.free_slots()[0])
	main._close_modal()
	b.setup(c, g)
	var mn := Vector2(INF, INF); var mx := -mn
	for cell in c.cells:
		mn = mn.min(cell["pos"]); mx = mx.max(cell["pos"])
	b.hud_top = 0; b.hud_bottom = 0; b.hud_right = 0
	main.set_process(false)
	b.focus((mn + mx) * 0.5)
	b.target = b.target_goal
	b.pitch = deg_to_rad(80)
	b.dist_goal = (mx - mn).length() * 0.0095
	b.dist = b.dist_goal
	main.top_panel.visible = false
	main.bottom_panel.visible = false
	main.side_panel.visible = false
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png("/tmp/shots/rnd_track.png")
	quit()
