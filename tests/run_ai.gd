extends SceneTree
## Prova senza grafica: partita completa con sole CPU.
## godot --headless --path . -s res://tests/run_ai.gd -- res://data/courses/prova.json

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var path := "res://data/courses/prova.json" if args.is_empty() else args[0]
	var c := Course.new()
	if not c.load_file(path):
		print("ERRORE: ", c.error)
		quit(1)
		return
	print("percorso ", c.title, ": ", c.cells.size(), " caselle, lunghezza casella ", snapped(c.cell_len, 0.1), ", limiti ", c.limits.size())
	for g in 2:
		var game := SledGame.new()
		game.setup(c, [true, true, true, true, true])
		for p in game.players:
			var fs := game.free_slots()
			game.take_slot(p, fs[randi() % fs.size()])
		game.deal_all()
		var safety := 0
		while not game.over and safety < 200:
			safety += 1
			for p in game.race_order():
				if not game.racing(p): continue
				if p.hand.is_empty():
					game.add_dent(p, 1)
					if p.wrecked: continue
					game.draw_up(p)
				var ch := game.ai_choose(p)
				var m := game.mat_after(p, ch["pend"])
				game.log_text = game.describe(ch["pend"], ch["o"], m)
				game.commit_play(p, ch["pend"])
				for t in ch["o"]["path"]:
					p.cell = t
				game.after_move(p, ch["o"])
			game.check_round_end()
		var line := []
		for r in game.results:
			line.append("%s %s (amm. %d)" % [r["p"].name, r["st"], r["p"].dents])
		print("gara %d, %d giri: %s" % [g + 1, game.round_n, " | ".join(line)])
	quit(0)
