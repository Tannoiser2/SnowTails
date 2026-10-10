extends SceneTree
func _init() -> void:
	var m = load("res://scenes/mapper.tscn").instantiate()
	root.add_child(m)
	await create_timer(0.6).timeout
	m._load(m.ids.find("uturn_R_p02"))
	m.mode = "drift"
	m.show_drift = true
	m._refresh()
	await process_frame
	var a := 18
	var t: Array = m._auto_drift[0][a] + m._auto_drift[1][a]
	if t.size() > 0:
		m._tap_drift(m.cells[a], 5.0); m._tap_drift(m.cells[t[0]], 5.0)
	m._tap_drift(m.cells[21], 5.0); m._tap_drift(m.cells[27], 5.0)
	m._tap_drift(m.cells[25], 5.0)
	m.cam.position = m.cells[21]
	m.cam.zoom = Vector2(1.6, 1.6)
	await create_timer(0.4).timeout
	root.get_texture().get_image().save_png("/tmp/shots/drift_edit.png")
	quit()
