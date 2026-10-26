extends SceneTree
## Confronta le derive del gioco (su tutto il percorso) con quelle che l'editor mostra per ogni faccia.
func _face_drifts(face: Dictionary) -> Array:
	var dc := Course.face_drifts(face)
	var out := {}
	for sd in 2:
		for i in (dc[sd] as Array).size():
			for j in dc[sd][i]:
				out["%d>%d" % [i, j]] = true
	return [out, (face["cells"] as Array).size()]

func _init() -> void:
	var da := DirAccess.open("res://data/courses/")
	var seen := {}
	for f in da.get_files():
		if not f.ends_with(".json"): continue
		var c := Course.new()
		if not c.load_file("res://data/courses/" + f): continue
		for pi in c.pieces.size():
			var pc: Dictionary = c.pieces[pi]
			var face: Dictionary = pc["face"]
			var ids: Array = pc["cells"]
			var fd := _face_drifts(face)
			var exp: Dictionary = fd[0]
			if ids.size() != int(fd[1]):
				print(f, " pezzo ", pi, " ", face["id"], ": caselle ", ids.size(), " vs faccia ", fd[1])
			var got := {}
			var cross := []
			for a in ids.size():
				var c0: Dictionary = c.cells[ids[a]]
				for t in c0["dl"] + c0["dr"]:
					var b := ids.find(t)
					if b < 0:
						cross.append("%d>%s" % [a, str(t)])
					else:
						got["%d>%d" % [a, b]] = true
			var extra := []
			var miss := []
			for k in got:
				if not exp.has(k): extra.append(k)
			for k in exp:
				if not got.has(k): miss.append(k)
			var key := "%s|%s|%s|%s" % [face["id"], str(extra), str(miss), str(cross.size())]
			if (extra.size() > 0 or miss.size() > 0 or cross.size() > 0) and not seen.has(key):
				seen[key] = true
				print(f, " ", face["id"], " in più nel gioco: ", extra, " mancano: ", miss, " verso altre tessere: ", cross)
	quit()
