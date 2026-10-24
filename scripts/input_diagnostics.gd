extends Node
## Opt-in, passive input trace: ?input_debug=1 (never consumes or synthesizes input).
var enabled := false
var _elapsed := 0.0

func _ready() -> void:
	if OS.has_feature("web"):
		enabled = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('input_debug') === '1'"))
	set_process(enabled)
	set_process_input(enabled)
	if not enabled:
		return
	JavaScriptBridge.eval("""
	if (window.snowtailsStartup) window.snowtailsStartup("Godot avviato; costruzione del menu.");
	window.snowtailsInput = {events: [], controls: [], log: function(s) {
	  this.events.push(s); if (this.events.length > 40) this.events.shift();
	  document.getElementById('input-trace').textContent = this.events.slice(-12).join('\\n');
	  console.log('[input] ' + s);
	}};
	var trace = document.createElement('pre'); trace.id = 'input-trace';
	trace.style.cssText = 'position:fixed;bottom:0;left:0;z-index:100;pointer-events:none;background:#000c;color:white;font:14px monospace;max-width:100%;margin:0';
	document.body.appendChild(trace);
	['pointerdown','pointerup','mousedown','mouseup','touchstart','touchend','click'].forEach(function(t) {
	  document.addEventListener(t, function(e) {
	    snowtailsInput.log('DOM ' + t + ' target=' + e.target.tagName + '#' + e.target.id + ' pointer=' + (e.pointerType || '') + ' button=' + e.button);
	  }, {capture:true, passive:true});
	});
	snowtailsInput.log('UA ' + navigator.userAgent + ' maxTouchPoints=' + navigator.maxTouchPoints);
	""", true)
	get_tree().node_added.connect(_watch)
	_visit(get_tree().root)
	_log("Godot %s emulate_touch=%s emulate_mouse=%s" % [Engine.get_version_info().string, Input.emulate_touch_from_mouse, Input.emulate_mouse_from_touch])

func _visit(n: Node) -> void:
	_watch(n)
	for child in n.get_children():
		_visit(child)

func _watch(n: Node) -> void:
	if n is Control:
		n.gui_input.connect(func(ev):
			if ev is InputEventMouseButton or ev is InputEventScreenTouch:
				_log("GUI %s filter=%d %s" % [n.get_path(), n.mouse_filter, ev.as_text()]))
	if n is BaseButton:
		n.pressed.connect(func(): _log("PRESSED %s" % n.get_path()))

func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton or ev is InputEventScreenTouch:
		var hovered := get_viewport().gui_get_hovered_control()
		_log("INPUT %s device=%d hover=%s" % [ev.as_text(), ev.device, str(hovered.get_path()) if hovered else "none"])

func _log(s: String) -> void:
	JavaScriptBridge.eval("window.snowtailsInput.log(%s)" % JSON.stringify(s), true)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.5:
		return
	_elapsed = 0.0
	var controls: Array = []
	_collect(get_tree().root, controls)
	JavaScriptBridge.eval("window.snowtailsInput.controls = %s" % JSON.stringify(controls), true)

func _collect(n: Node, result: Array) -> void:
	if n is Control and n.is_visible_in_tree():
		var xf: Transform2D = n.get_viewport().get_final_transform() * n.get_global_transform_with_canvas()
		var rect: Rect2 = xf * Rect2(Vector2.ZERO, n.size)
		result.append({"path": str(n.get_path()), "type": n.get_class(), "filter": n.mouse_filter,
			"text": n.text if n is Button else "", "disabled": n.disabled if n is BaseButton else false,
			"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]})
	for child in n.get_children():
		_collect(child, result)
