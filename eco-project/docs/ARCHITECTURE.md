# Архитектура ECO-GAME

## 1. Слои приложения

### 1.1 Autoload Синглтоны (Global Services)
| Сервис | Ответственность | Файл |
|--------|-----------------|------|
| GameManager | Основное управление игрой | scripts/autoload/game_manager.gd |
| EventBus | Сигналы между сценами | scripts/autoload/event_bus.gd |
| AudioManager | Музыка и звуки | scripts/autoload/audio_manager.gd |
| SaveManager | Сохранения/загрузки | scripts/autoload/save_manager.gd |
| DataManager | Кеш глобальных данных | scripts/autoload/data_manager.gd |

### 1.2 Game Layer
- World (сцена)
  - Player (скрипт + сцена)
  - EcosystemController (скрипт управления биомом)
  - EnvironmentManager (скрипт управления климатом)

### 1.3 UI Layer
- Отдельна от Game Layer
- Подписывается на EventBus
- НЕ общается напрямую с игровой логикой

### 1.4 Data Layer
- Статические данные в `resources/data/*.json`
- Динамические данные в синглтонах
- Cache паттерн в DataManager

## 2. Паттерны кода

### 2.1 Сигнал-ориентированная архитектура
```gdscript
# Плохо: прямое общение
player.damage(10)

# Хорошо: через EventBus
EventBus.player_damaged.emit(10)
```

### 2.2 Dependency Injection для тестирования
```gdscript
class_name PlayerController
extends Node

@export var config: PlayerConfig  # Внедрение зависимостей
```

## 3. Поток данных

```
User Input
    ↓
InputHandler (scripts/core/input_handler.gd)
    ↓
Game Logic Layer (PlayerController, EcosystemController)
    ↓
EventBus.signal_name.emit(data)
    ↓
UI Layer (подписана на сигналы)
    ↓
SaveManager (асинхронно сохраняет)
```

## 4. Критические правила

❌ **НЕЛЬЗЯ:**
- Сцены общаются напрямую без EventBus
- UI обращается к игровой логике напрямую
- Скрипты игры содержат UI логику
- Жесткие пути (использовать NodePath)

✅ **ОБЯЗАТЕЛЬНО:**
- Все сигналы определены в EventBus
- Все данные кешируются в DataManager
- Каждый слой не зависит от других