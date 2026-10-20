extends SceneTree
func _find_button(n: Node, text: String) -> Button:
	if n is Button and (n as Button).text == text: return n
	for c in n.get_children():
		var r := _find_button(c, text)
		if r: return r
	return null
func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	_find_button(main.modal_layer, "5").pressed.emit()
	await process_frame
	var cpus := []
	_collect(main.modal_layer, "Persona", cpus)
	cpus[2].pressed.emit()
	await create_timer(0.3).timeout
	print("slitte ", main.setup_n, " ai ", main.setup_ai)
	root.get_texture().get_image().save_png("/tmp/shots/menu.png")
	main.course_files.append("res://data/courses/prova.json")
	main.course_idx = main.course_files.size() - 1
	main._menu_refresh_info()
	main.start_game()
	await create_timer(2.5).timeout
	root.get_texture().get_image().save_png("/tmp/shots/menu_game.png")
	quit()
func _collect(n: Node, text: String, out: Array) -> void:
	if n is Button and (n as Button).text == text: out.append(n)
	for c in n.get_children(): _collect(c, text, out)
