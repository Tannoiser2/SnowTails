class_name SledGame
extends RefCounted
## Regole di gioco: mazzi, slitte, movimento, ammaccature, ordine, CPU.

const NAMES := ["Rosso", "Blu", "Giallo", "Verde", "Nero"]
const COLORS := [Color("cf3a30"), Color("2a9ac0"), Color("e0b020"), Color("5a9e2f"), Color("3b4048")]
const SLOTN := {"L": "cane sx", "R": "cane dx", "B": "freno"}

class Player:
	var id := 0
	var name := ""
	var color := Color.WHITE
	var ai := false
	var deck: Array = []
	var hand: Array = []
	var discard: Array = []
	var used: Array = []
	var L := 3
	var R := 3
	var B := 3
	var lc := false
	var rc := false
	var dents := 0
	var cell := -1
	var wrecked := false
	var moves := 0
	var slot := -1
	var stalls := 0
	var finish_round := 0      # giro in cui ha tagliato il traguardo (0 = non ancora)

var course: Course
var players: Array = []
var round_n := 1
var order: Array = []
var oi := 0
var log_text := ""
var over := false
var results: Array = []
var saplings := {}          # alberelli ancora in pista
# registrazione per il replay: history[giro-1] = [{pid, path: [partenza, ...], dents, wrecked, sap}]
var history: Array = []
var start_record := {}
var initial_saplings := {}
var last_fx := {}           # effetti dell'ultima mossa, per il replay

func setup(c: Course, ai_flags: Array) -> void:
	course = c
	players.clear()
	for i in ai_flags.size():
		var p := Player.new()
		p.id = i
		p.name = NAMES[i]
		p.color = COLORS[i]
		p.ai = bool(ai_flags[i])
		p.deck = make_deck()
		players.append(p)
	round_n = 1
	over = false
	results = []
	order = []
	saplings = {}
	for id in c.saplings:
		saplings[id] = true
	initial_saplings = saplings.duplicate()
	history = []
	start_record = {}
	oi = 0

func make_deck() -> Array:
	var d := []
	for v in range(1, 6):
		for k in 4:
			d.append(v)
	d.shuffle()
	return d

func cell(id: int) -> Dictionary:
	return course.cells[id]

func hand_size(p: Player) -> int:
	return p.hand.size() + p.dents

# ---------- partenza ----------
func free_slots() -> Array:
	var out := []
	for k in 5:
		var taken := false
		for p in players:
			if p.slot == k:
				taken = true
		if not taken:
			out.append(k)
	return out

func take_slot(p: Player, k: int) -> void:
	p.slot = k
	p.cell = course.start_cells[k]

func deal_all() -> void:
	for p in players:
		start_record[p.id] = p.cell
	for p in players:
		var n := 5
		if p.slot == 3: n = 6
		if p.slot == 4: n = 7
		for k in n:
			p.hand.append(p.deck.pop_back())
		p.hand.sort()

# ---------- ordine di gara ----------
func prog_key(p: Player) -> float:
	var c := cell(p.cell)
	var nc := course.next_corner(c["piece"])
	var side: float = clamp(float(c["lat"]) / course.lane_w, -2.5, 2.5)
	var tb := 2.5 - side          # verso sinistra = interno
	if not nc.is_empty() and nc["turn"] == "R":
		tb = 2.5 + side
	return floor(float(c["s"]) / (course.cell_len * 0.3)) * 10.0 + tb

func race_order() -> Array:
	var arr := []
	for p in players:
		if not p.wrecked and p.cell >= 0:
			arr.append(p)
	arr.sort_custom(func(a, b): return prog_key(a) > prog_key(b))
	return arr

func rank_of(p: Player) -> int:
	return race_order().find(p) + 1

func is_finished(p: Player) -> bool:
	return not p.wrecked and p.cell >= 0 and int(cell(p.cell)["piece"]) >= course.finish_piece

# ---------- carte ----------
func add_dent(p: Player, n: int) -> void:
	for i in n:
		if p.dents >= 4:
			if is_finished(p):
				continue
			p.wrecked = true
			p.cell = -1
			return
		p.dents += 1

func draw_up(p: Player) -> void:
	while hand_size(p) < 5:
		if p.deck.is_empty():
			p.deck = p.discard + p.used
			p.discard = []
			p.used = []
			p.deck.shuffle()
			if p.deck.is_empty():
				break
		p.hand.append(p.deck.pop_back())
	p.hand.sort()

func mat_after(p: Player, pend: Array) -> Dictionary:
	var m := {"L": p.L, "R": p.R, "B": p.B}
	for x in pend:
		m[x["slot"]] = x["v"]
	return m

func commit_play(p: Player, pend: Array) -> void:
	for x in pend:
		var v: int = x["v"]
		p.hand.erase(v)
		match String(x["slot"]):
			"L":
				if p.lc: p.used.append(p.L)
				p.L = v
				p.lc = true
			"R":
				if p.rc: p.used.append(p.R)
				p.R = v
				p.rc = true
			_:
				p.discard.append(v)
				p.B = v

# ---------- movimento ----------
## Tutti gli esiti possibili del movimento: ogni passo è "avanti" (oltre una linea blu)
## o "deriva" (avanti in diagonale oltre una linea nera); dove la rete offre più
## caselle si esplorano tutte. Gli esiti sono raggruppati per casella d'arrivo.
func compute_outs(p: Player, m: Dictionary, all_paths := false) -> Array:
	var speed: int = m["L"] + m["R"] - m["B"]
	var drift: int = m["R"] - m["L"]
	if speed <= 0:
		return [{"path": [], "end": p.cell, "dents": 0, "corner_dents": 0, "crash": "", "bonus": false, "bonus_n": 0, "speed": 0, "sap": []}]
	var dir := signi(drift)
	var k: int = min(abs(drift), speed)
	var occ := {}
	for q in players:
		# le slitte già arrivate restano parcheggiate oltre la linea ma non ostacolano chi arriva dopo
		if q != p and not q.wrecked and q.cell >= 0 and q.finish_round == 0:
			occ[q.cell] = true
	var res := []
	_dfs(p.cell, speed, k, dir, speed, occ, [], 0, res, 0, [])
	for r in res:
		r["from"] = p.cell
	if drift == 0 and p.moves > 0:
		var b := rank_of(p)
		_dfs(p.cell, speed + b, 0, 0, speed + b, occ, [], 0, res, b, [])
		for r in res:
			r["from"] = p.cell
	if all_paths:
		return res
	var best := {}
	for r in res:
		var sc: float = r["dents"] * 10.0 + (3.0 if r["crash"] == "sled" else 0.0) + (0.5 if r["bonus"] else 0.0)
		r["_sc"] = sc
		if not best.has(r["end"]) or sc < best[r["end"]]["_sc"]:
			best[r["end"]] = r
	return best.values()

func _out(path: Array, end: int, crash: String, cd: int, total: int, bonus_n: int, sap: Array) -> Dictionary:
	return {"path": path, "end": end, "crash": crash, "corner_dents": cd, "sap": sap,
		"dents": cd + sap.size() + (1 if crash == "edge" else 0), "bonus": bonus_n > 0, "bonus_n": bonus_n, "speed": total}

func _dfs(cur: int, steps: int, drifts: int, dir: int, total: int, occ: Dictionary, path: Array, cd: int, res: Array, bonus_n: int, sap: Array) -> void:
	if res.size() > 20000:
		return
	if steps == 0:
		res.append(_out(path, cur, "", cd, total, bonus_n, sap))
		return
	var c := cell(cur)
	var kinds := []
	if drifts < steps:
		kinds.append("f")
	if drifts > 0:
		kinds.append("d")
	for kind in kinds:
		var targets: Array = c["fwd"] if kind == "f" else (c["dr"] if dir > 0 else c["dl"])
		var nd: int = drifts - (1 if kind == "d" else 0)
		if targets.is_empty():
			var crash := "end" if (kind == "f" and course.is_last_piece(c["piece"])) else "edge"
			var r := _out(path, cur, crash, cd, total, bonus_n, sap)
			var hv := course.heading(cur)
			if kind == "d":
				hv = (hv + Vector2(-hv.y, hv.x) * float(dir)).normalized()
			r["hit_dir"] = hv
			res.append(r)
			continue
		for t in targets:
			if occ.has(t):
				var r2 := _out(path, cur, "sled", cd, total, bonus_n, sap)
				r2["hit_dir"] = (cell(t)["pos"] - c["pos"]).normalized()
				r2["hit_cell"] = t
				res.append(r2)
				continue
			var cd2: int = cd + course.limit_dents(c["piece"], cell(t)["piece"], total) + course.leap_dents(cur, t, total)
			var p2 := path.duplicate()
			p2.append(t)
			var s2 := sap
			if saplings.has(t):
				s2 = sap.duplicate()
				s2.append(t)
			_dfs(t, steps - 1, nd, dir, total, occ, p2, cd2, res, bonus_n, s2)

func describe(pend: Array, o: Dictionary, m: Dictionary) -> String:
	var v: int = pend[0]["v"]
	var where := []
	for x in pend:
		where.append(SLOTN[x["slot"]])
	var s := ""
	if pend.size() > 1:
		s = "%d carte da %d su %s" % [pend.size(), v, " e ".join(where)]
	else:
		s = "una carta da %d su %s" % [v, where[0]]
	s += ", velocità %d" % o["speed"]
	if o["bonus"]:
		s += " (bonus +%d)" % o["bonus_n"]
	var d: int = m["R"] - m["L"]
	if d != 0:
		s += ", deriva %d a %s" % [abs(d), "destra" if d > 0 else "sinistra"]
	return s

## Dopo il movimento. Restituisce true se un umano deve scartare carte.
func after_move(p: Player, o: Dictionary) -> bool:
	p.moves += 1
	p.stalls = p.stalls + 1 if (o["path"] as Array).is_empty() else 0
	var msgs := []
	var corner_only: int = int(o["corner_dents"]) - _leap_part(o)
	if corner_only > 0:
		msgs.append("curva presa troppo forte (+%d)" % corner_only)
	if _leap_part(o) > 0:
		msgs.append("salto troppo lento (+%d)" % _leap_part(o))
	var in_crev: bool = course.crevasse.has(int(o["end"]))
	if in_crev:
		msgs.append("si ferma nella spaccatura e non pesca")
	var sap: Array = o.get("sap", [])
	if sap.size() > 0:
		msgs.append("travolge %s (+%d)" % ["un alberello" if sap.size() == 1 else "%d alberelli" % sap.size(), sap.size()])
		for t in sap:
			saplings.erase(t)
	if o["crash"] == "edge":
		msgs.append("urta il bordo (+1)")
	if o["crash"] == "sled":
		msgs.append("tampona e non pesca")
	if o["dents"] > 0:
		add_dent(p, o["dents"])
	if p.wrecked:
		msgs.append("la slitta va in pezzi!")
	elif is_finished(p) and p.finish_round == 0:
		p.finish_round = round_n
		var n := 0
		for q in players:
			if q.finish_round > 0: n += 1
		msgs.append("taglia il traguardo! (%d° ad arrivare)" % n)
	if not msgs.is_empty():
		log_text += " — " + "; ".join(msgs)
	if p.wrecked:
		return false
	if o["crash"] != "sled" and not in_crev:
		draw_up(p)
	if hand_size(p) > 5 and not p.hand.is_empty():
		if p.ai:
			ai_discard(p)
		else:
			return true
	return false

## Parte delle ammaccature dovuta al salto (calcolata lungo il percorso dell'esito).
func _leap_part(o: Dictionary) -> int:
	var d := 0
	var prev: int = o.get("from", -1)
	for t in o["path"]:
		if prev >= 0:
			d += course.leap_dents(prev, t, int(o["speed"]))
		prev = t
	return d

## Registra la mossa appena fatta (chiamata dopo after_move).
func record(p: Player, start_cell: int, path: Array, sap: Array) -> void:
	while history.size() < round_n:
		history.append([])
	var full := [start_cell]
	full.append_array(path)
	history[round_n - 1].append({"pid": p.id, "path": full, "dents": p.dents, "wrecked": p.wrecked,
		"end": p.cell, "sap": sap.duplicate(), "fx": last_fx.duplicate()})
	last_fx = {}

## Una slitta ancora in corsa: non distrutta e non ancora oltre il traguardo.
func racing(p: Player) -> bool:
	return not p.wrecked and p.finish_round == 0

## La gara finisce quando tutte le slitte rimaste hanno tagliato il traguardo.
func check_round_end() -> bool:
	var left := 0
	for p in players:
		if racing(p):
			left += 1
	if left == 0 or round_n >= 100:
		_game_over()
		return true
	round_n += 1
	return false

func _game_over() -> void:
	over = true
	var fin := []
	var notf := []
	var wr := []
	for p in players:
		if p.wrecked: wr.append(p)
		elif is_finished(p): fin.append(p)
		else: notf.append(p)
	var by_key := func(a, b): return prog_key(a) > prog_key(b)
	# prima chi ha tagliato il traguardo in un giro precedente, poi chi è più lontano oltre la linea
	fin.sort_custom(func(a, b):
		if a.finish_round != b.finish_round:
			return a.finish_round < b.finish_round
		return prog_key(a) > prog_key(b))
	notf.sort_custom(by_key)
	results = []
	for p in fin:
		var past := int(floor((float(cell(p.cell)["s"]) - course.finish_s) / course.cell_len)) + 1
		results.append({"p": p, "st": "arrivata al giro %d, %d oltre il traguardo" % [p.finish_round, max(past, 0)]})
	for p in notf:
		results.append({"p": p, "st": "ancora in gara"})
	for p in wr:
		results.append({"p": p, "st": "distrutta"})

# ---------- CPU ----------
func ai_choose(p: Player) -> Dictionary:
	var counts := {}
	for v in p.hand:
		counts[v] = counts.get(v, 0) + 1
	var subs := [["L"], ["R"], ["B"], ["L", "R"], ["L", "B"], ["R", "B"], ["L", "R", "B"]]
	var best := {}
	for v in counts.keys():
		for sub in subs:
			if sub.size() > counts[v]:
				continue
			var pend := []
			for s in sub:
				pend.append({"v": v, "slot": s})
			var m := mat_after(p, pend)
			for o in compute_outs(p, m):
				var sc := ai_score(p, m, o, pend.size())
				if best.is_empty() or sc > best["sc"]:
					best = {"sc": sc, "pend": pend, "o": o}
	return best

func ai_score(p: Player, m: Dictionary, o: Dictionary, n_cards: int) -> float:
	var st := cell(p.cell)
	var en := cell(o["end"])
	var cl := course.cell_len
	# avanzamento misurato in passi che mancano al traguardo: tiene conto
	# dei vicoli ciechi (crepacci, cumuli, strisce esterne delle curve)
	var s: float = float(int(st["togo"]) - int(en["togo"])) * 10.0
	var fin: bool = int(en["piece"]) >= course.finish_piece
	if fin:
		# oltre il traguardo conta andare il più lontano possibile (spareggio nello stesso giro)
		s += 300.0 + (float(en["s"]) - course.finish_s) / cl * 25.0
	if p.dents + int(o["dents"]) >= 5 and not fin:
		return -500.0 + s
	s -= float(o["dents"]) * (22.0 + p.dents * 14.0)
	if o["crash"] == "sled" or course.crevasse.has(int(o["end"])):
		s -= 14.0
	var S2: int = m["L"] + m["R"] - m["B"]
	var d2: int = m["R"] - m["L"]
	if S2 <= 1:
		s -= 10.0
	var nl := course.next_limit(float(en["s"]))
	if not nl.is_empty():
		var dist: float = (float(nl["s"]) - float(en["s"])) / cl
		if S2 > int(nl["lim"]) and dist <= S2 + 2:
			s -= (S2 - int(nl["lim"])) * (14.0 if dist <= S2 else 6.0)
	var lp := course.next_leap(float(en["s"]))
	if not lp.is_empty():
		var dl: float = (float(lp["s"]) - float(en["s"])) / cl
		if dl <= S2 + 1 and S2 < int(lp["min"]):
			s -= (int(lp["min"]) - S2) * 10.0
	if not fin:
		var steps: int = max(S2, 0)
		var k: int = min(abs(d2), steps)
		var cc: int = o["end"]
		for i in k:
			var opts: Array = cell(cc)["dr"] if d2 > 0 else cell(cc)["dl"]
			if opts.is_empty():
				s -= 18.0
				break
			cc = opts[0]
		var nc := course.next_corner(en["piece"])
		if not nc.is_empty():
			var side: float = clamp(float(en["lat"]) / course.lane_w, -2.5, 2.5)
			s += side * (1.5 if nc["turn"] == "R" else -1.5)
	if (o["path"] as Array).is_empty():
		s -= 12.0 + 60.0 * p.stalls
	if not fin:
		# vicolo cieco vicino: al prossimo turno servirà derivare
		var run: int = int(en.get("run", 99))
		if run < max(S2, 1):
			s -= 6.0 * (max(S2, 1) - run)
	s -= abs(d2) * 1.5 + n_cards * 0.5
	return s + randf() * 3.0

func ai_discard(p: Player) -> void:
	while hand_size(p) > 5 and not p.hand.is_empty():
		var counts := {}
		for v in p.hand:
			counts[v] = counts.get(v, 0) + 1
		var bestv: int = p.hand[0]
		for v in counts.keys():
			if counts[v] > counts[bestv] or (counts[v] == counts[bestv] and v > bestv):
				bestv = v
		p.hand.erase(bestv)
		p.discard.append(bestv)
