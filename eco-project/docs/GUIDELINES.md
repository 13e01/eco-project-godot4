# Гайдлайны кодирования

## GDScript стиль
- Переменные: `snake_case`
- Функции: `snake_case()`
- Классы: `PascalCase`
- Константы: `SCREAMING_SNAKE_CASE`

## Аннотации типов (ОБЯЗАТЕЛЬНО)
```gdscript
# Правильно
func take_damage(amount: int) -> void:
    health -= amount

# Неправильно
func take_damage(amount):
    health = health - amount
```

## Документирование функций
```gdscript
## Наносит урон игроку и запускает анимацию.
## [br]damage_amount: количество урона (int)
func take_damage(damage_amount: int) -> void:
    pass
```

## Сигналы в EventBus
```gdscript
# scripts/autoload/event_bus.gd
extends Node

## Запускается когда игрок получает урон
signal player_damaged(amount: int)

## Запускается когда экосистема меняется
signal ecosystem_state_changed(state: EcosystemState)
```

## Обработка ошибок
```gdscript
# Использовать assert для разработки
assert(health >= 0, "Health не может быть отрицательным")

# Использовать push_error для логирования
if data == null:
    push_error("Данные не загружены: %s" % file_path)
    return null