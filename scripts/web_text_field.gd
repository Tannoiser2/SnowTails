class_name WebTextField
extends Node
## Campo HTML invisibile tenuto sopra un LineEdit (nel browser, sui dispositivi touch):
## toccandolo si apre la tastiera del sistema e il testo passa al LineEdit.

static var _n := 0
var _le: LineEdit
var _el: JavaScriptObject
var _cb_input: JavaScriptObject
var _cb_key: JavaScriptObject
var _cb_blur: JavaScriptObject
var _last := ""

func _ready() -> void:
	_le = get_parent() as LineEdit
	if _le == null or not OS.has_feature("web") or not DisplayServer.is_touchscreen_available():
		set_process(false)
		return
	_n += 1
	var doc := JavaScriptBridge.get_interface("document")
	_el = doc.createElement("input")
	_el.type = "text"
	_el.id = "godot-text-%d" % _n
	_el.setAttribute("autocomplete", "off")
	_el.setAttribute("autocorrect", "off")
	_el.setAttribute("enterkeyhint", "done")
	if _le.max_length > 0:
		_el.setAttribute("maxlength", str(_le.max_length))
	# trasparente ma presente: il tocco arriva al campo vero e Safari apre la tastiera;
	# 16px evita lo zoom automatico di iOS
	_el.setAttribute("style", "position:fixed;left:0;top:0;width:10px;height:10px;z-index:20;opacity:0.02;" +
		"border:0;margin:0;padding:0;background:transparent;color:transparent;caret-color:transparent;" +
		"font-size:16px;outline:none;-webkit-appearance:none;display:none;")
	_el.value = _le.text
	_cb_input = JavaScriptBridge.create_callback(_on_input)
	_cb_key = JavaScriptBridge.create_callback(_on_key)
	_cb_blur = JavaScriptBridge.create_callback(_on_blur)
	_el.addEventListener("input", _cb_input)
	_el.addEventListener("keydown", _cb_key)
	_el.addEventListener("blur", _cb_blur)
	doc.body.appendChild(_el)
	_last = _le.text

func _on_input(_args) -> void:
	var t := String(_el.value)
	if _le.max_length > 0:
		t = t.substr(0, _le.max_length)
	_last = t
	_le.text = t
	_le.caret_column = t.length()
	_le.text_changed.emit(t)

func _on_key(args) -> void:
	var ev = args[0]
	if String(ev.key) == "Enter":
		_el.blur()
		_le.text_submitted.emit(_le.text)

func _on_blur(_args) -> void:
	_le.release_focus()

func _process(_d: float) -> void:
	if _el == null:
		return
	if not _le.is_visible_in_tree():
		_el.style.display = "none"
		return
	# posizione del campo del gioco in pixel CSS della pagina
	var canvas = JavaScriptBridge.get_interface("document").getElementById("canvas")
	if canvas == null:
		return
	var br = canvas.getBoundingClientRect()
	var cw := float(canvas.width)
	var bw := float(br.width)
	if cw <= 0.0 or bw <= 0.0:
		return
	var k := bw / cw
	# dalle coordinate del gioco ai pixel della tela: comprende l'ingrandimento dell'interfaccia
	# (content scale), che get_screen_transform() non conta
	var xf := _le.get_viewport().get_final_transform() * _le.get_global_transform_with_canvas()
	var pos := xf.origin
	var sz := _le.size * xf.get_scale()
	_el.style.display = "block"
	_el.style.left = "%dpx" % int(float(br.left) + pos.x * k)
	_el.style.top = "%dpx" % int(float(br.top) + pos.y * k)
	_el.style.width = "%dpx" % max(int(sz.x * k), 20)
	_el.style.height = "%dpx" % max(int(sz.y * k), 20)
	# testo cambiato dal gioco (per esempio caricando un percorso): si aggiorna il campo HTML
	if _le.text != _last:
		_last = _le.text
		_el.value = _le.text

func _exit_tree() -> void:
	if _el != null:
		_el.remove()
		_el = null
