extends SceneTree
## Solo per i test: crea in user://faces una mappatura sintetica (curve di Bézier)
## per curve e inversioni, così il percorso Nutcracker si può collaudare.
## Con l'argomento "clean" la rimuove.
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] == "clean":
		for id in ["corner_L_p07", "uturn_R_p02", "corner_R_p08", "uturn_L_p01"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://faces/" + id + ".json"))
		print("pulito"); quit(); return
	DirAccess.make_dir_recursive_absolute("user://faces")
	for id in ["corner_L_p07", "uturn_R_p02", "corner_R_p08", "uturn_L_p01"]:
		var f := FaceDB.load_face(id)
		var lw := float(f["lane_width"])
		var em := FaceDB.v2(f["entry"]["mid"]); var ed := FaceDB.v2(f["entry"]["dir"]).normalized()
		var xm := FaceDB.v2(f["exit"]["mid"]); var xd := FaceDB.v2(f["exit"]["dir"]).normalized()
		var el := Vector2(ed.y, -ed.x); var xl := Vector2(xd.y, -xd.x)
		var lanes := []
		for k in 5:
			var a := em + el * lw * (2 - k)
			var b := xm + xl * lw * (2 - k)
			var D := a.distance_to(b) * (0.55 if f["type"] == "corner" else 1.1)
			var c1 := a + ed * D; var c2 := b - xd * D
			var pts := []
			var L := 0.0; var prev := a
			for i in range(1, 201):
				var t := i / 200.0
				var p := a.bezier_interpolate(c1, c2, b, t)
				L += p.distance_to(prev); prev = p
			var n: int = max(1, int(round(L / 97.0)))
			for j in n:
				var t := (j + 0.5) / n
				var p := a.bezier_interpolate(c1, c2, b, t)
				pts.append([p.x, p.y])
			lanes.append(pts)
		f["lanes"] = lanes
		var file := FileAccess.open("user://faces/" + id + ".json", FileAccess.WRITE)
		file.store_string(JSON.stringify(f)); file.close()
		print(id, " corsie: ", lanes.map(func(l): return l.size()))
	quit()
