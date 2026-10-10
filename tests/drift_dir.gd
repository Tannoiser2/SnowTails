extends SceneTree
func _has(m, a: int, b: int) -> bool:
	return (m._drift_cache[0][a] as Array).has(b) or (m._drift_cache[1][a] as Array).has(b)
func _init() -> void:
	var m = load("res://scenes/mapper.tscn").instantiate()
	root.add_child(m)
	await create_timer(0.6).timeout
	m._load(m.ids.find("straight_p16a"))
	(m.mode_btns["drift"] as Button).pressed.emit()
	await process_frame
	# due caselle senza diagonale: la aggiungo "all'indietro" apposta (14 -> 0)
	m._tap_drift(m.cells[14], 5.0); m._tap_drift(m.cells[0], 5.0)
	print("14->0 presente: ", _has(m, 14, 0), "   0->14 presente: ", _has(m, 0, 14))
	# una diagonale calcolata a->b; la tocco al contrario b->a: deve girarsi verso il secondo punto
	var b: int = (m._auto_drift[0][0] + m._auto_drift[1][0])[0]
	m._tap_drift(m.cells[b], 5.0); m._tap_drift(m.cells[0], 5.0)
	print("dopo il tocco ", b, "->0:  ", b, "->0 presente ", _has(m, b, 0), ",  0->", b, " presente ", _has(m, 0, b))
	quit()
