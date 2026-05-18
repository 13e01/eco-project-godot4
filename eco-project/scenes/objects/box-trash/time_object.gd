extends StaticBody2D

@onready var past_box = $PastBox
@onready var future_trash = $FutureTrash

const BOX_FRICTION = 800.0 
@onready var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var start_position: Vector2

# Состояния головоломки
var is_box_broken = false
var current_is_future = false

func _ready():
	add_to_group("time_objects")
	if past_box:
		start_position = past_box.global_position
	change_time_state(false)

func _physics_process(delta):
	if past_box.visible and not is_box_broken:
		if not past_box.is_on_floor():
			past_box.velocity.y += gravity * delta
		
		past_box.velocity.x = move_toward(past_box.velocity.x, 0, BOX_FRICTION * delta)
		past_box.move_and_slide()
	
	future_trash.global_position = past_box.global_position

func change_time_state(is_future):
	current_is_future = is_future
	
	if is_future:
		future_trash.visible = true
		past_box.visible = false
		past_box.get_node("CollisionShape2D").set_deferred("disabled", true)
		
		if is_box_broken:
			future_trash.get_node("CollisionShape2D").set_deferred("disabled", true)
			future_trash.modulate.a = 0.3
		else:
			future_trash.get_node("CollisionShape2D").disabled = false
			future_trash.modulate.a = 1.0
	else:
		past_box.visible = true
		future_trash.visible = false
		future_trash.get_node("CollisionShape2D").set_deferred("disabled", true)
		
		if is_box_broken:
			past_box.get_node("CollisionShape2D").set_deferred("disabled", true)
			past_box.modulate.a = 0.3
		else:
			past_box.get_node("CollisionShape2D").disabled = false
			past_box.modulate.a = 1.0

# РЕАЛИЗАЦИЯ АЛГОРИТМА ПОЛОМКИ (Без вмешательства в скрипт игрока)
func destroy_box_effect():
	if is_box_broken: 
		return
		
	is_box_broken = true
	print("1. Хрусь! Коробка потеряла коллизию на месте. Робот падает сквозь неё.")
	
	past_box.velocity = Vector2.ZERO
	change_time_state(current_is_future)
	
	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(past_box): return
	
	print("2. Прошла 1 секунда. Телепортируем призрака на спавн.")
	past_box.global_position = start_position
	future_trash.global_position = start_position
	past_box.velocity = Vector2.ZERO
	
	await get_tree().create_timer(3.0).timeout
	if not is_instance_valid(past_box): return
	
	print("3. Прошли 3 секунды на спавне. Коробка снова твердая и готова к работе!")
	is_box_broken = false
	
	change_time_state(current_is_future)
