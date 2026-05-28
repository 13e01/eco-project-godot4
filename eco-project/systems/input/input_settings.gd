extends Node

signal bindings_changed

const SAVE_PATH := "user://input_bindings.cfg"

const ACTIONS := [
	{"name": "move_left", "label": "Move Left", "keys": [KEY_A, KEY_LEFT]},
	{"name": "move_right", "label": "Move Right", "keys": [KEY_D, KEY_RIGHT]},
	{"name": "move_up", "label": "Move Up", "keys": [KEY_W, KEY_UP]},
	{"name": "move_down", "label": "Move Down", "keys": [KEY_S, KEY_DOWN]},
	{"name": "jump", "label": "Jump", "keys": [KEY_SPACE]},
	{"name": "switch_time", "label": "Time Switch", "keys": [KEY_E]},
	{"name": "interact", "label": "Interact", "keys": [KEY_F]},
]

func _ready() -> void:
	ensure_defaults()
	load_bindings()

func ensure_defaults() -> void:
	for action_data in ACTIONS:
		var action_name := String(action_data["name"])
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		if InputMap.action_get_events(action_name).is_empty():
			_apply_keys(action_name, action_data["keys"])

func reset_to_defaults() -> void:
	for action_data in ACTIONS:
		_apply_keys(String(action_data["name"]), action_data["keys"])
	save_bindings()
	bindings_changed.emit()

func rebind_action(action_name: String, event: InputEventKey) -> void:
	if event == null or event.physical_keycode == KEY_NONE:
		return
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	_apply_keys(action_name, [event.physical_keycode])
	save_bindings()
	bindings_changed.emit()

func get_action_label(action_name: String) -> String:
	for action_data in ACTIONS:
		if String(action_data["name"]) == action_name:
			return String(action_data["label"])
	return action_name.capitalize()

func get_binding_text(action_name: String) -> String:
	var names: Array[String] = []
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			names.append(OS.get_keycode_string(key_event.physical_keycode))
	return " / ".join(names) if not names.is_empty() else "Unbound"

func save_bindings() -> void:
	var config := ConfigFile.new()
	for action_data in ACTIONS:
		var action_name := String(action_data["name"])
		var keys: Array[int] = []
		for event in InputMap.action_get_events(action_name):
			if event is InputEventKey:
				keys.append((event as InputEventKey).physical_keycode)
		config.set_value("bindings", action_name, keys)
	config.save(SAVE_PATH)

func load_bindings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for action_data in ACTIONS:
		var action_name := String(action_data["name"])
		var fallback: Array = action_data["keys"]
		var keys: Array = config.get_value("bindings", action_name, fallback)
		_apply_keys(action_name, keys)
	bindings_changed.emit()

func _apply_keys(action_name: String, keys: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	InputMap.action_erase_events(action_name)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = int(key)
		InputMap.action_add_event(action_name, event)
