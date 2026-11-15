extends Node

signal settings_changed
signal wind_changed(speed_mph: float, direction_rad: float)
signal fullscreen_changed(is_fullscreen: bool)

# Range Settings
var range_settings: RangeSettings = RangeSettings.new()
const OPENFAIRWAY_LOG_LEVEL_INFO := 2
var practice_mode_primed : bool = false
var is_chipping_minigame : bool = false
var is_putting_minigame : bool = false
var current_selected_club : String = "Dr"

# Wind Simulation state
var current_wind_speed_mph: float = 0.0
var current_wind_direction_rad: float = 0.0
var wind_initialized_for_round: bool = false

## When true, temporary in-match forced settings are active and disk saving is blocked
## so the player's personal settings file is not overwritten.
var suppress_save: bool = false


var _loaded_announcer_settings := {}

func _ready() -> void:
	var physics_logger_script = load("res://addons/openfairway/physics/PhysicsLogger.cs")
	if physics_logger_script != null:
		if physics_logger_script.has_method("SetLevel"):
			physics_logger_script.call("SetLevel", OPENFAIRWAY_LOG_LEVEL_INFO)
		elif physics_logger_script.has_method("set_level"):
			physics_logger_script.call("set_level", OPENFAIRWAY_LOG_LEVEL_INFO)
	load_settings()
	_setup_audio_players()
	
	if has_node("/root/EventBus"):
		var eb = get_node("/root/EventBus")
		if eb.has_signal("club_selected") and not eb.is_connected("club_selected", Callable(self, "_on_club_selected")):
			eb.connect("club_selected", Callable(self, "_on_club_selected"))
	
	# Wait for announcer engine if it enters tree later
	var announcer = get_node_or_null("/root/AnnouncerEngine")
	if announcer:
		_apply_announcer_settings(announcer)
	else:
		get_tree().root.child_entered_tree.connect(_on_root_child_entered_tree)
		
	# Connect save_settings to settings_changed signal
	range_settings.settings_changed.connect(save_settings)
	range_settings.wind_enabled.setting_changed.connect(_on_wind_enabled_changed)

	# Fullscreen setup for Windows, macOS, and desktop platforms
	if is_fullscreen_supported():
		range_settings.windowed_fullscreen.setting_changed.connect(_on_windowed_fullscreen_setting_changed)
		if range_settings.windowed_fullscreen.value:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_tree().root.size_changed.connect(_on_root_window_resized)


func _on_club_selected(club_name: String) -> void:
	current_selected_club = club_name


func apply_foam_ball_boost(data: Dictionary, fallback_club: String = "") -> void:
	FoamBallBoost.apply_boost(data, fallback_club if not fallback_club.is_empty() else current_selected_club)


func is_low_graphics() -> bool:
	if is_driving_range_scene():
		return false
	if range_settings != null and range_settings.settings.has("graphics_quality"):
		return range_settings.settings["graphics_quality"].value == "Low"
	return MobilePerformance.is_mobile()


func get_graphics_quality() -> String:
	if range_settings != null and range_settings.settings.has("graphics_quality"):
		return str(range_settings.settings["graphics_quality"].value)
	return MobilePerformance.get_default_graphics_quality()


## Roads, clubhouses, houses, and other surrounding buildings are shown on
## graphics qualities where enabled in download/generation settings (Medium and High by default).
func is_surrounding_features_enabled() -> bool:
	var q = get_graphics_quality()
	return MobilePerformance.is_surrounding_features_enabled_for_quality(null, q)


func _on_root_child_entered_tree(node: Node) -> void:
	if node.name == "AnnouncerEngine":
		_apply_announcer_settings(node)
		get_tree().root.child_entered_tree.disconnect(_on_root_child_entered_tree)


func _apply_announcer_settings(announcer: Node) -> void:
	for key in _loaded_announcer_settings.keys():
		announcer.set(key, _loaded_announcer_settings[key])


func is_fullscreen_supported() -> bool:
	var os_name = OS.get_name()
	return os_name in ["Windows", "macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]


func is_fullscreen() -> bool:
	if not is_fullscreen_supported():
		return false
	var mode = DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func set_fullscreen(enabled: bool) -> void:
	if not is_fullscreen_supported():
		return
	var target_mode = DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != target_mode:
		DisplayServer.window_set_mode(target_mode)
	if range_settings.windowed_fullscreen.value != enabled:
		range_settings.windowed_fullscreen.set_value(enabled)
		save_settings()
	emit_signal("fullscreen_changed", enabled)


func toggle_fullscreen() -> void:
	set_fullscreen(not is_fullscreen())


func _on_windowed_fullscreen_setting_changed(val: Variant) -> void:
	var enabled = bool(val)
	var target_mode = DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != target_mode:
		DisplayServer.window_set_mode(target_mode)
	emit_signal("fullscreen_changed", enabled)


func _on_root_window_resized() -> void:
	if not is_fullscreen_supported():
		return
	var current_fs = is_fullscreen()
	if range_settings.windowed_fullscreen.value != current_fs:
		range_settings.windowed_fullscreen.set_value(current_fs)
		save_settings()
		emit_signal("fullscreen_changed", current_fs)


func _unhandled_input(event: InputEvent) -> void:
	if not is_fullscreen_supported():
		return
	if event.is_action_pressed("toggle_fullscreen"):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		# Windows / PC: Alt + Enter or F11
		if event.alt_pressed and (event.keycode == KEY_ENTER or event.physical_keycode == KEY_ENTER):
			toggle_fullscreen()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_F11 or event.physical_keycode == KEY_F11:
			toggle_fullscreen()
			get_viewport().set_input_as_handled()
			return
		# macOS: Command + F or Control + Command + F
		elif event.meta_pressed and (event.keycode == KEY_F or event.physical_keycode == KEY_F):
			toggle_fullscreen()
			get_viewport().set_input_as_handled()
			return


func resett_defaults():
	range_settings.reset_defaults()
	wind_initialized_for_round = false
	current_wind_speed_mph = 0.0
	if is_fullscreen_supported():
		set_fullscreen(true)
	if has_node("/root/KeybindingManager"):
		get_node("/root/KeybindingManager").reset_to_defaults()
	var announcer = get_node_or_null("/root/AnnouncerEngine")
	if announcer:
		announcer.set("AnnouncerCoursePlay", true)
		announcer.set("HeckleCoursePlay", true)
		announcer.set("AnnouncerRange", false)
		announcer.set("HeckleRange", false)
		announcer.set("AnnouncerMiniGames", false)
		announcer.set("HeckleMiniGames", false)
		announcer.set("PraiseEnabled", true)
		announcer.set("ActiveVoice", "")
		announcer.set("Pitch", 1.0)
		announcer.set("Rate", 1.0)
	save_settings()
	emit_signal("settings_changed")


func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load("user://global_settings.cfg")
	if err != OK:
		return
	
	# Load RangeSettings
	for key in range_settings.settings.keys():
		if config.has_section_key("range_settings", key):
			var val = config.get_value("range_settings", key)
			range_settings.settings[key].set_value(val)
			
	# Migration for camera settings if updating from older config files with small camera distance
	var migrated := false
	if range_settings.shot_tracer_count.value in [1, 2, 4]:
		range_settings.shot_tracer_count.set_value(10)
		migrated = true
	elif range_settings.shot_tracer_count.value > 10:
		range_settings.shot_tracer_count.set_value(10)
		migrated = true
	if range_settings.camera_distance.value >= 14.0 or is_equal_approx(range_settings.camera_distance.value, 5.2):
		range_settings.camera_distance.set_value(3.6)
		migrated = true
	if range_settings.camera_fov.value < 50.0:
		range_settings.camera_fov.set_value(55.0)
		migrated = true
	if range_settings.camera_height.value >= 2.0 or is_equal_approx(range_settings.camera_height.value, 1.65):
		range_settings.camera_height.set_value(1.35)
		migrated = true
	if is_equal_approx(range_settings.ball_reset_timer.value, 3.0):
		range_settings.ball_reset_timer.set_value(1.5)
		migrated = true
	
	# Migration / validation for green speed (clamp out-of-bounds legacy settings like 30.0/50.0 to standard 10.0)
	if range_settings.green_speed.value < 5.0 or range_settings.green_speed.value > 16.0:
		range_settings.green_speed.set_value(10.0)
		migrated = true
	
	# Migration / validation for displayed_stats
	var stats_val = range_settings.displayed_stats.value
	var legacy_default_stats = [
		"Distance", "Carry", "Speed", "VLA", "HLA", "BackSpin",
		"SideSpin", "TotalSpin", "SpinAxis", "Apex", "Offline", "FaceAngle"
	]
	if not (stats_val is Array) or stats_val.is_empty() or stats_val == legacy_default_stats:
		range_settings.displayed_stats.set_value(StatDefinitions.DEFAULT_ENABLED_STAT_IDS.duplicate())
		migrated = true
	else:
		var valid_ids = StatDefinitions.get_all_stat_ids()
		var cleaned_stats: Array[String] = []
		for s in stats_val:
			var s_str = str(s)
			if s_str == "Speed":
				s_str = "BallSpeed"
			if valid_ids.has(s_str) and not cleaned_stats.has(s_str) and cleaned_stats.size() < StatDefinitions.MAX_DISPLAYED_STATS:
				cleaned_stats.append(s_str)
		if cleaned_stats.is_empty():
			cleaned_stats = StatDefinitions.DEFAULT_ENABLED_STAT_IDS.duplicate()
		if cleaned_stats != stats_val:
			range_settings.displayed_stats.set_value(cleaned_stats)
			migrated = true

	# Validation / migration for TCP server IP and Port (GSPro Open Connect v1)
	var port_val = range_settings.tcp_server_port.value
	if typeof(port_val) != TYPE_INT and typeof(port_val) != TYPE_FLOAT:
		range_settings.tcp_server_port.set_value(49152)
		migrated = true
	elif int(port_val) < 1 or int(port_val) > 65535:
		range_settings.tcp_server_port.set_value(49152)
		migrated = true

	var ip_val = range_settings.tcp_server_ip.value
	if typeof(ip_val) != TYPE_STRING or str(ip_val).strip_edges().is_empty():
		range_settings.tcp_server_ip.set_value("0.0.0.0")
		migrated = true

	# Validation for Launch Monitor Tab & Guide Device preferences
	var tab_val = range_settings.launch_monitor_tab.value
	if typeof(tab_val) != TYPE_INT and typeof(tab_val) != TYPE_FLOAT:
		range_settings.launch_monitor_tab.set_value(0)
		migrated = true
	elif int(tab_val) < 0 or int(tab_val) > 3:
		range_settings.launch_monitor_tab.set_value(0)
		migrated = true

	var gspro_device_val = str(range_settings.gspro_selected_device.value).strip_edges()
	var valid_gspro_devices := ["mlm2pro", "garmin_r10", "flightscope", "uneekor", "bushnell", "pitrac", "shot_injector"]
	if not valid_gspro_devices.has(gspro_device_val):
		range_settings.gspro_selected_device.set_value("mlm2pro")
		migrated = true

	var log_path_val = str(range_settings.debug_log_path.value).strip_edges()
	if log_path_val.is_empty():
		range_settings.debug_log_path.set_value("user://debug.log")
		migrated = true

	if migrated:
		save_settings()
	
	# Load AnnouncerSettings
	_loaded_announcer_settings.clear()
	var announcer_keys = [
		"AnnouncerCoursePlay",
		"HeckleCoursePlay",
		"AnnouncerRange",
		"HeckleRange",
		"AnnouncerMiniGames",
		"HeckleMiniGames",
		"PraiseEnabled",
		"ActiveVoice",
		"Pitch",
		"Rate"
	]
	for key in announcer_keys:
		var config_key = key.to_lower()
		if config.has_section_key("announcer", config_key):
			_loaded_announcer_settings[key] = config.get_value("announcer", config_key)

	# Migration / default fallbacks if upgrading from legacy announcer settings
	if not _loaded_announcer_settings.has("AnnouncerCoursePlay"):
		_loaded_announcer_settings["AnnouncerCoursePlay"] = true
	if not _loaded_announcer_settings.has("HeckleCoursePlay"):
		_loaded_announcer_settings["HeckleCoursePlay"] = true
	if not _loaded_announcer_settings.has("AnnouncerRange"):
		_loaded_announcer_settings["AnnouncerRange"] = false
	if not _loaded_announcer_settings.has("HeckleRange"):
		_loaded_announcer_settings["HeckleRange"] = false
	if not _loaded_announcer_settings.has("AnnouncerMiniGames"):
		_loaded_announcer_settings["AnnouncerMiniGames"] = false
	if not _loaded_announcer_settings.has("HeckleMiniGames"):
		_loaded_announcer_settings["HeckleMiniGames"] = false
	if not _loaded_announcer_settings.has("PraiseEnabled"):
		_loaded_announcer_settings["PraiseEnabled"] = true
			
	var announcer = get_node_or_null("/root/AnnouncerEngine")
	if announcer:
		_apply_announcer_settings(announcer)

	if has_node("/root/KeybindingManager"):
		get_node("/root/KeybindingManager").load_keybindings()


func save_settings() -> void:
	if suppress_save:
		return
	var config = ConfigFile.new()
	# Load existing file first to preserve other sections (keybindings, controller bindings, etc.)
	config.load("user://global_settings.cfg")
	
	# Save RangeSettings
	for key in range_settings.settings.keys():
		config.set_value("range_settings", key, range_settings.settings[key].value)
	
	# Save AnnouncerSettings
	var announcer = get_node_or_null("/root/AnnouncerEngine")
	if announcer:
		_loaded_announcer_settings["AnnouncerCoursePlay"] = announcer.get("AnnouncerCoursePlay")
		_loaded_announcer_settings["HeckleCoursePlay"] = announcer.get("HeckleCoursePlay")
		_loaded_announcer_settings["AnnouncerRange"] = announcer.get("AnnouncerRange")
		_loaded_announcer_settings["HeckleRange"] = announcer.get("HeckleRange")
		_loaded_announcer_settings["AnnouncerMiniGames"] = announcer.get("AnnouncerMiniGames")
		_loaded_announcer_settings["HeckleMiniGames"] = announcer.get("HeckleMiniGames")
		_loaded_announcer_settings["PraiseEnabled"] = announcer.get("PraiseEnabled")
		_loaded_announcer_settings["ActiveVoice"] = announcer.get("ActiveVoice")
		_loaded_announcer_settings["Pitch"] = announcer.get("Pitch")
		_loaded_announcer_settings["Rate"] = announcer.get("Rate")
		
	for key in _loaded_announcer_settings.keys():
		config.set_value("announcer", key.to_lower(), _loaded_announcer_settings[key])

	# Also save/sync keybindings if KeybindingManager is active
	if has_node("/root/KeybindingManager"):
		var km = get_node("/root/KeybindingManager")
		var actions = km.get_all_actions()
		for action_name in actions.keys():
			var code = actions[action_name]["current_key"] as int
			config.set_value("keybindings", action_name, code)
			var joy = actions[action_name].get("current_joy", -1) as int
			config.set_value("controller_bindings", action_name, joy)
			
	var err = config.save("user://global_settings.cfg")
	if err != OK:
		push_error("Failed to save settings: %d" % err)


var _clap_player: AudioStreamPlayer = null

func play_golf_clap() -> void:
	if not range_settings.golf_clap_enabled.value:
		return
	if _clap_player == null:
		_clap_player = AudioStreamPlayer.new()
		add_child(_clap_player)
		var stream = load("res://assets/audio/golf_clap.mp3")
		_clap_player.stream = stream
	_clap_player.play()


var _ambient_player: AudioStreamPlayer = null
var _menu_music_player: AudioStreamPlayer = null
var _minigames_music_player: AudioStreamPlayer = null
var _audio_check_timer: float = 0.0
var _ambient_nature_stream: AudioStream = null
var _ambient_rain_stream: AudioStream = null
var _is_rain_ambient: bool = false
var _is_rain_mode: bool = false

func _process(delta: float) -> void:
	_audio_check_timer += delta
	if _audio_check_timer >= 0.25:
		_audio_check_timer = 0.0
		update_audio_state()


var _minigame_tracks: Array[AudioStream] = []
var _minigame_track_index: int = 0

func _setup_audio_players() -> void:
	if _ambient_player == null:
		_ambient_player = AudioStreamPlayer.new()
		_ambient_player.name = "AmbientNaturePlayer"
		add_child(_ambient_player)
		
		var path = "res://assets/audio/ambient_nature.ogg"
		if ResourceLoader.exists(path):
			_ambient_nature_stream = load(path)
			if _ambient_nature_stream and "loop" in _ambient_nature_stream:
				_ambient_nature_stream.loop = true

		var rain_path = "res://assets/audio/ambient_rain.ogg"
		if ResourceLoader.exists(rain_path):
			_ambient_rain_stream = load(rain_path)
			if _ambient_rain_stream and "loop" in _ambient_rain_stream:
				_ambient_rain_stream.loop = true

		var stream = _ambient_rain_stream if (_is_rain_ambient and _ambient_rain_stream != null) else _ambient_nature_stream
		if stream:
			_ambient_player.stream = stream
			_ambient_player.volume_db = -18.0 if _is_rain_ambient else -25.0
			_ambient_player.finished.connect(func():
				if _should_play_ambient():
					_ambient_player.play()
			)
				
	if _menu_music_player == null:
		_menu_music_player = AudioStreamPlayer.new()
		_menu_music_player.name = "MenuMusicPlayer"
		add_child(_menu_music_player)
		
		var path = "res://assets/audio/menu_soundtrack.wav"
		if ResourceLoader.exists(path):
			var stream = load(path)
			if stream:
				if "loop" in stream:
					stream.loop = true
				_menu_music_player.stream = stream
				_menu_music_player.volume_db = -34.0
				_menu_music_player.finished.connect(func():
					if _should_play_menu_music():
						_menu_music_player.play()
				)

	if _minigames_music_player == null:
		_minigames_music_player = AudioStreamPlayer.new()
		_minigames_music_player.name = "MinigamesMusicPlayer"
		add_child(_minigames_music_player)
		
		var track_paths = [
			"res://assets/audio/minigames_music.mp3",
			"res://assets/audio/boogie_pecan_pie.mp3"
		]
		_minigame_tracks.clear()
		for t_path in track_paths:
			if ResourceLoader.exists(t_path):
				var stream = load(t_path)
				if stream:
					if "loop" in stream:
						stream.loop = false
					_minigame_tracks.append(stream)
		
		if not _minigame_tracks.is_empty():
			_minigame_track_index = 0
			_minigames_music_player.stream = _minigame_tracks[0]
			_minigames_music_player.volume_db = -22.0
			_minigames_music_player.finished.connect(_on_minigames_music_finished)
				
	range_settings.ambient_sound_enabled.setting_changed.connect(func(_val): update_audio_state())
	range_settings.menu_music_enabled.setting_changed.connect(func(_val): update_audio_state())
	range_settings.minigame_music_enabled.setting_changed.connect(func(_val): update_audio_state())
	
	if has_node("/root/SceneManager"):
		var scn_mgr = get_node("/root/SceneManager")
		if scn_mgr.has_signal("scene_changed"):
			scn_mgr.scene_changed.connect(func(): update_audio_state())
			
	get_tree().root.child_entered_tree.connect(func(_node): call_deferred("update_audio_state"))
	call_deferred("update_audio_state")


var _mock_active_scene: Node = null

func set_mock_active_scene(scene: Node) -> void:
	_mock_active_scene = scene

func get_active_scene() -> Node:
	return _get_active_scene()

func _get_active_scene() -> Node:
	if _mock_active_scene != null and is_instance_valid(_mock_active_scene):
		return _mock_active_scene
	if is_inside_tree():
		if has_node("/root/SceneManager"):
			var scn_mgr = get_node("/root/SceneManager")
			var scn = scn_mgr.get("current_scene") as Node
			if scn != null and is_instance_valid(scn):
				return scn
		var tree := get_tree()
		if tree != null:
			return tree.current_scene
	return null


func is_minigames_menu_screen() -> bool:
	var scene := _get_active_scene()
	if scene == null:
		return false

	var scene_name := str(scene.name).to_lower()
	var script: Script = scene.get_script()
	var script_path := str(script.resource_path).to_lower() if script != null else ""
	var file_path := str(scene.scene_file_path).to_lower() if "scene_file_path" in scene else ""

	var full_id := (scene_name + " " + script_path + " " + file_path).to_lower()
	return full_id.contains("minigames_menu") or full_id.contains("minigamesmenu")


func is_minigames_gameplay_screen() -> bool:
	var scene := _get_active_scene()
	if scene == null:
		return false

	var scene_name := str(scene.name).to_lower()
	var script: Script = scene.get_script()
	var script_path := str(script.resource_path).to_lower() if script != null else ""
	var file_path := str(scene.scene_file_path).to_lower() if "scene_file_path" in scene else ""

	var full_id := (scene_name + " " + script_path + " " + file_path).to_lower()
	return full_id.contains("putting_practice") or full_id.contains("puttingpractice") \
		or full_id.contains("chipping") or full_id.contains("/minigames/")


func is_putting_minigame_screen() -> bool:
	if is_putting_minigame:
		return true
	var scene := _get_active_scene()
	if scene == null:
		return false
	var scene_name := str(scene.name).to_lower()
	var script: Script = scene.get_script()
	var script_path := str(script.resource_path).to_lower() if script != null else ""
	var file_path := str(scene.scene_file_path).to_lower() if "scene_file_path" in scene else ""
	var full_id := (scene_name + " " + script_path + " " + file_path).to_lower()
	return full_id.contains("putting_practice") or full_id.contains("puttingpractice")


func get_effective_green_speed() -> float:
	if range_settings != null and "green_speed" in range_settings:
		var raw_speed = float(range_settings.green_speed.value)
		# Calibrated green speed:
		# Setting 10.0 (default) yields effective speed 5.0 (speed of 5.0 previously)
		# Setting 15.0 yields effective speed 10.0 (speed of 10.0 previously)
		# Setting 5.0 yields effective speed 3.33 (slower than 10.0)
		# Linear shift in friction multiplier: speed_mult = 4.0 - 0.2 * raw_speed
		# effective_speed = 10.0 / speed_mult
		var speed_mult: float = 4.0 - 0.2 * raw_speed
		if speed_mult <= 0.05:
			return 200.0
		return 10.0 / speed_mult
	return 5.0


func is_minigames_scene() -> bool:
	return is_minigames_menu_screen() or is_minigames_gameplay_screen()


func is_menu_screen() -> bool:
	var scene := _get_active_scene()
	if scene == null:
		return true

	var scene_name := str(scene.name).to_lower()
	var script: Script = scene.get_script()
	var script_path := str(script.resource_path).to_lower() if script != null else ""
	var file_path := str(scene.scene_file_path).to_lower() if "scene_file_path" in scene else ""

	var full_id := (scene_name + " " + script_path + " " + file_path).to_lower()

	# Menu / setup / selection / analytics screens (excluding minigames_menu which uses minigame soundtrack)
	if full_id.contains("main_menu") or full_id.contains("mainmenu") \
		or full_id.contains("course_selector") or full_id.contains("courseselector") \
		or full_id.contains("course_play_setup") or full_id.contains("courseplaysetup") \
		or full_id.contains("players_menu") or full_id.contains("playersmenu") \
		or full_id.contains("analytics") or full_id.contains("history") \
		or full_id.contains("custom_course_creator") or full_id.contains("osm_download") \
		or full_id.contains("course_preview"):
		return true

	return false


func _should_play_menu_music() -> bool:
	if not range_settings.menu_music_enabled.value:
		return false
	return is_menu_screen() and not is_minigames_scene()


func _should_play_ambient() -> bool:
	if not range_settings.ambient_sound_enabled.value:
		return false
	return not is_menu_screen() and not is_minigames_scene()


func _should_play_minigame_music() -> bool:
	if not range_settings.minigame_music_enabled.value:
		return false
	return is_minigames_scene()


func _on_minigames_music_finished() -> void:
	if _minigame_tracks.is_empty():
		return
	_minigame_track_index = (_minigame_track_index + 1) % _minigame_tracks.size()
	_minigames_music_player.stream = _minigame_tracks[_minigame_track_index]
	if _should_play_minigame_music():
		_minigames_music_player.play()


func update_audio_state() -> void:
	# Menu Soundtrack logic
	if _menu_music_player != null and _menu_music_player.stream != null:
		if _should_play_menu_music():
			if not _menu_music_player.playing:
				_menu_music_player.play()
		else:
			if _menu_music_player.playing:
				_menu_music_player.stop()

	# Minigames Music Soundtrack logic
	if _minigames_music_player != null and _minigames_music_player.stream != null:
		if _should_play_minigame_music():
			if not _minigames_music_player.playing:
				_minigames_music_player.play()
		else:
			if _minigames_music_player.playing:
				_minigames_music_player.stop()

	# Ambient Nature Sounds logic (disabled in minigames and menus)
	if _ambient_player != null and _ambient_player.stream != null:
		if _should_play_ambient():
			if not _ambient_player.playing:
				_ambient_player.play()
		else:
			if _ambient_player.playing:
				_ambient_player.stop()


func set_rain_mode(is_rain: bool) -> void:
	_is_rain_mode = is_rain
	set_rain_ambient(is_rain)


func is_rain_mode() -> bool:
	return _is_rain_mode


func set_rain_ambient(is_rain: bool) -> void:
	_is_rain_ambient = is_rain
	_is_rain_mode = is_rain
	if _ambient_player == null:
		return
	var target_stream = _ambient_rain_stream if (is_rain and _ambient_rain_stream != null) else _ambient_nature_stream
	if target_stream != null and _ambient_player.stream != target_stream:
		var was_playing = _ambient_player.playing
		_ambient_player.stream = target_stream
		_ambient_player.volume_db = -18.0 if is_rain else -25.0
		if was_playing and _should_play_ambient():
			_ambient_player.play()


# -----------------------------------------------------------------------------
# Wind Simulation Helpers
# -----------------------------------------------------------------------------

func _on_wind_enabled_changed(enabled: bool) -> void:
	if enabled:
		if not wind_initialized_for_round or current_wind_speed_mph <= 0.0:
			generate_new_wind()
		else:
			wind_changed.emit(current_wind_speed_mph, current_wind_direction_rad)
	else:
		wind_changed.emit(0.0, current_wind_direction_rad)


func is_driving_range_scene() -> bool:
	var scene := _get_active_scene()
	if scene == null:
		return false
	if ("is_driving_range" in scene and bool(scene.get("is_driving_range"))) or (scene.has_meta("is_driving_range") and bool(scene.get_meta("is_driving_range"))):
		return true
	var scene_name := str(scene.name).to_lower()
	var script: Script = scene.get_script()
	var script_path := str(script.resource_path).to_lower() if script != null else ""
	var file_path := str(scene.scene_file_path).to_lower() if "scene_file_path" in scene else ""
	var full_id := (scene_name + " " + script_path + " " + file_path).to_lower()

	if scene.has_node("CoursePlay") or full_id.contains("course_play") or full_id.contains("courseplaysetup") or full_id.contains("course_selector"):
		return false

	return (scene_name == "range" or file_path.ends_with("range.tscn") or file_path.ends_with("range.scn"))


func is_wind_enabled() -> bool:
	if is_driving_range_scene():
		return false
	if range_settings != null and range_settings.settings.has("wind_enabled"):
		return bool(range_settings.wind_enabled.value)
	return false


func generate_new_wind() -> void:
	current_wind_direction_rad = randf_range(0.0, TAU)
	current_wind_speed_mph = _pick_weighted_random_wind_speed()
	if range_settings != null and range_settings.settings.has("wind_speed"):
		range_settings.wind_speed.set_value(current_wind_speed_mph)
	wind_initialized_for_round = true
	wind_changed.emit(current_wind_speed_mph, current_wind_direction_rad)
	print("[GlobalSettings] Wind generated for course: %.1f MPH @ %.1f°" % [current_wind_speed_mph, rad_to_deg(current_wind_direction_rad)])


func _pick_weighted_random_wind_speed() -> float:
	# Weighted buckets for realistic golf wind distribution:
	# - 6-12 MPH: Most frequent (55% total)
	# - 2-5 MPH: Next most frequent (20% total)
	# - 13-15 MPH: Next most frequent (15% total)
	# - 1 MPH: Very infrequent (2% total)
	# - 16-20 MPH: Very infrequent (8% total)
	var roll := randf() * 100.0
	if roll < 55.0:
		return float(randi_range(6, 12))
	elif roll < 75.0:
		return float(randi_range(2, 5))
	elif roll < 90.0:
		return float(randi_range(13, 15))
	elif roll < 92.0:
		return 1.0
	else:
		return float(randi_range(16, 20))


func set_wind_speed_mph(speed: float) -> void:
	current_wind_speed_mph = clampf(speed, 0.0, 50.0)
	if range_settings != null and range_settings.settings.has("wind_speed"):
		range_settings.wind_speed.set_value(current_wind_speed_mph)
	wind_changed.emit(current_wind_speed_mph, current_wind_direction_rad)


func start_round_wind(force_new: bool = true) -> void:
	if has_node("/root/OnlineSession") and get_node("/root/OnlineSession").is_online_match:
		return
	if is_wind_enabled():
		if force_new or not wind_initialized_for_round or current_wind_speed_mph <= 0.0:
			generate_new_wind()
	else:
		wind_initialized_for_round = false


const WIND_PEAK_ALTITUDE_METERS: float = 25.0

func get_wind_vector_mps() -> Vector3:
	if not is_wind_enabled() or current_wind_speed_mph <= 0.0:
		return Vector3.ZERO
	var speed_mps: float = current_wind_speed_mph * 0.44704
	# In Godot 3D, +X is East, +Z is South. Horizontal plane wind:
	return Vector3(cos(current_wind_direction_rad), 0.0, sin(current_wind_direction_rad)) * speed_mps


## Returns the atmospheric boundary layer wind scaling factor (0.0 to 1.0)
## as a function of height above ground (altitude_m).
## Near ground level (start/end of trajectory), wind effect is ~0.0 (little to no effect).
## It increases smoothly up to 1.0 (the full listed amount) at peak heights (>= 25m).
func get_wind_altitude_factor(altitude_m: float) -> float:
	return smoothstep(0.0, WIND_PEAK_ALTITUDE_METERS, maxf(0.0, altitude_m))


## Returns the effective wind vector scaled by the elevation gradient for the given altitude.
func get_wind_vector_at_altitude_mps(altitude_m: float) -> Vector3:
	var base_vec := get_wind_vector_mps()
	if base_vec.is_zero_approx():
		return Vector3.ZERO
	return base_vec * get_wind_altitude_factor(altitude_m)


func get_relative_wind_arrow_and_angle(ball_pos: Vector3, aim_target_pos: Vector3, fallback_forward: Vector3 = Vector3.ZERO) -> Dictionary:
	var fwd_h: Vector3 = aim_target_pos - ball_pos
	fwd_h.y = 0.0
	if fwd_h.length_squared() < 0.001:
		fwd_h = fallback_forward
		fwd_h.y = 0.0
		if fwd_h.length_squared() < 0.001:
			fwd_h = Vector3.RIGHT
	fwd_h = fwd_h.normalized()
	var right_h: Vector3 = fwd_h.cross(Vector3.UP).normalized()

	var world_wind_dir := Vector3(cos(current_wind_direction_rad), 0.0, sin(current_wind_direction_rad))
	var w_fwd: float = world_wind_dir.dot(fwd_h)
	var w_right: float = world_wind_dir.dot(right_h)
	var angle_rad: float = atan2(w_right, w_fwd)
	var deg: float = rad_to_deg(angle_rad)

	var arrow: String = "↑"
	if deg >= -22.5 and deg < 22.5:
		arrow = "↑"
	elif deg >= 22.5 and deg < 67.5:
		arrow = "↗"
	elif deg >= 67.5 and deg < 112.5:
		arrow = "→"
	elif deg >= 112.5 and deg < 157.5:
		arrow = "↘"
	elif deg >= 157.5 or deg < -157.5:
		arrow = "↓"
	elif deg >= -157.5 and deg < -112.5:
		arrow = "↙"
	elif deg >= -112.5 and deg < -67.5:
		arrow = "←"
	elif deg >= -67.5 and deg < -22.5:
		arrow = "↖"

	var thick_arrow: String = arrow

	return {
		"arrow": arrow,
		"thick_arrow": thick_arrow,
		"angle_deg": deg,
		"w_fwd": w_fwd,
		"w_right": w_right,
		"speed_mph": current_wind_speed_mph
	}



