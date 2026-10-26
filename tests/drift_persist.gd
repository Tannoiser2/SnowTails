extends SceneTree
## Una deriva tolta nell'editor (correzione salvata) sparisce davvero in gara; esportazione e incorporazione.
func _edge(c: Course, fid: String, a: int, b: int) -> bool:
	for pc in c.pieces:
		if pc["face"]["id"] == fid:
			var ids: Array = pc["cells"]
			var x: Dictionary = c.cells[ids[a]]
			return (x["dl"] + x["dr"]).has(ids[b])
	return false
func _init() -> void:
	var fid := "corner_L_p07"
	FaceDB.reset_face(fid)
	var f := FaceDB.load_face(fid)
	var auto := Course.face_auto_drifts(f)
	var a := -1
	var b := -1
	for i in (auto[1] as Array).size():
		if (auto[1][i] as Array).size() > 0:
			a = i
			b = int(auto[1][i][0])
			break
	var c := Course.new()
	c.load_file("res://data/courses/bruce.json")
	print("prima: ", a, ">", b, " c'è ", _edge(c, fid, a, b))
	f["drift_remove"] = [[a, b, "R"]]
	f["drift_add"] = []
	FaceDB.save_face(f)
	var c2 := Course.new()
	c2.load_file("res://data/courses/bruce.json")
	print("dopo il salvataggio: c'è ", _edge(c2, fid, a, b))
	var where := FaceDB.export_corrections()
	print("esportato in ", where)
	var b2: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(where))
	print("facce nel file: ", (b2["faces"] as Dictionary).keys())
	FaceDB.reset_face(fid)
	quit()
