extends SceneTree
## Replay di una gara fra CPU: la telecamera deve muoversi di continuo, senza soste né scatti.
func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.3).timeout
	main.course_idx = main.course_files.find("res://data/courses/prova.json")
	main.setup_n = 4
	main.setup_ai = [true, true, true, true, true]
	Engine.time_scale = 12.0
	main.start_game()
	for i in 6000:
		await process_frame
		if main.game != null and main.game.over:
			break
	Engine.time_scale = 1.0
	main.start_replay()
	var b = main.board
	var prev: Vector3 = b.target
	var speeds := []
	var t0 := Time.get_ticks_msec()
	var shots := 0
	while main.phase == "replay" and Time.get_ticks_msec() - t0 < 9000:
		await process_frame
		var d: float = (b.target - prev).length() / max(get_root().get_process_delta_time() if false else 1.0 / 60.0, 0.001)
		speeds.append((b.target - prev).length())
		prev = b.target
		if shots < 3 and Time.get_ticks_msec() - t0 > 2500 * (shots + 1):
			if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png("/tmp/shots/replay_%d.png" % shots)
			shots += 1
	# fotogrammi fermi (spostamento quasi nullo) e scatti (spostamento molto sopra la media)
	var tot := 0.0
	for v in speeds:
		tot += v
	var mean: float = tot / max(speeds.size(), 1)
	var still := 0
	var jumps := 0
	for i in range(30, speeds.size()):
		if speeds[i] < mean * 0.05:
			still += 1
		if speeds[i] > mean * 6.0:
			jumps += 1
	print("REPLAY fotogrammi=", speeds.size(), " media=", snapped(mean, 0.0001), " fermi=", still, " scatti=", jumps)
	quit()
