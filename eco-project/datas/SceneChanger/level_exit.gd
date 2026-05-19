extends Area2D

@export_file("*.tscn") var next_level_path: String

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# ПРИНТ 1: Проверяем, видит ли зона хоть какой-то физический объект
	print("Физический объект вошел в триггер: ", body.name)
	
	if body.is_in_group("player"):
		# ПРИНТ 2: Проверяем, распознал ли код группу игрока
		print("Игрок успешно распознан! Запускаю смену сцены на: ", next_level_path)
		
		if next_level_path and next_level_path != "":
			SceneChanger.change_level(next_level_path)
		else:
			push_warning("Предупреждение: Путь к следующему уровню пуст!")
