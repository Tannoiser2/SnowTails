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
	_find(main.modal_layer, "Editor").pressed.emit()
	await create_timer(0.4).timeout
	root.get_texture().get_image().save_png("/tmp/shots/tab_editor.png")
	_find(main.modal_layer, "Elimina").pressed.emit()
	await create_timer(0.2).timeout
	_find(main.modal_layer, "Sicuro?").pressed.emit()
	await create_timer(0.4).timeout
	print("esiste ancora: ", FileAccess.file_exists(CourseEditor.USER_DIR + "prova_mia.json"), " tab ", main.menu_tab)
	_find(main.modal_layer, "Pista casuale").pressed.emit()
	await create_timer(0.6).timeout
	root.get_texture().get_image().save_png("/tmp/shots/tab_random.png")
	quit()
