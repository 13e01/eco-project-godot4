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

const TRASH_ATLAS := preload("res://assets/Trashville-Tileset-Package-v1.1/Trashville-Tileset-Package-v1.1.png")

var _is_cleaned: bool = false
var _current_is_future: bool = false
var _nearby_actor: Node

@onready var _collision: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var _dirty_visual: Node2D = get_node_or_null("DirtyVisual")
@onready var _clean_visual: Node2D = get_node_or_null("CleanVisual")

func _ready() -> void:
	_ensure_unique_cleanup_id()
	add_to_group("eco_objects")
	add_to_group("time_objects")
	_build_pixel_trash_visual()
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
			get_tree().call_group("eco_ui", "show_interaction_prompt", _interaction_text())
	_refresh_visual_state()

func request_cleanup(actor: Node = null) -> bool:
	if _is_cleaned:
		return false
	if clean_requires_past and _current_is_future:
		return false

	var manager := _manager()
	if manager == null:
		return false
	var changed: bool = manager.clean_eco_object(eco_id, reward_points, restoration_weight, self )
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
		get_tree().call_group("eco_ui", "show_interaction_prompt", _interaction_text())
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
	_play_cleanup_animation()

func _manager() -> Node:
	return get_node_or_null("/root/EcoManager")

func _ensure_unique_cleanup_id() -> void:
	if eco_id == &"":
		return
	var base_id := String(eco_id)
	for node in get_tree().get_nodes_in_group("eco_objects"):
		if node == self:
			continue
		if String(node.get("eco_id")) == base_id:
			var suffix := String(get_path()).replace("/", "_").replace("@", "").replace(":", "_")
			eco_id = StringName("%s_%s" % [base_id, suffix])
			push_warning("Duplicate EcoObject eco_id '%s' remapped to '%s'." % [base_id, String(eco_id)])
			return

func _interaction_text() -> String:
	var input_settings := get_node_or_null("/root/InputSettings")
	var key_text: String = input_settings.get_binding_text("interact") if input_settings and input_settings.has_method("get_binding_text") else "F"
	return tr("HUD_CLEAN_POLLUTION") % key_text

func _play_cleanup_animation() -> void:
	var burst_parent := get_parent() as Node2D
	if burst_parent == null:
		return
	visible = true
	if _dirty_visual:
		_dirty_visual.visible = true
		_dirty_visual.modulate.a = 1.0
	for i in range(12):
		var spark := Polygon2D.new()
		spark.color = Color(0.58, 1.0, 0.55, 0.86)
		spark.polygon = PackedVector2Array([Vector2(0, -4), Vector2(3, 0), Vector2(0, 4), Vector2(-3, 0)])
		spark.global_position = global_position
		burst_parent.add_child(spark)
		var angle := TAU * float(i) / 12.0
		var tween := create_tween()
		tween.tween_property(spark, "global_position", global_position + Vector2(cos(angle), sin(angle)) * randf_range(24.0, 52.0), 0.35)
		tween.parallel().tween_property(spark, "modulate:a", 0.0, 0.35)
		tween.tween_callback(spark.queue_free)
	if _dirty_visual:
		var tween := create_tween()
		tween.tween_property(_dirty_visual, "scale", Vector2(1.25, 0.65), 0.12)
		tween.tween_property(_dirty_visual, "modulate:a", 0.0, 0.28)
		tween.tween_callback(func():
			_dirty_visual.scale = Vector2.ONE
			_refresh_visual_state()
		)

func _build_pixel_trash_visual() -> void:
	if _dirty_visual == null or _dirty_visual.has_node("PixelTrashCluster"):
		return
	for child in _dirty_visual.get_children():
		if child is Polygon2D:
			(child as Polygon2D).visible = false
	var cluster := Node2D.new()
	cluster.name = "PixelTrashCluster"
	_dirty_visual.add_child(cluster)

	var id := String(eco_id)
	if id.contains("toxic"):
		_add_atlas_sprite(cluster, Rect2(296, 480, 16, 32), Vector2(-8, -6), Vector2(1.35, 1.35), Color(0.62, 1.0, 0.32, 1.0))
		_add_atlas_sprite(cluster, Rect2(264, 480, 16, 32), Vector2(11, -2), Vector2(1.2, 1.2), Color(0.74, 1.0, 0.42, 1.0))
		_add_toxic_glow(cluster)
	elif id.contains("oil") or id.contains("platform"):
		_add_atlas_sprite(cluster, Rect2(264, 480, 16, 32), Vector2(-10, 1), Vector2(1.25, 0.95), Color(0.16, 0.17, 0.18, 1.0))
		_add_atlas_sprite(cluster, Rect2(296, 480, 16, 32), Vector2(10, 3), Vector2(1.1, 0.9), Color(0.05, 0.06, 0.07, 1.0))
		_add_oil_puddle(cluster)
	elif id.contains("scrap") or id.contains("machine") or id.contains("landfill"):
		_add_atlas_sprite(cluster, Rect2(264, 480, 16, 32), Vector2(-18, 2), Vector2(1.15, 1.05), Color(0.86, 0.76, 0.62, 1.0))
		_add_atlas_sprite(cluster, Rect2(296, 480, 16, 32), Vector2(2, -3), Vector2(1.2, 1.2), Color(0.72, 0.74, 0.75, 1.0))
		_add_atlas_sprite(cluster, Rect2(264, 480, 16, 32), Vector2(21, 4), Vector2(0.95, 0.9), Color(0.42, 0.48, 0.55, 1.0))
		_add_scrap_silhouette(cluster)
	else:
		_add_atlas_sprite(cluster, Rect2(264, 480, 16, 32), Vector2(-9, 1), Vector2(1.25, 1.15), Color(0.92, 0.84, 0.72, 1.0))
		_add_atlas_sprite(cluster, Rect2(296, 480, 16, 32), Vector2(10, 3), Vector2(1.05, 1.0), Color(0.78, 0.78, 0.72, 1.0))

func _add_atlas_sprite(parent: Node2D, region: Rect2, pos: Vector2, sprite_scale: Vector2, tint: Color) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = TRASH_ATLAS
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.position = pos
	sprite.scale = sprite_scale
	sprite.modulate = tint
	sprite.z_index = 5
	parent.add_child(sprite)

func _add_toxic_glow(parent: Node2D) -> void:
	var glow := Polygon2D.new()
	glow.color = Color(0.44, 0.9, 0.12, 0.34)
	glow.position = Vector2(0, 16)
	glow.polygon = PackedVector2Array([Vector2(-30, -6), Vector2(30, -7), Vector2(38, 8), Vector2(-36, 9)])
	parent.add_child(glow)

func _add_oil_puddle(parent: Node2D) -> void:
	var puddle := Polygon2D.new()
	puddle.color = Color(0.02, 0.025, 0.03, 0.86)
	puddle.position = Vector2(0, 18)
	puddle.polygon = PackedVector2Array([Vector2(-34, -6), Vector2(24, -9), Vector2(39, 2), Vector2(18, 10), Vector2(-28, 8)])
	parent.add_child(puddle)

func _add_scrap_silhouette(parent: Node2D) -> void:
	var shard := Polygon2D.new()
	shard.color = Color(0.22, 0.24, 0.26, 1.0)
	shard.position = Vector2(0, 8)
	shard.polygon = PackedVector2Array([Vector2(-34, 8), Vector2(-18, -18), Vector2(2, 2), Vector2(28, -14), Vector2(36, 9)])
	parent.add_child(shard)
