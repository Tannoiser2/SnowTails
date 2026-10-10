extends SceneTree
func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.8).timeout
	root.get_texture().get_image().save_png("/tmp/shots/menu_a.png")
	main.course_idx = main.course_files.find("res://data/courses/hobbit.json")
	main.show_menu()
	await create_timer(0.6).timeout
	root.get_texture().get_image().save_png("/tmp/shots/menu_b.png")
	main.course_idx = main.course_files.size()
	main.rnd_diff = 2
	main.rnd_len = 2
	main.rnd_def = {}
	main.show_menu()
	await create_timer(0.8).timeout
	root.get_texture().get_image().save_png("/tmp/shots/menu_c.png")
	quit()
