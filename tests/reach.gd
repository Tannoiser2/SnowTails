extends SceneTree
func _init() -> void:
	for f in ["nutcracker", "hobbit", "yquem", "treemendous", "riddler", "bruce", "dagger"]:
		var c := Course.new()
		if not c.load_file("res://data/courses/%s.json" % f):
			print(f, " ERRORE ", c.error); continue
		var seen := {}
		var q: Array = c.start_cells.duplicate()
		for s in q: seen[s] = true
		while not q.is_empty():
			var id: int = q.pop_back()
			for t in c.cells[id]["fwd"] + c.cells[id]["dl"] + c.cells[id]["dr"]:
				if not seen.has(t):
					seen[t] = true; q.append(t)
		var fin := false
		for id in seen:
			if c.cells[id]["piece"] >= c.finish_piece: fin = true
		print(f, ": ", c.cells.size(), " caselle, raggiungibili ", seen.size(), ", traguardo raggiungibile: ", fin)
	quit()
