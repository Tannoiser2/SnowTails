extends SceneTree
## Gare fra CPU su piste casuali fanmade: devono arrivare in fondo.
func _init() -> void:
	var done := 0
	for i in 6:
		var d := CourseGen.new().generate(i % 3, 1, 500 + i, true)
		var c := Course.new()
		if d.is_empty() or not c.build(d):
			continue
		var g := SledGame.new()
		g.setup(c, [true, true, true, true], 77 + i)
		for p in g.players:
			g.take_slot(p, g.free_slots()[0])
		g.deal_all()
		var guard := 0
		while not g.over and guard < 2000:
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
		if g.over:
			done += 1
	print("GARE CASUALI FANMADE finite %d/6" % done)
	quit()
