extends Node2D

@onready var nature_layer = $World2D/TileMapLayer_Nature
@onready var trash_layer = $World2D/TileMapLayer_Trash
@onready var nature_bg = $ParallaxBackground/ParallaxLayer_Nature
@onready var trash_bg = $ParallaxBackground/ParallaxLayer_Trash
@onready var canvas_mod = $CanvasModulate
@onready var player = $Player

var is_future = false

const TIME_COOLDOWN_DURATION = 2.0 
var time_cooldown_timer = 0.0

func _ready():
	nature_bg.visible = true
	trash_bg.visible = true
	nature_bg.modulate.a = 1.0
	trash_bg.modulate.a = 0.0
	
	if player.has_signal("health_changed") and not player.health_changed.is_connected($UI.update_sprout_ui):
		player.health_changed.connect($UI.update_sprout_ui)
	
	if player.has_signal("player_crushed"):
		player.player_crushed.connect(show_game_over)
	
	update_world_state()

func _process(delta):
	if player.is_dying:
		return
		
	if time_cooldown_timer > 0.0:
		time_cooldown_timer -= delta
		
	if is_future and player.current_health <= 0:
		is_future = false
		if has_node("UI") and $UI.has_method("play_time_tunnel_effect"):
			$UI.play_time_tunnel_effect()
		update_world_state()
		print("Критический разряд! Возврат в прошлое...")

func _input(event):
	if player.is_dying:
		return

	if event.is_action_pressed("switch_time"):
		if time_cooldown_timer > 0.0:
			return

		if not is_future and player.current_health <= 5:
			print("Недостаточно заряда для прыжка!")
			return
			
		if has_node("UI") and $UI.has_method("play_time_tunnel_effect"):
			$UI.play_time_tunnel_effect()
		
		is_future = !is_future
		time_cooldown_timer = TIME_COOLDOWN_DURATION
		update_world_state()

func update_world_state():
	nature_layer.visible = !is_future
	nature_layer.enabled = !is_future
	trash_layer.visible = is_future
	trash_layer.enabled = is_future
	
	player.is_in_future = is_future
	
	var tween = create_tween()
	if is_future:
		tween.tween_property(nature_bg, "modulate:a", 0.0, 0.5)
		tween.parallel().tween_property(trash_bg, "modulate:a", 1.0, 0.5)
		canvas_mod.color = Color(0.6, 0.5, 0.5)
	else:
		tween.tween_property(nature_bg, "modulate:a", 1.0, 0.5)
		tween.parallel().tween_property(trash_bg, "modulate:a", 0.0, 0.5)
		canvas_mod.color = Color(1, 1, 1)

	# --- АВТОМАТИЧЕСКОЕ ПЕРЕКЛЮЧЕНИЕ ВСЕХ ОБЪЕКТОВ НА СЦЕНЕ ---
	get_tree().call_group("time_objects", "change_time_state", is_future)
	# ---------------------------------------------------------

func show_game_over():
	if has_node("UI") and $UI.has_method("display_lepeshka_screen"):
		$UI.display_lepeshka_screen()

func restart_level_safe():
	await get_tree().create_timer(2.0).timeout
	get_tree().call_deferred("reload_current_scene")
