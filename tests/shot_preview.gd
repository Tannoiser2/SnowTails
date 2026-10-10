extends SceneTree
func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.course_idx = main.course_files.find("res://data/courses/prova.json")
	main.setup_n = 3
	main.start_game()
	for i in 80:
		if main.phase == "slots": break
		await create_timer(0.1).timeout
	main._take_slot(main.game.free_slots()[0])
	for i in 120:
		if main.phase == "cards": break
		await create_timer(0.1).timeout
	main.cur.moves = 1
	main.show_paths = true
	# una carta diversa dai cani per avere deriva
	var idx := -1
	for i in main.cur.hand.size():
		if main.cur.hand[i] != 3: idx = i
	main._tap_card(max(idx, 0))
	main._tap_slot("R")
	await create_timer(1.2).timeout
	root.get_texture().get_image().save_png("/tmp/shots/preview.png")
	quit()
