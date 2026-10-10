extends SceneTree
## Gioca una gara breve con sole CPU, mostra la classifica e il replay.
func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.course_idx = main.course_files.find("res://data/courses/prova.json")
	main.setup_n = 4
	main.setup_ai = [true, true, true, true, true]
	main.start_game()
	for i in 600:
		await create_timer(0.1).timeout
		if main.phase == "over": break
	await create_timer(0.6).timeout
	root.get_texture().get_image().save_png("/tmp/shots/results.png")
	print("giri registrati: ", main.game.history.size(), " mosse giro 1: ", main.game.history[0].size())
	main.start_replay()
	await create_timer(1.3).timeout
	root.get_texture().get_image().save_png("/tmp/shots/replay1.png")
	await create_timer(4.0).timeout
	root.get_texture().get_image().save_png("/tmp/shots/replay2.png")
	main.replay_stop = true
	await create_timer(1.0).timeout
	print("fase dopo il replay: ", main.phase)
	quit()
