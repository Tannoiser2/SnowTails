extends SceneTree
func _init() -> void:
	for f in ["nutcracker", "hobbit", "yquem", "treemendous", "riddler", "bruce", "dagger"]:
		var c := Course.new()
		c.load_file("res://data/courses/%s.json" % f)
		var line := []
		for pi in range(1, c.pieces.size()):
			var n := 0
			for id in c.pieces[pi - 1]["cells"]:
				for t in c.cells[id]["fwd"]:
					if c.cells[t]["piece"] == pi: n += 1
			line.append("%s>%s:%d" % [String(c.pieces[pi-1]["face"]["id"]).get_slice("_", 0).left(4), String(c.pieces[pi]["face"]["id"]).get_slice("_", 0).left(4), n])
		print(f, "  ", " ".join(line))
	quit()
