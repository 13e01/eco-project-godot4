# API документация сервисов

## GameManager
```gdscript
func start_game() -> void
func pause_game() -> void
func resume_game() -> void
func end_game(reason: String) -> void
```

## EventBus
```gdscript
# Сигналы, не методы!
signal game_started
signal game_paused
signal player_died(reason: String)
signal ecosystem_changed(new_state: EcosystemState)
```

## SaveManager
```gdscript
func save_game(slot: int) -> void  # Асинхронно
func load_game(slot: int) -> SaveData
func get_save_info(slot: int) -> Dictionary