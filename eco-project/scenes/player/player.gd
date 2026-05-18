extends CharacterBody2D

signal health_changed(new_value)
signal player_crushed

# --- НАСТРОЙКИ ДВИЖЕНИЯ ---
const SPEED = 200.0
const JUMP_VELOCITY = -360.0

# --- GAME FEEL ---
const COYOTE_DURATION = 0.15
const AIR_CONTROL_MULTIPLIER = 0.65
const FALL_GRAVITY_SCALE = 0.75
const SQUASH_SPEED = 15.0

var coyote_timer = 0.0
var jump_lockout_timer = 0.0 # НОВЫЙ ТАЙМЕР: жесткая блокировка прыжка при поломке

# --- СОСТОЯНИЕ СМЕРТИ ---
var is_dying = false
var death_timer = 0.0
var shake_intensity = 5.0
var target_death_zoom = Vector2.ONE 
var explosion_launched = false      

@export var max_health: float = 100.0
var current_health: float = 100.0
var is_in_future = false 

var damage_rate = 15.0 
var recovery_rate = 20.0

@onready var sprite = $AnimatedSprite2D
@onready var camera = $Camera2D
@onready var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
@onready var explosion_sprite = $ExplosionSprite

func _physics_process(delta):
	if is_dying:
		_process_death_sequence(delta)
		return

	if test_move(global_transform, Vector2.ZERO):
		start_death_sequence()
		return

	var was_on_floor = is_on_floor()
	jump_lockout_timer -= delta # Уменьшаем таймер блокировки

	if not is_on_floor():
		velocity.y += gravity * FALL_GRAVITY_SCALE * delta
		coyote_timer -= delta
	else:
		coyote_timer = COYOTE_DURATION

	if is_in_future:
		current_health -= damage_rate * delta
	else:
		current_health = move_toward(current_health, 100.0, recovery_rate * delta)
	
	current_health = clamp(current_health, 0, 100.0)
	health_changed.emit(current_health)

	# ПРОВЕРКА ПРЫЖКА С УЧЕТОМ ЖЕСТКОЙ БЛОКИРОВКИ
	if coyote_timer > 0.0 and input_jump() and jump_lockout_timer <= 0.0:
		velocity.y = JUMP_VELOCITY
		coyote_timer = 0.0
		sprite.scale = Vector2(0.8, 1.2)

	var direction = Input.get_axis("ui_left", "ui_right")
	var max_allowed_speed = SPEED if is_on_floor() else SPEED * AIR_CONTROL_MULTIPLIER

	if direction:
		var accel = SPEED * (0.25 if is_on_floor() else 0.05)
		velocity.x = move_toward(velocity.x, direction * max_allowed_speed, accel)
		sprite.flip_h = direction > 0
		if is_on_floor(): sprite.play("walk")
	else:
		var friction = SPEED * (0.25 if is_on_floor() else 0.02)
		velocity.x = move_toward(velocity.x, 0, friction)
		if is_on_floor(): sprite.play("idle")

	move_and_slide()

	# --- ВЗАИМОДЕЙСТВИЕ С КОРОБКОЙ ---
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider and collider.name == "PastBox":
			var normal = collision.get_normal()
			
			# 1. Если робот встал на коробку СВЕРХУ
			if normal.y < -0.5:
				jump_lockout_timer = 0.2 # Блокируем прыжок на 0.2 секунды
				coyote_timer = 0.0       # Обнуляем койот-тайм, чтобы не было прыжка "в падении"
				
				if collider.get_parent().has_method("destroy_box_effect"):
					collider.get_parent().destroy_box_effect()
			
			# 2. Если робот толкает коробку СБОКУ
			elif abs(normal.x) > 0.5:
				collider.velocity.x = -normal.x * 120.0 
	# --------------------------------------------------

	if is_on_floor() and not was_on_floor:
		sprite.scale = Vector2(1.3, 0.7)

	sprite.scale.x = lerp(sprite.scale.x, 1.0, SQUASH_SPEED * delta)
	sprite.scale.y = lerp(sprite.scale.y, 1.0, SQUASH_SPEED * delta)

func start_death_sequence():
	is_dying = true
	death_timer = 0.0
	velocity = Vector2.ZERO
	sprite.play("idle")
	
	target_death_zoom = camera.zoom * 2.5
	print("Бум! Робот раздавлен. Приближаем камеру до: ", target_death_zoom)

func _process_death_sequence(delta):
	# ... (Код смерти остался без изменений) ...
	death_timer += delta
	
	if death_timer < 0.6:
		camera.zoom = camera.zoom.lerp(target_death_zoom, 5.0 * delta)
		sprite.position = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
	elif death_timer < 0.8:
		sprite.position = Vector2.ZERO
	elif death_timer < 1.2:
		if not explosion_launched:
			explosion_launched = true
			sprite.visible = false            
			explosion_sprite.visible = true   
			explosion_sprite.play()           
	else:
		set_physics_process(false)
		player_crushed.emit() 

func input_jump():
	return Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_accept")
