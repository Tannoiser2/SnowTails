extends SceneTree
func _find(n: Node, text: String) -> Button:
	if n is Button and (n as Button).text.begins_with(text): return n
	for c in n.get_children():
		var r := _find(c, text)
		if r: return r
	return null
func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.8).timeout
	root.get_texture().get_image().save_png("/tmp/shots/m_thumbs.png")
	print("list panel ", main._modal_panel.size)
	_find(main.modal_layer, "Gran Tour").pressed.emit()
	await create_timer(0.4).timeout
	print("tour panel ", main._modal_panel.size, " sel ", main.tour_sel.size())
	_find(main.modal_layer, "✓  Bruce").pressed.emit()
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png("/tmp/shots/m_tour.png")
	print("sel ", main.tour_sel.size(), " info ", main._menu_info.text)
	main.setup_ai = [true, true, true, true, true]
	main.start_game()
	await create_timer(1.0).timeout
	for race in 2:
		# risultato finto: si chiude la gara subito
		main.game.results = []
		var ps: Array = main.game.players.duplicate()
		ps.shuffle()
		for p in ps:
			main.game.results.append({"p": p, "st": "arrivata"})
		main.game.over = true
		main._show_results()
		await create_timer(0.6).timeout
		root.get_texture().get_image().save_png("/tmp/shots/m_res%d.png" % race)
		print("tot ", main.tour["tot"])
		_find(main.modal_layer, "Prossima").pressed.emit()
		await create_timer(1.0).timeout
	quit()
