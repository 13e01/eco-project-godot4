extends Control

const MOVE_LEFT := &"move_left"
const MOVE_RIGHT := &"move_right"
const MOVE_UP := &"move_up"
const MOVE_DOWN := &"move_down"
const JUMP := &"jump"
const SWITCH_TIME := &"switch_time"
const INTERACT := &"interact"

const ACTION_BUTTONS := [
	{"action": JUMP, "label": "J"},
	{"action": SWITCH_TIME, "label": "T"},
	{"action": INTERACT, "label": "I"},
]

@export var show_on_desktop := false

var _safe_rect := Rect2()
var _joystick_center := Vector2.ZERO
var _joystick_radius := 72.0
var _knob_radius := 30.0
var _joystick_vector := Vector2.ZERO
var _joystick_touch_id := -1
var _button_radius := 34.0
var _button_rects: Dictionary = {}
var _touch_actions: Dictionary = {}
var _pressed_actions: Dictionary = {}
var _mouse_action: StringName = &""
var _mouse_using_joystick := false


func _ready() -> void:
	anchors_preset = PRESET_FULL_RECT
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = show_on_desktop or OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile")
	set_process_input(visible)
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()


func _exit_tree() -> void:
	_release_all()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)
	elif show_on_desktop and event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif show_on_desktop and event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _draw() -> void:
	if not visible:
		return

	var base_color := Color(0.05, 0.07, 0.08, 0.38)
	var rim_color := Color(0.82, 0.95, 0.86, 0.82)
	var active_color := Color(0.32, 0.78, 0.53, 0.7)
	var knob_center := _joystick_center + (_joystick_vector * (_joystick_radius - _knob_radius * 0.55))

	draw_circle(_joystick_center, _joystick_radius, base_color)
	draw_arc(_joystick_center, _joystick_radius, 0.0, TAU, 64, rim_color, 3.0)
	draw_circle(knob_center, _knob_radius, active_color if _joystick_vector.length() > 0.01 else Color(0.82, 0.95, 0.86, 0.55))

	var font := get_theme_default_font()
	for button_data in ACTION_BUTTONS:
		var action: StringName = button_data.action
		var rect: Rect2 = _button_rects.get(action, Rect2())
		var center := rect.get_center()
		var pressed := _pressed_actions.has(action)
		draw_circle(center, _button_radius, active_color if pressed else base_color)
		draw_arc(center, _button_radius, 0.0, TAU, 48, rim_color, 3.0)

		var label: String = button_data.label
		var font_size := int(max(18.0, _button_radius * 0.82))
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size)
		draw_string(font, center - text_size * 0.5 + Vector2(0.0, text_size.y * 0.78), label, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size, Color(0.95, 1.0, 0.96, 0.92))


func _update_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var safe_area := DisplayServer.get_display_safe_area()
	_safe_rect = Rect2(Vector2.ZERO, viewport_size)
	if safe_area.size.x > 0 and safe_area.size.y > 0:
		var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
		var display_safe_rect := Rect2(Vector2(safe_area.position), Vector2(safe_area.size))
		var clamped_safe_rect := viewport_rect.intersection(display_safe_rect)
		if clamped_safe_rect.size.x > 0.0 and clamped_safe_rect.size.y > 0.0:
			_safe_rect = clamped_safe_rect

	var min_axis: float = min(_safe_rect.size.x, _safe_rect.size.y)
	var scale: float = clamp(min_axis / 720.0, 0.78, 1.35)
	var margin: float = 30.0 * scale

	_joystick_radius = 72.0 * scale
	_knob_radius = 30.0 * scale
	_button_radius = 34.0 * scale

	_joystick_center = Vector2(
		_safe_rect.position.x + margin + _joystick_radius,
		_safe_rect.end.y - margin - _joystick_radius
	)

	_button_rects.clear()
	var gap: float = 18.0 * scale
	var button_step: float = _button_radius * 2.0 + gap
	var right: float = _safe_rect.end.x - margin - _button_radius
	var bottom: float = _safe_rect.end.y - margin - _button_radius
	var centers := {
		JUMP: Vector2(right, bottom - button_step),
		SWITCH_TIME: Vector2(right - button_step, bottom),
		INTERACT: Vector2(right, bottom),
	}
	for action in centers:
		_button_rects[action] = Rect2(centers[action] - Vector2.ONE * _button_radius, Vector2.ONE * _button_radius * 2.0)

	queue_redraw()


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _is_inside_joystick(event.position) and _joystick_touch_id == -1:
			_joystick_touch_id = event.index
			_set_joystick_vector(event.position)
			return

		var action := _button_action_at(event.position)
		if not action.is_empty():
			_touch_actions[event.index] = action
			_press_action(action)
			return

	if _joystick_touch_id == event.index:
		_joystick_touch_id = -1
		_set_joystick_vector(_joystick_center)
		return

	if _touch_actions.has(event.index):
		_release_action(_touch_actions[event.index])
		_touch_actions.erase(event.index)


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index == _joystick_touch_id:
		_set_joystick_vector(event.position)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed:
		if _is_inside_joystick(event.position):
			_mouse_using_joystick = true
			_set_joystick_vector(event.position)
			return

		_mouse_action = _button_action_at(event.position)
		if not _mouse_action.is_empty():
			_press_action(_mouse_action)
			return

	if _mouse_using_joystick:
		_mouse_using_joystick = false
		_set_joystick_vector(_joystick_center)
	if not _mouse_action.is_empty():
		_release_action(_mouse_action)
		_mouse_action = &""


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _mouse_using_joystick:
		_set_joystick_vector(event.position)


func _is_inside_joystick(point: Vector2) -> bool:
	return point.distance_to(_joystick_center) <= _joystick_radius * 1.45


func _button_action_at(point: Vector2) -> StringName:
	for action in _button_rects:
		var rect: Rect2 = _button_rects[action]
		if point.distance_to(rect.get_center()) <= _button_radius * 1.25:
			return action
	return &""


func _set_joystick_vector(point: Vector2) -> void:
	var offset := point - _joystick_center
	_joystick_vector = offset.limit_length(_joystick_radius) / _joystick_radius
	_apply_axis_action(MOVE_LEFT, max(-_joystick_vector.x, 0.0))
	_apply_axis_action(MOVE_RIGHT, max(_joystick_vector.x, 0.0))
	_apply_axis_action(MOVE_UP, max(-_joystick_vector.y, 0.0))
	_apply_axis_action(MOVE_DOWN, max(_joystick_vector.y, 0.0))
	queue_redraw()


func _apply_axis_action(action: StringName, strength: float) -> void:
	if strength > 0.18:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _press_action(action: StringName) -> void:
	if _pressed_actions.has(action):
		return

	_pressed_actions[action] = true
	Input.action_press(action)
	queue_redraw()


func _release_action(action: StringName) -> void:
	if not _pressed_actions.has(action):
		return

	_pressed_actions.erase(action)
	Input.action_release(action)
	queue_redraw()


func _release_all() -> void:
	_set_joystick_vector(_joystick_center)
	for action in _pressed_actions.keys():
		Input.action_release(action)
	_pressed_actions.clear()
	_touch_actions.clear()
	_joystick_touch_id = -1
	_mouse_action = &""
	_mouse_using_joystick = false
