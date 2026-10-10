class_name CardView
extends Control
## Una carta in mano (immagine vera). Selezionata si alza e prende il bordo verde.

signal pressed

var value := 0             # 1-5, oppure 0 = ammaccatura
var owner_id := 0         # giocatore: colore delle carte
var selected := false
var reserved := false      # già messa sulla plancia (in attesa di conferma)
var disabled := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func setup(v: int, sel: bool, res: bool, dis: bool, owner := 0) -> void:
	value = v
	owner_id = owner
	selected = sel
	reserved = res
	disabled = dis
	queue_redraw()

func _draw() -> void:
	var tex := CardArt.card(value, owner_id) if value > 0 else CardArt.dent()
	if tex == null:
		return
	var ts := tex.get_size()
	var h := size.y - 10.0
	var w: float = h * ts.x / ts.y
	if w > size.x:
		w = size.x
		h = w * ts.y / ts.x
	var lift := -8.0 if selected else 0.0
	var r := Rect2(Vector2((size.x - w) * 0.5, 8.0 + lift), Vector2(w, h))
	draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.22))
	var mod := Color.WHITE
	if reserved:
		mod = Color(1, 1, 1, 0.3)
	elif disabled and value > 0:
		mod = Color(0.75, 0.75, 0.75, 0.75)
	draw_texture_rect(tex, r, false, mod)
	if selected:
		draw_rect(r.grow(2), Color("147f7a"), false, 4.0)

func _gui_input(ev: InputEvent) -> void:
	if disabled or value <= 0:
		return
	if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed):
		pressed.emit()
		accept_event()
