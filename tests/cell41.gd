extends SceneTree
func _init() -> void:
	var c := Course.new()
	c.load_file("res://data/courses/nutcracker.json")
	for pi in c.pieces.size():
		if String(c.pieces[pi]["face"]["id"]) != "corner_L_p07": continue
		var ids: Array = c.pieces[pi]["cells"]
		for li in [41, 10, 7, 0]:
			var cell: Dictionary = c.cells[ids[li]]
			var f := []
			for t in cell["fwd"]:
				f.append("%s:%d" % ["stessa" if c.cells[t]["piece"] == pi else "dopo", ids.find(t) if c.cells[t]["piece"] == pi else t])
			print("casella ", li, " avanti -> ", f, "  derive sx ", cell["dl"].size(), " dx ", cell["dr"].size())
		break
	quit()
