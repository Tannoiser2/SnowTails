extends SceneTree
## Schermate a una data risoluzione: menu, regole, partita, classifica.
func _init() -> void:
	var tag := OS.get_environment("SHOT_TAG")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.6).timeout
	root.get_texture().get_image().save_png("/tmp/shots/%s_menu.png" % tag)
	main.course_idx = main.course_files.find("res://data/courses/prova.json")
	main._menu_refresh_info()
	main.setup_n = 4
	main.setup_ai = [false, true, true, true, true]
	main.start_game()
	await create_timer(1.0).timeout
	for i in 20:
		if main.phase == "slots":
			main._do_act({"k": "slot", "v": main.game.free_slots()[0]})
		await create_timer(0.5).timeout
		if main.phase == "cards":
			break
	root.get_texture().get_image().save_png("/tmp/shots/%s_game.png" % tag)
	main.show_help()
	await create_timer(0.4).timeout
	root.get_texture().get_image().save_png("/tmp/shots/%s_help.png" % tag)
	main._close_modal()
	main.game._game_over()
	main._show_results()
	await create_timer(0.4).timeout
	root.get_texture().get_image().save_png("/tmp/shots/%s_results.png" % tag)
	quit()
