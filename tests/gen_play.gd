extends SceneTree
## Genera piste casuali e le fa correre alle CPU.
func _init() -> void:
	var gen := CourseGen.new()
	for spec in [[0, 0], [1, 1], [2, 2], [2, 1], [1, 2]]:
		var def := gen.generate(spec[0], spec[1])
		var c := Course.new()
		c.build(def)
		var game := SledGame.new()
		game.setup(c, [true, true, true, true])
		for p in game.players:
			var fs := game.free_slots()
			game.take_slot(p, fs[randi() % fs.size()])
		game.deal_all()
		var safety := 0
		while not game.over and safety < 120:
			safety += 1
			for p in game.race_order():
				if not game.racing(p): continue
				if p.hand.is_empty():
					game.add_dent(p, 1)
					if p.wrecked: continue
					game.draw_up(p)
				var ch := game.ai_choose(p)
				game.commit_play(p, ch["pend"])
				for t in ch["o"]["path"]: p.cell = t
				game.after_move(p, ch["o"])
			game.check_round_end()
		var w := 0
		for p in game.players: if p.wrecked: w += 1
		print("diff %d lung %d: %d tessere, %d giri, vince %s, distrutte %d — %s" % [spec[0], spec[1], def["pieces"].size(), game.round_n, game.results[0]["p"].name if game.results.size() > 0 else "-", w, def["note"]])
	quit()
