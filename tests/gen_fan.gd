extends SceneTree
## Piste casuali con i segmenti fanmade: devono venire valide e finire in pianura.
func _init() -> void:
	var okn := 0
	var fans := 0
	for i in 12:
		var gen := CourseGen.new()
		var d := gen.generate(i % 3, (i / 3) % 3, 1000 + i, true)
		if d.is_empty():
			continue
		var c := Course.new()
		if c.build(d):
			okn += 1
			for pid in d["pieces"]:
				if String(pid).begins_with("fan_"): fans += 1
			var last_h: float = c.pieces[c.finish_piece]["h0"]
			if last_h > 0.01:
				print("ATTENZIONE arrivo in alto: ", d["pieces"])
	print("PISTE FANMADE valide %d/12, segmenti fanmade in tutto %d" % [okn, fans])
	quit()
