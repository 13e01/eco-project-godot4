# Структуры данных проекта

## Глобальные структуры

### PlayerData
```gdscript
class_name PlayerData
extends Resource

var player_id: String
var health: int
var energy: int
var inventory: Array[InventoryItem]
var position: Vector2
var level: int
```

### EcosystemState
```gdscript
class_name EcosystemState
extends Resource

var biome: String  # "forest", "desert", "ocean"
var temperature: float  # -50 to 50
var humidity: int  # 0-100
var pollution: int  # 0-100
var species: Dictionary  # Словарь видов
```

### SaveData
```gdscript
class_name SaveData
extends Resource

var timestamp: int
var player_data: PlayerData
var ecosystem_data: EcosystemState
var playtime: int
```

## Правила типов
- Используй typed переменные везде
- Для сложных данных создавай класс с @export
- Сохраняй простые типы в JSON