extends SceneTree
## Il crepaccio non deve essere scavalcabile: nessun passo in avanti deve saltare
## le caselle bloccate della corsia centrale (prima e ultima).
func _init() -> void:
	for f in ["yquem", "bruce"]:
		var c := Course.new()
		c.load_file("res://data/courses/%s.json" % f)
		var cp := -1
		for pi in c.pieces.size():
			if String(c.pieces[pi]["face"]["id"]).begins_with("chasm"): cp = pi
		var long_jumps := 0
		for pi in [cp - 1, cp, cp + 1]:
			for id in c.pieces[pi]["cells"]:
				for t in c.cells[id]["fwd"]:
					var d: float = (c.cells[t]["pos"] - c.cells[id]["pos"]).length()
					if d > c.cell_len * 1.4 and String(c.pieces[c.cells[id]["piece"]]["face"].get("type","")) == "straight":
						long_jumps += 1
						print("  salto sospetto: ", id, " -> ", t, " lunghezza ", snapped(d / c.cell_len, 0.1), " caselle")
		print(f, ": collegamenti che scavalcano caselle intorno al crepaccio: ", long_jumps)
	quit()
