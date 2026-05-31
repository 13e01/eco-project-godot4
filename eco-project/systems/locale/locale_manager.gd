extends Node
## Autoload that manages the active locale and persists the user's choice.
## Emits [signal locale_changed] so any open UI can refresh its labels
## without restarting the game.

signal locale_changed

const SAVE_PATH := "user://locale.cfg"

## Ordered list of supported locales. The display name shown in the
## language selector is the native name of each language.
const SUPPORTED_LOCALES: Array[Dictionary] = [
	{"code": "en", "label": "English"},
	{"code": "ru", "label": "Русский"},
	{"code": "kk", "label": "Қазақша"},
]

func _ready() -> void:
	_load_locale()

## Change the active locale at runtime.  Persists the choice and
## notifies all listeners so they can call [code]tr()[/code] again.
func set_locale(code: String) -> void:
	TranslationServer.set_locale(code)
	_save_locale(code)
	locale_changed.emit()

## Return the index of the current locale inside [const SUPPORTED_LOCALES].
func get_current_index() -> int:
	var current := TranslationServer.get_locale().substr(0, 2)
	for i in range(SUPPORTED_LOCALES.size()):
		if SUPPORTED_LOCALES[i]["code"] == current:
			return i
	return 0

func _save_locale(code: String) -> void:
	var config := ConfigFile.new()
	config.set_value("locale", "code", code)
	config.save(SAVE_PATH)

func _load_locale() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		var code: String = config.get_value("locale", "code", "en")
		TranslationServer.set_locale(code)
