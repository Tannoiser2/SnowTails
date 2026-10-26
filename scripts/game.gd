class_name SledGame
extends RefCounted
## Regole di gioco: mazzi, slitte, movimento, ammaccature, ordine, CPU.

const NAMES := ["Rosso", "Blu", "Giallo", "Verde", "Nero"]
const COLORS := [Color("cf3a30"), Color("2a9ac0"), Color("e0b020"), Color("5a9e2f"), Color("3b4048")]
const SLOTN := {"L": "cane sx", "R": "cane dx", "B": "freno"}

class Player:
	var id := 0
	var seat := 0          # colore/posto scelto nel menu (indice in NAMES e COLORS)
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
	var half := false          # mezza ammaccatura (variante simultanea): due mezze fanno una intera
	var cell := -1
	var wrecked := false
	var moves := 0
	var slot := -1
	var stalls := 0
	var finish_round := 0      # giro in cui ha tagliato il traguardo (0 = non ancora)
	var smart := true          # CPU che guarda avanti le caratteristiche fanmade (false = la vecchia, per i confronti)

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
## Neve fresca ancora intatta: la prima slitta che ci passa la spazza via (come gli alberelli)
var fresh := {}
var initial_fresh := {}
var last_fx := {}
var last_snow := []         # neve fresca spazzata dall'ultima mossa, per il replay           # effetti dell'ultima mossa, per il replay
## Generatore casuale della partita: tutti i mescolamenti passano da qui. Online ogni dispositivo
## parte dallo stesso seme, quindi i mazzi restano identici ovunque senza doverli trasmettere.
var rng := RandomNumberGenerator.new()
## Variante: tutti programmano la mossa, poi le slitte si muovono insieme.
## Le rotte si calcolano senza tener conto delle altre slitte; i conflitti si risolvono dopo.
var simultaneous := false

## Mescola un elenco con il generatore della partita (al posto di Array.shuffle, che usa quello globale).
func shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

## seed_value 0 = partita qualunque; online tutti usano il seme scelto da chi ha creato la stanza.
func setup(c: Course, ai_flags: Array, seed_value := 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	course = c
	players.clear()
	# ai_flags: un valore per colore; -1 (o null) = colore non in gara
	for i in ai_flags.size():
		var f = ai_flags[i]
		if f == null or (typeof(f) != TYPE_BOOL and int(f) < 0):
			continue
		var p := Player.new()
		p.id = players.size()
		p.seat = i
		p.name = NAMES[i]
		p.color = COLORS[i]
		p.ai = bool(f)
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
	fresh = c.fresh.duplicate()
	initial_fresh = fresh.duplicate()
	history = []
	start_record = {}
	oi = 0

func make_deck() -> Array:
	var d := []
	for v in range(1, 6):
		for k in 4:
			d.append(v)
	shuffle(d)
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

## Mezza ammaccatura: la seconda mezza diventa un'ammaccatura intera.
func add_half_dent(p: Player) -> void:
	if p.half:
		p.half = false
		add_dent(p, 1)
	else:
		p.half = true

func draw_up(p: Player) -> void:
	while hand_size(p) < 5:
		if p.deck.is_empty():
			p.deck = p.discard + p.used
			p.discard = []
			p.used = []
			shuffle(p.deck)
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
## Segmenti fanmade: chi parte in salita perde UP_LOSS punti di velocità (come un freno in più);
## chi parte in discesa guadagna 1 punto ogni DOWN_PER (3 → 4, 6 → 8, 9 → 12); la neve fresca
## costa 2 punti per casella; sul ghiaccio chi
## entra derivando continua a derivare e a fine movimento scivola avanti di una casella;
## il vento sposta di una corsia ogni 2 caselle percorse; la baita ripara un'ammaccatura.
const UP_LOSS := 3
const DOWN_PER := 3

## Velocità con la plancia m partendo dalla casella cell: cani − freno, poi la pendenza.
func effective_speed(cell_id: int, m: Dictionary) -> int:
	var speed: int = m["L"] + m["R"] - m["B"]
	match course.slope_of(cell_id) if cell_id >= 0 else "":
		"up":
			speed -= UP_LOSS
		"down":
			if speed > 0:
				speed += speed / DOWN_PER
	if cell_id >= 0:
		speed += course.wind_speed_of(cell_id)
	return max(speed, 0)

## Deriva con la plancia m partendo dalla casella cell: cane destro − cane sinistro, più il vento
## della tessera (WIND_PUSH corsie nel suo verso). Positiva = a destra.
const WIND_PUSH := 1
func effective_drift(cell_id: int, m: Dictionary) -> int:
	var d: int = m["R"] - m["L"]
	if cell_id >= 0:
		d += course.wind_of(cell_id) * WIND_PUSH
	return d

func compute_outs(p: Player, m: Dictionary, all_paths := false) -> Array:
	var base: int = max(m["L"] + m["R"] - m["B"], 0)
	var speed: int = effective_speed(p.cell, m)
	var drift: int = effective_drift(p.cell, m)
	var wind_d: int = drift - (m["R"] - m["L"])
	var slope_delta: int = speed - base
	if speed <= 0:
		return [{"path": [], "end": p.cell, "dents": 0, "corner_dents": 0, "crash": "", "bonus": false, "bonus_n": 0, "speed": 0, "sap": []}]
	var dir := signi(drift)
	var k: int = min(abs(drift), speed)
	var occ := {}
	for q in ([] if simultaneous else players):
		# le slitte già arrivate restano parcheggiate oltre la linea ma non ostacolano chi arriva dopo
		if q != p and not q.wrecked and q.cell >= 0 and q.finish_round == 0:
			occ[q.cell] = true
	var res := []
	var up0: bool = course.slope_of(p.cell) == "up"
	_dfs(p.cell, speed, k, dir, speed, occ, [], 0, res, 0, [], up0, "")
	if drift == 0 and m["L"] == m["R"] and p.moves > 0:
		var b := rank_of(p)
		_dfs(p.cell, speed + b, 0, 0, speed + b, occ, [], 0, res, b, [], up0, "")
	for r in res:
		r["from"] = p.cell
		_post_move(r, occ)
		if slope_delta != 0:
			r["slope"] = slope_delta
		if wind_d != 0:
			r["wind"] = wind_d
		if course.wind_speed_of(p.cell) != 0:
			r["wind_speed"] = course.wind_speed_of(p.cell)
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

func _dfs(cur: int, steps: int, drifts: int, dir: int, total: int, occ: Dictionary, path: Array, cd: int, res: Array, bonus_n: int, sap: Array, up := false, last := "") -> void:
	if res.size() > 20000:
		return
	if steps == 0:
		res.append(_out(path, cur, "", cd, total, bonus_n, sap))
		return
	var c := cell(cur)
	var kinds := []
	if course.has_mod(cur, "ice") and last == "d" and drifts > 0:
		# sul ghiaccio la deriva non si ferma: chi ci entra derivando continua a derivare
		kinds = ["d"]
	else:
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
			var cost := 2 if fresh.has(t) else 1
			var up2: bool = up or course.slope_of(t) == "up"
			if cost > steps:
				# non ci entra: neve fresca troppo profonda per i punti rimasti
				var r3 := _out(path, cur, "", cd, total, bonus_n, sap)
				r3["stopped"] = "fresh"
				res.append(r3)
				continue
			var cd2: int = cd + course.limit_dents(c["piece"], cell(t)["piece"], total) + course.leap_dents(cur, t, total)
			var p2 := path.duplicate()
			p2.append(t)
			var s2 := sap
			if saplings.has(t):
				s2 = sap.duplicate()
				s2.append(t)
			_dfs(t, steps - cost, nd if cost == 1 else min(nd, steps - cost), dir, total, occ, p2, cd2, res, bonus_n, s2, up2, kind)

## Variante simultanea: dalle mosse programmate (pid -> {pend, o}) ricava gli esiti reali.
## Le slitte si muovono insieme per tutta la durata del giro: chi ha n caselle da fare entra
## nella casella k al tempo k/n. Due slitte non possono stare nella stessa casella nello stesso
## momento. Si decide in quest'ordine: prima chi resta ferma (non può spostarsi), poi chi va più
## veloce, a parità chi era più avanti a inizio giro. Ognuna, se può, sceglie fra le rotte
## equivalenti (stessa casella d'arrivo, stessa velocità, non più ammaccature) una che non tocca
## nessuno; se non c'è, si ferma prima del contatto e prende mezza ammaccatura.
## Gli alberelli li travolge chi ci passa per primo.
func resolve_simultaneous(progs: Dictionary) -> Array:
	var list := []
	for p in race_order():
		if racing(p) and progs.has(p.id):
			list.append(p)
	var rank := {}
	for i in list.size():
		rank[list[i].id] = i
	var cands := {}
	for p in list:
		var o0: Dictionary = progs[p.id]["o"]
		var lst := [o0]
		if not (o0["path"] as Array).is_empty():
			var m := mat_after(p, progs[p.id]["pend"])
			for o in compute_outs(p, m, true):
				if lst.size() >= 60:
					break
				if int(o["end"]) == int(o0["end"]) and int(o["speed"]) == int(o0["speed"]) and o["bonus"] == o0["bonus"] \
						and int(o["dents"]) <= int(o0["dents"]) and str(o["path"]) != str(o0["path"]) and String(o["crash"]) == String(o0["crash"]):
					lst.append(o)
		cands[p.id] = lst
	var prio := list.duplicate()
	prio.sort_custom(func(a, b):
		var sa: int = 1000 if (progs[a.id]["o"]["path"] as Array).is_empty() else int(progs[a.id]["o"]["speed"])
		var sb: int = 1000 if (progs[b.id]["o"]["path"] as Array).is_empty() else int(progs[b.id]["o"]["speed"])
		if sa != sb:
			return sa > sb
		return rank[a.id] < rank[b.id])
	var fixed := []          # [{cell, a, b, pid}]
	var done := {}
	for p in prio:
		var lst: Array = cands[p.id]
		var o0: Dictionary = lst[0]
		var n: int = max((o0["path"] as Array).size(), 1)
		var best = null
		var best_sc := INF
		for i in lst.size():
			var o: Dictionary = lst[i]
			var tl := _timeline(p.id, [p.cell] + o["path"], n, (o["path"] as Array).size())
			if _clash(tl, fixed) >= 0:
				continue
			# a parità, meglio non intralciare le rotte di chi deve ancora decidere
			var sc := 0.0 if i == 0 else 0.25
			for q in prio:
				if q != p and not done.has(q.id):
					var qo: Dictionary = progs[q.id]["o"]
					var qn: int = max((qo["path"] as Array).size(), 1)
					if _clash(_timeline(q.id, [q.cell] + qo["path"], qn, (qo["path"] as Array).size()), tl) >= 0:
						sc += 1.0
			if sc < best_sc:
				best_sc = sc
				best = o
		var o_use: Dictionary
		var half := false
		var yield_pid := -1
		var hit := -1
		if best != null:
			o_use = (best as Dictionary).duplicate(true)
		else:
			o_use = o0.duplicate(true)
			var full: Array = [p.cell] + o_use["path"]
			var k: int = full.size() - 1
			while k > 0:
				var c := _clash(_timeline(p.id, full, n, k), fixed)
				if c < 0:
					break
				if k == full.size() - 1 or yield_pid < 0:
					yield_pid = int(fixed[c]["pid"])
				k -= 1
			hit = full[k + 1] if k + 1 < full.size() else -1
			o_use["path"] = full.slice(1, k + 1)
			half = true
		var path: Array = o_use["path"]
		var total := int(o_use["speed"])
		var cd := 0
		var prev: int = p.cell
		for t in path:
			cd += course.limit_dents(cell(prev)["piece"], cell(t)["piece"], total) + course.leap_dents(prev, t, total)
			prev = t
		o_use["end"] = p.cell if path.is_empty() else path[path.size() - 1]
		o_use["from"] = p.cell
		o_use["corner_dents"] = cd
		o_use["half"] = half
		o_use["n"] = n
		if half:
			o_use["crash"] = "bump"
			if hit >= 0:
				o_use["hit_cell"] = hit
				o_use["hit_dir"] = (cell(hit)["pos"] - cell(o_use["end"])["pos"]).normalized()
			if yield_pid >= 0:
				o_use["yield_to"] = players[yield_pid].name
		fixed.append_array(_timeline(p.id, [p.cell] + path, n, path.size()))
		done[p.id] = {"p": p, "pend": progs[p.id]["pend"], "o": o_use, "start": p.cell, "n": n}
	# alberelli: li prende chi ci arriva per primo
	var first := {}
	for pid in done:
		var x: Dictionary = done[pid]
		var pth: Array = x["o"]["path"]
		for k in pth.size():
			var t: int = pth[k]
			if saplings.has(t):
				var tm: float = float(k + 1) / float(x["n"])
				if not first.has(t) or tm < first[t][0] or (tm == first[t][0] and rank[pid] < rank[first[t][1]]):
					first[t] = [tm, pid]
	var plan := []
	for p in list:
		var x: Dictionary = done[p.id]
		var o: Dictionary = x["o"]
		var sap := []
		for t in o["path"]:
			if first.has(t) and int(first[t][1]) == p.id:
				sap.append(t)
		o["sap"] = sap
		o["dents"] = int(o["corner_dents"]) + sap.size() + (1 if String(o["crash"]) == "edge" else 0)
		plan.append(x)
	return plan

## Occupazione nel tempo (giro da 0 a 1): la slitta entra nella casella k di full al tempo k/n
## e la lascia quando entra nella successiva; nell'ultima casella raggiunta (stop) resta per sempre.
## La casella di partenza si libera subito, tranne per chi non si muove.
func _timeline(pid: int, full: Array, n: int, stop: int) -> Array:
	var tl := []
	if stop <= 0:
		tl.append({"cell": full[0], "a": 0.0, "b": INF, "pid": pid})
		return tl
	for k in range(1, stop + 1):
		var a := float(k) / float(n)
		var b: float = INF if k == stop else float(k + 1) / float(n)
		tl.append({"cell": full[k], "a": a, "b": b, "pid": pid})
	return tl

## Indice in other del primo intervallo che si sovrappone a tl (stessa casella, stesso momento), o -1.
func _clash(tl: Array, other: Array) -> int:
	for x in tl:
		for i in other.size():
			var y: Dictionary = other[i]
			if int(y["cell"]) == int(x["cell"]) and max(float(x["a"]), float(y["a"])) < min(float(x["b"]), float(y["b"])) - 0.000001:
				return i
	return -1

## Dopo il movimento scelto: scivolata sul ghiaccio e spinta del vento.
func _post_move(r: Dictionary, occ: Dictionary) -> void:
	if String(r["crash"]) != "":
		return
	var path: Array = (r["path"] as Array).duplicate()
	if path.is_empty():
		return
	var end: int = r["end"]
	var sap: Array = (r["sap"] as Array).duplicate()
	# ghiaccio: a fine movimento si scivola avanti di una casella
	if course.has_mod(end, "ice"):
		var fw: Array = cell(end)["fwd"]
		if not fw.is_empty():
			var h := course.heading(end)
			var t: int = fw[0]
			for f in fw:
				if (cell(f)["pos"] - cell(end)["pos"]).normalized().dot(h) > (cell(t)["pos"] - cell(end)["pos"]).normalized().dot(h):
					t = f
			if occ.has(t):
				r["crash"] = "sled"
				r["hit_cell"] = t
				r["hit_dir"] = (cell(t)["pos"] - cell(end)["pos"]).normalized()
			else:
				path.append(t)
				end = t
				r["ice"] = true
				if saplings.has(t) and not sap.has(t):
					sap.append(t)
	r["path"] = path
	r["end"] = end
	r["sap"] = sap
	r["dents"] = int(r["corner_dents"]) + sap.size() + (1 if String(r["crash"]) == "edge" else 0)

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
	var sd := int(o.get("slope", 0))
	if sd < 0:
		msgs.append("la salita la rallenta (%d)" % sd)
	elif sd > 0:
		msgs.append("in discesa prende velocità (+%d)" % sd)
	match String(o.get("stopped", "")):
		"fresh":
			msgs.append("si pianta nella neve fresca")
	if o.get("ice", false):
		msgs.append("scivola sul ghiaccio")
	if int(o.get("wind", 0)) != 0:
		msgs.append("il vento la spinge %s (%d)" % ["a destra" if int(o["wind"]) > 0 else "a sinistra", abs(int(o["wind"]))])
	if int(o.get("wind_speed", 0)) != 0:
		msgs.append("vento %s (%+d)" % ["a favore" if int(o["wind_speed"]) > 0 else "contrario", int(o["wind_speed"])])
	if in_crev:
		msgs.append("si ferma nella spaccatura e non pesca")
	var swept := []
	for t in o["path"]:
		if fresh.has(t):
			swept.append(t)
			fresh.erase(t)
	if swept.size() > 0:
		msgs.append("spazza via la neve fresca")
	o["snow"] = swept
	last_snow = swept.duplicate()
	var sap: Array = o.get("sap", [])
	if sap.size() > 0:
		msgs.append("travolge %s (+%d)" % ["un alberello" if sap.size() == 1 else "%d alberelli" % sap.size(), sap.size()])
		for t in sap:
			saplings.erase(t)
	if o["crash"] == "edge":
		msgs.append("urta il bordo (+1)")
	if o["crash"] == "sled":
		msgs.append("tampona e non pesca")
	if o.get("half", false):
		msgs.append("frena per non urtare %s (+½)" % String(o.get("yield_to", "un'altra slitta")))
	if o["dents"] > 0:
		add_dent(p, o["dents"])
	if o.get("half", false) and not p.wrecked:
		add_half_dent(p)
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
	# baita: chi ci si ferma ripara metà dei danni (arrotondando a suo favore), ma non pesca
	var repaired := false
	if course.huts.has(int(o["end"])) and String(o["crash"]) == "" and (p.dents > 0 or p.half):
		var units := p.dents * 2 + (1 if p.half else 0)      # in mezze ammaccature
		var left := units / 2
		p.dents = left / 2
		p.half = left % 2 == 1
		repaired = true
		log_text += " — si ripara alla baita (metà dei danni, non pesca)"
	if o["crash"] != "sled" and not in_crev and not repaired:
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
		"end": p.cell, "sap": sap.duplicate(), "snow": last_snow.duplicate(), "fx": last_fx.duplicate()})
	last_snow = []
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
	var cands := _ai_candidates(p)
	if cands.is_empty():
		return {}
	cands.sort_custom(func(a, b): return a["sc"] > b["sc"])
	if not p.smart or not ai_parts.get("ply2", true):
		return cands[0]
	# sguardo al turno dopo: per le mosse migliori si simula anche la mossa seguente con le
	# carte che restano in mano. Così salite, discese, vento e ghiaccio si valutano davvero.
	var best: Dictionary = cands[0]
	var best_sc := -INF
	for i in min(AI_TOP, cands.size()):
		var c: Dictionary = cands[i]
		var sc: float = c["sc"] + AI_PLY2 * _ai_next_turn(p, c)
		if sc > best_sc:
			best_sc = sc
			best = c
	return best

const AI_TOP := 6
const AI_PLY2 := 0.6

func _ai_candidates(p: Player) -> Array:
	var counts := {}
	for v in p.hand:
		counts[v] = counts.get(v, 0) + 1
	var subs := [["L"], ["R"], ["B"], ["L", "R"], ["L", "B"], ["R", "B"], ["L", "R", "B"]]
	var out := []
	for v in counts.keys():
		for sub in subs:
			if sub.size() > counts[v]:
				continue
			var pend := []
			for s in sub:
				pend.append({"v": v, "slot": s})
			var m := mat_after(p, pend)
			for o in compute_outs(p, m):
				out.append({"sc": ai_score(p, m, o, pend.size()), "pend": pend, "o": o, "m": m})
	return out

## Miglior avanzamento del turno dopo, partendo dall'esito c, con le carte rimaste in mano.
func _ai_next_turn(p: Player, c: Dictionary) -> float:
	var o: Dictionary = c["o"]
	if int(cell(o["end"])["piece"]) >= course.finish_piece:
		return 30.0
	var save := {"cell": p.cell, "L": p.L, "R": p.R, "B": p.B, "hand": p.hand.duplicate(), "moves": p.moves, "dents": p.dents}
	p.cell = o["end"]
	p.L = c["m"]["L"]
	p.R = c["m"]["R"]
	p.B = c["m"]["B"]
	for x in c["pend"]:
		p.hand.erase(x["v"])
	p.moves += 1
	p.dents += int(o["dents"])
	var best := -60.0
	var counts := {}
	for v in p.hand:
		counts[v] = counts.get(v, 0) + 1
	var subs := [["L"], ["R"], ["B"], ["L", "R"]]
	var from_togo := int(cell(p.cell)["togo"])
	for v in counts.keys():
		for sub in subs:
			if sub.size() > counts[v]:
				continue
			var pend := []
			for s2 in sub:
				pend.append({"v": v, "slot": s2})
			for o2 in compute_outs(p, mat_after(p, pend)):
				var sc := float(from_togo - int(cell(o2["end"])["togo"])) * 10.0
				sc -= float(o2["dents"]) * (22.0 + p.dents * 14.0)
				if p.dents + int(o2["dents"]) >= 5:
					sc -= 300.0
				if sc > best:
					best = sc
	p.cell = save["cell"]
	p.L = save["L"]
	p.R = save["R"]
	p.B = save["B"]
	p.hand = save["hand"]
	p.moves = save["moves"]
	p.dents = save["dents"]
	return best if best > -60.0 else 0.0

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
	if p.smart and not fin:
		s += _ai_lookahead(p, o, S2, d2)
		# dalla pendenza si riparte più veloci o più lenti: lo sa per le curve e i salti che vengono dopo
		if ai_parts["down"]:
			S2 = effective_speed(int(o["end"]), m)
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
	if course.huts.has(int(o["end"])) and (p.dents > 0 or p.half) and String(o["crash"]) == "":
		# la baita ripara metà dei danni: vale di più con tante ammaccature
		var units := p.dents * 2 + (1 if p.half else 0)
		s += 6.0 + float(units - units / 2) * 6.0 + (10.0 if p.dents >= 3 else 0.0)
	if (o["path"] as Array).is_empty():
		s -= 12.0 + 60.0 * p.stalls
	if not fin:
		# vicolo cieco vicino: al prossimo turno servirà derivare
		var run: int = int(en.get("run", 99))
		if run < max(S2, 1):
			s -= 6.0 * (max(S2, 1) - run)
	s -= abs(d2) * 1.5 + n_cards * 0.5
	return s + randf() * 3.0

## Uno sguardo al turno dopo, sulle caratteristiche fanmade: velocità sprecata in salita,
## vento che spingerà contro il bordo, neve fresca già spazzata da seguire.
static var ai_parts := {"up": false, "wind": true, "fresh": true, "down": true, "ply2": true}
func _ai_lookahead(p: Player, o: Dictionary, S2: int, d2: int) -> float:
	var s := 0.0
	var end: int = o["end"]
	var reach: int = max(S2, 1) + 1
	# salita davanti: con la plancia veloce si sprecheranno punti (e in salita si arriva lenti)
	var id := end
	for k in (reach + 1 if ai_parts["up"] else 0):
		if course.slope_of(id) == "up":
			s -= float(min(S2, UP_LOSS)) * 1.5
			break
		var fw: Array = cell(id)["fwd"]
		if fw.is_empty():
			break
		id = fw[0]
	# vento: al prossimo turno sposterà di S2/2 corsie; conviene avere spazio da quel lato
	var w := course.wind_of(end)
	if w != 0 and S2 > 1 and ai_parts["wind"]:
		var pushes: int = WIND_PUSH
		var room := 0
		var cc := end
		for i in pushes:
			var t: int = cell(cc).get("side_r" if w > 0 else "side_l", -1)
			if t < 0:
				break
			room += 1
			cc = t
		if room < pushes:
			s -= float(pushes - room) * 9.0
		# derivare contro vento lo compensa
		if d2 != 0 and signi(d2) == -w:
			s += 3.0
	# neve fresca intatta proprio davanti: meglio una corsia già spazzata
	var fw2: Array = cell(end)["fwd"]
	if ai_parts["fresh"] and not fw2.is_empty() and fresh.has(fw2[0]):
		s -= 3.0
	return s

func ai_discard(p: Player) -> void:
	for v in ai_discard_values(p):
		p.hand.erase(v)
		p.discard.append(v)

## Le carte che la CPU scarterebbe (senza toccare la mano): servono anche quando, online,
## il computer prende il posto di un giocatore che si è scollegato.
func ai_discard_values(p: Player) -> Array:
	var hand: Array = p.hand.duplicate()
	var out := []
	while hand.size() + p.dents > 5 and not hand.is_empty():
		var counts := {}
		for v in hand:
			counts[v] = counts.get(v, 0) + 1
		var bestv: int = hand[0]
		for v in counts.keys():
			if counts[v] > counts[bestv] or (counts[v] == counts[bestv] and v > bestv):
				bestv = v
		hand.erase(bestv)
		out.append(bestv)
	return out
