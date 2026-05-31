# Структура проекта

## Дерево папок
```
eco_game/
├── scenes/
│   ├── core/              # Основные сцены (Main, Loading, UI)
│   ├── game/              # Игровые сцены (World, Player, Ecosystem)
│   ├── ui/                # UI элементы (Menu, HUD, Dialogs)
│   └── managers/          # Менеджер сцены для сервисов
├── scripts/
│   ├── autoload/          # Глобальные синглтоны (Managers)
│   ├── core/              # Базовые классы и утилиты
│   ├── game/              # Игровая логика
│   ├── ui/                # UI логика
│   ├── data/              # Обработка данных
│   └── services/          # Внешние API, сохранения
├── resources/
│   ├── data/              # JSON/CSV данные
│   ├── theme/             # Theme ресурсы
│   ├── audio/             # Музыка и звуки
│   └── textures/          # Спрайты и текстуры
├── docs/                  # Документация
│   ├── ARCHITECTURE.md
│   ├── DATA_STRUCTURES.md
│   ├── API.md
│   └── GUIDELINES.md
├── tests/                 # GDScript тесты (если используется)
├── .godot/                # Кеш Godot (в .gitignore)
├── .git/
├── project.godot          # Godot конфиг
├── .gitignore
└── .gitignore_ai          # Для AI моделей
```

## Назначение папок
- **scenes/** - Все .tscn файлы, видимые в сцене
- **scripts/** - Все .gd файлы, четко разделены по типам
- **resources/** - Данные, не код: JSON, изображения, звуки
- **docs/** - Только Markdown документация
- **tests/** - Модульные тесты

## Правила именования
- Сцены: `PascalCase.tscn` (PlayerCharacter.tscn)
- Скрипты: `snake_case.gd` (player_manager.gd)
- Ресурсы: `snake_case` (player_stats.json, forest_biome.tres)
- Переменные: `snake_case` (player_health, is_jumping)