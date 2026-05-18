extends CanvasLayer

@onready var health_bar = $SproutHealthBar
@onready var glitch_effect = $GlitchEffect
@onready var death_screen = $DeathScreen

# Ссылка на узел шейдера, который мы перенесли в UI
@onready var time_shader = $TimeJumpShader

func _ready():
	glitch_effect.visible = false
	glitch_effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glitch_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	death_screen.visible = false
	death_screen.get_node("Background").modulate.a = 0.0
	death_screen.get_node("LepeshkaText").visible = false
	
	# Сбрасываем шейдер тоннеля при старте
	if time_shader and time_shader.material is ShaderMaterial:
		time_shader.material.set_shader_parameter("effect_power", 0.0)

func update_sprout_ui(health_value):
	if health_value <= 0.01:
		if glitch_effect:
			glitch_effect.visible = false
		return

	health_bar.value = health_value
	
	if health_value < 40:
		glitch_effect.visible = true
		var intensity = remap(health_value, 0, 40, 1.0, 0.0)
		
		if glitch_effect.material is ShaderMaterial:
			glitch_effect.material.set_shader_parameter("shake_power", 0.05 * intensity)
			glitch_effect.material.set_shader_parameter("shake_color_rate", 0.02 * intensity)
		
		glitch_effect.modulate.a = remap(health_value, 0, 40, 1.0, 0.3)
	else:
		glitch_effect.visible = false

# ФУНКЦИЯ ЭФФЕКТА: Теперь живет внутри UI
func play_time_tunnel_effect():
	if time_shader and time_shader.material is ShaderMaterial:
		var mat = time_shader.material
		
		# Мгновенная вспышка искажения
		mat.set_shader_parameter("effect_power", 1.0)
		
		# Плавное затухание за 0.7 секунды
		var tween = create_tween()
		tween.tween_property(mat, "shader_parameter/effect_power", 0.0, 0.7)

func display_lepeshka_screen():
	glitch_effect.visible = false 
	if time_shader: time_shader.visible = false # Выключаем тоннель при смерти
	death_screen.visible = true
	
	var bg = death_screen.get_node("Background")
	var text = death_screen.get_node("LepeshkaText")
	
	text.visible = true
	
	var tween = create_tween()
	tween.tween_property(bg, "modulate:a", 1.0, 0.5)
	
	tween.tween_callback(func():
		var level = get_parent()
		if level and level.has_method("restart_level_safe"):
			level.restart_level_safe()
	)
