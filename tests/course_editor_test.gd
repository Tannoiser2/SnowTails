extends SceneTree
func _init() -> void:
	CourseEditor.start_from = ""
	var e = load("res://scenes/course_editor.tscn").instantiate()
	root.add_child(e)
	await create_timer(0.5).timeout
	for tok in ["start_p22", "@straight", "@straight", "corner_R_p08", "@saplings", "uturn_L_p01", "@straight", "corner_L_p07", "@straight", "finish_p21", "@straight"]:
		e._add(tok)
	e.name_edit.text = "Prova editor"
	await create_timer(0.4).timeout
	root.get_texture().get_image().save_png("/tmp/shots/ced.png")
	e._save()
	print(e.status.text)
	print(FileAccess.file_exists("user://courses/prova_editor.json"))
	var c := Course.new()
	print("si carica: ", c.load_file("user://courses/prova_editor.json"), " ", c.error)
	quit()
