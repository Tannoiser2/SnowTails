extends SceneTree
func _init() -> void:
	var m = load("res://scenes/mapper.tscn").instantiate()
	root.add_child(m)
	await create_timer(0.6).timeout
	m._load(m.ids.find("straight_p16a"))
	(m.mode_btns["drift"] as Button).pressed.emit()
	await process_frame
	var t: int = (m._drift_cache[0][0] + m._drift_cache[1][0])[0]
	# tolgo toccando prima l'arrivo e poi la partenza
	m._tap_drift(m.cells[t], 5.0); m._tap_drift(m.cells[0], 5.0)
	print("dopo aver tolto: visibile ", (m._drift_cache[0][0] + m._drift_cache[1][0]).has(t), "  tolte ", m.drift_remove)
	m._tap_drift(m.cells[0], 5.0); m._tap_drift(m.cells[t], 5.0)
	print("dopo averla rimessa: visibile ", (m._drift_cache[0][0] + m._drift_cache[1][0]).has(t), "  tolte ", m.drift_remove, " aggiunte ", m.drift_add)
	quit()
