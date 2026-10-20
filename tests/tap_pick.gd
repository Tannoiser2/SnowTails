extends SceneTree
## Tocco sullo schermo -> casella: verifica su tutte le tessere (bivio compreso).
func _init() -> void:
	var c := Course.new()
	c.load_file("res://data/courses/fanmade.json")
	var b := BoardView3D.new()
	root.add_child(b)
	var g := SledGame.new()
	g.setup(c, [true, true])
	b.setup(c, g)
	b.current_id = -1
	b.redraw()
	await create_timer(0.3).timeout
	var bad := 0
	var tot := 0
	var badfork := 0
	for pi in c.pieces.size():
		var fork := String(c.pieces[pi]["face"].get("type", "")) == "fork"
		var f := SegmentFx.frame(c, pi)
		b.target_goal = BoardView3D.to3(f["mid"])
		b.target = b.target_goal
		b.yaw_goal = BoardView3D.yaw_of(f["dir"]) + 0.4
		b.yaw = b.yaw_goal
		b.pitch = deg_to_rad(40)
		b.dist_goal = 6.0
		b.dist = 6.0
		await create_timer(0.15).timeout
		for id in c.pieces[pi]["cells"]:
			var sp := b.cam.unproject_position(BoardView3D.to3(c.cells[id]["pos"], 0.03))
			var w := b._screen_to_world(sp)
			var best := -1
			var bd := INF
			for j in c.cells.size():
				var d: float = w.distance_to(c.cells[j]["pos"])
				if d < bd:
					bd = d; best = j
			tot += 1
			if best != id or bd > c.lane_w * 0.95:
				bad += 1
				if fork: badfork += 1
	print("caselle: ", tot, " sbagliate: ", bad, " (bivio: ", badfork, ")")
	quit()
