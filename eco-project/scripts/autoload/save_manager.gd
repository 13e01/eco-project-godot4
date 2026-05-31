extends Node

## Менеджер сохранений.
## Асинхронно сохраняет и загружает состояние игры.

const SAVE_DIR: String = "user://saves/"
const SAVE_EXTENSION: String = ".save"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func save_game(slot: int) -> void:
	var save_path: String = SAVE_DIR + "slot_" + str(slot) + SAVE_EXTENSION
	var save_data: Dictionary = _collect_save_data()
	
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("Не удалось открыть файл для сохранения: %s" % save_path)
		return
	
	file.store_line(JSON.stringify(save_data))
	file.close()
	EventBus.game_saved.emit(slot)

func load_game(slot: int) -> Dictionary:
	var save_path: String = SAVE_DIR + "slot_" + str(slot) + SAVE_EXTENSION
	
	if not FileAccess.file_exists(save_path):
		push_error("Файл сохранения не найден: %s" % save_path)
		return {}
	
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_error("Не удалось открыть файл загрузки: %s" % save_path)
		return {}
	
	var json_str: String = file.get_line()
	var data: Dictionary = JSON.parse_string(json_str)
	file.close()
	
	if data.is_empty():
		push_error("Данные сохранения повреждены: %s" % save_path)
		return {}
	
	EventBus.game_loaded.emit(slot)
	return data

func get_save_info(slot: int) -> Dictionary:
	var save_path: String = SAVE_DIR + "slot_" + str(slot) + SAVE_EXTENSION
	
	if not FileAccess.file_exists(save_path):
		return {}
	
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	var json_str: String = file.get_line()
	file.close()
	
	return JSON.parse_string(json_str)

func _collect_save_data() -> Dictionary:
	return {
		"timestamp": Time.get_unix_time_from_system(),
		"player_data": {},
		"playtime": 0
	}