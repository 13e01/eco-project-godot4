extends Node2D

const CLEAN_GOOD_ENDING_PERCENT := 70.0
const RESTORATION_THRESHOLDS := [25.0, 50.0, 75.0]

var _level: Node
var _world: Node2D
var _player: Node
var _canvas_modulate: CanvasModulate
var _is_future := false
var _restoration_percent := 0.0
var _effects_by_id: Dictionary = {}
var _cleaned_ids: Dictionary = {}
var _impact_layer: Node2D
var _future_atmosphere: CanvasLayer
var _smog: ColorRect
var _sun_flash: ColorRect
var _corruption: ColorRect
var _particle_layer: Node2D

func setup(level: Node, world: Node2D, player: Node, canvas_modulate: CanvasModulate) -> void:
	_level = level
	_world = world
	_player = player
	_canvas_modulate = canvas_modulate
	_build_layers()
	_index_future_effects()
	_connect_manager()
	_refresh_restoration_state(false)

func set_future_state(is_future: bool) -> void:
	_is_future = is_future
	_refresh_restoration_state(true)

func play_cleanup_feedback(eco_id: StringName, source: Node = null) -> void:
	var id := String(eco_id)
	_cleaned_ids[id] = true
	var impact_position := _resolve_impact_position(id, source)
	_spawn_restoration_burst(impact_position)
	_play_wow_moment(id, impact_position)
	_shake_camera(8.0, 0.32)
	_pulse_screen(Color(0.65, 1.0, 0.72, 0.24), 0.55)
	_refresh_restoration_state(true)

func _connect_manager() -> void:
	var manager := get_node_or_null("/root/EcoManager")
	if manager == null:
		return
	if manager.has_signal("eco_object_cleaned") and not manager.eco_object_cleaned.is_connected(_on_eco_object_cleaned):
		manager.eco_object_cleaned.connect(_on_eco_object_cleaned)
	if manager.has_signal("restoration_changed") and not manager.restoration_changed.is_connected(_on_restoration_changed):
		manager.restoration_changed.connect(_on_restoration_changed)
	_restoration_percent = manager.get_restoration_percent() if manager.has_method("get_restoration_percent") else 0.0

func _build_layers() -> void:
	_impact_layer = Node2D.new()
	_impact_layer.name = "EcoImpactLayer"
	_world.add_child(_impact_layer)

	_particle_layer = Node2D.new()
	_particle_layer.name = "RestorationParticles"
	_world.add_child(_particle_layer)

	_future_atmosphere = CanvasLayer.new()
	_future_atmosphere.name = "FutureAtmosphere"
	_future_atmosphere.layer = 0
	_level.add_child(_future_atmosphere)

	_smog = ColorRect.new()
	_smog.name = "FutureSmog"
	_smog.set_anchors_preset(Control.PRESET_FULL_RECT)
	_smog.color = Color(0.23, 0.18, 0.17, 0.0)
	_smog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_future_atmosphere.add_child(_smog)

	_corruption = ColorRect.new()
	_corruption.name = "FutureCorruptionWash"
	_corruption.set_anchors_preset(Control.PRESET_FULL_RECT)
	_corruption.color = Color(0.48, 0.09, 0.12, 0.0)
	_corruption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_future_atmosphere.add_child(_corruption)

	_sun_flash = ColorRect.new()
	_sun_flash.name = "SunBreakFlash"
	_sun_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sun_flash.color = Color(1.0, 0.9, 0.55, 0.0)
	_sun_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_future_atmosphere.add_child(_sun_flash)

func _index_future_effects() -> void:
	_effects_by_id.clear()
	if _world == null:
		return
	for node in get_tree().get_nodes_in_group("eco_future_effects"):
		if not _world.is_ancestor_of(node):
			continue
		var id := String(node.get("eco_id"))
		if id.is_empty():
			continue
		_effects_by_id[id] = node
		_create_payoff_cluster(id, node.global_position)

func _create_payoff_cluster(id: String, origin: Vector2) -> void:
	var cluster := Node2D.new()
	cluster.name = "Payoff_%s" % id
	cluster.position = origin
	_impact_layer.add_child(cluster)

	var dirty_count := 7
	var clean_count := 8
	if id.contains("toxic"):
		dirty_count = 12
		clean_count = 13
		_add_sun_rays(cluster)
	elif id.contains("oil") or id.contains("river") or id.contains("platform"):
		dirty_count = 10
		clean_count = 12
		_add_plant_bridge(cluster)
	elif id.contains("machine") or id.contains("landfill"):
		dirty_count = 16
		clean_count = 10
		_add_final_route_hint(cluster)

	var dirty := Node2D.new()
	dirty.name = "DirtyPayoff"
	cluster.add_child(dirty)
	for i in range(dirty_count):
		dirty.add_child(_make_debris(i, dirty_count, id))

	var clean := Node2D.new()
	clean.name = "CleanPayoff"
	clean.visible = false
	cluster.add_child(clean)
	for i in range(clean_count):
		clean.add_child(_make_plant(i, clean_count, id))

	cluster.set_meta("eco_id", id)
	_update_cluster_visibility(cluster, false)

func _make_debris(index: int, count: int, id: String) -> Polygon2D:
	var p := Polygon2D.new()
	var angle := TAU * float(index) / float(max(count, 1))
	var radius := 44.0 + float(index % 4) * 18.0
	p.position = Vector2(cos(angle), sin(angle) * 0.55) * radius
	p.rotation = angle * 0.4
	p.scale = Vector2.ONE * (0.65 + float(index % 3) * 0.22)
	p.color = Color(0.16, 0.13, 0.12, 0.92)
	if id.contains("toxic"):
		p.color = Color(0.25, 0.48, 0.08, 0.88)
	elif id.contains("oil") or id.contains("platform"):
		p.color = Color(0.03, 0.04, 0.045, 0.9)
	p.polygon = PackedVector2Array([Vector2(-14, -8), Vector2(12, -11), Vector2(18, 7), Vector2(2, 14), Vector2(-16, 9)])
	return p

func _make_plant(index: int, count: int, id: String) -> Node2D:
	var sprout := Node2D.new()
	var angle := TAU * float(index) / float(max(count, 1))
	var radius := 38.0 + float(index % 5) * 16.0
	sprout.position = Vector2(cos(angle), sin(angle) * 0.45) * radius + Vector2(0, -8)
	sprout.scale = Vector2.ONE * (0.75 + float(index % 4) * 0.18)

	var stem := Polygon2D.new()
	stem.color = Color(0.24, 0.66, 0.32, 0.96)
	stem.polygon = PackedVector2Array([Vector2(-3, 12), Vector2(3, 12), Vector2(2, -12), Vector2(-2, -12)])
	sprout.add_child(stem)

	var leaf_l := Polygon2D.new()
	leaf_l.color = Color(0.42, 0.86, 0.43, 0.95)
	leaf_l.polygon = PackedVector2Array([Vector2(0, -5), Vector2(-18, -12), Vector2(-11, 2)])
	sprout.add_child(leaf_l)

	var leaf_r := Polygon2D.new()
	leaf_r.color = Color(0.56, 0.92, 0.48, 0.92)
	leaf_r.polygon = PackedVector2Array([Vector2(0, -10), Vector2(18, -17), Vector2(10, -2)])
	sprout.add_child(leaf_r)

	if id.contains("toxic"):
		sprout.modulate = Color(1.08, 1.16, 0.82, 1.0)
	return sprout

func _add_sun_rays(cluster: Node2D) -> void:
	var rays := Node2D.new()
	rays.name = "WowSunRays"
	rays.visible = false
	cluster.add_child(rays)
	for i in range(5):
		var ray := Polygon2D.new()
		ray.color = Color(1.0, 0.86, 0.45, 0.18)
		ray.position = Vector2(-120 + i * 56, -160)
		ray.polygon = PackedVector2Array([Vector2(-14, 0), Vector2(14, 0), Vector2(48, 230), Vector2(-48, 230)])
		rays.add_child(ray)

func _add_plant_bridge(cluster: Node2D) -> void:
	var bridge := Polygon2D.new()
	bridge.name = "WowPlantBridge"
	bridge.visible = false
	bridge.color = Color(0.34, 0.76, 0.38, 0.88)
	bridge.position = Vector2(0, -54)
	bridge.polygon = PackedVector2Array([Vector2(-118, -10), Vector2(118, -12), Vector2(108, 14), Vector2(-104, 18)])
	cluster.add_child(bridge)

func _add_final_route_hint(cluster: Node2D) -> void:
	var path := Polygon2D.new()
	path.name = "WowFinalRoute"
	path.visible = false
	path.color = Color(0.65, 0.9, 0.58, 0.56)
	path.position = Vector2(54, -72)
	path.polygon = PackedVector2Array([Vector2(-80, -10), Vector2(150, -18), Vector2(164, 12), Vector2(-72, 16)])
	cluster.add_child(path)

func _on_eco_object_cleaned(eco_id: StringName, _reward: int, source: Node) -> void:
	play_cleanup_feedback(eco_id, source)

func _on_restoration_changed(percent: float, _restored_weight: float, _total_weight: float) -> void:
	var crossed_threshold := _threshold_crossed(_restoration_percent, percent)
	_restoration_percent = percent
	if crossed_threshold:
		_pulse_screen(Color(1.0, 0.92, 0.55, 0.18), 0.75)
		_shake_camera(4.0, 0.22)
	_refresh_restoration_state(true)

func _threshold_crossed(previous: float, current: float) -> bool:
	for threshold in RESTORATION_THRESHOLDS:
		if previous < threshold and current >= threshold:
			return true
	return false

func _refresh_restoration_state(animate: bool) -> void:
	var cleaned_ratio := clampf(_restoration_percent / 100.0, 0.0, 1.0)
	if _canvas_modulate:
		var future_dirty := Color(0.56, 0.45, 0.43)
		var future_clean := Color(0.92, 0.95, 0.82)
		var past_clean := Color(1.0, 1.0, 1.0)
		var target := future_dirty.lerp(future_clean, cleaned_ratio) if _is_future else past_clean.lerp(Color(1.02, 1.0, 0.94), cleaned_ratio * 0.35)
		if animate:
			create_tween().tween_property(_canvas_modulate, "color", target, 0.45)
		else:
			_canvas_modulate.color = target

	var smog_alpha := (0.32 * (1.0 - cleaned_ratio)) if _is_future else 0.0
	var corruption_alpha := (0.17 * (1.0 - cleaned_ratio)) if _is_future else 0.0
	_tween_color_alpha(_smog, smog_alpha, animate)
	_tween_color_alpha(_corruption, corruption_alpha, animate)

	_set_bus_volume("Glitch", lerp(-22.0, -13.0, 1.0 - cleaned_ratio))
	_set_bus_volume("Ambient", lerp(-8.0, -12.0, 1.0 - cleaned_ratio))

	for cluster in _impact_layer.get_children():
		_update_cluster_visibility(cluster, animate)

func _update_cluster_visibility(cluster: Node, animate: bool) -> void:
	var id := String(cluster.get_meta("eco_id", ""))
	var cleaned := _cleaned_ids.has(id) or _manager_is_cleaned(id)
	var show_future := _is_future
	var dirty := cluster.get_node_or_null("DirtyPayoff") as CanvasItem
	var clean := cluster.get_node_or_null("CleanPayoff") as CanvasItem
	_set_canvas_visible(dirty, show_future and not cleaned, animate)
	_set_canvas_visible(clean, show_future and cleaned, animate)
	for extra_name in ["WowSunRays", "WowPlantBridge", "WowFinalRoute"]:
		_set_canvas_visible(cluster.get_node_or_null(extra_name) as CanvasItem, show_future and cleaned, animate)

func _manager_is_cleaned(id: String) -> bool:
	var manager := get_node_or_null("/root/EcoManager")
	return manager != null and manager.has_method("is_cleaned") and manager.is_cleaned(StringName(id))

func _set_canvas_visible(item: CanvasItem, should_show: bool, animate: bool) -> void:
	if item == null:
		return
	item.visible = true
	var target_alpha := 1.0 if should_show else 0.0
	if not animate:
		item.modulate.a = target_alpha
		item.visible = should_show
		return
	if should_show:
		item.modulate.a = min(item.modulate.a, 0.05)
	var tween := create_tween()
	tween.tween_property(item, "modulate:a", target_alpha, 0.5)
	if not should_show:
		tween.tween_callback(func(): item.visible = false)

func _tween_color_alpha(rect: ColorRect, alpha: float, animate: bool) -> void:
	if rect == null:
		return
	var color := rect.color
	color.a = alpha
	if animate:
		create_tween().tween_property(rect, "color", color, 0.45)
	else:
		rect.color = color

func _resolve_impact_position(id: String, source: Node) -> Vector2:
	if _effects_by_id.has(id) and is_instance_valid(_effects_by_id[id]):
		return _effects_by_id[id].global_position
	if source is Node2D:
		return source.global_position
	return _player.global_position if _player is Node2D else Vector2.ZERO

func _play_wow_moment(id: String, impact_position: Vector2) -> void:
	if id.contains("toxic"):
		_pulse_screen(Color(1.0, 0.88, 0.42, 0.42), 0.9)
		_shake_camera(12.0, 0.45)
		AudioManager.play_event(&"future_changed", {"volume_db": -3.0, "pitch": 0.92})
	elif id.contains("oil") or id.contains("river") or id.contains("platform"):
		_spawn_wave(impact_position, Color(0.34, 0.84, 0.76, 0.42), 150.0)
		AudioManager.play_event(&"eco_cleanup", {"volume_db": -4.0, "pitch": 1.08})
	elif id.contains("machine") or id.contains("landfill"):
		_pulse_screen(Color(0.7, 1.0, 0.58, 0.34), 0.8)
		_shake_camera(15.0, 0.5)
		AudioManager.play_event(&"future_changed", {"volume_db": -2.0, "pitch": 0.82})

func _spawn_restoration_burst(origin: Vector2) -> void:
	for i in range(28):
		var particle := Polygon2D.new()
		particle.color = Color(0.58, 1.0, 0.5, 0.9)
		particle.polygon = PackedVector2Array([Vector2(0, -5), Vector2(4, 0), Vector2(0, 5), Vector2(-4, 0)])
		particle.position = origin
		_particle_layer.add_child(particle)
		var angle := TAU * float(i) / 28.0 + randf_range(-0.16, 0.16)
		var distance := randf_range(42.0, 140.0)
		var tween := create_tween()
		tween.tween_property(particle, "position", origin + Vector2(cos(angle), sin(angle)) * distance, randf_range(0.45, 0.8))
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.8)
		tween.tween_callback(particle.queue_free)

func _spawn_wave(origin: Vector2, color: Color, radius: float) -> void:
	var wave := Polygon2D.new()
	wave.color = color
	wave.position = origin
	wave.polygon = PackedVector2Array([Vector2(-32, -6), Vector2(32, -6), Vector2(40, 6), Vector2(-40, 6)])
	_particle_layer.add_child(wave)
	var tween := create_tween()
	tween.tween_property(wave, "scale", Vector2(radius / 32.0, 2.0), 0.55)
	tween.parallel().tween_property(wave, "modulate:a", 0.0, 0.55)
	tween.tween_callback(wave.queue_free)

func _pulse_screen(color: Color, duration: float) -> void:
	if _sun_flash == null:
		return
	_sun_flash.color = color
	var tween := create_tween()
	tween.tween_property(_sun_flash, "color:a", 0.0, duration)

func _shake_camera(amount: float, duration: float) -> void:
	var camera := _player.get_node_or_null("Camera2D") as Camera2D if _player else null
	if camera == null:
		return
	var start_offset := camera.offset
	var steps: int = maxi(4, int(duration / 0.035))
	var tween := create_tween()
	for i in range(steps):
		var strength := amount * (1.0 - float(i) / float(steps))
		tween.tween_property(camera, "offset", Vector2(randf_range(-strength, strength), randf_range(-strength, strength)), duration / float(steps))
	tween.tween_property(camera, "offset", start_offset, 0.05)

func _set_bus_volume(bus_name: String, volume_db: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, volume_db)
