extends Area2D

@export_file("*.tscn") var next_level_path: String

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		AudioManager.play_ui_click()
		if next_level_path and next_level_path != "":
			SceneChanger.change_level(next_level_path)
		else:
			push_warning("Предупреждение: Путь к следующему уровню пуст!")
