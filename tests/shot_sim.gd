extends SceneTree
## Variante simultanea con due persone e due CPU: copertina, programmazione, partenza insieme.
func _press(n: Node, text: String) -> bool:
	if n is Button and (n as Button).text == text:
		(n as Button).pressed.emit()
		return true
	for c in n.get_children():
		if _press(c, text):
			return true
	return false
func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.course_idx = main.course_files.find("res://data/courses/prova.json")
	main.setup_n = 4
	main.setup_ai = [false, false, true, true, true]
	main.sim_variant = true
	main.show_menu()
	await create_timer(0.5).timeout
	root.get_texture().get_image().save_png("/tmp/shots/sim_menu.png")
	main.start_game()
	var shots := 0
	var programmed := 0
	for i in 600:
		await create_timer(0.1).timeout
		if main.phase == "slots":
			main._do_act({"k": "slot", "v": main.game.free_slots()[0]})
		elif main.modal_root != null and main.phase == "simwait":
			if shots == 0:
				await create_timer(0.5).timeout
				root.get_texture().get_image().save_png("/tmp/shots/sim_curtain.png")
				shots = 1
			_press(main.modal_layer, "Sono pronto")
		elif main.phase == "cards":
			var p = main.cur
			var hi: int = p.hand.size() - 1
			main._tap_card(hi)
			main._tap_slot("L" if programmed % 2 == 0 else "R")
			await create_timer(0.2).timeout
			if shots == 1:
				root.get_texture().get_image().save_png("/tmp/shots/sim_cards.png")
				shots = 2
			main._confirm()
			await create_timer(0.2).timeout
			if main.phase == "dest":
				main._submit_move(main.pending, main.outs[0])
			programmed += 1
		elif main.phase == "discard":
			main._tap_card(0)
		elif main.phase == "anim" and shots == 2:
			await create_timer(0.9).timeout
			root.get_texture().get_image().save_png("/tmp/shots/sim_move.png")
			shots = 3
		if main.game != null and main.game.round_n >= 3:
			break
	print("SIM persone: giro ", main.game.round_n, " mosse programmate ", programmed, " fase ", main.phase)
	print("LOG ", main.game.log_text)
	quit()
