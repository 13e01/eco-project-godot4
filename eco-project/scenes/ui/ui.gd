extends CanvasLayer

@onready var health_bar: Control = $RoundProgressBar
@onready var glitch_effect: ColorRect = $GlitchEffect
@onready var death_screen: Control = $DeathScreen
@onready var time_shader: ColorRect = $TimeJumpShader
var _warning_played: bool = false
var _eco_points_label: Label
var _restoration_label: Label
var _future_notice: Label
var _interaction_prompt: Label
var _future_flash: ColorRect
var _eco_manager: Node

func _ready() -> void:
	glitch_effect.visible = false
	glitch_effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glitch_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	death_screen.visible = false
	death_screen.get_node("Background").modulate.a = 0.0
	death_screen.get_node("LepeshkaText").visible = false
	
	# Сбрасываем шейдер тоннеля при старте
	if time_shader and time_shader.material is ShaderMaterial:
		time_shader.material.set_shader_parameter("effect_power", 0.0)

	_connect_ui_sound_events(self)
	add_to_group("eco_ui")
	_build_eco_hud()

func connect_eco_manager(manager: Node) -> void:
	_eco_manager = manager
	if _eco_manager == null:
		return
	if _eco_manager.has_signal("eco_points_changed") and not _eco_manager.eco_points_changed.is_connected(_on_eco_points_changed):
		_eco_manager.eco_points_changed.connect(_on_eco_points_changed)
	if _eco_manager.has_signal("restoration_changed") and not _eco_manager.restoration_changed.is_connected(_on_restoration_changed):
		_eco_manager.restoration_changed.connect(_on_restoration_changed)
	if _eco_manager.has_signal("future_changed") and not _eco_manager.future_changed.is_connected(_on_future_changed):
		_eco_manager.future_changed.connect(_on_future_changed)
	if _eco_manager.has_method("get_restoration_percent"):
		_on_restoration_changed(_eco_manager.get_restoration_percent(), 0.0, 0.0)
	var points_value = _eco_manager.get("eco_points")
	if points_value != null:
		_on_eco_points_changed(int(points_value), 0)

func show_eco_popup(world_position: Vector2, points: int) -> void:
	var popup := Label.new()
	popup.text = "+%d eco" % points
	popup.add_theme_font_size_override("font_size", 18)
	popup.modulate = Color(0.54, 1.0, 0.62, 1.0)
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(popup)
	var canvas_position := get_viewport().get_canvas_transform() * world_position
	popup.global_position = canvas_position
	_play_audio_event(&"eco_coin", {"volume_db": -10.0})

	var tween := create_tween()
	tween.tween_property(popup, "global_position", canvas_position + Vector2(0, -32), 0.75)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.75)
	tween.tween_callback(popup.queue_free)

func show_interaction_prompt(text: String) -> void:
	if not _interaction_prompt:
		return
	_interaction_prompt.text = text
	_interaction_prompt.modulate.a = 1.0

func hide_interaction_prompt() -> void:
	if not _interaction_prompt:
		return
	_interaction_prompt.modulate.a = 0.0

func update_sprout_ui(health_value: float) -> void:
	if health_value <= 0.01:
		if glitch_effect:
			glitch_effect.visible = false
		return

	# Обновляем значение круглого прогресс-бара
	if health_bar:
		health_bar.value = health_value
	
	# Логика эффекта глитча при низком здоровье
	if health_value < 40.0:
		if not _warning_played:
			_warning_played = true
			_play_audio_event(&"low_hp_tick", {"volume_db": -10.0})
		glitch_effect.visible = true
		var intensity := remap(health_value, 0.0, 40.0, 1.0, 0.0)
		
		if glitch_effect.material is ShaderMaterial:
			glitch_effect.material.set_shader_parameter("shake_power", 0.05 * intensity)
			glitch_effect.material.set_shader_parameter("shake_color_rate", 0.02 * intensity)
		
		glitch_effect.modulate.a = remap(health_value, 0.0, 40.0, 1.0, 0.3)
	else:
		_warning_played = false
		glitch_effect.visible = false

# Эффект временного тоннеля
func play_time_tunnel_effect() -> void:
	_play_audio_event(&"time_switch_ok", {"volume_db": -8.0})
	if time_shader and time_shader.material is ShaderMaterial:
		var mat := time_shader.material as ShaderMaterial
		
		# Мгновенная вспышка искажения
		mat.set_shader_parameter("effect_power", 1.0)
		
		# Плавное затухание за 0.7 секунды
		var tween := create_tween()
		tween.tween_property(mat, "shader_parameter/effect_power", 0.0, 0.7)

func _build_eco_hud() -> void:
	var panel := VBoxContainer.new()
	panel.name = "EcoHud"
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -260.0
	panel.offset_top = 24.0
	panel.offset_right = -24.0
	panel.offset_bottom = 96.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	_eco_points_label = Label.new()
	_eco_points_label.text = "Eco 0"
	_eco_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_eco_points_label.add_theme_font_size_override("font_size", 18)
	panel.add_child(_eco_points_label)

	_restoration_label = Label.new()
	_restoration_label.text = "Environment Restored: 0%"
	_restoration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_restoration_label.modulate = Color(0.72, 0.92, 0.78, 0.9)
	_restoration_label.add_theme_font_size_override("font_size", 14)
	panel.add_child(_restoration_label)

	_future_notice = Label.new()
	_future_notice.text = "Future changed"
	_future_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_future_notice.modulate = Color(0.65, 0.95, 1.0, 0.0)
	_future_notice.add_theme_font_size_override("font_size", 15)
	panel.add_child(_future_notice)

	_interaction_prompt = Label.new()
	_interaction_prompt.name = "InteractionPrompt"
	_interaction_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_interaction_prompt.offset_left = -150.0
	_interaction_prompt.offset_top = -108.0
	_interaction_prompt.offset_right = 150.0
	_interaction_prompt.offset_bottom = -72.0
	_interaction_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interaction_prompt.text = "[F] Clean Pollution"
	_interaction_prompt.modulate = Color(0.86, 1.0, 0.72, 0.0)
	_interaction_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interaction_prompt.add_theme_font_size_override("font_size", 18)
	add_child(_interaction_prompt)

	_future_flash = ColorRect.new()
	_future_flash.name = "FutureChangedFlash"
	_future_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_future_flash.color = Color(0.52, 1.0, 0.72, 0.0)
	_future_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_future_flash)

func _on_eco_points_changed(points: int, _delta: int) -> void:
	if _eco_points_label:
		_eco_points_label.text = "Eco %d" % points

func _on_restoration_changed(percent: float, _restored_weight: float, _total_weight: float) -> void:
	if _restoration_label:
		_restoration_label.text = "Environment Restored: %d%%" % int(round(percent))

func _on_future_changed(_eco_id: StringName) -> void:
	if not _future_notice:
		return
	_future_notice.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(0.8)
	tween.tween_property(_future_notice, "modulate:a", 0.0, 0.5)
	if _future_flash:
		_future_flash.color.a = 0.18
		var flash_tween := create_tween()
		flash_tween.tween_property(_future_flash, "color:a", 0.0, 0.45)

# Экран смерти "Лепешка"
func display_lepeshka_screen() -> void:
	_play_audio_event(&"death", {"volume_db": -3.0})
	glitch_effect.visible = false 
	if time_shader: 
		time_shader.visible = false
		
	death_screen.visible = true
	
	var bg := death_screen.get_node("Background")
	var text := death_screen.get_node("LepeshkaText")
	text.visible = true
	
	var tween := create_tween()
	tween.tween_property(bg, "modulate:a", 1.0, 0.5)
	
	tween.tween_callback(func():
		var level := get_parent()
		if level and level.has_method("restart_level_safe"):
			level.restart_level_safe()
	)

func _connect_ui_sound_events(node: Node) -> void:
	if node is BaseButton:
		var button: BaseButton = node as BaseButton
		if not button.mouse_entered.is_connected(_on_ui_hover):
			button.mouse_entered.connect(_on_ui_hover)
		if not button.pressed.is_connected(_on_ui_click):
			button.pressed.connect(_on_ui_click)

	for child: Node in node.get_children():
		_connect_ui_sound_events(child)

func _on_ui_hover() -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager and audio_manager.has_method("play_ui_hover"):
		audio_manager.play_ui_hover()

func _on_ui_click() -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager and audio_manager.has_method("play_ui_click"):
		audio_manager.play_ui_click()

func _play_audio_event(event_name: StringName, options: Dictionary = {}) -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager and audio_manager.has_method("play_event"):
		audio_manager.play_event(event_name, options)
