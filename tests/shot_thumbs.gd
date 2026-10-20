extends SceneTree
func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.8).timeout
	root.get_texture().get_image().save_png("/tmp/shots/thumbs_%s.png" % OS.get_environment("TAG"))
	quit()
