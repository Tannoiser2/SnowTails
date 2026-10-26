extends SceneTree
## Libreria online delle piste (con tests/firebase_mock.py): ST_STEP=a (crea e carica), b (scarica e cancella), c (vede la cancellazione).
## Ogni passo usa una cartella dati diversa (ST_SESSION e --user-dir non servono: si svuota user://courses).
func _clear() -> void:
	var da := DirAccess.open(CourseEditor.USER_DIR)
	if da:
		for f in da.get_files():
			DirAccess.remove_absolute(CourseEditor.USER_DIR + f)
func _init() -> void:
	var net := Net.new()
	root.add_child(net)
	await process_frame
	await process_frame
	CourseLibrary.set_word(net, "parola segreta di prova")
	var step := OS.get_environment("ST_STEP")
	if step == "a":
		_clear()
		var d := {"name": "Pista online", "pieces": ["start_p21", "straight_p13a", "finish_p21"], "saved_at": "2026-10-26T10:00:00"}
		CourseLibrary._write(CourseEditor.USER_DIR + "pista_online.json", d)
		var r := await CourseLibrary.sync(net)
		print("A: ", r)
	elif step == "b":
		_clear()
		var r := await CourseLibrary.sync(net)
		print("B: ", r, " file: ", FileAccess.file_exists(CourseEditor.USER_DIR + "pista_online.json"))
		DirAccess.remove_absolute(CourseEditor.USER_DIR + "pista_online.json")
		print("B cancella: ", await CourseLibrary.remove(net, "pista_online"))
	else:
		var d := {"name": "Pista online", "pieces": ["start_p21", "straight_p13a", "finish_p21"], "saved_at": "2026-10-26T10:00:00"}
		CourseLibrary._write(CourseEditor.USER_DIR + "pista_online.json", d)
		var r := await CourseLibrary.sync(net)
		print("C: ", r, " file: ", FileAccess.file_exists(CourseEditor.USER_DIR + "pista_online.json"))
	quit()
