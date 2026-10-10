extends SceneTree
func _init() -> void:
	var m = load("res://scenes/mapper.tscn").instantiate()
	root.add_child(m)
	await create_timer(0.6).timeout
	m._load(m.ids.find("corner_L_p07"))
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png("/tmp/shots/m1.png")
	m.show_drift = true
	m._refresh()
	m.cam.zoom *= 1.8
	m.cam.position = m.cells[3] if m.cells.size() > 3 else m.cam.position
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png("/tmp/shots/m2.png")
	quit()
