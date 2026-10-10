extends SceneTree
func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.course_idx = main.course_files.find("res://data/courses/nutcracker.json")
	main.setup_n = 2
	main.setup_ai = [true, false, true, true, true]
	main.start_game()
	for i in 200:
		if main.phase == "slots": break
		await create_timer(0.1).timeout
	main._take_slot(main.game.free_slots()[0])
	for i in 200:
		if main.phase == "cards": break
		await create_timer(0.1).timeout
	var c: Course = main.course
	var up := -1
	for pi in c.pieces.size():
		if String(c.pieces[pi]["face"]["id"]).begins_with("uturn"): up = pi
	var ids: Array = c.pieces[up]["cells"]
	main.cur.cell = ids[17]
	main.cur.moves = 1
	main.show_paths = true
	main.board.set_follow(true)
	var idx := -1
	for i in main.cur.hand.size():
		if main.cur.hand[i] >= 4: idx = i
	main._tap_card(max(idx, 0))
	main._tap_slot("L")
	await create_timer(0.3).timeout
	main.board.dist_goal = 6.0
	await create_timer(1.2).timeout
	root.get_texture().get_image().save_png("/tmp/shots/uturn_prev.png")
	quit()
