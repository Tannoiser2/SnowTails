extends SceneTree
var main
func _init() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()

func shot(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png("/tmp/shots/" + name + ".png")

func wait(t: float) -> void:
	await create_timer(t).timeout

func _run() -> void:
	await wait(0.5)
	await shot("01_menu")
	main.course_files.append("res://data/courses/prova.json")
	main.course_idx = main.course_files.size() - 1
	main.setup_n = 5
	main.start_game()
	await wait(0.3)
	# attende il turno di scelta umano
	for i in 40:
		if main.phase == "slots": break
		await wait(0.2)
	await shot("02_slots")
	main._take_slot(main.game.free_slots()[0])
	for i in 80:
		if main.phase == "cards": break
		await wait(0.2)
	await wait(0.5)
	await shot("03_cards")
	main._tap_card(0)
	main._tap_slot("B")
	await shot("04_pending")
	main._confirm()
	await wait(0.5)
	await shot("05_dest")
	if main.phase == "dest":
		main._apply_choice(main.pending.duplicate(), main.outs[main.outs.size()-1])
	for i in 80:
		if main.phase == "cards" or main.phase == "discard": break
		await wait(0.2)
	await wait(0.5)
	await shot("06_next")
	quit()
