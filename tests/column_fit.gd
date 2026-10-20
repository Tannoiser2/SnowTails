extends SceneTree
func _find(n: Node, text: String) -> Button:
	if n is Button and (n as Button).text == text and (n as Button).is_visible_in_tree(): return n
	for c in n.get_children():
		var r := _find(c, text)
		if r: return r
	return null
func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.course_files.append("res://data/courses/prova.json")
	main.course_idx = main.course_files.size() - 1
	main.setup_n = 5
	main.setup_ai = [false, true, true, true, true]
	main.start_game()
	var heights := {}
	var worst := -9999.0
	var vh: float = main.get_viewport().get_visible_rect().size.y
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 40000:
		await create_timer(0.05).timeout
		if main.phase == "slots" and main.cur != null and not main.cur.ai:
			main._take_slot(main.game.free_slots()[0])
		if main.top_panel:
			var k: String = main.phase + ("_cpu" if main.cur != null and main.cur.ai else "")
			heights[k] = int(main.top_panel.size.y)
		for txt in ["Muovi la slitta", "Cambia carte"]:
			var b := _find(main.side_inner, txt)
			if b: worst = max(worst, b.get_global_rect().end.y - vh)
		if main.phase == "cards" and not main.cur.ai:
			if main.game.round_n >= 2: break
			main._tap_card(0); main._tap_slot("B"); main._confirm()
			await create_timer(0.3).timeout
			if main.phase == "dest":
				main._apply_choice(main.pending.duplicate(), main.outs[main.outs.size() - 1])
	print("altezza barra di stato per fase: ", heights)
	print("pulsanti oltre il bordo (px, <=0 va bene): ", worst)
	quit()
