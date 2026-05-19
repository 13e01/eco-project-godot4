extends Node

## Синглтон для безопасного переключения уровней в фоновом потоке.
## Реализует экран загрузки с анимированным ползунком прогресса.

const FADE_DURATION: float = 0.3

var loading_screen_scene: PackedScene = preload("res://datas/SceneChanger/LoadingScreen.tscn")


func change_level(target_scene_path: String) -> void:
	# 1. Валидация и конвертация путей
	if target_scene_path.begins_with("uid://"):
		var id := ResourceUID.text_to_id(target_scene_path)
		target_scene_path = ResourceUID.get_id_path(id)

	if not ResourceLoader.exists(target_scene_path):
		push_error("SceneChanger: Файл уровня не найден по пути: " + target_scene_path)
		return

	# 2. Инициализация экрана загрузки
	var loading_screen := loading_screen_scene.instantiate()
	get_tree().root.add_child(loading_screen)
	
	var progress_bar := loading_screen.find_child("LoadingBar", true, false)
	var background := loading_screen.find_child("Background", true, false)
	
	if not progress_bar or not background:
		push_error("SceneChanger: Критическая ошибка! На сцене LoadingScreen отсутствуют узлы LoadingBar или Background.")
		loading_screen.queue_free()
		return

	progress_bar.value = 0.0

	# 3. Анимация появления экрана загрузки
	background.modulate.a = 0.0
	progress_bar.modulate.a = 0.0
	
	var tween_in := create_tween().set_parallel(true)
	tween_in.tween_property(background, "modulate:a", 1.0, FADE_DURATION)
	tween_in.tween_property(progress_bar, "modulate:a", 1.0, FADE_DURATION)
	await tween_in.finished

	# 4. Запуск асинхронного потока загрузки уровня
	var error := ResourceLoader.load_threaded_request(target_scene_path)
	if error != OK:
		push_error("SceneChanger: Не удалось инициализировать фоновую загрузку ресурса. Код: " + str(error))
		loading_screen.queue_free()
		return

	# 5. Цикл мониторинга прогресса загрузки
	var progress: Array = []
	
	while true:
		var status := ResourceLoader.load_threaded_get_status(target_scene_path, progress)
		
		match status:
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				progress_bar.value = progress[0] * 100.0
			ResourceLoader.THREAD_LOAD_LOADED:
				progress_bar.value = 100.0
				break
			_:
				push_error("SceneChanger: Внутренний сбой потока загрузки Godot (Код статуса: " + str(status) + ")")
				loading_screen.queue_free()
				return
				
		await get_tree().process_frame

	# 6. Смена активной сцены на загруженный уровень
	var new_scene := ResourceLoader.load_threaded_get(target_scene_path) as PackedScene
	get_tree().change_scene_to_packed(new_scene)

	# 7. Анимация растворения экрана загрузки
	var tween_out := create_tween().set_parallel(true)
	tween_out.tween_property(background, "modulate:a", 0.0, FADE_DURATION)
	tween_out.tween_property(progress_bar, "modulate:a", 0.0, FADE_DURATION)
	await tween_out.finished
	
	# Освобождение памяти
	loading_screen.queue_free()
