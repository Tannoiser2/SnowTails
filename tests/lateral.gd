extends SceneTree
## Collegamenti in avanti che vanno di lato rispetto al senso di marcia (angolo con la linea centrale).
func _init() -> void:
	var out := {}
	for f in ["nutcracker", "hobbit", "riddler"]:
		var c := Course.new()
		c.load_file("res://data/courses/%s.json" % f)
		for cell in c.cells:
			var pc: Dictionary = c.pieces[cell["piece"]]
			var fid := String(pc["face"]["id"])
			if not (fid.begins_with("uturn") or fid.begins_with("corner")): continue
			for t in cell["fwd"]:
				if c.cells[t]["piece"] != cell["piece"]: continue
				var v: Vector2 = (c.cells[t]["pos"] - cell["pos"]).normalized()
				# direzione di marcia locale: dalla linea centrale, vicino al punto medio
				var mid: Vector2 = (c.cells[t]["pos"] + cell["pos"]) * 0.5
				var s0 := c.project(mid, cell["piece"]).x
				var a := c.project(mid + v * 5.0, cell["piece"]).x - s0
				var ang := rad_to_deg(acos(clamp(a / 5.0, -1.0, 1.0)))
				if ang > 50.0:
					var li: int = pc["cells"].find(cell["id"])
					var lt: int = pc["cells"].find(t)
					out["%s %d->%d" % [fid, li, lt]] = int(ang)
	for k in out: print(k, "  angolo ", out[k])
	quit()
