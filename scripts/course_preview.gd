class_name CoursePreview
extends Control
## Anteprima dall'alto di un percorso intero: disegna le tessere già posate.

var course: Course
var message := ""
var _bounds := Rect2()
var _rot := 0.0
var _corners: Array = []
static var _cache := {}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(func():
		_fit()
		queue_redraw())

var _pieces: Array = []      # {xf, face, tex_path, bad}

func show_course(c: Course) -> void:
	var list := []
	for pc in c.pieces:
		list.append({"xf": pc["xf"], "face": pc["face"], "tex_path": pc["tex_path"], "bad": false})
	show_pieces(list, c)

## Disegna pezzi posati anche se il percorso non è completo (editor dei percorsi).
func show_pieces(list: Array, c: Course = null) -> void:
	course = c
	_pieces = list
	message = ""
	_corners = []
	for pc in list:
		var sz := _size_of(pc)
		for corner in [Vector2.ZERO, Vector2(sz.x, 0), sz, Vector2(0, sz.y)]:
			_corners.append((pc["xf"] as Transform2D) * corner)
	_fit()
	queue_redraw()

## Sceglie la rotazione che fa riempire meglio il riquadro alla pista.
func _fit() -> void:
	if _corners.is_empty():
		return
	var best := -1.0
	var box := size if size.x > 10 else Vector2(460, 290)
	for k in 12:
		var ang := deg_to_rad(15.0 * k)
		var r := Rect2(Vector2(_corners[0]).rotated(ang), Vector2.ZERO)
		for p in _corners:
			r = r.expand((p as Vector2).rotated(ang))
		var sc: float = min(box.x / max(r.size.x, 1.0), box.y / max(r.size.y, 1.0))
		if sc > best * 1.03:
			best = sc
			_rot = ang
			_bounds = r

func show_message(t: String) -> void:
	course = null
	_pieces = []
	message = t
	queue_redraw()

func _size_of(pc: Dictionary) -> Vector2:
	var f: Dictionary = pc["face"]
	if f.has("size"):
		return FaceDB.v2(f["size"])
	var t := _tex(pc["tex_path"])
	return t.get_size() / float(f.get("img_scale", 1.0)) if t else Vector2(100, 100)

static func _tex(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var t := FaceDB.load_texture(path)
	if t:
		var img := t.get_image()
		if img:
			if img.is_compressed():
				img.decompress()
			img.generate_mipmaps()
			t = ImageTexture.create_from_image(img)
	_cache[path] = t
	return t

func _draw() -> void:
	draw_style_box(UIKit.box(Color("7f93a6"), 16), Rect2(Vector2.ZERO, size))
	if _pieces.is_empty():
		if message != "":
			var font := ThemeDB.fallback_font
			draw_string(font, Vector2(16, size.y * 0.5), message, HORIZONTAL_ALIGNMENT_CENTER, size.x - 32, 18, Color.WHITE)
		return
	if _bounds.size.x <= 0 or _bounds.size.y <= 0:
		return
	var pad := 12.0
	var sc: float = min((size.x - 2 * pad) / _bounds.size.x, (size.y - 2 * pad) / _bounds.size.y)
	var off: Vector2 = (size - _bounds.size * sc) * 0.5 - _bounds.position * sc
	var view := Transform2D(0.0, Vector2(sc, sc), 0.0, off) * Transform2D(_rot, Vector2.ZERO)
	# ombra sotto le tessere, poi le tessere
	for pass_i in 2:
		for pc in _pieces:
			var t := _tex(pc["tex_path"])
			if t == null:
				continue
			var shift := Transform2D(0.0, Vector2(4, 5)) if pass_i == 0 else Transform2D.IDENTITY
			draw_set_transform_matrix(shift * view * (pc["xf"] as Transform2D))
			var tint := Color.WHITE
			if pass_i == 0:
				tint = Color(0, 0, 0, 0.35)
			elif pc.get("bad", false):
				tint = Color(1.0, 0.55, 0.55)
			draw_texture_rect(t, Rect2(Vector2.ZERO, _size_of(pc)), false, tint)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if course == null:
		return
	# partenza
	if course.start_cells.size() > 2:
		var p: Vector2 = view * (course.cells[course.start_cells[2]]["pos"] as Vector2)
		draw_circle(p, 9, Color("2b8f55"))
		draw_arc(p, 9, 0, TAU, 20, Color.WHITE, 2.5)
	# traguardo
	if course.finish_piece >= 0:
		var a: Vector2 = view * course.finish_a
		var b: Vector2 = view * course.finish_b
		draw_line(a, b, Color("1e3550"), 4.0)
