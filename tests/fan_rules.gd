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
	# salita: chi parte in salita perde 3 punti (7 → 4)
	var up_pi := -1
	var down_pi := -1
	for pi in c.pieces.size():
		var sl := String((c.pieces[pi]["mods"] as Dictionary).get("slope", ""))
		if sl == "up" and up_pi < 0: up_pi = pi
		if sl == "down" and down_pi < 0: down_pi = pi
	p.cell = _cell(up_pi, 1, 2)
	var outs := g.compute_outs(p, {"L": 4, "R": 3, "B": 0})
	var sp := []
	for o in outs: sp.append(int(o["speed"]))
	tot += 1; if sp.min() == 4 and int(outs[0].get("slope", 0)) == -3: ok += 1
	print("salita: velocità 7 in partenza → ", sp.min(), " (pendenza ", outs[0].get("slope", 0), ")")
	# discesa: +1 ogni 3 (6 → 8, 9 → 12, 3 → 4)
	var res_d := []
	for base in [[2, 1, 0], [3, 3, 0], [5, 4, 0]]:
		p.cell = _cell(down_pi, 1, 2)
		outs = g.compute_outs(p, {"L": base[0], "R": base[1], "B": base[2]})
		var mx := 0
		for o in outs: mx = max(mx, int(o["speed"]) - int(o.get("bonus_n", 0)))
		res_d.append(mx)
	tot += 1; if res_d == [4, 8, 12]: ok += 1
	print("discesa: 3, 6, 9 → ", res_d)
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
	# vento: la manica a vento aggiunge 1 di deriva nel suo verso (cani uguali → deriva 1)
	var wind_pi := -1
	for pi in c.pieces.size():
		if (c.pieces[pi]["mods"] as Dictionary).has("wind") and c.slope_of(c.pieces[pi]["cells"][0]) == "":
			wind_pi = pi
			break
	if wind_pi < 0:
		for pi in c.pieces.size():
			if (c.pieces[pi]["mods"] as Dictionary).has("wind"): wind_pi = pi; break
	p.cell = _cell(wind_pi, 0, 2)
	var wd := g.effective_drift(p.cell, {"L": 3, "R": 3, "B": 1})
	outs = g.compute_outs(p, {"L": 3, "R": 3, "B": 1})
	tot += 1; if abs(wd) == 1 and int(outs[0].get("wind", 0)) == wd: ok += 1
	print("vento: deriva con cani uguali = ", wd, " esito vento ", outs[0].get("wind", 0))
	# baita: ci si ferma sopra con un'ammaccatura → riparata, niente carte
	var hut: int = c.huts.keys()[0]
	p.dents = 3
	p.hand = [1, 2]
	var o2 := {"path": [hut], "end": hut, "crash": "", "dents": 0, "corner_dents": 0, "sap": [], "from": hut, "speed": 1}
	g.after_move(p, o2)
	# 3 ammaccature = 6 mezze; metà riparata → 3 mezze: 1 ammaccatura e mezza
	tot += 1; if p.dents == 1 and p.half and p.hand.size() == 2: ok += 1
	print("baita: ammaccature ", p.dents, " mezza ", p.half, " carte ", p.hand.size())
	# neve fresca spazzata: dopo il passaggio la casella costa 1
	var fc: int = c.grid_cell(5, 1, 0)
	var had := g.fresh.has(fc)
	g.after_move(p, {"path": [fc], "end": fc, "crash": "", "dents": 0, "corner_dents": 0, "sap": [], "from": fc, "speed": 1})
	tot += 1; if had and not g.fresh.has(fc): ok += 1
	print("neve spazzata: prima ", had, " dopo ", g.fresh.has(fc))
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
