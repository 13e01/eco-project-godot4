extends Node2D

enum EffectType {
	HIDE_DIRTY,
	SHOW_CLEAN,
	SWAP_DIRTY_TO_CLEAN,
	ENABLE_WHEN_CLEAN,
	DISABLE_WHEN_CLEAN
}

@export var eco_id: StringName = &"trash_01"
@export var effect_type: EffectType = EffectType.SWAP_DIRTY_TO_CLEAN
@export var dirty_node_path: NodePath
@export var clean_node_path: NodePath
@export var affected_collision_paths: Array[NodePath] = []
@export var fade_seconds: float = 0.25

var _is_cleaned: bool = false
var _current_is_future: bool = false
var _dirty_node: CanvasItem
var _clean_node: CanvasItem

func _ready() -> void:
	add_to_group("eco_future_effects")
	add_to_group("time_objects")
	_dirty_node = get_node_or_null(dirty_node_path) as CanvasItem
	_clean_node = get_node_or_null(clean_node_path) as CanvasItem
	var manager := get_node_or_null("/root/EcoManager")
	apply_eco_state(eco_id, manager.is_cleaned(eco_id) if manager else false)

func change_time_state(is_future: bool) -> void:
	_current_is_future = is_future
	_refresh(false)

func apply_eco_state(target_eco_id: StringName, cleaned_state: bool) -> void:
	if target_eco_id != eco_id:
		return
	_is_cleaned = cleaned_state
	_refresh(true)

func _refresh(animate: bool) -> void:
	var show_dirty := _current_is_future
	var show_clean := false
	var collisions_disabled := not _current_is_future

	match effect_type:
		EffectType.HIDE_DIRTY:
			show_dirty = _current_is_future and not _is_cleaned
			show_clean = false
			collisions_disabled = not _current_is_future or _is_cleaned
		EffectType.SHOW_CLEAN:
			show_dirty = false
			show_clean = _current_is_future and _is_cleaned
			collisions_disabled = not (_current_is_future and _is_cleaned)
		EffectType.SWAP_DIRTY_TO_CLEAN:
			show_dirty = _current_is_future and not _is_cleaned
			show_clean = _current_is_future and _is_cleaned
			collisions_disabled = not _current_is_future
		EffectType.ENABLE_WHEN_CLEAN:
			show_dirty = false
			show_clean = _current_is_future and _is_cleaned
			collisions_disabled = not (_current_is_future and _is_cleaned)
		EffectType.DISABLE_WHEN_CLEAN:
			show_dirty = _current_is_future and not _is_cleaned
			show_clean = false
			collisions_disabled = not _current_is_future or _is_cleaned

	_set_canvas_visible(_dirty_node, show_dirty, animate)
	_set_canvas_visible(_clean_node, show_clean, animate)
	_set_collision_disabled(collisions_disabled)

func _set_canvas_visible(item: CanvasItem, should_show: bool, animate: bool) -> void:
	if item == null:
		return
	item.visible = should_show
	if not animate or fade_seconds <= 0.0:
		item.modulate.a = 1.0 if should_show else 0.0
		return
	if should_show:
		item.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(item, "modulate:a", 1.0 if should_show else 0.0, fade_seconds)
	if not should_show:
		tween.tween_callback(func(): item.visible = false)

func _set_collision_disabled(disabled: bool) -> void:
	for path: NodePath in affected_collision_paths:
		var node := get_node_or_null(path)
		if node is CollisionShape2D or node is CollisionPolygon2D:
			node.set_deferred("disabled", disabled)
