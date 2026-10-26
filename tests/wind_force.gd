extends SceneTree
## Forza del vento, vento a favore/contrario e neve fresca a caso.
func _init() -> void:
	var def := {"name": "prova vento", "pieces": ["start_p21", "straight_p13a",
		{"id": "straight_p14a", "mods": {"wind": "F", "wind_force": 2}},
		{"id": "straight_p16a", "mods": {"wind": "C", "wind_force": 3}},
		{"id": "straight_p18a", "mods": {"wind": "R", "wind_force": 0}},
		{"id": "straight_p20a", "mods": {"fresh": true}}, "finish_p21"]}
	var ok := 0
	var tot := 0
	var d1 := Course.randomize_def(def)
	var c := Course.new()
	c.build(d1)
	var g := SledGame.new()
	g.setup(c, [true])
	var m := {"L": 3, "R": 3, "B": 1}
	var sF := g.effective_speed(c.pieces[2]["cells"][3], m)
	var sC := g.effective_speed(c.pieces[3]["cells"][3], m)
	tot += 1; if sF == 7 and sC == 2: ok += 1
	print("a favore 2: 5 → ", sF, "   contrario 3: 5 → ", sC)
	var f0 := int(d1["pieces"][4]["mods"]["wind_force"])
	var dr := g.effective_drift(c.pieces[4]["cells"][3], m)
	tot += 1; if f0 >= 1 and f0 <= 3 and dr == f0: ok += 1
	print("forza a sorte: ", f0, " deriva con cani uguali ", dr)
	var seen := {}
	for k in 6:
		var dk := Course.randomize_def(def)
		var ck := Course.new()
		ck.build(dk)
		var ks := ck.fresh.keys()
		ks.sort()
		seen[str(ks)] = true
		if k == 0: print("neve fresca: ", ks.size(), " cumuli")
	tot += 1; if seen.size() >= 4: ok += 1
	print("disposizioni diverse della neve in 6 gare: ", seen.size())
	print("VENTO E NEVE: %d/%d" % [ok, tot])
	quit()
