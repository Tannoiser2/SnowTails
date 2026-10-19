extends SceneTree
## Confronto fra la CPU nuova (guarda avanti le caratteristiche fanmade) e la vecchia,
## su piste casuali fanmade: posizione media d'arrivo (1 = primo) e vittorie.
func _init() -> void:
	var races := int(OS.get_environment("RACES")) if OS.get_environment("RACES") != "" else 40
	var only := OS.get_environment("PARTS")
	if only != "":
		for k in SledGame.ai_parts:
			SledGame.ai_parts[k] = only.split(",").has(k)
	var pos := {true: 0.0, false: 0.0}
	var cnt := {true: 0, false: 0}
	var wins := {true: 0, false: 0}
	var dents := {true: 0.0, false: 0.0}
	var run := 0
	for i in races:
		var d := CourseGen.new().generate(i % 3, 1 + (i % 2), 9000 + i, OS.get_environment("FAN") != "0")
		var c := Course.new()
		if d.is_empty() or not c.build(d):
			continue
		var g := SledGame.new()
		g.setup(c, [true, true, true, true], 3000 + i)
		# metà CPU nuove e metà vecchie, a posti alterni per non favorire nessuno
		for k in g.players.size():
			g.players[k].smart = ((k + i) % 2 == 0)
		for p in g.players:
			g.take_slot(p, g.free_slots()[0])
		g.deal_all()
		var guard := 0
		while not g.over and guard < 300:
			guard += 1
			g.order = g.race_order()
			for p in g.order:
				if not g.racing(p):
					continue
				if p.hand.is_empty():
					g.add_dent(p, 1)
					g.draw_up(p)
					if p.wrecked: continue
				var ch := g.ai_choose(p)
				if ch.is_empty():
					continue
				g.commit_play(p, ch["pend"])
				p.cell = ch["o"]["end"]
				g.after_move(p, ch["o"])
			g.check_round_end()
		if not g.over:
			continue
		run += 1
		for r in g.results.size():
			var p = g.results[r]["p"]
			pos[p.smart] += r + 1
			cnt[p.smart] += 1
			dents[p.smart] += p.dents
		wins[g.results[0]["p"].smart] += 1
	print("DUELLO su %d gare: CPU nuova posizione media %.2f, vittorie %d, ammaccature medie %.2f | vecchia %.2f, vittorie %d, ammaccature %.2f" % [run,
		pos[true] / max(cnt[true], 1), wins[true], dents[true] / max(cnt[true], 1),
		pos[false] / max(cnt[false], 1), wins[false], dents[false] / max(cnt[false], 1)])
	quit()
