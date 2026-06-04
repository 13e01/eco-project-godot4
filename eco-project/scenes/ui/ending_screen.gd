extends Control

const GOOD_ENDING_PERCENT := 65.0
const MAIN_MENU := "res://scenes/ui/main_menu.tscn"

@onready var _background: ColorRect = %Background
@onready var _sun: ColorRect = %Sunlight
@onready var _glitch: ColorRect = %GlitchWash
@onready var _plants: Node2D = %Plants
@onready var _title: Label = %EndingTitle
@onready var _subtitle: Label = %EndingSubtitle
@onready var _percent: Label = %PercentLabel
@onready var _fade: ColorRect = %Fade

var _restoration := 0.0
var _good := false

func _ready() -> void:
	_restoration = EcoManager.get_restoration_percent()
	_good = _restoration >= GOOD_ENDING_PERCENT
	_setup_scene()
	_play_cinematic()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		SceneChanger.change_level(MAIN_MENU)

func _setup_scene() -> void:
	_percent.text = tr("HUD_RESTORATION") % int(round(_restoration))
	if _good:
		_background.color = Color(0.18, 0.28, 0.24, 1.0)
		_sun.color = Color(1.0, 0.86, 0.48, 0.0)
		_glitch.color = Color(0.2, 0.7, 0.48, 0.0)
		_title.text = tr("ENDING_GOOD_TITLE")
		_subtitle.text = tr("ENDING_GOOD_SUBTITLE")
		AudioManager.set_time_era(false, 1.4)
	else:
		_background.color = Color(0.12, 0.1, 0.1, 1.0)
		_sun.color = Color(0.55, 0.22, 0.18, 0.0)
		_glitch.color = Color(0.58, 0.08, 0.12, 0.0)
		_title.text = tr("ENDING_BAD_TITLE")
		_subtitle.text = tr("ENDING_BAD_SUBTITLE")
		AudioManager.set_time_era(true, 1.4)
	_build_plants()

func _build_plants() -> void:
	for i in range(18 if _good else 5):
		var sprout := Node2D.new()
		sprout.position = Vector2(120 + i * 64, 515 + sin(float(i)) * 22)
		sprout.scale = Vector2.ONE * (0.8 + float(i % 4) * 0.18)
		_plants.add_child(sprout)

		var stem := Polygon2D.new()
		stem.color = Color(0.36, 0.8, 0.35, 0.95) if _good else Color(0.25, 0.36, 0.22, 0.8)
		stem.polygon = PackedVector2Array([Vector2(-4, 22), Vector2(4, 22), Vector2(2, -24), Vector2(-2, -24)])
		sprout.add_child(stem)

		var leaf := Polygon2D.new()
		leaf.color = Color(0.58, 0.96, 0.45, 0.94) if _good else Color(0.28, 0.42, 0.24, 0.75)
		leaf.polygon = PackedVector2Array([Vector2(0, -18), Vector2(30, -34), Vector2(13, -4), Vector2(-24, -28), Vector2(-10, 2)])
		sprout.add_child(leaf)

func _play_cinematic() -> void:
	_fade.color.a = 1.0
	_title.modulate.a = 0.0
	_subtitle.modulate.a = 0.0
	_percent.modulate.a = 0.0
	_plants.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 0.0, 1.0)
	tween.parallel().tween_property(_sun, "color:a", 0.36 if _good else 0.12, 1.4)
	tween.parallel().tween_property(_glitch, "color:a", 0.04 if _good else 0.24, 1.1)
	tween.tween_property(_plants, "modulate:a", 1.0, 1.0)
	tween.tween_property(_title, "modulate:a", 1.0, 0.65)
	tween.parallel().tween_property(_subtitle, "modulate:a", 1.0, 0.65)
	tween.tween_property(_percent, "modulate:a", 1.0, 0.45)
