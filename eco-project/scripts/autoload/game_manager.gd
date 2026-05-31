extends Node

## Основное управление игрой (Game Loop).
## Контролирует состояния игры: start, pause, resume, end.

var is_paused: bool = false

func start_game() -> void:
	is_paused = false
	EventBus.game_started.emit()

func pause_game() -> void:
	if is_paused:
		return
	is_paused = true
	get_tree().paused = true
	EventBus.game_paused.emit()

func resume_game() -> void:
	if not is_paused:
		return
	is_paused = false
	get_tree().paused = false
	EventBus.game_resumed.emit()

func end_game(reason: String) -> void:
	is_paused = true
	get_tree().paused = true
	EventBus.game_ended.emit(reason)