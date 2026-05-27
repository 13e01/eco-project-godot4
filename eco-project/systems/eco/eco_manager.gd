extends Node

signal eco_points_changed(points: int, delta: int)
signal restoration_changed(percent: float, restored_weight: float, total_weight: float)
signal eco_object_cleaned(eco_id: StringName, reward: int, source: Node)
signal future_changed(eco_id: StringName)

var eco_points: int = 0
var eco_object_states: Dictionary = {}
var _registered_objects: Dictionary = {}
var _current_level_id: String = ""
var _restored_weight: float = 0.0
var _total_weight: float = 0.0

func begin_level(level_id: String, keep_existing_state: bool = false) -> void:
	if _current_level_id == level_id and keep_existing_state:
		return
	_current_level_id = level_id
	_registered_objects.clear()
	eco_object_states.clear()
	eco_points = 0
	_recalculate_restoration()
	eco_points_changed.emit(eco_points, 0)

func register_eco_object(eco_id: StringName, reward: int, restoration_weight: float, cleaned_by_default: bool = false) -> void:
	if eco_id == &"":
		push_warning("Eco object has empty eco_id.")
		return

	var id := String(eco_id)
	if not _registered_objects.has(id):
		_registered_objects[id] = {
			"reward": max(reward, 0),
			"weight": maxf(restoration_weight, 0.0)
		}

	if not eco_object_states.has(id):
		eco_object_states[id] = cleaned_by_default

	_recalculate_restoration()

func unregister_eco_object(eco_id: StringName) -> void:
	var id := String(eco_id)
	if _registered_objects.erase(id):
		_recalculate_restoration()

func is_cleaned(eco_id: StringName) -> bool:
	return bool(eco_object_states.get(String(eco_id), false))

func clean_eco_object(eco_id: StringName, reward: int = -1, restoration_weight: float = -1.0, source: Node = null) -> bool:
	if eco_id == &"":
		return false

	var id := String(eco_id)
	if is_cleaned(eco_id):
		return false

	if not _registered_objects.has(id):
		register_eco_object(eco_id, max(reward, 0), maxf(restoration_weight, 0.0))

	var object_data: Dictionary = _registered_objects[id]
	var resolved_reward: int = int(object_data.get("reward", 0)) if reward < 0 else max(reward, 0)
	eco_object_states[id] = true
	eco_points += resolved_reward

	_recalculate_restoration()
	eco_object_cleaned.emit(eco_id, resolved_reward, source)
	eco_points_changed.emit(eco_points, resolved_reward)
	restoration_changed.emit(get_restoration_percent(), _restored_weight, _total_weight)
	future_changed.emit(eco_id)

	get_tree().call_group("eco_future_effects", "apply_eco_state", eco_id, true)
	get_tree().call_group("eco_objects", "apply_eco_state", eco_id, true)

	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager:
		audio_manager.play_event(&"eco_cleanup", {"volume_db": -6.0})
		audio_manager.play_event(&"future_changed", {"volume_db": -8.0})
	return true

func apply_registered_states() -> void:
	for id: String in eco_object_states.keys():
		var cleaned := bool(eco_object_states[id])
		get_tree().call_group("eco_future_effects", "apply_eco_state", StringName(id), cleaned)
		get_tree().call_group("eco_objects", "apply_eco_state", StringName(id), cleaned)
	restoration_changed.emit(get_restoration_percent(), _restored_weight, _total_weight)
	eco_points_changed.emit(eco_points, 0)

func get_restoration_percent() -> float:
	if _total_weight <= 0.0:
		return 0.0
	return clampf((_restored_weight / _total_weight) * 100.0, 0.0, 100.0)

func get_save_data() -> Dictionary:
	return {
		"level_id": _current_level_id,
		"eco_points": eco_points,
		"eco_object_states": eco_object_states.duplicate(true)
	}

func load_save_data(data: Dictionary) -> void:
	_current_level_id = String(data.get("level_id", _current_level_id))
	eco_points = int(data.get("eco_points", 0))
	eco_object_states = Dictionary(data.get("eco_object_states", {})).duplicate(true)
	_recalculate_restoration()
	apply_registered_states()

func _recalculate_restoration() -> void:
	_restored_weight = 0.0
	_total_weight = 0.0
	for id: String in _registered_objects.keys():
		var weight := float(_registered_objects[id].get("weight", 0.0))
		_total_weight += weight
		if bool(eco_object_states.get(id, false)):
			_restored_weight += weight
