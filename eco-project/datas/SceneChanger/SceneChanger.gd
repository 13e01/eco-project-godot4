extends Node

## Синглтон для безопасного переключения уровней в фоновом потоке.
## Реализует экран загрузки с анимированным ползунком прогресса.

const FADE_DURATION: float = 0.3
const MIN_DURATION: float = 1.5 # Минимальное время загрузки в секундах

var loading_screen_scene: PackedScene = preload("res://datas/SceneChanger/LoadingScreen.tscn")


func change_level(target_scene_path: String) -> void:
	# 1. Валидация и конвертация путей
	if target_scene_path.begins_with("uid://"):
		var id: int = ResourceUID.text_to_id(target_scene_path)
		target_scene_path = ResourceUID.get_id_path(id)

	if not ResourceLoader.exists(target_scene_path):
		push_error("SceneChanger: Файл уровня не найден по пути: " + target_scene_path)
		return

	# 2. Инициализация экрана загрузки
	var loading_screen: Node = loading_screen_scene.instantiate()
	get_tree().root.add_child(loading_screen)
	
	# Кастуем к базовым классам Godot, чтобы работали свойства value и modulate
	var progress_bar: Range = loading_screen.find_child("LoadingBar", true, false) as Range
	var background: CanvasItem = loading_screen.find_child("Background", true, false) as CanvasItem
	
	if not progress_bar or not background:
		push_error("SceneChanger: Критическая ошибка! На сцене LoadingScreen отсутствуют узлы LoadingBar или Background.")
		loading_screen.queue_free()
		return

	progress_bar.value = 0.0

	# 3. Анимация появления экрана загрузки
	background.modulate.a = 0.0
	progress_bar.modulate.a = 0.0
	
	var tween_in: Tween = create_tween().set_parallel(true)
	tween_in.tween_property(background, "modulate:a", 1.0, FADE_DURATION)
	tween_in.tween_property(progress_bar, "modulate:a", 1.0, FADE_DURATION)
	await tween_in.finished

	# 4. Запуск асинхронного потока загрузки уровня
	var error: Error = ResourceLoader.load_threaded_request(target_scene_path)
	if error != OK:
		push_error("SceneChanger: Не удалось инициализировать фоновую загрузку ресурса. Код: " + str(error))
		loading_screen.queue_free()
		return

	# 5. Цикл мониторинга прогресса загрузки
	var progress: Array = []
	var real_progress_normalized: float = 0.0
	var sim_time: float = 0.0

	while true:
		var delta: float = get_process_delta_time()
		sim_time += delta
		
		var status: int = ResourceLoader.load_threaded_get_status(target_scene_path, progress)
		
		match status:
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				if progress.size() > 0:
					real_progress_normalized = progress[0]
			ResourceLoader.THREAD_LOAD_LOADED:
				real_progress_normalized = 1.0
			_:
				push_error("SceneChanger: Внутренний сбой потока загрузки Godot.")
				loading_screen.queue_free()
				return
		
		# Все математические переменные теперь строго типизированы как float
		var time_ratio: float = clamp(sim_time / MIN_DURATION, 0.0, 1.0)
		var fluid_curve: float = time_ratio * time_ratio * (3.0 - 2.0 * time_ratio)
		var current_progress: float = min(real_progress_normalized, fluid_curve)
		
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			current_progress = fluid_curve
			
		progress_bar.value = current_progress * progress_bar.max_value
		
		if status == ResourceLoader.THREAD_LOAD_LOADED and time_ratio >= 1.0:
			break
				
		await get_tree().process_frame

	# 6. Смена активной сцены на загруженный уровень
	var new_scene: PackedScene = ResourceLoader.load_threaded_get(target_scene_path) as PackedScene
	get_tree().change_scene_to_packed(new_scene)

	# 7. Анимация растворения экрана загрузки
	var tween_out: Tween = create_tween().set_parallel(true)
	tween_out.tween_property(background, "modulate:a", 0.0, FADE_DURATION)
	tween_out.tween_property(progress_bar, "modulate:a", 0.0, FADE_DURATION)
	await tween_out.finished
	
	# Освобождение памяти
	loading_screen.queue_free()
