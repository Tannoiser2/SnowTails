extends SceneTree
## Verifica che una correzione salvata sopravviva a un'immagine rifatta (spostata).
func _init() -> void:
	var id := "corner_L_p07"
	FaceDB.reset_face(id)
	var f := FaceDB.load_face(id)
	var n0 := (f["cells"] as Array).size()
	f["links"] = (f["links"] as Array).slice(0, 10)
	print("salvato in: ", FaceDB.save_face(f))
	var g := FaceDB.load_face(id)
	print("dopo il salvataggio: caselle ", (g["cells"] as Array).size(), "/", n0, ", collegamenti ", (g["links"] as Array).size(), ", modificata ", g.get("user_edited", false))
	# simula una base rifatta con l'immagine spostata di (12, -7)
	var user = JSON.parse_string(FileAccess.get_file_as_string("user://faces/" + id + ".json"))
	user["ref_entry"] = [user["ref_entry"][0] - 12, user["ref_entry"][1] + 7]
	var fh := FileAccess.open("user://faces/" + id + ".json", FileAccess.WRITE); fh.store_string(JSON.stringify(user)); fh.close()
	var h := FaceDB.load_face(id)
	print("spostamento compensato: ", FaceDB.v2(h["cells"][0]) - FaceDB.v2(g["cells"][0]))
	FaceDB.reset_face(id)
	print("dopo il ripristino: collegamenti ", (FaceDB.load_face(id)["links"] as Array).size(), ", modificata ", FaceDB.load_face(id).get("user_edited", false))
	quit()
