extends SceneTree
## Schermo condiviso + telefoni sul finto Firebase (tests/firebase_mock.py).
## ST_ROLE=table|phone, ST_CODEFILE, ST_SIM=1 per il movimento simultaneo, ST_WANT=colore del telefono.
## Alla fine ognuno stampa l'impronta della gara: devono coincidere.
var main
var role := ""
var acted := ""
var t0 := 0

func _init() -> void:
	role = OS.get_environment("ST_ROLE")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	t0 = Time.get_ticks_msec()
	_run()

func _wait(s: float) -> void:
	await create_timer(s).timeout

func _run() -> void:
	await _wait(0.5)
	var cf := OS.get_environment("ST_CODEFILE")
	if role == "table":
		main.course_idx = main.course_files.find("res://data/courses/bruce.json")
		main.setup_on = [true, true, true, true, false]
		main.setup_ai = [false, true, false, true, true]    # Rosso e Giallo ai telefoni, Blu e Verde CPU
		main.sim_variant = OS.get_environment("ST_SIM") == "1"
		await main._online_create(true)
		var code: String = main.online.get("code", "")
		print("STTEST stanza ", code, " seat ", main.online.get("seat"))
		var f := FileAccess.open(cf, FileAccess.WRITE)
		f.store_string(code)
		f.close()
		while true:
			var room: Dictionary = await main.net.room(code)
			if Net._as_dict(room.get("seats", {})).size() >= 2:
				break
			await _wait(0.5)
		await main._online_start()
	else:
		var code := ""
		while code == "":
			if FileAccess.file_exists(cf):
				code = FileAccess.get_file_as_string(cf).strip_edges()
			await _wait(0.3)
		main._phone_join(code)
		await _wait(2.0)
		main._on_name.text = "Tel" + OS.get_environment("ST_WANT")
		main._join_want = int(OS.get_environment("ST_WANT"))
		await main._online_join()
		print("STTEST entrato ", main.online)
	while true:
		await process_frame
		if Time.get_ticks_msec() - t0 > 900000:
			print("STTEST tempo scaduto, fase ", main.phase)
			quit(2)
			return
		if main.game == null:
			continue
		if main.game.over:
			break
		if role == "phone" and OS.get_environment("ST_PHASE") == "drop" and main.game.round_n >= 3:
			print("STTEST esco a metà gara")
			quit(0)
			return
		if role == "table" or main.cur == null:
			continue
		var key := "%d:%s:%d:%d" % [int(main.online.get("n", 0)), main.phase, main.game.round_n, main.cur.id]
		if acted == key:
			continue
		match main.phase:
			"slots":
				acted = key
				main._do_act({"k": "slot", "v": main.game.free_slots()[0]})
			"cards":
				acted = key
				var ch: Dictionary = main.game.ai_choose(main.cur)
				if main.game.simultaneous:
					main._submit_move(ch["pend"], ch["o"])
				else:
					main._do_act(main._move_act(ch["pend"], ch["o"]), ch["o"])
			"discard":
				acted = key
				main._do_act({"k": "disc", "v": main.game.ai_discard_values(main.cur)})
	await _wait(0.5)
	var fp := []
	for p in main.game.players:
		fp.append("%s:%d:%d:%s:%d:%s" % [p.name, p.cell, p.dents, p.wrecked, p.finish_round, str(p.hand)])
	print("STTEST impronta ", main.online.get("n"), " giri ", main.game.round_n, " sim ", main.game.simultaneous, " | ", " | ".join(fp))
	quit(0)
