extends SceneTree
## Prova con tocchi veri: pulsante «Deriva», poi due tocchi sullo schermo.
func _touch(m, w: Vector2) -> void:
	var sp: Vector2 = m.get_canvas_transform() * w
	var e := InputEventScreenTouch.new(); e.index = 0; e.position = sp; e.pressed = true
	m._unhandled_input(e)
	var e2 := InputEventScreenTouch.new(); e2.index = 0; e2.position = sp; e2.pressed = false
	m._unhandled_input(e2)

func _init() -> void:
	var m = load("res://scenes/mapper.tscn").instantiate()
	root.add_child(m)
	await create_timer(0.6).timeout
	var id := "straight_p16a"
	FaceDB.reset_face(id)
	m._load(m.ids.find(id))
	await process_frame
	(m.mode_btns["drift"] as Button).pressed.emit()
	await process_frame
	print("modalità: ", m.mode)
	var n_links: int = m.links.size()
	_touch(m, m.cells[0])
	await process_frame
	_touch(m, m.cells[14])
	await process_frame
	print("collegamenti prima/dopo: ", n_links, "/", m.links.size(), "  derive aggiunte: ", m.drift_add, "  tolte: ", m.drift_remove)
	quit()
