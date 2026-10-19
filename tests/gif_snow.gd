extends SceneTree
## Una slitta attraversa la neve fresca e spazza via i cumuli (solo la vista 3D).
func _init() -> void:
	var c := Course.new()
	c.load_file("res://data/courses/fanmade.json")
	var b := BoardView3D.new()
	root.add_child(b)
	var g := SledGame.new()
	g.setup(c, [true])
	var p = g.players[0]
	var pi := 5
	var path := [c.grid_cell(pi - 1, 5, 0)]
	for col in range(0, 6):
		path.append(c.grid_cell(pi, col, 0))
	p.cell = path[0]
	b.setup(c, g)
	b.redraw()
	b.focus_cell(c.grid_cell(pi, 2, 0), true)
	b.target = b.target_goal
	b.dist_goal = 4.6
	b.dist = 4.6
	b.pitch = deg_to_rad(34)
	b.yaw = b.yaw_goal + 0.5
	b.yaw_goal = b.yaw
	b.set_follow(false)
	await create_timer(0.8).timeout
	var pts := []
	for id in path:
		pts.append(BoardView3D.to3(c.cells[id]["pos"], 0.004))
	var frames := 54
	var last := 0
	for k in frames:
		var f := float(k) / float(frames - 12)
		var x: float = clamp(f, 0.0, 1.0) * (pts.size() - 1)
		var i: int = min(int(x), pts.size() - 2)
		var dv: Vector3 = pts[i + 1] - pts[i]
		b.replay[p.id] = {"pos": (pts[i] as Vector3).lerp(pts[i + 1], x - i), "dir": Vector2(dv.x, dv.z).normalized(), "run": 1.0 if f < 1.0 else 0.0}
		while last < int(x + 0.001) and last < path.size() - 1:
			last += 1
			var t: int = path[last]
			if g.fresh.has(t):
				b.sweep_snow(t, (c.cells[t]["pos"] - c.cells[path[last - 1]]["pos"]).normalized())
		await create_timer(0.05).timeout
		root.get_texture().get_image().save_png("/tmp/shots/snow_%02d.png" % k)
	quit()
