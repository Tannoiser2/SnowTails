extends SceneTree
func _find(n: Node, text: String) -> Button:
	if n is Button and (n as Button).text == text: return n
	for c in n.get_children():
		var r := _find(c, text)
		if r: return r
	return null
func _init() -> void:
	# una pista dell'utente da eliminare
	DirAccess.make_dir_recursive_absolute(CourseEditor.USER_DIR)
	var src := FileAccess.get_file_as_string("res://data/courses/prova.json")
	var d: Dictionary = JSON.parse_string(src)
	d["name"] = "Pista di prova mia"
	var f := FileAccess.open(CourseEditor.USER_DIR + "prova_mia.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(d)); f.close()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.6).timeout
	root.get_texture().get_image().save_png("/tmp/shots/tab_list.png")
	print("list ", main._modal_panel.position, main._modal_panel.size, main._modal_panel.scale)
	_find(main.modal_layer, "Editor").pressed.emit()
	await create_timer(0.4).timeout
	root.get_texture().get_image().save_png("/tmp/shots/tab_editor.png")
	print("edit ", main._modal_panel.position, main._modal_panel.size, main._modal_panel.scale)
	_find(main.modal_layer, "Elimina").pressed.emit()
	await create_timer(0.2).timeout
	_find(main.modal_layer, "Sicuro?").pressed.emit()
	await create_timer(0.4).timeout
	print("esiste ancora: ", FileAccess.file_exists(CourseEditor.USER_DIR + "prova_mia.json"), " tab ", main.menu_tab)
	_find(main.modal_layer, "Pista casuale").pressed.emit()
	await create_timer(0.6).timeout
	root.get_texture().get_image().save_png("/tmp/shots/tab_random.png")
	print("rand ", main._modal_panel.position, main._modal_panel.size, main._modal_panel.scale)
	_find(main.modal_layer, "Simultaneo").pressed.emit()
	await create_timer(0.3).timeout
	print("sim  ", main._modal_panel.position, main._modal_panel.size, main._modal_panel.scale)
	var nos := []
	_collect(main.modal_layer, "No", nos)
	nos[1].pressed.emit()
	await create_timer(0.1).timeout
	nos = []
	_collect(main.modal_layer, "No", nos)
	nos[2].pressed.emit()
	await create_timer(0.1).timeout
	nos = []
	_collect(main.modal_layer, "No", nos)
	nos[0].pressed.emit()
	await create_timer(0.3).timeout
	print("flags ", main._seat_flags(), " n ", main.setup_n)
	root.get_texture().get_image().save_png("/tmp/shots/tab_seats.png")
	main.start_game()
	await create_timer(1.0).timeout
	for pl in main.game.players: print(pl.id, " ", pl.name, " seat ", pl.seat)
	quit()
func _collect(n: Node, text: String, out: Array) -> void:
	if n is Button and (n as Button).text == text: out.append(n)
	for c in n.get_children(): _collect(c, text, out)
