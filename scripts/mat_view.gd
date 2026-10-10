class_name MatView
extends Control
## Plancia della slitta con le carte e il gettone freno veri.
## Le carte giocate coprono i cani stampati; quelle in attesa di conferma hanno il bordo verde.

signal slot_tapped(slot: String)

var player = null          # SledGame.Player
var pending: Array = []    # {slot, v}
var interactive := false
var targeting := false     # una carta è selezionata: evidenzia gli spazi
var _rects := {}
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	resized.connect(queue_redraw)

func setup(p, pend: Array, inter: bool, target: bool) -> void:
	player = p
	pending = pend
	interactive = inter
	targeting = target
	queue_redraw()

func _process(delta: float) -> void:
	if targeting:
		_t += delta
		queue_redraw()

func _pend(slot: String) -> Variant:
	for x in pending:
		if x["slot"] == slot:
			return x
	return null

func _draw() -> void:
	if player == null:
		return
	var tex := CardArt.mat(player.id)
	if tex == null:
		return
	var ts := tex.get_size()
	var sc: float = min(size.x / ts.x, size.y / ts.y)
	var dsz := ts * sc
	var org := (size - dsz) * 0.5
	draw_texture_rect(tex, Rect2(org, dsz), false)
	var slots := CardArt.mat_slots(player.id)
	_rects.clear()
	for k in ["L", "R", "B"]:
		if not slots.has(k):
			continue
		var r: Array = slots[k]
		var rect := Rect2(org + Vector2(r[0], r[1]) * dsz, Vector2(r[2] - r[0], r[3] - r[1]) * dsz)
		_rects[k] = rect
		var pd: Variant = _pend(k)
		var val: int
		var has_card := true
		if pd != null:
			val = pd["v"]
		elif k == "L":
			val = player.L
			has_card = player.lc
		elif k == "R":
			val = player.R
			has_card = player.rc
		else:
			val = player.B
		if k == "B":
			var tt := CardArt.brake(val)
			if tt:
				var tsz := tt.get_size()
				var s2: float = min(rect.size.x / tsz.x, rect.size.y / tsz.y) * 0.98
				var tr := Rect2(rect.get_center() - tsz * s2 * 0.5, tsz * s2)
				draw_texture_rect(tt, tr, false)
		elif has_card:
			var ct := CardArt.card(val, player.id)
			if ct:
				var grow := rect.grow(rect.size.x * 0.03)
				if pd != null:
					grow = grow.grow(rect.size.x * 0.02)
					draw_rect(grow.grow(3), Color(0, 0, 0, 0.25))
				draw_texture_rect(ct, grow, false)
		if pd != null:
			draw_rect(rect.grow(rect.size.x * 0.05), Color("147f7a"), false, 4.0)
		elif interactive and targeting:
			var a := 0.35 + 0.25 * sin(_t * 5.0)
			draw_rect(rect, Color(0.08, 0.5, 0.48, a * 0.35))
			draw_rect(rect, Color(0.08, 0.5, 0.48, a + 0.3), false, 3.0)

func _gui_input(ev: InputEvent) -> void:
	if not interactive:
		return
	var pos := Vector2.INF
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		pos = ev.position
	elif ev is InputEventScreenTouch and ev.pressed:
		pos = ev.position
	if pos == Vector2.INF:
		return
	for k in ["L", "R", "B"]:
		if _rects.has(k) and (_rects[k] as Rect2).grow(6).has_point(pos):
			slot_tapped.emit(k)
			accept_event()
			return
