extends SceneTree
## Verifica le regole dei segmenti fanmade sulla pista di prova.
var c: Course
var g: SledGame

func _init() -> void:
	c = Course.new()
	if not c.load_file("res://data/courses/fanmade.json"):
		print("ERRORE ", c.error); quit(); return
	g = SledGame.new()
	g.setup(c, [true])
	var p = g.players[0]
	p.moves = 1
	var ok := 0
	var tot := 0
	# salita: si parte dal rettilineo prima della salita, corsia centrale, velocità 7
	p.cell = _cell(1, 2, 2)
	var outs := g.compute_outs(p, {"L": 4, "R": 4, "B": 1})
	var max_up := 0
	for o in outs:
		var used := 0
		var seen_up := false
		for t in o["path"]:
			if c.slope_of(t) == "up": seen_up = true
		if seen_up: max_up = max(max_up, (o["path"] as Array).size())
	tot += 1; if max_up <= SledGame.UP_MAX and max_up > 0: ok += 1
	print("salita: caselle massime con la salita di mezzo = ", max_up, " (limite ", SledGame.UP_MAX, ")")
	# discesa: si parte in discesa con velocità 1 → almeno 5
	p.cell = _cell(6, 1, 2)
	outs = g.compute_outs(p, {"L": 1, "R": 1, "B": 1})
	var mn := 99
	for o in outs: mn = min(mn, (o["path"] as Array).size())
	tot += 1; if mn >= SledGame.DOWN_MIN or outs[0].get("slid", false): ok += 1
	print("discesa: caselle con velocità 1 = ", mn, " slid=", outs[0].get("slid", false))
	# neve fresca: tessera 7, corsia con cumuli: con velocità 3 si fanno meno di 3 caselle
	p.cell = _cell(5, 0, 0)
	outs = g.compute_outs(p, {"L": 2, "R": 2, "B": 1})
	var lens := []
	for o in outs: lens.append((o["path"] as Array).size())
	tot += 1; if lens.min() < 3: ok += 1
	print("neve fresca: lunghezze con velocità 3 = ", lens)
	# ghiaccio: si finisce sul ghiaccio → una casella in più
	p.cell = _cell(3, 0, 2)
	outs = g.compute_outs(p, {"L": 2, "R": 2, "B": 2})
	tot += 1; if outs.size() > 0 and outs[0].get("ice", false) and (outs[0]["path"] as Array).size() == 3: ok += 1
	print("ghiaccio: velocità 2 → caselle ", (outs[0]["path"] as Array).size(), " ice=", outs[0].get("ice", false))
	# vento (con la discesa: si parte a 5 almeno) → spinte di lato
	p.cell = _cell(6, 0, 2)
	outs = g.compute_outs(p, {"L": 2, "R": 2, "B": 0})
	tot += 1; if int(outs[0].get("wind", 0)) >= 1: ok += 1
	print("vento: spinte = ", outs[0].get("wind", 0), " fine corsia laterale ", c.cells[outs[0]["end"]]["lat"])
	# baita: ci si ferma sopra con un'ammaccatura → riparata, niente carte
	var hut: int = c.huts.keys()[0]
	p.dents = 1
	p.hand = [1, 2]
	var o2 := {"path": [hut], "end": hut, "crash": "", "dents": 0, "corner_dents": 0, "sap": [], "from": hut, "speed": 1}
	g.after_move(p, o2)
	tot += 1; if p.dents == 0 and p.hand.size() == 2: ok += 1
	print("baita: ammaccature ", p.dents, " carte ", p.hand.size())
	# bivio: 4 + 4 caselle lunghe, 6 + 6 normali, niente corsia di mezzo
	tot += 1; if (c.pieces[4]["cells"] as Array).size() == 20: ok += 1
	print("bivio: caselle ", (c.pieces[4]["cells"] as Array).size())
	# caratteristiche sommate: la tessera 2 è salita e vento insieme
	tot += 1; if c.slope_of(c.pieces[2]["cells"][0]) == "up" and c.wind_of(c.pieces[2]["cells"][0]) == 1: ok += 1
	print("REGOLE FANMADE: %d/%d" % [ok, tot])
	quit()

## Casella della tessera pi alla colonna col (0 = ingresso) e corsia lane (0..4 da sinistra).
func _cell(pi: int, col: int, lane: int) -> int:
	var pc: Dictionary = c.pieces[pi]
	var d: Vector2 = (pc["exit_mid"] - pc["entry_mid"]).normalized()
	var right := Vector2(-d.y, d.x)
	var best := -1
	var bd := INF
	var target: Vector2 = pc["entry_mid"] + d * c.cell_len * (col + 0.5) + right * c.lane_w * (lane - 2)
	for id in pc["cells"]:
		var dd: float = (c.cells[id]["pos"] - target).length()
		if dd < bd:
			bd = dd
			best = id
	return best
