extends Node2D

const GARBAGE_SCENE = preload("res://scenes/objects/garbage/garbage_collectible.tscn")

const GARBAGE_COUNT_MIN := 5
const GARBAGE_COUNT_MAX := 7
const SPAWN_CENTER := Vector2(1500, 800)
const SPREAD_RADIUS := 120.0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var count := rng.randi_range(GARBAGE_COUNT_MIN, GARBAGE_COUNT_MAX)

	for i in count:
		var offset := Vector2(
			rng.randf_range(-SPREAD_RADIUS, SPREAD_RADIUS),
			rng.randf_range(-SPREAD_RADIUS, SPREAD_RADIUS)
		)
		var piece := GARBAGE_SCENE.instantiate()
		piece.global_position = SPAWN_CENTER + offset
		add_child(piece)