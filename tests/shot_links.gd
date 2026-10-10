extends SceneTree
func _init() -> void:
	var m = load("res://scenes/mapper.tscn").instantiate()
	root.add_child(m)
	await create_timer(0.6).timeout
	for spec in [["straight_p16a", "rett"], ["corner_L_p07", "curva"]]:
		m._load(m.ids.find(spec[0]))
		m.show_drift = true
		m._refresh()
		await process_frame
		var c: Vector2 = Vector2.ZERO
		for p in m.cells: c += p
		c /= max(m.cells.size(), 1)
		m.cam.position = c
		m.cam.zoom = Vector2(1.25, 1.25) if spec[1] == "rett" else Vector2(1.0, 1.0)
		await create_timer(0.4).timeout
		root.get_texture().get_image().save_png("/tmp/shots/links_%s.png" % spec[1])
	quit()
