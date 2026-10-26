extends SceneTree
func _init() -> void:
	var def := Course.randomize_def({"name": "v", "pieces": ["start_p21", "straight_p13a",
		{"id": "straight_p14a", "mods": {"wind": "F", "wind_force": 3}},
		{"id": "straight_p16a", "mods": {"wind": "C", "wind_force": 1, "fresh": true}}, "finish_p21"]})
	var c := Course.new()
	c.build(def)
	var b := BoardView3D.new()
	root.add_child(b)
	var g := SledGame.new()
	g.setup(c, [true])
	b.setup(c, g)
	b.current_id = -1
	b.redraw()
	for pi in [2, 3]:
		var f := SegmentFx.frame(c, pi)
		b.target_goal = BoardView3D.to3(f["mid"])
		b.target = b.target_goal
		b.yaw_goal = BoardView3D.yaw_of(f["dir"]) + 0.5
		b.yaw = b.yaw_goal
		b.pitch = deg_to_rad(35)
		b.dist_goal = 6.0
		b.dist = 6.0
		await create_timer(1.5).timeout
		root.get_texture().get_image().save_png("/tmp/shots/wind_%d.png" % pi)
	quit()
