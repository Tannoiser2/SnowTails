extends Node
## Normalize click-only browser activation before Godot's canvas input handlers.
func _ready() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(FileAccess.get_file_as_string("res://scripts/web_input_compat.js"), true)
