extends SceneTree
## Menu con la pista casuale fanmade scelta.
func _press(n: Node, text: String) -> bool:
	if n is Button and (n as Button).text == text:
		(n as Button).pressed.emit()
		return true
	for c in n.get_children():
		if _press(c, text):
			return true
	return false
func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.6).timeout
	_press(main.modal_layer, "Pista casuale")
	await create_timer(0.5).timeout
	_press(main.modal_layer, "sì: pendii, vento, ghiaccio…")
	await create_timer(0.8).timeout
	root.get_texture().get_image().save_png("/tmp/shots/menu_random.png")
	print("casuale=", main._is_random(), " fan=", main.rnd_fan, " pezzi=", (main.rnd_def.get("pieces", []) as Array).size())
	quit()
