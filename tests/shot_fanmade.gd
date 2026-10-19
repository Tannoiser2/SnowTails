extends SceneTree
## Inquadra ogni segmento fanmade della pista di prova e salva una schermata.
func _init() -> void:
	var c := Course.new()
	if not c.load_file("res://data/courses/fanmade.json"):
		print("ERRORE percorso: ", c.error)
		quit()
		return
	var b := BoardView3D.new()
	root.add_child(b)
	var g := SledGame.new()
	g.setup(c, [true, true, true])
	for p in g.players:
		g.take_slot(p, g.free_slots()[0])
	b.setup(c, g)
	b.current_id = -1
	b.redraw()
	await create_timer(0.5).timeout
	var names := {}
	for pi in c.pieces.size():
		var seg := String(c.pieces[pi]["seg"])
		if seg == "":
			continue
		# una slitta sulla tessera, per avere la misura
		g.players[0].cell = c.pieces[pi]["cells"][14]
		b.redraw()
		var f := SegmentFx.frame(c, pi)
		var mid: Vector2 = f["mid"]
		b.target_goal = BoardView3D.to3(mid)
		b.target = b.target_goal
		var d: Vector2 = f["dir"]
		b.yaw_goal = BoardView3D.yaw_of(d) + (0.9 if seg in ["up", "down"] else 0.5)
		b.yaw = b.yaw_goal
		b.pitch = deg_to_rad(24 if seg in ["up", "down"] else 38)
		b.dist_goal = 5.5
		b.dist = 5.5
		await create_timer(1.2).timeout
		root.get_texture().get_image().save_png("/tmp/shots/fan_%s.png" % seg)
		if OS.get_environment("GIF_SEG") == seg:
			for k in 36:
				await create_timer(0.06).timeout
				root.get_texture().get_image().save_png("/tmp/shots/gif_%s_%02d.png" % [seg, k])
		print("shot ", seg)
	# vista d'insieme di lato per vedere il dislivello
	var a: Vector2 = c.pieces[2]["entry_mid"]
	var z: Vector2 = c.pieces[7]["exit_mid"]
	b.target_goal = BoardView3D.to3((a + z) * 0.5, 0.3)
	b.target = b.target_goal
	b.yaw_goal = BoardView3D.yaw_of((z - a).normalized()) + PI * 0.32
	b.yaw = b.yaw_goal
	b.pitch = deg_to_rad(22)
	b.dist_goal = 17.0
	b.dist = 17.0
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png("/tmp/shots/fan_side.png")
	quit()
