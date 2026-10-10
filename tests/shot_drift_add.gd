extends SceneTree
func _init() -> void:
	var m = load("res://scenes/mapper.tscn").instantiate()
	root.add_child(m)
	await create_timer(0.6).timeout
	m._load(m.ids.find("straight_p16a"))
	(m.mode_btns["drift"] as Button).pressed.emit()
	await process_frame
	m._tap_drift(m.cells[1], 5.0); m._tap_drift(m.cells[7], 5.0)
	m._tap_drift(m.cells[8], 5.0); m._tap_drift(m.cells[3], 5.0)
	m.cam.position = (m.cells[1] + m.cells[7]) * 0.5
	m.cam.zoom = Vector2(2.0, 2.0)
	await create_timer(0.4).timeout
	root.get_texture().get_image().save_png("/tmp/shots/drift_add.png")
	print("aggiunte ", m.drift_add, " tolte ", m.drift_remove, " collegamenti ", m.links.size())
	quit()
