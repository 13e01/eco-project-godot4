extends Node

const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
const BUS_UI: StringName = &"UI"
const BUS_AMBIENT: StringName = &"Ambient"
const BUS_GLITCH: StringName = &"Glitch"

const AUDIO_ROOT: String = "res://audio"
const PLAYER_POOL_SIZE: int = 10
const DEFAULT_CROSSFADE_TIME: float = 0.9
const LOW_HP_INTERVAL: float = 1.2

var _streams_by_event: Dictionary = {}
var _stream_cache: Dictionary = {}

var _sfx_players: Array[AudioStreamPlayer] = []
var _ui_players: Array[AudioStreamPlayer] = []
var _ambient_players: Array[AudioStreamPlayer] = []
var _glitch_players: Array[AudioStreamPlayer] = []

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _ambient_a: AudioStreamPlayer
var _ambient_b: AudioStreamPlayer
var _low_hp_layer: AudioStreamPlayer
var _loading_layer: AudioStreamPlayer

var _is_future: bool = false
var _low_hp_active: bool = false
var _low_hp_intensity: float = 0.0
var _low_hp_tick_timer: float = 0.0
var _loading_last_step: int = -1

func _ready() -> void:
	_setup_buses()
	_create_players()
	_build_event_map()
	_start_world_layers()

func _process(delta: float) -> void:
	if _low_hp_active:
		_low_hp_tick_timer -= delta
		if _low_hp_tick_timer <= 0.0:
			_low_hp_tick_timer = lerp(LOW_HP_INTERVAL, 0.45, _low_hp_intensity)
			play_event(&"low_hp_tick")

func play_event(event_name: StringName, options: Dictionary = {}) -> void:
	if not _streams_by_event.has(event_name):
		return
	var candidates: Array = _streams_by_event[event_name]
	if candidates.is_empty():
		return
	var random_index: int = randi_range(0, candidates.size() - 1)
	var stream: AudioStream = candidates[random_index]
	if stream == null:
		return

	var bus_name: StringName = StringName(options.get("bus", String(_default_bus_for_event(event_name))))
	var player: AudioStreamPlayer = _next_free_player(bus_name)
	if player == null:
		return

	player.pitch_scale = float(options.get("pitch", randf_range(0.96, 1.05)))
	player.volume_db = float(options.get("volume_db", 0.0))
	player.stream = stream
	player.play()

func set_time_era(is_future: bool, crossfade_time: float = DEFAULT_CROSSFADE_TIME) -> void:
	_is_future = is_future
	_crossfade_world_layers(crossfade_time)
	_crossfade_music(crossfade_time)

func set_low_hp_state(enabled: bool, normalized_intensity: float) -> void:
	_low_hp_active = enabled
	_low_hp_intensity = clampf(normalized_intensity, 0.0, 1.0)
	if not _low_hp_active:
		_low_hp_tick_timer = 0.0
		_set_player_volume(_low_hp_layer, -40.0)
		_set_bus_ducking(false)
		return

	_low_hp_tick_timer = min(_low_hp_tick_timer, 0.2)
	_set_player_volume(_low_hp_layer, lerp(-28.0, -14.0, _low_hp_intensity))
	_set_bus_ducking(_low_hp_intensity > 0.35)

func set_loading_progress(normalized: float) -> void:
	var clamped: float = clampf(normalized, 0.0, 1.0)
	var step: int = int(floor(clamped * 8.0))
	if step == _loading_last_step:
		return
	_loading_last_step = step
	play_event(&"loading_tick", {"bus": String(BUS_UI), "pitch": randf_range(0.96, 1.02), "volume_db": -8.0})

func on_loading_start() -> void:
	_loading_last_step = -1
	play_event(&"loading_start", {"bus": String(BUS_UI), "volume_db": -7.0})

func on_loading_end() -> void:
	play_event(&"loading_complete", {"bus": String(BUS_UI), "volume_db": -6.0})

func play_ui_hover() -> void:
	play_event(&"ui_hover", {"bus": String(BUS_UI), "volume_db": -10.0})

func play_ui_click() -> void:
	play_event(&"ui_click", {"bus": String(BUS_UI), "volume_db": -8.0})

func _setup_buses() -> void:
	_ensure_bus(BUS_MUSIC, BUS_MASTER)
	_ensure_bus(BUS_SFX, BUS_MASTER)
	_ensure_bus(BUS_UI, BUS_MASTER)
	_ensure_bus(BUS_AMBIENT, BUS_MASTER)
	_ensure_bus(BUS_GLITCH, BUS_MASTER)

	AudioServer.set_bus_volume_db(_bus_idx(BUS_MASTER), 0.0)
	AudioServer.set_bus_volume_db(_bus_idx(BUS_MUSIC), -7.0)
	AudioServer.set_bus_volume_db(_bus_idx(BUS_SFX), -4.0)
	AudioServer.set_bus_volume_db(_bus_idx(BUS_UI), -8.0)
	AudioServer.set_bus_volume_db(_bus_idx(BUS_AMBIENT), -10.0)
	AudioServer.set_bus_volume_db(_bus_idx(BUS_GLITCH), -13.0)

	_ensure_effect(BUS_MASTER, AudioEffectLimiter.new())
	var compressor: AudioEffectCompressor = AudioEffectCompressor.new()
	compressor.threshold = -16.0
	compressor.ratio = 4.0
	compressor.attack_us = 15.0
	compressor.release_ms = 180.0
	_ensure_effect(BUS_GLITCH, compressor)

func _create_players() -> void:
	for _i: int in range(PLAYER_POOL_SIZE):
		_sfx_players.append(_spawn_player(BUS_SFX))
		_ui_players.append(_spawn_player(BUS_UI))
		_ambient_players.append(_spawn_player(BUS_AMBIENT))
		_glitch_players.append(_spawn_player(BUS_GLITCH))

	_music_a = _spawn_player(BUS_MUSIC)
	_music_b = _spawn_player(BUS_MUSIC)
	_ambient_a = _spawn_player(BUS_AMBIENT)
	_ambient_b = _spawn_player(BUS_AMBIENT)
	_low_hp_layer = _spawn_player(BUS_GLITCH)
	_loading_layer = _spawn_player(BUS_UI)

	_music_a.volume_db = -40.0
	_music_b.volume_db = -40.0
	_ambient_a.volume_db = -40.0
	_ambient_b.volume_db = -40.0
	_low_hp_layer.volume_db = -40.0
	_loading_layer.volume_db = -40.0

func _build_event_map() -> void:
	var all_audio_paths: PackedStringArray = []
	_collect_audio_paths(AUDIO_ROOT, all_audio_paths)

	_register(&"jump", all_audio_paths, ["jump", "whoosh", "phaserup"])
	_register(&"land", all_audio_paths, ["land", "thud", "impact", "step"])
	_register(&"footstep_swamp", all_audio_paths, ["footstep_grass", "grass", "carpet"])
	_register(&"footstep_trash", all_audio_paths, ["footstep_concrete", "footstep_snow", "concrete"])
	_register(&"low_hp_tick", all_audio_paths, ["tick", "glitch", "warning"])
	_register(&"time_switch_ok", all_audio_paths, ["phasejump", "phaserup", "switch", "powerup"])
	_register(&"time_switch_denied", all_audio_paths, ["error", "deny", "question"])
	_register(&"time_auto_eject", all_audio_paths, ["phaserdown", "highdown", "error"])
	_register(&"death", all_audio_paths, ["explosion", "crash", "explosioncrunch", "destroy"])
	_register(&"respawn", all_audio_paths, ["open", "powerup", "maximize"])
	_register(&"time_object_push", all_audio_paths, ["scratch", "slide", "stone"])
	_register(&"time_object_break", all_audio_paths, ["break", "crunch", "explosioncrunch"])
	_register(&"time_object_respawn", all_audio_paths, ["open", "phasejump", "maximize"])
	_register(&"time_object_ghost", all_audio_paths, ["glitch", "phasejump", "phaserdown"])
	_register(&"eco_cleanup", all_audio_paths, ["confirmation", "pluck", "glass", "powerup"])
	_register(&"eco_coin", all_audio_paths, ["tick", "select", "confirmation"])
	_register(&"future_changed", all_audio_paths, ["phasejump", "highup", "powerup"])
	_register(&"ui_hover", all_audio_paths, ["select", "scroll"])
	_register(&"ui_click", all_audio_paths, ["switch", "toggle", "select"])
	_register(&"loading_start", all_audio_paths, ["open", "powerup"])
	_register(&"loading_tick", all_audio_paths, ["tick", "scroll"])
	_register(&"loading_complete", all_audio_paths, ["maximize", "powerup", "highup"])
	_register(&"ambient_swamp", all_audio_paths, ["forest", "swamp", "wind", "grass", "hum"])
	_register(&"ambient_future", all_audio_paths, ["glitch", "industrial", "trash", "noise", "buzz"])
	_register(&"music_swamp", all_audio_paths, ["music", "ambient", "calm", "loop"])
	_register(&"music_future", all_audio_paths, ["future", "distort", "dark", "glitch", "loop"])
	_register(&"low_hp_layer", all_audio_paths, ["glitch", "hum", "drone"])
	_register(&"wind_layer", all_audio_paths, ["wind", "air"])

func _register(event_name: StringName, all_paths: PackedStringArray, keywords: Array[String]) -> void:
	var streams: Array[AudioStream] = []
	for path: String in all_paths:
		var lowered: String = path.to_lower()
		var matched: bool = false
		for keyword: String in keywords:
			if lowered.contains(keyword):
				matched = true
				break
		if not matched:
			continue
		var stream: AudioStream = _get_stream(path)
		if stream != null:
			streams.append(stream)
	_streams_by_event[event_name] = streams

func _collect_audio_paths(dir_path: String, result: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var file_name: String = dir.get_next()
		if file_name.is_empty():
			break
		if file_name.begins_with("."):
			continue
		var child_path: String = dir_path.path_join(file_name)
		if dir.current_is_dir():
			_collect_audio_paths(child_path, result)
		elif file_name.to_lower().ends_with(".ogg"):
			result.append(child_path)
	dir.list_dir_end()

func _get_stream(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return null
	_stream_cache[path] = stream
	return stream

func _start_world_layers() -> void:
	_play_loop(_ambient_a, _pick_loop(&"ambient_swamp"), -17.0)
	_play_loop(_ambient_b, _pick_loop(&"ambient_future"), -40.0)
	_play_loop(_music_a, _pick_loop(&"music_swamp"), -15.0)
	_play_loop(_music_b, _pick_loop(&"music_future"), -40.0)
	_play_loop(_low_hp_layer, _pick_loop(&"low_hp_layer"), -40.0)
	_play_loop(_loading_layer, _pick_loop(&"wind_layer"), -40.0)

func _play_loop(player: AudioStreamPlayer, stream: AudioStream, volume_db: float) -> void:
	if player == null or stream == null:
		return
	player.stream = stream
	player.volume_db = volume_db
	player.play()

func _pick_loop(event_name: StringName) -> AudioStream:
	if not _streams_by_event.has(event_name):
		return null
	var candidates: Array = _streams_by_event[event_name]
	if candidates.is_empty():
		return null
	return candidates[randi_range(0, candidates.size() - 1)]

func _crossfade_world_layers(duration: float) -> void:
	if _is_future:
		_fade_player(_ambient_a, -40.0, duration)
		_fade_player(_ambient_b, -16.0, duration)
	else:
		_fade_player(_ambient_a, -16.0, duration)
		_fade_player(_ambient_b, -40.0, duration)

func _crossfade_music(duration: float) -> void:
	if _is_future:
		_fade_player(_music_a, -40.0, duration)
		_fade_player(_music_b, -14.0, duration)
	else:
		_fade_player(_music_a, -14.0, duration)
		_fade_player(_music_b, -40.0, duration)

func _fade_player(player: AudioStreamPlayer, target_db: float, duration: float) -> void:
	if player == null:
		return
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", target_db, maxf(duration, 0.05))

func _set_player_volume(player: AudioStreamPlayer, volume_db: float) -> void:
	if player == null:
		return
	if absf(player.volume_db - volume_db) < 0.01:
		return
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", volume_db, 0.2)

func _set_bus_ducking(enabled: bool) -> void:
	var target_music: float = -12.0 if enabled else -7.0
	var target_ambient: float = -14.0 if enabled else -10.0
	AudioServer.set_bus_volume_db(_bus_idx(BUS_MUSIC), target_music)
	AudioServer.set_bus_volume_db(_bus_idx(BUS_AMBIENT), target_ambient)

func _default_bus_for_event(event_name: StringName) -> StringName:
	if String(event_name).begins_with("ui_") or String(event_name).begins_with("loading_"):
		return BUS_UI
	if String(event_name).contains("ambient") or String(event_name).contains("music"):
		return BUS_AMBIENT
	if String(event_name).contains("low_hp"):
		return BUS_GLITCH
	return BUS_SFX

func _next_free_player(bus_name: StringName) -> AudioStreamPlayer:
	var pool: Array[AudioStreamPlayer] = _pool_for_bus(bus_name)
	for player: AudioStreamPlayer in pool:
		if not player.playing:
			return player
	return pool[0] if not pool.is_empty() else null

func _pool_for_bus(bus_name: StringName) -> Array[AudioStreamPlayer]:
	match bus_name:
		BUS_UI:
			return _ui_players
		BUS_AMBIENT:
			return _ambient_players
		BUS_GLITCH:
			return _glitch_players
		_:
			return _sfx_players

func _spawn_player(bus_name: StringName) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = String(bus_name)
	player.max_polyphony = 1
	add_child(player)
	return player

func _ensure_bus(bus_name: StringName, send_to: StringName) -> void:
	var idx: int = AudioServer.get_bus_index(String(bus_name))
	if idx == -1:
		AudioServer.add_bus(AudioServer.bus_count)
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, String(bus_name))
	var send_idx: int = AudioServer.get_bus_index(String(send_to))
	if send_idx != -1:
		AudioServer.set_bus_send(idx, String(send_to))

func _ensure_effect(bus_name: StringName, effect: AudioEffect) -> void:
	var idx: int = _bus_idx(bus_name)
	if idx == -1:
		return
	for effect_idx: int in range(AudioServer.get_bus_effect_count(idx)):
		var existing: AudioEffect = AudioServer.get_bus_effect(idx, effect_idx)
		if existing.get_class() == effect.get_class():
			return
	AudioServer.add_bus_effect(idx, effect, 0)

func _bus_idx(bus_name: StringName) -> int:
	return AudioServer.get_bus_index(String(bus_name))
