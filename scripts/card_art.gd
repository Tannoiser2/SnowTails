class_name CardArt
extends RefCounted
## Grafica originale: carte cane 1-5, carta ammaccatura, gettoni freno e plance delle slitte.

const MAT_KEYS := ["red", "blue", "yellow", "green", "black"]
static var _tex := {}
static var _mats := {}

static func _load(path: String) -> Texture2D:
	if _tex.has(path):
		return _tex[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	_tex[path] = t
	return t

## Carta cane di valore v nel colore del giocatore (le carte rosse sono quelle originali).
static func card(v: int, player_id := 0) -> Texture2D:
	var key: String = MAT_KEYS[player_id % MAT_KEYS.size()]
	if key == "red":
		return _load("res://assets/cards/card_%d.webp" % v)
	var t := _load("res://assets/cards/card_%s_%d.webp" % [key, v])
	return t if t else _load("res://assets/cards/card_%d.webp" % v)

static func dent() -> Texture2D:
	return _load("res://assets/cards/card_dent.webp")

static func brake(v: int) -> Texture2D:
	return _load("res://assets/cards/brake_%d.webp" % v)

static func mat(player_id: int) -> Texture2D:
	return _load("res://assets/mats/%s.webp" % MAT_KEYS[player_id % MAT_KEYS.size()])

## Rettangoli normalizzati (0-1) di cane sinistro "L", cane destro "R" e freno "B" sulla plancia.
static func mat_slots(player_id: int) -> Dictionary:
	if _mats.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://assets/mats/mats.json"))
		_mats = d if d is Dictionary else {}
	return _mats.get(MAT_KEYS[player_id % MAT_KEYS.size()], {})
