extends SceneTree
func _find(n: Node, text: String) -> Button:
	if n is Button and (n as Button).text.begins_with(text): return n
	for c in n.get_children():
		var r := _find(c, text)
		if r: return r
	return null
func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.8).timeout
	var tag := OS.get_environment("TAG")
	root.get_texture().get_image().save_png("/tmp/shots/ru_menu_%s.png" % tag)
	_find(main.modal_layer, "Regole").pressed.emit()
	await create_timer(0.5).timeout
	root.get_texture().get_image().save_png("/tmp/shots/ru_base_%s.png" % tag)
	_find(main.modal_layer, "Mostra anche").pressed.emit()
	await create_timer(0.5).timeout
	var sc: ScrollContainer = null
	for n in main.modal_layer.find_children("*", "ScrollContainer", true, false):
		sc = n
	sc.scroll_vertical = 100000
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png("/tmp/shots/ru_fan_%s.png" % tag)
	_find(main.modal_layer, "Chiudi").pressed.emit()
	await create_timer(0.5).timeout
	print("dopo chiudi: menu? ", main._menu_tab_box != null and main._menu_tab_box.is_inside_tree())
	quit()
