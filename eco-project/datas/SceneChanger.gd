extends Node

func change_level(target_scene_path: String) -> void:
	# Проверка на существование файла перед переходом
	if not ResourceLoader.exists(target_scene_path):
		push_error("Ошибка: Сцена '" + target_scene_path + "' не найдена!")
		return
		
	# Сама смена сцены
	var error = get_tree().change_scene_to_file(target_scene_path)
	if error != OK:
		push_error("Ошибка перехода: " + str(error))
