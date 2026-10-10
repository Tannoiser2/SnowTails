extends SceneTree
## Cerca collegamenti in avanti che in realtà tornano indietro rispetto al senso di marcia.
func _init() -> void:
	var seen := {}
	for f in ["nutcracker", "hobbit", "yquem", "treemendous", "riddler", "bruce", "dagger"]:
		var c := Course.new()
		c.load_file("res://data/courses/%s.json" % f)
		for cell in c.cells:
			var pc: Dictionary = c.pieces[cell["piece"]]
			var fid := String(pc["face"]["id"])
			var local_ids: Array = pc["cells"]
			for t in cell["fwd"]:
				var ds: float = float(c.cells[t]["s"]) - float(cell["s"])
				# anche il verso locale: confronto con la direzione delle altre caselle della catena
				if ds < -c.cell_len * 0.15:
					var key := "%s %d->%d" % [fid, local_ids.find(cell["id"]), local_ids.find(t) if c.cells[t]["piece"] == cell["piece"] else -1]
					if not seen.has(key):
						seen[key] = true
						print(f, ": ", key, " ds=", snapped(ds / c.cell_len, 0.01))
	quit()
