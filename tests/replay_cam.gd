extends SceneTree
## Nel replay, dopo aver spostato la telecamera, questa deve restare ferma finché Segui è spento.
func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.course_idx = main.course_files.find("res://data/courses/prova.json")
	main.setup_n = 3
	main.setup_ai = [true, true, true, true, true]
	main.start_game()
	for i in 600:
		await create_timer(0.1).timeout
		if main.phase == "over": break
	main.start_replay()
	await create_timer(0.8).timeout
	var b: BoardView3D = main.board
	b._pan(Vector2(120, 40))
	var t0: Vector3 = b.target_goal
	await create_timer(4.0).timeout
	print("segui dopo lo spostamento: ", b.follow, "  telecamera ferma: ", b.target_goal.distance_to(t0) < 0.001)
	b.set_follow(true)
	await create_timer(2.5).timeout
	print("con segui riattivato si muove: ", b.target_goal.distance_to(t0) > 0.01)
	main.replay_stop = true
	await create_timer(0.5).timeout
	quit()
