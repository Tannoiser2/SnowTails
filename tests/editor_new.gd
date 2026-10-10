extends SceneTree
func _touch(m, w: Vector2) -> void:
	var sp: Vector2 = m.get_canvas_transform() * w
	for pressed in [true, false]:
		var e := InputEventScreenTouch.new(); e.index = 0; e.position = sp; e.pressed = pressed
		m._unhandled_input(e)
func _init() -> void:
	var m = load("res://scenes/mapper.tscn").instantiate()
	root.add_child(m)
	await create_timer(0.6).timeout
	m._load(m.ids.find("straight_p16a"))
	(m.mode_btns["chain"] as Button).pressed.emit()
	await process_frame
	var n: int = m.links.size()
	var l: Array = m.links[0]
	_touch(m, m.cells[l[0]]); _touch(m, m.cells[l[1]])
	print("avanti: tolto ", m.links.size() == n - 1)
	_touch(m, m.cells[l[0]]); _touch(m, m.cells[l[1]])
	print("avanti: rimesso ", m.links.size() == n)
	(m.mode_btns["cells"] as Button).pressed.emit()
	var nc: int = m.cells.size()
	_touch(m, m.cells[0] + Vector2(0, -300))
	print("caselle: aggiunta ", m.cells.size() == nc + 1)
	_touch(m, m.cells[m.cells.size() - 1])
	print("caselle: tolta ", m.cells.size() == nc)
	m._load(m.ids.find("uturn_R_p02"))
	(m.mode_btns["drift"] as Button).pressed.emit()
	await create_timer(0.4).timeout
	root.get_texture().get_image().save_png("/tmp/shots/editor_new.png")
	quit()
