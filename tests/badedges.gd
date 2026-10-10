extends SceneTree
## Cerca passi (avanti o deriva) verso tessere precedenti, troppo lunghi o all'indietro.
func _init() -> void:
	for f in ["nutcracker", "hobbit", "yquem", "treemendous", "riddler", "bruce", "dagger"]:
		var c := Course.new()
		c.load_file("res://data/courses/%s.json" % f)
		var n := {"tessera_prec": 0, "lunghi": 0, "indietro": 0}
		var ex := []
		for cell in c.cells:
			for kind in ["fwd", "dl", "dr"]:
				for t in cell[kind]:
					var o: Dictionary = c.cells[t]
					var d: float = (o["pos"] - cell["pos"]).length() / c.cell_len
					if int(o["piece"]) < int(cell["piece"]):
						n["tessera_prec"] += 1
						if ex.size() < 4: ex.append("%s %s(%d)->%s(%d) %.1f" % [kind, c.pieces[cell["piece"]]["face"]["id"], cell["id"], c.pieces[o["piece"]]["face"]["id"], t, d])
					if d > 2.2:
						n["lunghi"] += 1
						if ex.size() < 8: ex.append("lungo %s %s %d->%d %.1f" % [kind, c.pieces[cell["piece"]]["face"]["id"], cell["id"], t, d])
					if float(o["s"]) < float(cell["s"]) - c.cell_len * 0.5:
						n["indietro"] += 1
		print(f, " ", n, " ", ex)
	quit()
