extends Control

const FIRST_LEVEL := "res://scenes/maps/tutorial/TutorialLevel.tscn"
const SAVE_PATH := "user://eco_continue.cfg"
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]

@onready var _settings_panel: Control = %SettingsPanel
@onready var _continue_button: Button = %ContinueButton
@onready var _contrast: ColorRect = %EcoFutureContrast
@onready var _master_slider: HSlider = %MasterSlider
@onready var _music_slider: HSlider = %MusicSlider
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _fullscreen: CheckButton = %FullscreenToggle
@onready var _resolution: OptionButton = %ResolutionOptions
@onready var _settings_box: VBoxContainer = $SettingsPanel/SettingsBox

var _language_option: OptionButton

var _time := 0.0
var _key_rows: Dictionary = {}
var _pending_rebind_action := ""
var _rebind_overlay: Label

func _ready() -> void:
	_settings_panel.visible = false
	_continue_button.disabled = not FileAccess.file_exists(SAVE_PATH)
	_populate_resolutions()
	_sync_audio_sliders()
	_build_language_selector()
	_build_keybind_ui()
	_connect_buttons(self )
	if InputSettings.has_signal("bindings_changed") and not InputSettings.bindings_changed.is_connected(_refresh_keybind_labels):
		InputSettings.bindings_changed.connect(_refresh_keybind_labels)
	if not LocaleManager.locale_changed.is_connected(_on_locale_changed):
		LocaleManager.locale_changed.connect(_on_locale_changed)
	AudioManager.set_time_era(false, 0.25)

func _process(delta: float) -> void:
	_time += delta
	if _contrast.material is ShaderMaterial:
		_contrast.material.set_shader_parameter("time", _time)

func _on_start_pressed() -> void:
	_save_continue_path(FIRST_LEVEL)
	SceneChanger.change_level(FIRST_LEVEL)

func _on_continue_pressed() -> void:
	var path := _load_continue_path()
	SceneChanger.change_level(path if ResourceLoader.exists(path) else FIRST_LEVEL)

func _on_settings_pressed() -> void:
	_settings_panel.visible = true

func _on_back_pressed() -> void:
	if not _pending_rebind_action.is_empty():
		_pending_rebind_action = ""
		_update_rebind_overlay()
		return
	_settings_panel.visible = false

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_master_slider_value_changed(value: float) -> void:
	_set_bus_linear("Master", value)

func _on_music_slider_value_changed(value: float) -> void:
	_set_bus_linear("Music", value)

func _on_sfx_slider_value_changed(value: float) -> void:
	_set_bus_linear("SFX", value)
	_set_bus_linear("UI", value)

func _on_fullscreen_toggle_toggled(toggled_on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if toggled_on else DisplayServer.WINDOW_MODE_WINDOWED)

func _on_resolution_options_item_selected(index: int) -> void:
	if index < 0 or index >= RESOLUTIONS.size():
		return
	DisplayServer.window_set_size(RESOLUTIONS[index])

func _unhandled_input(event: InputEvent) -> void:
	if _pending_rebind_action.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			_pending_rebind_action = ""
			_update_rebind_overlay()
			get_viewport().set_input_as_handled()
			return
		InputSettings.rebind_action(_pending_rebind_action, event)
		_pending_rebind_action = ""
		_update_rebind_overlay()
		get_viewport().set_input_as_handled()

func _build_language_selector() -> void:
	var lang_label := Label.new()
	lang_label.text = tr("SETTINGS_LANGUAGE")
	lang_label.name = "LanguageLabel"
	_settings_box.add_child(lang_label)
	# Move before back button (which is always last)
	var back_btn := _settings_box.get_node_or_null("BackButton")
	if back_btn:
		_settings_box.move_child(lang_label, back_btn.get_index())

	_language_option = OptionButton.new()
	_language_option.name = "LanguageOption"
	for locale_data in LocaleManager.SUPPORTED_LOCALES:
		_language_option.add_item(String(locale_data["label"]))
	_language_option.select(LocaleManager.get_current_index())
	_language_option.item_selected.connect(_on_language_selected)
	_settings_box.add_child(_language_option)
	if back_btn:
		_settings_box.move_child(_language_option, back_btn.get_index())

func _on_language_selected(index: int) -> void:
	if index >= 0 and index < LocaleManager.SUPPORTED_LOCALES.size():
		LocaleManager.set_locale(LocaleManager.SUPPORTED_LOCALES[index]["code"])

func _on_locale_changed() -> void:
	# Rebuild dynamically-created labels (keybinds, controls title, reset)
	# Remove old dynamic controls
	var keybind_list := _settings_box.get_node_or_null("KeybindList")
	if keybind_list:
		keybind_list.queue_free()
	for child in _settings_box.get_children():
		if child is Label and child.name == "ControlsTitle":
			child.queue_free()
		if child is Button and child.name == "ResetControlsBtn":
			child.queue_free()
		if child is Label and child.name == "RebindOverlay":
			child.queue_free()
	# Update language label
	var lang_label := _settings_box.get_node_or_null("LanguageLabel")
	if lang_label:
		lang_label.text = tr("SETTINGS_LANGUAGE")
	# Rebuild keybinds next frame so freed nodes are gone
	_key_rows.clear()
	await get_tree().process_frame
	_build_keybind_ui()
	_connect_buttons(self )

func _populate_resolutions() -> void:
	_resolution.clear()
	for resolution_size in RESOLUTIONS:
		_resolution.add_item("%dx%d" % [resolution_size.x, resolution_size.y])
	_resolution.select(0)

func _sync_audio_sliders() -> void:
	_master_slider.value = _bus_to_linear("Master")
	_music_slider.value = _bus_to_linear("Music")
	_sfx_slider.value = _bus_to_linear("SFX")
	_fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

func _build_keybind_ui() -> void:
	var title := Label.new()
	title.text = tr("SETTINGS_CONTROLS")
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_box.add_child(title)

	var list := VBoxContainer.new()
	list.name = "KeybindList"
	list.add_theme_constant_override("separation", 6)
	_settings_box.add_child(list)

	for action_data in InputSettings.ACTIONS:
		var action_name := String(action_data["name"])
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 30)
		list.add_child(row)

		var name_label := Label.new()
		name_label.text = InputSettings.get_action_label(action_name)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var key_button := Button.new()
		key_button.custom_minimum_size = Vector2(140, 28)
		key_button.text = InputSettings.get_binding_text(action_name)
		key_button.pressed.connect(_start_rebind.bind(action_name))
		row.add_child(key_button)
		_key_rows[action_name] = key_button

	var reset_button := Button.new()
	reset_button.text = tr("SETTINGS_RESET_CONTROLS")
	reset_button.pressed.connect(_reset_controls)
	_settings_box.add_child(reset_button)

	_rebind_overlay = Label.new()
	_rebind_overlay.text = ""
	_rebind_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rebind_overlay.modulate = Color(0.9, 1.0, 0.72, 0.0)
	_settings_box.add_child(_rebind_overlay)

func _start_rebind(action_name: String) -> void:
	_pending_rebind_action = action_name
	_update_rebind_overlay()

func _reset_controls() -> void:
	InputSettings.reset_to_defaults()
	_pending_rebind_action = ""
	_update_rebind_overlay()

func _refresh_keybind_labels() -> void:
	for action_name in _key_rows.keys():
		var button := _key_rows[action_name] as Button
		if button:
			button.text = InputSettings.get_binding_text(action_name)

func _update_rebind_overlay() -> void:
	if _rebind_overlay == null:
		return
	if _pending_rebind_action.is_empty():
		_rebind_overlay.modulate.a = 0.0
		_refresh_keybind_labels()
		return
	_rebind_overlay.text = tr("SETTINGS_PRESS_KEY") % InputSettings.get_action_label(_pending_rebind_action)
	_rebind_overlay.modulate.a = 1.0

func _set_bus_linear(bus_name: String, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(value, 0.0, 1.0)))
	AudioServer.set_bus_mute(idx, value <= 0.001)

func _bus_to_linear(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return 1.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))

func _save_continue_path(path: String) -> void:
	var config := ConfigFile.new()
	config.set_value("continue", "scene", path)
	config.save(SAVE_PATH)

func _load_continue_path() -> String:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return FIRST_LEVEL
	return String(config.get_value("continue", "scene", FIRST_LEVEL))

func _connect_buttons(node: Node) -> void:
	if node is BaseButton:
		var button := node as BaseButton
		if not button.mouse_entered.is_connected(_on_hover):
			button.mouse_entered.connect(_on_hover)
		if not button.pressed.is_connected(_on_click):
			button.pressed.connect(_on_click)
	for child in node.get_children():
		_connect_buttons(child)

func _on_hover() -> void:
	AudioManager.play_ui_hover()

func _on_click() -> void:
	AudioManager.play_ui_click()
