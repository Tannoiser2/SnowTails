class_name CourseLibrary
extends RefCounted
## Libreria online delle piste create con l'editor (Firebase, snowtails/library/<chiave>/<pista>).
## La chiave viene da una parola segreta scelta dal giocatore: su ogni dispositivo dove la si
## inserisce si ritrovano le stesse piste. Sul dispositivo restano anche le copie locali
## (user://courses), così le piste si usano pure senza rete.
## Le piste cancellate restano come «lapide» ({deleted: true}) perché la cancellazione arrivi
## anche agli altri dispositivi.

const PATH := "snowtails/library"

static func key_of(word: String) -> String:
	return ("snowtails-library:" + word.strip_edges().to_lower()).sha256_text().substr(0, 40)

static func word(net: Net) -> String:
	return str(net.load_session().get("lib", ""))

static func set_word(net: Net, w: String) -> void:
	net._save({"lib": w.strip_edges()})

static func linked(net: Net) -> bool:
	return word(net) != ""

static func _local_files() -> Dictionary:
	var out := {}
	var da := DirAccess.open(CourseEditor.USER_DIR)
	if da == null:
		return out
	for f in da.get_files():
		if f.ends_with(".json"):
			out[f.get_basename()] = CourseEditor.USER_DIR + f
	return out

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}

static func _write(path: String, d: Dictionary) -> void:
	if not DirAccess.dir_exists_absolute(CourseEditor.USER_DIR):
		DirAccess.make_dir_recursive_absolute(CourseEditor.USER_DIR)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d, " "))
		f.close()

static func _url_path(net: Net, tid := "") -> String:
	var p := "%s/%s" % [PATH, key_of(word(net))]
	return p if tid == "" else p + "/" + tid

## Allinea le piste locali e quelle online: vale la versione salvata per ultima.
## Restituisce {ok, down, up, gone, error}.
static func sync(net: Net) -> Dictionary:
	var res := {"ok": false, "down": 0, "up": 0, "gone": 0, "error": ""}
	if not linked(net):
		res["error"] = "Libreria non collegata."
		return res
	if not await net.sign_in():
		res["error"] = net.last_error
		return res
	var r := await net.db_get(_url_path(net))
	if r["code"] != 200:
		res["error"] = "risposta %d" % int(r["code"])
		return res
	var remote := Net._as_dict(r["data"])
	var local := _local_files()
	for tid in remote:
		var e = remote[tid]
		if not e is Dictionary:
			continue
		var rt := str(e.get("saved_at", ""))
		var ld := _read(local[tid]) if local.has(tid) else {}
		var lt := str(ld.get("saved_at", ""))
		if e.get("deleted", false):
			if local.has(tid) and rt >= lt:
				DirAccess.remove_absolute(local[tid])
				local.erase(tid)
				res["gone"] += 1
			continue
		if not local.has(tid) or rt > lt:
			var d = JSON.parse_string(str(e.get("def", "")))
			if d is Dictionary:
				d["saved_at"] = rt
				_write(CourseEditor.USER_DIR + tid + ".json", d)
				res["down"] += 1
	for tid in local:
		var ld := _read(local[tid])
		if ld.is_empty():
			continue
		var e = remote.get(tid, null)
		var rt := str(e.get("saved_at", "")) if e is Dictionary else ""
		var lt := str(ld.get("saved_at", ""))
		if e == null or (lt > rt) or (e is Dictionary and e.get("deleted", false) and lt > rt):
			if lt == "":
				lt = Time.get_datetime_string_from_system(true)
				ld["saved_at"] = lt
				_write(local[tid], ld)
			if await upload(net, tid, ld):
				res["up"] += 1
	res["ok"] = true
	return res

## Carica una pista nella libreria (se collegata).
static func upload(net: Net, tid: String, def: Dictionary) -> bool:
	if not linked(net) or not await net.sign_in():
		return false
	var body := {"name": str(def.get("name", tid)), "def": JSON.stringify(def), "saved_at": str(def.get("saved_at", Time.get_datetime_string_from_system(true)))}
	var r := await net.db_put(_url_path(net, tid), body)
	return r["code"] == 200

## La pista è stata cancellata qui: anche negli altri dispositivi va tolta.
static func remove(net: Net, tid: String) -> bool:
	if not linked(net) or not await net.sign_in():
		return false
	var r := await net.db_put(_url_path(net, tid), {"name": tid, "deleted": true, "saved_at": Time.get_datetime_string_from_system(true)})
	return r["code"] == 200
