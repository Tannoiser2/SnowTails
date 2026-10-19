extends SceneTree
## Editor dei percorsi con la pista fanmade caricata e un rettilineo selezionato.
func _init() -> void:
	CourseEditor.start_from = "res://data/courses/fanmade.json"
	var ed = load("res://scenes/course_editor.tscn").instantiate()
	root.add_child(ed)
	await create_timer(1.5).timeout
	ed.list.select(2)
	ed._refresh_mods()
	ed._focus_piece(2)
	await create_timer(1.2).timeout
	root.get_texture().get_image().save_png("/tmp/shots/editor.png")
	quit()
