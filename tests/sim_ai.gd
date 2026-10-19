extends SceneTree
## Variante simultanea con sole CPU: la gara deve finire e due slitte in gara non devono mai
## trovarsi sulla stessa casella alla fine di un giro.
func _init() -> void:
	Engine.time_scale = 12.0
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.3).timeout
	var cpath := OS.get_environment("COURSE") if OS.get_environment("COURSE") != "" else "res://data/courses/prova.json"
	main.course_idx = main.course_files.find(cpath)
	main._menu_refresh_info()
	main.setup_n = 5
	main.setup_ai = [true, true, true, true, true]
	main.sim_variant = true
	main.start_game()
	var last_round := 0
	var clashes := 0
	var crashes := 0
	for i in 4000:
		await process_frame
		var g = main.game
		if g == null:
			continue
		if g.round_n != last_round and main.phase != "anim":
			last_round = g.round_n
			var seen := {}
			for p in g.players:
				if g.racing(p) and p.cell >= 0:
					if seen.has(p.cell):
						clashes += 1
					seen[p.cell] = true
		if g.over:
			break
	var g2 = main.game
	for r in g2.history:
		for mv in r:
			if mv.get("fx", {}).get("crash", "") in ["sled", "bump"]:
				crashes += 1
	print("SIM simultanea: finita=", g2.over, " giri=", g2.round_n, " sovrapposizioni=", clashes, " frenate con mezza ammaccatura=", crashes)
	for r in g2.results:
		print("  ", r["p"].name, ": ", r["st"])
	quit()
