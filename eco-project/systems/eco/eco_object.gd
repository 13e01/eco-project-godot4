extends Area2D

signal cleaned(eco_id: StringName)

enum CleanupMode {
	ON_TOUCH,
	MANUAL
}

@export var eco_id: StringName = &"trash_01"
@export var cleanup_mode: CleanupMode = CleanupMode.ON_TOUCH
@export var reward_points: int = 10
@export var restoration_weight: float = 1.0
@export var cleaned_by_default: bool = false
@export var hide_when_cleaned: bool = true
@export var disable_collision_when_cleaned: bool = true
@export var clean_requires_past: bool = true
@export var floating_text_offset: Vector2 = Vector2(0, -32)

var _is_cleaned: bool = false
var _current_is_future: bool = false
var _nearby_actor: Node

@onready var _collision: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var _dirty_visual: Node2D = get_node_or_null("DirtyVisual")
@onready var _clean_visual: Node2D = get_node_or_null("CleanVisual")

func _ready() -> void:
	add_to_group("eco_objects")
	add_to_group("time_objects")
	var manager := _manager()
	if manager:
		manager.register_eco_object(eco_id, reward_points, restoration_weight, cleaned_by_default)

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	if manager and manager.has_signal("future_changed") and not manager.is_connected("future_changed", _on_future_changed):
		manager.connect("future_changed", _on_future_changed)

	apply_eco_state(eco_id, manager.is_cleaned(eco_id) if manager else cleaned_by_default)
	change_time_state(false)

func _exit_tree() -> void:
	var manager := _manager()
	if manager and manager.has_signal("future_changed") and manager.is_connected("future_changed", _on_future_changed):
		manager.disconnect("future_changed", _on_future_changed)

func change_time_state(is_future: bool) -> void:
	_current_is_future = is_future
	if clean_requires_past and is_future and not _is_cleaned:
		monitoring = false
		get_tree().call_group("eco_ui", "hide_interaction_prompt")
	else:
		monitoring = not _is_cleaned
		if cleanup_mode == CleanupMode.MANUAL and _nearby_actor != null and not _is_cleaned:
			get_tree().call_group("eco_ui", "show_interaction_prompt", "[F] Clean Pollution")
	_refresh_visual_state()

func request_cleanup(actor: Node = null) -> bool:
	if _is_cleaned:
		return false
	if clean_requires_past and _current_is_future:
		return false

	var manager := _manager()
	if manager == null:
		return false
	var changed: bool = manager.clean_eco_object(eco_id, reward_points, restoration_weight, self)
	if changed:
		cleaned.emit(eco_id)
		_spawn_feedback(actor)
	return changed

func apply_eco_state(target_eco_id: StringName, cleaned_state: bool) -> void:
	if target_eco_id != eco_id:
		return
	_is_cleaned = cleaned_state
	monitoring = not _is_cleaned
	monitorable = not _is_cleaned
	if _is_cleaned:
		get_tree().call_group("eco_ui", "hide_interaction_prompt")
	if _collision and disable_collision_when_cleaned:
		_collision.set_deferred("disabled", _is_cleaned)
	_refresh_visual_state()

func _refresh_visual_state() -> void:
	visible = not (_is_cleaned and hide_when_cleaned)
	if _dirty_visual:
		_dirty_visual.visible = not _is_cleaned
	if _clean_visual:
		_clean_visual.visible = _is_cleaned

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player") and body.name != "Player":
		return
	_nearby_actor = body
	if cleanup_mode == CleanupMode.MANUAL and not _is_cleaned and not _current_is_future:
		get_tree().call_group("eco_ui", "show_interaction_prompt", "[F] Clean Pollution")
		return
	if cleanup_mode != CleanupMode.ON_TOUCH:
		return
	request_cleanup(body)

func _on_body_exited(body: Node) -> void:
	if body != _nearby_actor:
		return
	_nearby_actor = null
	get_tree().call_group("eco_ui", "hide_interaction_prompt")

func _unhandled_input(event: InputEvent) -> void:
	if cleanup_mode != CleanupMode.MANUAL:
		return
	if _nearby_actor == null:
		return
	if event.is_action_pressed("interact"):
		request_cleanup(_nearby_actor)
		get_viewport().set_input_as_handled()

func _on_future_changed(changed_eco_id: StringName) -> void:
	if changed_eco_id == eco_id:
		apply_eco_state(eco_id, true)

func _spawn_feedback(_actor: Node) -> void:
	get_tree().call_group("eco_ui", "hide_interaction_prompt")
	get_tree().call_group("eco_ui", "show_eco_popup", global_position + floating_text_offset, reward_points)

func _manager() -> Node:
	return get_node_or_null("/root/EcoManager")
