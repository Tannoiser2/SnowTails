extends SceneTree
## Casi controllati della variante simultanea sul rettilineo di prova.
func _init() -> void:
	var c := Course.new()
	c.load_file("res://data/courses/prova.json")
	var g := SledGame.new()
	g.setup(c, [true, true, true])
	g.simultaneous = true
	var a = g.players[0]
	var b = g.players[1]
	var z = g.players[2]
	# a e b sulla stessa corsia, b due caselle davanti; z lontano
	var lane: int = c.start_cells[2]
	var cells := [lane]
	for i in 12:
		cells.append(c.cells[cells[-1]]["fwd"][0])
	a.cell = cells[0]
	b.cell = cells[2]
	z.cell = c.start_cells[0]
	for p in g.players:
		p.moves = 1
	# 1) stessa casella d'arrivo, a più veloce: a entra, b (più lento) si ferma prima
	var oa := _straight(g, a, 6)
	var ob := _straight(g, b, 4)
	var plan := g.resolve_simultaneous({a.id: {"pend": [], "o": oa}, b.id: {"pend": [], "o": ob}})
	_show("caso 1", plan)
	# 2) stessa velocità: vince chi era davanti (b)
	var oa2 := _straight(g, a, 5)
	var ob2 := _straight(g, b, 3)
	plan = g.resolve_simultaneous({a.id: {"pend": [], "o": oa2}, b.id: {"pend": [], "o": ob2}})
	_show("caso 2 (velocità diverse, arrivo uguale)", plan)
	quit()

func _straight(g: SledGame, p, n: int) -> Dictionary:
	var path := []
	var cur: int = p.cell
	for i in n:
		cur = g.course.cells[cur]["fwd"][0]
		path.append(cur)
	return {"path": path, "end": cur, "dents": 0, "corner_dents": 0, "crash": "", "bonus": false, "bonus_n": 0, "speed": n, "sap": []}

func _show(t: String, plan: Array) -> void:
	var s := t + ":"
	for x in plan:
		s += "  %s da %d → %d (%d caselle%s)" % [x["p"].name, x["start"], x["o"]["end"], (x["o"]["path"] as Array).size(), ", mezza ammaccatura, cede a " + String(x["o"].get("yield_to", "?")) if x["o"]["half"] else ""]
	print(s)
