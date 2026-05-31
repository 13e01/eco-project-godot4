extends Node

## Менеджер кеширования данных.
## Хранит глобальные данные и предоставляет быстрый доступ к ним.

var player_data: Dictionary = {}
var ecosystem_state: Dictionary = {}

func cache_player_data(data: Dictionary) -> void:
	player_data = data

func get_player_data() -> Dictionary:
	return player_data

func cache_ecosystem_state(state: Dictionary) -> void:
	ecosystem_state = state

func get_ecosystem_state() -> Dictionary:
	return ecosystem_state

func clear_cache() -> void:
	player_data.clear()
	ecosystem_state.clear()

func load_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Не удалось загрузить JSON: %s" % path)
		return {}
	
	var json_str: String = file.get_as_text()
	file.close()
	return JSON.parse_string(json_str)