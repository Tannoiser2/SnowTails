extends SceneTree
## Confronta le derive del gioco (su tutto il percorso) con quelle che l'editor mostra per ogni faccia.
func _face_drifts(face: Dictionary) -> Array:
	var cells := []
	for p in face["cells"]:
		cells.append(FaceDB.v2(p))
	var links: Array = face.get("links", [])
	var fwd := []
	var bwd := []
	for i in cells.size():
		fwd.append([]); bwd.append([])
	for l in links:
		fwd[l[0]].append(l[1]); bwd[l[1]].append(l[0])
	var heads := []
	var fb := FaceDB.v2(face["entry"]["dir"]).normalized()
	for i in cells.size():
		heads.append(Course.heading_of(cells[i], fwd[i].map(func(j): return cells[j]), bwd[i].map(func(j): return cells[j]), fb))
	var dc := Course.drift_targets(cells, fwd, heads, 97.4, float(face.get("lane_width", 53.8)))
	for e in face.get("drift_remove", []):
		(dc[0][int(e[0])] as Array).erase(int(e[1])); (dc[1][int(e[0])] as Array).erase(int(e[1]))
	for e in face.get("drift_add", []):
		var sd := 0 if e[2] == "L" else 1
		if not (dc[sd][int(e[0])] as Array).has(int(e[1])): dc[sd][int(e[0])].append(int(e[1]))
	var out := {}
	for sd in 2:
		for i in cells.size():
			for j in dc[sd][i]:
				out["%d>%d" % [i, j]] = true
	return [out, cells.size()]

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
