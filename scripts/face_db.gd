class_name FaceDB
extends RefCounted
## Carica e salva le definizioni delle facce delle tessere.
## Le correzioni fatte nell'editor si salvano SEMPRE in user://faces (la cartella dati
## dell'utente, fuori dal progetto): gli aggiornamenti del progetto non le toccano.
## Contengono solo la rete (caselle e collegamenti) più l'ingresso della faccia al
## momento del salvataggio, così restano allineate anche se l'immagine viene rifatta.

const RES_DIR := "res://data/faces/"
const USER_DIR := "user://faces/"

static func load_face(id: String) -> Dictionary:
	var base := _read(RES_DIR + id + ".json")
	var user := _read(USER_DIR + id + ".json")
	if base.is_empty():
		return normalize(user) if not user.is_empty() else {}
	base = normalize(base)
	if user.is_empty():
		return base
	return _apply_override(base, normalize(user))

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}

## Applica la rete corretta dall'utente alla faccia di base, compensando un eventuale
## spostamento dell'immagine (si allinea sul punto d'ingresso).
static func _apply_override(base: Dictionary, user: Dictionary) -> Dictionary:
	var ref = user.get("ref_entry", null)
	if ref == null and user.has("entry"):
		ref = user["entry"]["mid"]
	var delta := Vector2.ZERO
	if ref != null:
		delta = v2(base["entry"]["mid"]) - v2(ref)
	var cells := []
	for p in user.get("cells", []):
		var q := v2(p) + delta
		cells.append([snapped(q.x, 0.1), snapped(q.y, 0.1)])
	var d := base.duplicate(true)
	d["cells"] = cells
	d["links"] = (user.get("links", []) as Array).duplicate(true)
	if user.has("drift_add") or user.has("drift_remove"):
		d["drift_add"] = (user.get("drift_add", []) as Array).duplicate(true)
		d["drift_remove"] = (user.get("drift_remove", []) as Array).duplicate(true)
	d["user_edited"] = true
	d["user_saved_at"] = user.get("saved_at", "")
	d.erase("doubts")
	# gli elementi speciali (alberelli, spaccatura) restano quelli della base solo se la rete non è cambiata
	if (user.get("cells", []) as Array).size() != (base.get("cells", []) as Array).size():
		d.erase("saplings")
		d.erase("crevasse")
	return d

static func has_user_override(id: String) -> bool:
	return FileAccess.file_exists(USER_DIR + id + ".json")

static func reset_face(id: String) -> void:
	var path := USER_DIR + id + ".json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

## Scrive la faccia corretta (base + correzione) dentro il progetto e toglie la correzione.
## Funziona solo avviando il gioco dall'editor di Godot, dove res:// è scrivibile.
static func incorporate(id: String) -> String:
	if not OS.has_feature("editor"):
		return "Si può fare solo avviando il gioco dall'editor di Godot."
	var d := load_face(id)
	if d.is_empty() or not d.get("user_edited", false):
		return "Questa faccia non ha correzioni da incorporare."
	for k in ["user_edited", "user_saved_at", "doubts", "lanes"]:
		d.erase(k)
	d["auto"] = false
	d["verified"] = true
	var f := FileAccess.open(RES_DIR + id + ".json", FileAccess.WRITE)
	if f == null:
		return "Non riesco a scrivere nel progetto."
	f.store_string(JSON.stringify(d, " "))
	f.close()
	reset_face(id)
	return ""

## Tutte le correzioni salvate su questo dispositivo, in un solo file da mandare (per incorporarle
## nel progetto quando il gioco non gira dall'editor: web, iPad, app esportata).
## Restituisce dove è finito il file, oppure "" se non ci sono correzioni.
static func export_corrections() -> String:
	var bundle := {"snowtails_corrections": 1, "saved_at": Time.get_datetime_string_from_system(), "faces": {}}
	var da := DirAccess.open(USER_DIR)
	if da == null:
		return ""
	for f in da.get_files():
		if f.ends_with(".json"):
			var d := _read(USER_DIR + f)
			if not d.is_empty() and d.has("cells"):
				bundle["faces"][f.get_basename()] = d
	if (bundle["faces"] as Dictionary).is_empty():
		return ""
	var txt := JSON.stringify(bundle, " ")
	var name := "snowtails_correzioni.json"
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(txt.to_utf8_buffer(), name, "application/json")
		return "Download: " + name
	var dir := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if dir == "" or not DirAccess.dir_exists_absolute(dir):
		dir = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	if dir == "" or not DirAccess.dir_exists_absolute(dir):
		dir = ProjectSettings.globalize_path("user://")
	var path := dir.path_join(name)
	var fa := FileAccess.open(path, FileAccess.WRITE)
	if fa == null:
		return ""
	fa.store_string(txt)
	fa.close()
	return path

## Incorpora nel progetto le correzioni di un file esportato (dall'editor o da riga di comando).
static func import_corrections(path: String) -> Array:
	var b := _read(path)
	var done := []
	for id in (b.get("faces", {}) as Dictionary):
		var base := _read(RES_DIR + String(id) + ".json")
		if base.is_empty():
			continue
		var d := _apply_override(normalize(base), normalize(b["faces"][id]))
		for k in ["user_edited", "user_saved_at", "doubts", "lanes"]:
			d.erase(k)
		d["auto"] = false
		d["verified"] = true
		var f := FileAccess.open(RES_DIR + String(id) + ".json", FileAccess.WRITE)
		if f == null:
			continue
		f.store_string(JSON.stringify(d, " "))
		f.close()
		done.append(id)
	return done

static func user_dir_global() -> String:
	if not DirAccess.dir_exists_absolute(USER_DIR):
		DirAccess.make_dir_recursive_absolute(USER_DIR)
	return ProjectSettings.globalize_path(USER_DIR)

## Converte il vecchio formato a corsie ("lanes") nel formato a rete:
## "cells" = centri delle caselle, "links" = collegamenti in avanti [da, a].
## Per la partenza l'ordine delle caselle corrisponde alle posizioni 1-5.
static func normalize(d: Dictionary) -> Dictionary:
	if d.has("cells") and (d["cells"] as Array).size() > 0:
		return d
	var cells := []
	var links := []
	if d.has("lanes"):
		for lane in d["lanes"]:
			var prev := -1
			for pt in lane:
				var p := v2(pt)
				var idx := -1
				for i in cells.size():
					if v2(cells[i]).distance_to(p) < 4.0:
						idx = i
						break
				if idx < 0:
					idx = cells.size()
					cells.append([p.x, p.y])
				if prev >= 0 and prev != idx:
					var l := [prev, idx]
					if not links.has(l):
						links.append(l)
				prev = idx
	d["cells"] = cells
	d["links"] = links
	return d

static func list_ids() -> Array:
	var ids := []
	for dir in [RES_DIR]:
		var da := DirAccess.open(dir)
		if da == null:
			continue
		for f in da.get_files():
			if f.ends_with(".json"):
				var id := f.get_basename()
				if not ids.has(id):
					ids.append(id)
	ids.sort()
	return ids

static func save_face(d: Dictionary) -> String:
	if not DirAccess.dir_exists_absolute(USER_DIR):
		DirAccess.make_dir_recursive_absolute(USER_DIR)
	var out := {"id": d["id"], "cells": d.get("cells", []), "links": d.get("links", []),
		"drift_add": d.get("drift_add", []), "drift_remove": d.get("drift_remove", []),
		"ref_entry": d["entry"]["mid"], "saved_at": Time.get_datetime_string_from_system()}
	var path: String = USER_DIR + String(d["id"]) + ".json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(out, " "))
	f.close()
	return ProjectSettings.globalize_path(path)

static func is_mapped(d: Dictionary) -> bool:
	var cells: Array = d.get("cells", [])
	if cells.is_empty():
		return false
	if String(d.get("type", "")) in ["start"]:
		return cells.size() >= 5
	return not (d.get("links", []) as Array).is_empty() or cells.size() <= 5

static func load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var t = load(path)
		if t is Texture2D:
			return t
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		return null
	return ImageTexture.create_from_image(img)

static func v2(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))
