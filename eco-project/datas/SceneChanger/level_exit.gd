extends Area2D

@export_file("*.tscn") var next_level_path: String
@export var ending_scene_path: String = "res://scenes/ui/ending_screen.tscn"
@export var save_continue_on_exit: bool = true

const SAVE_PATH := "user://eco_continue.cfg"

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		set_deferred("monitoring", false)
		AudioManager.play_ui_click()
		var target_path := next_level_path if next_level_path and next_level_path != "" else ending_scene_path
		if save_continue_on_exit:
			_save_continue_path(target_path)
		if target_path and target_path != "":
			var level := get_parent()
			if level and level.has_method("play_final_sequence") and target_path == ending_scene_path:
				await level.play_final_sequence(target_path, global_position)
				return
			SceneChanger.change_level(target_path)
		else:
			push_warning("Предупреждение: Путь к следующему уровню пуст!")

func _save_continue_path(path: String) -> void:
	var config := ConfigFile.new()
	config.set_value("continue", "scene", path)
	config.save(SAVE_PATH)
