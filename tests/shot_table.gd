extends SceneTree
## Schermate dello schermo condiviso e del telefono (con tests/firebase_mock.py).
var main
func _init() -> void:
	var role := OS.get_environment("ST_ROLE")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.6).timeout
	var cf := OS.get_environment("ST_CODEFILE")
	if role == "table":
		main.setup_on = [true, true, true, true, false]
		main.setup_ai = [false, true, false, true, true]
		main.sim_variant = true
		await main._online_create(true)
		var f := FileAccess.open(cf, FileAccess.WRITE)
		f.store_string(main.online["code"])
		f.close()
		await create_timer(5.0).timeout
		root.get_texture().get_image().save_png("/tmp/shots/tb_lobby.png")
		if OS.get_environment("ST_LOBBY_ONLY") == "1":
			quit()
			return
		await main._online_start()
		var shot := false
		while main.game == null or main.game.round_n < 3:
			await create_timer(0.3).timeout
			if main.game and main.game.round_n == 2 and main.phase == "simwait" and not shot:
				await create_timer(0.6).timeout
				root.get_texture().get_image().save_png("/tmp/shots/tb_wait.png")
				shot = true
	else:
		var code := ""
		while code == "":
			if FileAccess.file_exists(cf):
				code = FileAccess.get_file_as_string(cf).strip_edges()
			await create_timer(0.3).timeout
		main._phone_join(code)
		await create_timer(2.5).timeout
		root.get_texture().get_image().save_png("/tmp/shots/ph_join.png")
		main._on_name.text = "Anna"
		main._join_want = 0
		await main._online_join()
		var done := false
		while main.game == null or main.game.round_n < 3:
			await create_timer(0.3).timeout
			if main.game == null or main.cur == null:
				continue
			if main.phase == "slots":
				main._do_act({"k": "slot", "v": main.game.free_slots()[0]})
				await create_timer(0.5).timeout
			elif main.phase == "cards":
				if main.game.round_n == 2 and not done:
					var ch: Dictionary = main.game.ai_choose(main.cur)
					main.pending = []
					var i := 0
					for x in ch["pend"]:
						main.pending.append({"slot": x["slot"], "hi": main.cur.hand.find(x["v"]), "v": x["v"]})
					main._refresh()
					await create_timer(0.8).timeout
					root.get_texture().get_image().save_png("/tmp/shots/ph_cards.png")
					done = true
				var ch2: Dictionary = main.game.ai_choose(main.cur)
				main._submit_move(ch2["pend"], ch2["o"])
				await create_timer(0.5).timeout
			elif main.phase == "discard":
				main._do_act({"k": "disc", "v": main.game.ai_discard_values(main.cur)})
				await create_timer(0.5).timeout
	quit()
