extends SceneTree
## Prova dell'editor: togli una deriva calcolata e aggiungine una nuova, salva, e verifica nel percorso.
func _init() -> void:
	var m = load("res://scenes/mapper.tscn").instantiate()
	root.add_child(m)
	await create_timer(0.6).timeout
	var id := "straight_p16a"
	FaceDB.reset_face(id)
	m._load(m.ids.find(id))
	m.show_drift = true
	m._refresh()
	await process_frame
	m.mode = "drift"
	# casella 0 (corsia 0): ha una deriva calcolata verso la corsia 1
	var a := 0
	var auto_targets: Array = m._auto_drift[0][a] + m._auto_drift[1][a]
	print("derive calcolate da 0: ", auto_targets)
	m._tap_drift(m.cells[a], 5.0)
	m._tap_drift(m.cells[auto_targets[0]], 5.0)
	# aggiunge una deriva "strana": da 0 alla casella 2 della stessa corsia+2 (solo per prova)
	m._tap_drift(m.cells[a], 5.0)
	m._tap_drift(m.cells[14], 5.0)
	print("aggiunte ", m.drift_add, " tolte ", m.drift_remove)
	m._save()
	var c := Course.new()
	c.build({"name": "t", "pieces": ["start_p21", "straight_p16a", "finish_p21", "straight_p14a"]})
	var base: int = c.pieces[1]["cells"][0]
	var gid_rm: int = c.pieces[1]["cells"][auto_targets[0]]
	var gid_add: int = c.pieces[1]["cells"][14]
	var all: Array = c.cells[base]["dl"] + c.cells[base]["dr"]
	print("nel percorso: tolta assente ", not all.has(gid_rm), ", aggiunta presente ", all.has(gid_add))
	FaceDB.reset_face(id)
	quit()
