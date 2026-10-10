extends SceneTree
func _init() -> void:
	var c := Course.new()
	print("costruito: ", c.load_file("res://data/courses/salto.json"), " ", c.error, " spaccatura: ", c.crevasse.size(), " salti: ", c.leaps)
	var g := SledGame.new()
	g.setup(c, [false])
	var p = g.players[0]
	g.take_slot(p, 2)
	# porta la slitta a due caselle dalla spaccatura sulla stessa corsia
	var cur: int = p.cell
	while true:
		var nx: int = c.cells[cur]["fwd"][0]
		if c.crevasse.has(c.cells[nx]["fwd"][0]): break
		cur = nx
	p.cell = cur
	p.moves = 1
	for sp in [[2, 2, 2], [3, 3, 3], [4, 3, 3], [3, 3, 1]]:
		var m := {"L": sp[0], "R": sp[1], "B": sp[2]}
		var outs := g.compute_outs(p, m)
		for o in outs:
			if not o["bonus"]:
				print("velocità ", o["speed"], ": ammaccature ", o["dents"], ", fine nella spaccatura: ", c.crevasse.has(int(o["end"])))
				var hand_before: int = p.hand.size()
				var copy := {"path": o["path"], "end": o["end"], "crash": o["crash"], "corner_dents": o["corner_dents"], "dents": o["dents"], "sap": [], "speed": o["speed"], "from": o["from"], "bonus": false, "bonus_n": 0}
				var keep_cell: int = p.cell
				var keep_d: int = p.dents
				p.hand = [1, 2]
				p.deck = [1, 1, 1, 1, 1]
				g.log_text = ""
				g.after_move(p, copy)
				print("    -> ", g.log_text, " | carte in mano dopo: ", p.hand.size())
				p.cell = keep_cell
				p.dents = keep_d
				p.moves = 1
	quit()
