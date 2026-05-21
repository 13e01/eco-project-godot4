@tool
extends Control

# Базовые переменные
@export var value: float = 100.0: set = _set_value
@export var max_value: float = 100.0: set = _set_max_value

# Настройки внешнего вида (можно крутить прямо в инспекторе)
@export var radius: float = 40.0: set = _set_radius
@export var line_width: float = 8.0: set = _set_line_width
@export var progress_color: Color = Color.GREEN: set = _set_color
@export var background_color: Color = Color(0.2, 0.2, 0.2, 0.5): set = _set_bg_color

# Встроенная функция отрисовки векторной графики
func _draw() -> void:
	var center := size / 2.0
	
	# 1. Задний фон (серое кольцо-подложка)
	draw_arc(center, radius, 0.0, TAU, 64, background_color, line_width, true)
	
	# 2. Активная полоса прогресса
	var safe_max := max_value if max_value > 0.0 else 1.0
	var angle := (value / safe_max) * TAU
	
	# -PI / 2.0 разворачивает дугу на 12 часов (вверх)
	if angle > 0.0:
		draw_arc(center, radius, -PI / 2.0, angle - PI / 2.0, 64, progress_color, line_width, true)

# Сеттеры, принудительно обновляющие графику (queue_redraw) при изменении переменных
func _set_value(val: float) -> void:
	value = clamp(val, 0.0, max_value)
	queue_redraw()

func _set_max_value(val: float) -> void:
	max_value = max(0.0, val)
	queue_redraw()

func _set_radius(val: float) -> void:
	radius = val
	queue_redraw()

func _set_line_width(val: float) -> void:
	line_width = val
	queue_redraw()

func _set_color(val: Color) -> void:
	progress_color = val
	queue_redraw()

func _set_bg_color(val: Color) -> void:
	background_color = val
	queue_redraw()
