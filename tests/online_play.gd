extends SceneTree
## Prova del gioco online: due istanze del gioco (chi crea la stanza e un amico) giocano una gara
## intera tra loro sul finto Firebase (tests/firebase_mock.py). Le persone sono simulate dalla CPU.
## ST_ROLE=host|guest, ST_CODEFILE=file in cui l'host scrive il codice della stanza,
## ST_PHASE=drop: l'ospite esce a metà gara (per provare il rientro con ST_PHASE=back).
## Alla fine ognuno stampa l'impronta della gara: devono coincidere.

var main
var role := ""
var acted := -1
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
	var phase := OS.get_environment("ST_PHASE")
	main._on_name.text = "Host" if role == "host" else "Ospite"
	if role == "host":
		main.course_idx = main.course_files.find("res://data/courses/bruce.json")
		# Rosso (host), Blu fuori gara, Giallo (ospite), Verde CPU: i posti seguono i colori
		main.setup_on = [true, false, true, true, false]
		main.setup_ai = [false, true, false, true, true]
		await main._online_create()
		var code: String = main.online.get("code", "")
		print("STTEST stanza ", code)
		var f := FileAccess.open(cf, FileAccess.WRITE)
		f.store_string(code)
		f.close()
		# aspetta l'ospite
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
		main._on_code.text = code
		await main._online_join()
		print("STTEST entrato ", main.online)
	# gioca: quando tocca alla "persona" di questo dispositivo, decide la CPU
	var dropped := false
	while true:
		await process_frame
		if Time.get_ticks_msec() - t0 > 600000:
			print("STTEST tempo scaduto, fase ", main.phase)
			quit(2)
			return
		if main.game == null:
			continue
		if main.game.over:
			break
		if phase == "drop" and not dropped and main.game.round_n >= 3:
			print("STTEST esco a metà gara, mossa ", main.online.get("n"))
			quit(0)
			return
		var n: int = int(main.online.get("n", 0))
		if acted == n or main.cur == null:
			continue
		match main.phase:
			"slots":
				acted = n
				main._do_act({"k": "slot", "v": main.game.free_slots()[0]})
			"cards":
				acted = n
				var ch: Dictionary = main.game.ai_choose(main.cur)
				main._do_act(main._move_act(ch["pend"], ch["o"]), ch["o"])
			"discard":
				acted = n
				main._do_act({"k": "disc", "v": main.game.ai_discard_values(main.cur)})
	await _wait(0.5)
	var fp := []
	for p in main.game.players:
		fp.append("%s:%d:%d:%s:%d:%s" % [p.name, p.cell, p.dents, p.wrecked, p.finish_round, str(p.hand)])
	print("STTEST impronta ", main.online.get("n"), " giri ", main.game.round_n, " | ", " | ".join(fp))
	quit(0)
