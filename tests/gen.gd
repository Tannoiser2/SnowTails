extends SceneTree
func _init() -> void:
	var g := CourseGen.new()
	var t0 := Time.get_ticks_msec()
	for d in 3:
		for l in 3:
			var ok := 0
			var last := {}
			for k in 6:
				var def := g.generate(d, l)
				if not def.is_empty():
					ok += 1
					last = def
			print("diff ", d, " lung ", l, ": ", ok, "/6  ", last.get("note", g.last_error), "  ", (last.get("pieces", []) as Array).size(), " tessere")
	print("tempo ", Time.get_ticks_msec() - t0, " ms")
	quit()
