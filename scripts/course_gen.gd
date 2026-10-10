class_name CourseGen
extends RefCounted
## Genera un percorso casuale scegliendo solo difficoltà (0 bassa, 1 media, 2 alta)
## e lunghezza (0 corta, 1 media, 2 lunga). Rispetta i pezzi della scatola,
## evita che la pista si sovrapponga e verifica che il traguardo sia raggiungibile.

const PLAIN := ["straight_p13a", "straight_p14a", "straight_p14b", "straight_p16a", "straight_p16b",
	"straight_p18a", "straight_p18b", "straight_p19b", "straight_p20a", "straight_p20b"]
const SPECIAL := {"saplings": ["saplings_p13b", "saplings_p17a"], "snowdrift": ["snowdrift_p15a", "snowdrift_p15b"],
	"chasm": ["chasm_p17b", "chasm_p19a"], "leap": ["leap_p22a"]}
const DIFF_NAMES := ["bassa", "media", "alta"]
const LEN_NAMES := ["corta", "media", "lunga"]

var rng := RandomNumberGenerator.new()
var _faces := {}
var last_error := ""

func _face(id: String) -> Dictionary:
	if not _faces.has(id):
		_faces[id] = FaceDB.load_face(id)
	return _faces[id]

## Restituisce la definizione del percorso, o {} se non ci riesce.
func generate(diff: int, length: int, seed_value := 0) -> Dictionary:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	for attempt in 80:
		var seq := _try(diff, length)
		if seq.is_empty():
			continue
		var def := {"name": "Pista casuale (difficoltà %s, %s)" % [DIFF_NAMES[diff], LEN_NAMES[length]],
			"note": _summary(seq), "pieces": seq, "random": true, "difficulty": diff, "length": length}
		var c := Course.new()
		if c.build(def) and _finish_reachable(c):
			return def
	last_error = "Non sono riuscito a generare una pista valida: riprova."
	return {}

func _try(diff: int, length: int) -> Array:
	var n_mid: int = [6, 8, 11][length]          # tessere fra partenza e arrivo
	if diff == 0 and length == 2:
		n_mid = 10
	var max_corner: int = [3, 3, 4][diff]
	var max_u: int = [1, 1, 2][diff]
	var min_gap: int = [2, 1, 0][diff]           # rettilinei minimi fra due svolte
	if diff == 0 and length == 2:
		min_gap = 1
	var p_special: float = [0.12, 0.3, 0.5][diff]
	var kinds_ok: Array = [["saplings"], ["saplings", "snowdrift"], ["saplings", "snowdrift", "chasm", "leap"]][diff]
	var plain := PLAIN.duplicate()
	plain.shuffle()
	var specials := {}
	for k in SPECIAL:
		specials[k] = (SPECIAL[k] as Array).duplicate()
	var straights_left := 7          # l'ottavo rettilineo è quello di fuga dopo l'arrivo
	var corners := 0
	var us := 0
	var seq := []
	var gap := 0
	var first_turn := ""
	# posa incrementale con controllo di sovrapposizione
	var placed := []        # per ogni tessera: array di posizioni delle caselle
	var mid := Vector2.ZERO
	var dir := Vector2(0, -1)
	var start_id := "start_p21"
	var st := _place(start_id, -1, mid, dir)
	placed.append(st["cells"])
	mid = st["mid"]
	dir = st["dir"]
	var leading: int = 1 + rng.randi_range(0, 1)
	var i := 0
	while i < n_mid:
		var options := []
		var turn_ok: bool = gap >= min_gap and i >= leading and i < n_mid - 1
		if turn_ok and corners < max_corner:
			options.append(["C", 3.0 + diff])
		if turn_ok and us < max_u and i < n_mid - 2:
			options.append(["U", 1.5 + diff * 0.7])
		if straights_left > 0:
			options.append(["S", 3.0 - diff * 0.6])
		if options.is_empty():
			return []
		var pick := _weighted(options)
		var cands := []
		if pick == "S":
			var use_special: bool = rng.randf() < p_special and i >= leading
			if use_special:
				var ks: Array = kinds_ok.duplicate()
				ks.shuffle()
				for k in ks:
					if (specials[k] as Array).size() > 0:
						cands.append(specials[k][0])
						break
			if cands.is_empty() and plain.size() > 0:
				cands.append(plain[0])
		else:
			var sides := ["L", "R"]
			sides.shuffle()
			for sd in sides:
				if pick == "C":
					cands.append("corner_L_p07" if sd == "L" else "corner_R_p08")
				else:
					cands.append("uturn_L_p01" if sd == "L" else "uturn_R_p02")
		var ok := false
		for fid in cands:
			var pl := _place(fid, placed.size(), mid, dir)
			if pl.is_empty() or _collides(pl["cells"], placed):
				continue
			seq.append(fid)
			placed.append(pl["cells"])
			mid = pl["mid"]
			dir = pl["dir"]
			ok = true
			var f := _face(fid)
			var t := String(f.get("type", ""))
			if t == "straight":
				straights_left -= 1
				gap += 1
				if plain.has(fid): plain.erase(fid)
				for k in specials:
					(specials[k] as Array).erase(fid)
			else:
				gap = 0
				if t == "corner": corners += 1
				else: us += 1
				if first_turn == "":
					first_turn = String(f.get("turn", "L"))
			break
		if not ok:
			return []
		i += 1
	# almeno una svolta
	if corners + us == 0:
		return []
	# arrivo e rettilineo di fuga
	for fid in ["finish_p21", plain[0] if plain.size() > 0 else "straight_p16a"]:
		var pl := _place(fid, placed.size(), mid, dir)
		if pl.is_empty() or _collides(pl["cells"], placed):
			return []
		seq.append(fid)
		placed.append(pl["cells"])
		mid = pl["mid"]
		dir = pl["dir"]
	start_id = "start_p22" if first_turn == "R" else "start_p21"
	return [start_id] + seq

func _weighted(options: Array) -> String:
	var tot := 0.0
	for o in options: tot += o[1]
	var r := rng.randf() * tot
	for o in options:
		r -= o[1]
		if r <= 0: return o[0]
	return options[options.size() - 1][0]

## Posa una faccia dopo la precedente (stessa matematica di Course.build).
func _place(fid: String, index: int, prev_mid: Vector2, prev_dir: Vector2) -> Dictionary:
	var f := _face(fid)
	if f.is_empty() or not FaceDB.is_mapped(f):
		return {}
	var e_mid := FaceDB.v2(f["entry"]["mid"])
	var e_dir := FaceDB.v2(f["entry"]["dir"]).normalized()
	var x_mid := FaceDB.v2(f["exit"]["mid"])
	var x_dir := FaceDB.v2(f["exit"]["dir"]).normalized()
	var xf: Transform2D
	if index < 0:
		xf = Transform2D(Vector2(0, -1).angle() - x_dir.angle(), Vector2.ZERO)
		xf.origin = -xf.basis_xform(x_mid)
	else:
		xf = Transform2D(prev_dir.angle() - e_dir.angle(), Vector2.ZERO)
		xf.origin = prev_mid - xf.basis_xform(e_mid)
	var pts := []
	for p in f["cells"]:
		pts.append(xf * FaceDB.v2(p))
	return {"cells": pts, "mid": xf * x_mid, "dir": xf.basis_xform(x_dir).normalized(), "xf": xf, "face": f}

## Sovrapposizione: caselle troppo vicine a quelle di tessere non adiacenti.
func _collides(cells: Array, placed: Array) -> bool:
	var lim := 53.8 * 3.2
	for j in range(0, placed.size() - 1):
		for a in placed[j]:
			for b in cells:
				if (a as Vector2).distance_squared_to(b) < lim * lim:
					return true
	return false

func _finish_reachable(c: Course) -> bool:
	var seen := {}
	var q: Array = c.start_cells.duplicate()
	for s in q: seen[s] = true
	while not q.is_empty():
		var id: int = q.pop_back()
		if int(c.cells[id]["piece"]) >= c.finish_piece:
			return true
		for t in c.cells[id]["fwd"] + c.cells[id]["dl"] + c.cells[id]["dr"]:
			if not seen.has(t):
				seen[t] = true
				q.append(t)
	return false

func _summary(seq: Array) -> String:
	var n := {"corner": 0, "uturn": 0, "straight": 0, "saplings": 0, "snowdrift": 0, "chasm": 0, "leap": 0}
	for fid in seq:
		var f := _face(fid)
		var t := String(f.get("type", ""))
		if n.has(t): n[t] += 1
		var sp := String(f.get("special", ""))
		if n.has(sp): n[sp] += 1
	var pl := func(k: int, one: String, many: String) -> String: return "%d %s" % [k, one if k == 1 else many]
	var parts := [pl.call(n["corner"], "curva", "curve"), pl.call(n["uturn"], "inversione", "inversioni"), pl.call(n["straight"], "rettilineo", "rettilinei")]
	for k in [["saplings", "con alberelli"], ["snowdrift", "con cumulo"], ["chasm", "con crepaccio"], ["leap", "Leap of Death"]]:
		if n[k[0]] > 0:
			parts.append("%d %s" % [n[k[0]], k[1]] if k[0] != "leap" else k[1])
	return "Pista generata: " + ", ".join(parts) + "."
