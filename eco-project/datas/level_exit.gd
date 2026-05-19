extends Area2D

# Экспортируемое поле. Позволит выбирать сцену прямо в Инспекторе
@export_file("*.tscn") var next_level_path: String

func _ready() -> void:
	# Подключаем встроенный сигнал зоны к нашей функции
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# Проверяем по твоей группе "player"
	if body.is_in_group("player"):
		if next_level_path and next_level_path != "":
			SceneChanger.change_level(next_level_path)
		else:
			push_warning("Предупреждение: Путь к следующему уровню пуст!")
