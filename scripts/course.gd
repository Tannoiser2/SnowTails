class_name Course
extends RefCounted
## Percorso composto da tessere. Ogni tessera porta una rete di caselle:
## collegamenti "in avanti" (oltre una linea blu) disegnati o generati,
## più le derive (avanti in diagonale oltre una linea nera, anche per lo spigolo)
## calcolate qui dalla geometria.

var title := ""
var note := ""
var pieces: Array = []      # {face, xf: Transform2D, tex_path}
var cells: Array = []       # {id, piece, pos, fwd: [], bwd: [], dl: [], dr: [], s, lat}
var limits: Array = []      # {piece, lim, s, a, b}
var corners: Array = []     # {piece, turn}
var finish_piece := -1
var finish_s := 0.0
var finish_a := Vector2.ZERO
var finish_b := Vector2.ZERO
var start_cells: Array = []
var saplings: Array = []    # caselle con un alberello all'inizio della gara
var crevasse := {}          # caselle della spaccatura (Leap of Death) -> velocità minima
var leaps: Array = []       # {piece, min, s}
## Segmenti fanmade: tipo di ogni tessera ("up", "down", "wind", "ice", "fresh", "hut" o "")
var fresh := {}             # caselle con neve fresca
var huts := {}              # caselle della baita
## Altezza (unità del mondo 3D) all'ingresso e all'uscita di ogni tessera: salite e discese
const RISE := 1.1
var cell_len := 97.0
var lane_w := 53.8
var missing: Array = []
var error := ""

func load_file(path: String) -> bool:
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary):
		error = "File del percorso non valido: " + path
		return false
	return build(d)

func build(def: Dictionary) -> bool:
	title = String(def.get("name", "Percorso"))
	note = String(def.get("note", ""))
	pieces.clear(); cells.clear(); fresh.clear(); huts.clear(); limits.clear(); corners.clear(); missing.clear(); start_cells.clear(); saplings.clear(); crevasse.clear(); leaps.clear()
	finish_piece = -1
	var ids: Array = def.get("pieces", [])
	var prev_mid := Vector2.ZERO
	var prev_dir := Vector2(0, -1)
	for i in ids.size():
		var f := FaceDB.load_face(String(ids[i]))
		if f.is_empty():
			error = "Faccia mancante: " + String(ids[i])
			return false
		if not FaceDB.is_mapped(f):
			var lbl := String(f.get("label", ids[i]))
			if not missing.has(lbl):
				missing.append(lbl)
		var e_mid := FaceDB.v2(f["entry"]["mid"])
		var e_dir := FaceDB.v2(f["entry"]["dir"]).normalized()
		var x_mid := FaceDB.v2(f["exit"]["mid"])
		var x_dir := FaceDB.v2(f["exit"]["dir"]).normalized()
		var xf: Transform2D
		if i == 0:
			xf = Transform2D(Vector2(0, -1).angle() - x_dir.angle(), Vector2.ZERO)
			xf.origin = -xf.basis_xform(x_mid)
		else:
			xf = Transform2D(prev_dir.angle() - e_dir.angle(), Vector2.ZERO)
			xf.origin = prev_mid - xf.basis_xform(e_mid)
		prev_mid = xf * x_mid
		prev_dir = xf.basis_xform(x_dir).normalized()
		lane_w = float(f.get("lane_width", lane_w))
		pieces.append({"face": f, "xf": xf, "tex_path": String(f.get("image", "")), "seg": String(f.get("segment", "")),
			"wind": String(f.get("wind", "")), "h0": 0.0, "h1": 0.0,
			"entry_mid": xf * e_mid, "entry_dir": xf.basis_xform(e_dir).normalized(),
			"exit_mid": prev_mid, "exit_dir": prev_dir, "cells": []})
	if not missing.is_empty():
		error = "Tessere da mappare: " + ", ".join(missing)
		return false
	# caselle e collegamenti interni
	for pi in pieces.size():
		var pc: Dictionary = pieces[pi]
		var f: Dictionary = pc["face"]
		var xf: Transform2D = pc["xf"]
		var base := cells.size()
		for pt in f["cells"]:
			var id := cells.size()
			cells.append({"id": id, "piece": pi, "pos": xf * FaceDB.v2(pt), "fwd": [], "bwd": [], "dl": [], "dr": [], "s": 0.0, "lat": 0.0})
			pc["cells"].append(id)
		for l in f.get("links", []):
			_link(base + int(l[0]), base + int(l[1]))
		for si in f.get("saplings", []):
			saplings.append(base + int(si))
		for fi in f.get("fresh", []):
			if int(fi) >= 0:
				fresh[base + int(fi)] = true
		for hi in f.get("hut", []):
			if int(hi) >= 0:
				huts[base + int(hi)] = true
		var lm := int(f.get("leap_min", 0))
		for ci in f.get("crevasse", []):
			crevasse[base + int(ci)] = lm if lm > 0 else 5
		var typ := String(f.get("type", ""))
		if typ == "start" and start_cells.is_empty():
			for k in min(5, f["cells"].size()):
				start_cells.append(base + k)
		if typ == "finish" and finish_piece < 0:
			finish_piece = pi
		var turn := String(f.get("turn", ""))
		if turn != "":
			corners.append({"piece": pi, "turn": turn})
	_estimate_cell_len()
	_compute_heights()
	_compute_sideways()
	# giunzioni fra tessere
	for pi in range(1, pieces.size()):
		_join(pi - 1, pi)
	_compute_drifts()
	_apply_drift_edits()
	_compute_progress()
	_compute_dist_to_finish()
	# limiti e traguardo
	for pi in pieces.size():
		var pc: Dictionary = pieces[pi]
		var lim := int(pc["face"].get("limit", 0))
		var mid: Vector2 = pc["entry_mid"]
		var dir: Vector2 = pc["entry_dir"]
		var left := Vector2(dir.y, -dir.x)
		var a := mid + left * lane_w * 2.5
		var b := mid - left * lane_w * 2.5
		if lim > 0:
			limits.append({"piece": pi, "lim": lim, "s": _piece_start_s(pi), "a": a, "b": b})
		if pi == finish_piece:
			finish_a = a; finish_b = b; finish_s = _piece_start_s(pi)
	for pi in pieces.size():
		var best := INF
		var lm := 0
		for id in pieces[pi]["cells"]:
			if crevasse.has(id):
				best = min(best, float(cells[id]["s"]) - cell_len * 0.5)
				lm = crevasse[id]
		if lm > 0:
			leaps.append({"piece": pi, "min": lm, "s": best})
	if start_cells.size() != 5:
		error = "Il percorso deve iniziare con la tessera di partenza"
		return false
	if finish_piece < 0:
		error = "Il percorso non ha la tessera d'arrivo"
		return false
	return true

## Segmento fanmade della tessera di una casella ("" per le tessere normali).
func seg_of(id: int) -> String:
	return String(pieces[int(cells[id]["piece"])]["seg"])

## Vento della tessera di una casella: +1 spinge a destra, -1 a sinistra, 0 niente vento.
func wind_of(id: int) -> int:
	var pc: Dictionary = pieces[int(cells[id]["piece"])]
	if pc["seg"] != "wind":
		return 0
	return -1 if String(pc["wind"]) == "L" else 1

## Caselle accanto (stessa colonna, corsia a destra o a sinistra) sulle tessere dritte:
## servono al vento che sposta la slitta di lato.
func _compute_sideways() -> void:
	for pc in pieces:
		var d: Vector2 = (pc["exit_mid"] - pc["entry_mid"]).normalized()
		var right := Vector2(-d.y, d.x)
		for id in pc["cells"]:
			var c: Dictionary = cells[id]
			c["side_r"] = -1
			c["side_l"] = -1
			for o in pc["cells"]:
				if o == id:
					continue
				var v: Vector2 = cells[o]["pos"] - c["pos"]
				if abs(v.dot(d)) > cell_len * 0.3:
					continue
				var lat := v.dot(right)
				if abs(abs(lat) - lane_w) < lane_w * 0.35:
					c["side_r" if lat > 0 else "side_l"] = o

## Quota di ogni tessera: le salite alzano la pista di RISE, le discese la abbassano.
func _compute_heights() -> void:
	var h := 0.0
	for pc in pieces:
		pc["h0"] = h
		if pc["seg"] == "up":
			h += RISE
		elif pc["seg"] == "down":
			h = max(h - RISE, 0.0)
		pc["h1"] = h

## Quota della tessera pi nel punto p (coordinate del percorso): costante, o in pendenza
## lineare dall'ingresso all'uscita per salite e discese.
func piece_height(pi: int, p: Vector2) -> float:
	var pc: Dictionary = pieces[pi]
	if float(pc["h0"]) == float(pc["h1"]):
		return float(pc["h0"])
	var a: Vector2 = pc["entry_mid"]
	var b: Vector2 = pc["exit_mid"]
	var ab := b - a
	var t: float = clamp((p - a).dot(ab) / max(ab.length_squared(), 0.001), 0.0, 1.0)
	return lerp(float(pc["h0"]), float(pc["h1"]), t)

## Quota del terreno in un punto qualsiasi: la tessera che lo contiene (prima le pendenze).
func height_at(p: Vector2) -> float:
	var best := -1
	var bd := INF
	for pass_slope in [true, false]:
		for pi in pieces.size():
			var pc: Dictionary = pieces[pi]
			var slope: bool = float(pc["h0"]) != float(pc["h1"])
			if slope != pass_slope:
				continue
			var loc: Vector2 = (pc["xf"] as Transform2D).affine_inverse() * p
			var sz := FaceDB.v2(pc["face"].get("size", [600, 450]))
			if loc.x >= 0.0 and loc.y >= 0.0 and loc.x <= sz.x and loc.y <= sz.y:
				return piece_height(pi, p)
		if best >= 0:
			break
	for pi in pieces.size():
		var pc: Dictionary = pieces[pi]
		var d: float = min((pc["entry_mid"] - p).length(), (pc["exit_mid"] - p).length())
		if d < bd:
			bd = d
			best = pi
	return piece_height(best, p) if best >= 0 else 0.0

## Quota di una casella (calcolata sulla sua tessera, senza ambiguità).
func cell_height(id: int) -> float:
	return piece_height(int(cells[id]["piece"]), cells[id]["pos"])

func _link(a: int, b: int) -> void:
	if a == b or cells[a]["fwd"].has(b):
		return
	cells[a]["fwd"].append(b)
	cells[b]["bwd"].append(a)

func _estimate_cell_len() -> void:
	var acc := 0.0
	var n := 0
	for c in cells:
		if String(pieces[c["piece"]]["face"].get("type", "")) != "straight":
			continue
		for t in c["fwd"]:
			acc += (cells[t]["pos"] - c["pos"]).length(); n += 1
	if n > 0: cell_len = acc / n

## Collega le caselle d'uscita di una tessera con quelle d'ingresso della successiva.
func _join(pa: int, pb: int) -> void:
	var E: Vector2 = pieces[pb]["entry_mid"]
	var d: Vector2 = pieces[pb]["entry_dir"]
	var left := Vector2(d.y, -d.x)
	var outs := []
	var ins := []
	# sulle curve e inversioni le caselle lunghe della corsia interna hanno il centro lontano
	# dal bordo; sui rettilinei invece l'ultima casella deve toccare il bordo, altrimenti la
	# corsia è bloccata (crepaccio, cumulo) e non va collegata
	var pa_type := String(pieces[pa]["face"].get("type", ""))
	var reach: float = 1.7 if (pa_type == "corner" or pa_type == "uturn") else 0.95
	for id in pieces[pa]["cells"]:
		var c: Dictionary = cells[id]
		var inner := false
		for t in c["fwd"]:
			if cells[t]["piece"] == pa: inner = true
		if not inner and (E - c["pos"]).dot(d) < cell_len * reach:
			outs.append(id)
	for id in pieces[pb]["cells"]:
		var c: Dictionary = cells[id]
		var inner := false
		for t in c["bwd"]:
			if cells[t]["piece"] == pb: inner = true
		if not inner and (c["pos"] - E).dot(d) < cell_len * 0.95:
			ins.append(id)
	var taken := {}
	outs.sort_custom(func(a, b): return (E - cells[a]["pos"]).dot(d) < (E - cells[b]["pos"]).dot(d))
	for x in outs:
		var best := -1
		var bl := lane_w * 0.5
		for y in ins:
			if taken.has(y):
				continue
			var dv: Vector2 = cells[y]["pos"] - cells[x]["pos"]
			if dv.dot(d) <= 0:
				continue
			var lat: float = abs(dv.dot(left))
			if lat < bl:
				bl = lat
				best = y
		if best >= 0:
			_link(x, best)
			taken[best] = true
	# caselle d'ingresso rimaste scoperte: le collega alla casella più vicina della tessera
	# precedente sulla stessa linea. Serve solo per le caselle lunghe della corsia interna di
	# curve e inversioni: sui rettilinei (crepaccio, cumulo) una corsia che finisce prima del
	# bordo è bloccata apposta e non va scavalcata.
	var prev_type := String(pieces[pa]["face"].get("type", ""))
	if prev_type != "corner" and prev_type != "uturn":
		return
	for y in ins:
		if taken.has(y):
			continue
		var best2 := -1
		var bs := INF
		for id in pieces[pa]["cells"]:
			var dv: Vector2 = cells[y]["pos"] - cells[id]["pos"]
			var along: float = dv.dot(d)
			var lat: float = abs(dv.dot(left))
			if along <= 0 or along > cell_len * 2.6 or lat > lane_w * 0.75:
				continue
			# la casella di partenza non deve avere già un seguito nella stessa corsia
			var has_inner := false
			for t in cells[id]["fwd"]:
				if cells[t]["piece"] == pa and abs((cells[t]["pos"] - cells[id]["pos"]).dot(left)) < lane_w * 0.5:
					has_inner = true
			if has_inner:
				continue
			var sc: float = along + lat
			if sc < bs:
				bs = sc
				best2 = id
		if best2 >= 0:
			_link(best2, y)

# --- progresso lungo una linea centrale ---
var _cl: Array = []
var _clp: Array = []
var _cum: Array = []

func _compute_progress() -> void:
	# passi minimi fino all'ultima tessera, con avanti e derive: la linea centrale non deve
	# fermarsi dove una corsia è chiusa (crepaccio, cumulo)
	var last := pieces.size() - 1
	var back := {}
	for c in cells:
		back[c["id"]] = []
	for c in cells:
		for t in c["fwd"] + c["dl"] + c["dr"]:
			back[t].append(c["id"])
	var dist := {}
	var q := []
	for c in cells:
		if int(c["piece"]) == last and c["fwd"].is_empty():
			dist[c["id"]] = 0
			q.append(c["id"])
	var h := 0
	while h < q.size():
		var id: int = q[h]
		h += 1
		for b in back[id]:
			if not dist.has(b):
				dist[b] = dist[id] + 1
				q.append(b)
	# linea centrale: dalla posizione di partenza centrale, avanti finché si può, sempre verso l'arrivo
	_cl.clear(); _clp.clear(); _cum.clear()
	if start_cells.size() < 3:
		return
	var cur: int = start_cells[2]
	var dir: Vector2 = pieces[0]["exit_dir"]
	var guard := 0
	while cur >= 0 and guard < 5000:
		guard += 1
		_cl.append(cells[cur]["pos"]); _clp.append(cells[cur]["piece"])
		var opts: Array = []
		for t in cells[cur]["fwd"]:
			if dist.has(t): opts.append(t)
		if opts.is_empty():
			for t in cells[cur]["dl"] + cells[cur]["dr"]:
				if dist.has(t): opts.append(t)
		if opts.is_empty():
			break
		var nxt := -1
		var bd := INF
		for t in opts:
			var v: Vector2 = (cells[t]["pos"] - cells[cur]["pos"]).normalized()
			var sc: float = float(dist[t]) * 10.0 - v.dot(dir)
			if sc < bd:
				bd = sc; nxt = t
		dir = (cells[nxt]["pos"] - cells[cur]["pos"]).normalized()
		cur = nxt
	var tot := 0.0
	for i in _cl.size():
		if i > 0: tot += (_cl[i] - _cl[i - 1]).length()
		_cum.append(tot)
	for c in cells:
		var pr := project(c["pos"], c["piece"])
		c["s"] = pr.x
		c["lat"] = pr.y

func _topo() -> Array:
	var indeg := {}
	for c in cells: indeg[c["id"]] = c["bwd"].size()
	var q := []
	for c in cells:
		if indeg[c["id"]] == 0: q.append(c["id"])
	var out := []
	while not q.is_empty():
		var id: int = q.pop_front()
		out.append(id)
		for t in cells[id]["fwd"]:
			indeg[t] -= 1
			if indeg[t] == 0: q.append(t)
	if out.size() < cells.size():   # eventuali cicli: aggiunge il resto
		for c in cells:
			if not out.has(c["id"]): out.append(c["id"])
	return out

## Restituisce (progresso, scostamento laterale: positivo = a destra).
func project(p: Vector2, piece: int) -> Vector2:
	var best_d := INF
	var best := Vector2.ZERO
	for i in range(_cl.size() - 1):
		if abs(_clp[i] - piece) > 1 and abs(_clp[i + 1] - piece) > 1:
			continue
		var a: Vector2 = _cl[i]
		var b: Vector2 = _cl[i + 1]
		var ab := b - a
		var L2 := ab.length_squared()
		var t := 0.0
		if L2 > 0.0001: t = clamp((p - a).dot(ab) / L2, 0.0, 1.0)
		var q := a + ab * t
		var d := p.distance_squared_to(q)
		if d < best_d:
			best_d = d
			var dirv := ab.normalized()
			var right := Vector2(-dirv.y, dirv.x)
			best = Vector2(_cum[i] + sqrt(L2) * t, (p - q).dot(right))
	if _cl.size() >= 2:
		var n := _cl.size()
		var d0: Vector2 = (_cl[1] - _cl[0]).normalized()
		if (p - _cl[0]).dot(d0) < 0 and abs(_clp[0] - piece) <= 1:
			best.x = min(best.x, (p - _cl[0]).dot(d0))
		var dn: Vector2 = (_cl[n - 1] - _cl[n - 2]).normalized()
		if (p - _cl[n - 1]).dot(dn) > 0 and abs(_clp[n - 1] - piece) <= 1:
			best.x = max(best.x, _cum[n - 1] + (p - _cl[n - 1]).dot(dn))
	return best

## Direzione di marcia locale di una casella.
func heading(id: int) -> Vector2:
	var c: Dictionary = cells[id]
	return Course.heading_of(c["pos"], c["fwd"].map(func(t): return cells[t]["pos"]),
		c["bwd"].map(func(t): return cells[t]["pos"]), pieces[c["piece"]]["exit_dir"])

static func heading_of(p: Vector2, fwd_pos: Array, bwd_pos: Array, fallback: Vector2) -> Vector2:
	var v := Vector2.ZERO
	for q in fwd_pos: v += ((q as Vector2) - p).normalized()
	if v.length() < 0.01:
		for q in bwd_pos: v += (p - (q as Vector2)).normalized()
	if v.length() < 0.01:
		v = fallback
	return v.normalized()

func _compute_drifts() -> void:
	var pos := []
	var fwd := []
	var heads := []
	for c in cells:
		pos.append(c["pos"])
		fwd.append(c["fwd"])
		heads.append(heading(c["id"]))
	var res := Course.drift_targets(pos, fwd, heads, cell_len, lane_w)
	for i in cells.size():
		cells[i]["dl"] = res[0][i]
		cells[i]["dr"] = res[1][i]

## Modifiche manuali alle derive fatte nell'editor: [da, a, "L"|"R"] in indici della faccia.
func _apply_drift_edits() -> void:
	for pc in pieces:
		var f: Dictionary = pc["face"]
		var ids: Array = pc["cells"]
		for e in f.get("drift_remove", []):
			var a: int = int(e[0]); var b: int = int(e[1])
			if a >= ids.size() or b >= ids.size(): continue
			var c: Dictionary = cells[ids[a]]
			c["dl"].erase(ids[b]); c["dr"].erase(ids[b])
		for e in f.get("drift_add", []):
			var a2: int = int(e[0]); var b2: int = int(e[1])
			if a2 >= ids.size() or b2 >= ids.size(): continue
			var key := "dl" if String(e[2]) == "L" else "dr"
			var c2: Dictionary = cells[ids[a2]]
			if not (c2[key] as Array).has(ids[b2]):
				c2[key].append(ids[b2])

## Deriva: una casella avanti in diagonale, oltre una linea nera.
## Il punto ideale è una casella avanti e una corsia di lato; vanno bene caselle
## sfalsate (che si sovrappongono di lato) o che toccano solo per lo spigolo.
## Restituisce [sinistra, destra], ciascuno un array di liste di indici.
static func drift_targets(pos: Array, fwd: Array, heads: Array, L: float, W: float) -> Array:
	var dl := []
	var dr := []
	for i in pos.size():
		var f: Vector2 = heads[i]
		var r := Vector2(-f.y, f.x)
		var out := [[], []]
		for si in 2:
			var side := -1.0 if si == 0 else 1.0
			var cands := []
			for j in pos.size():
				if j == i or (fwd[i] as Array).has(j):
					continue
				var dv: Vector2 = pos[j] - pos[i]
				if dv.length_squared() > L * L * 4.0:
					continue
				var along: float = dv.dot(f)
				var lat: float = dv.dot(r) * side
				if along < L * 0.2 or along > L * 1.6 or lat < W * 0.5 or lat > W * 1.55:
					continue
				var sc: float = pow((along - L) / L, 2) + pow((lat - W) / W, 2) * 1.5
				cands.append([sc, j])
			cands.sort_custom(func(a, b): return a[0] < b[0])
			for k in cands.size():
				if k == 0 or (k < 2 and cands[k][0] < cands[0][0] + 0.12 and cands[k][0] < 0.35):
					out[si].append(cands[k][1])
		dl.append(out[0])
		dr.append(out[1])
	return [dl, dr]

## Passi minimi per arrivare oltre il traguardo, usando avanti e derive.
func _compute_dist_to_finish() -> void:
	var back := {}
	for c in cells:
		back[c["id"]] = []
	for c in cells:
		for t in c["fwd"] + c["dl"] + c["dr"]:
			back[t].append(c["id"])
	var q := []
	for c in cells:
		c["togo"] = 1000
		if int(c["piece"]) >= finish_piece and finish_piece >= 0:
			c["togo"] = 0
			q.append(c["id"])
	var h := 0
	while h < q.size():
		var id: int = q[h]
		h += 1
		for b in back[id]:
			if cells[b]["togo"] > cells[id]["togo"] + 1:
				cells[b]["togo"] = cells[id]["togo"] + 1
				q.append(b)
	# quanti passi in avanti restano prima di un vicolo cieco
	var order := _topo()
	for i in range(order.size() - 1, -1, -1):
		var id: int = order[i]
		var c: Dictionary = cells[id]
		var run := 0
		if c["fwd"].is_empty():
			run = 0 if int(c["piece"]) < pieces.size() - 1 else 99
		else:
			for t in c["fwd"]:
				run = max(run, int(cells[t].get("run", 0)) + 1)
		c["run"] = min(run, 99)

func _piece_start_s(pi: int) -> float:
	var best := INF
	for id in pieces[pi]["cells"]:
		best = min(best, float(cells[id]["s"]) - cell_len * 0.5)
	return best

# --- interrogazioni usate dal gioco ---
func limit_dents(from_piece: int, to_piece: int, total_speed: int) -> int:
	var d := 0
	for l in limits:
		if from_piece < l["piece"] and l["piece"] <= to_piece:
			d += max(0, total_speed - int(l["lim"]))
	return d

func next_limit(s: float) -> Dictionary:
	for l in limits:
		if l["s"] > s: return l
	return {}

## Ammaccature per un passo che entra nella spaccatura sotto la velocità minima.
func leap_dents(from_id: int, to_id: int, total_speed: int) -> int:
	if crevasse.has(to_id) and not crevasse.has(from_id):
		return max(0, int(crevasse[to_id]) - total_speed)
	return 0

func next_leap(s: float) -> Dictionary:
	for l in leaps:
		if l["s"] > s: return l
	return {}

func next_corner(piece: int) -> Dictionary:
	for c in corners:
		if c["piece"] >= piece: return c
	return {}

func is_last_piece(pi: int) -> bool:
	return pi >= pieces.size() - 1
