extends SceneTree
## Uso: godot --headless --path . -s tools/incorpora_correzioni.gd -- percorso/snowtails_correzioni.json
## Scrive in data/faces le facce con le correzioni del file esportato dal gioco.
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("Manca il file delle correzioni")
		quit(1)
		return
	print("Incorporate: ", FaceDB.import_corrections(args[0]))
	quit()
