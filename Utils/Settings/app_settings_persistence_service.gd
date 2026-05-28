class_name AppSettingsPersistenceService
extends RefCounted

const SAVE_PATH := "user://app_settings.cfg"
const LEGACY_SQUARE_PATH := "user://square_launch_monitor.cfg"
const SAVE_VERSION := 3
const OLD_DEFAULT_TCP_PORT := 55000


static func load_into(app_settings: AppSettings) -> void:
	if app_settings == null:
		return

	var config := ConfigFile.new()
	var load_error := config.load(SAVE_PATH)
	var save_version := int(config.get_value("meta", "version", 0)) if load_error == OK else 0
	if load_error == OK:
		_set_if_present(config, "player", "name", app_settings.player_name)
		_set_if_present(config, "player", "test_shots_enabled", app_settings.test_shots_enabled)
		_set_if_present(config, "player", "range_default_club", app_settings.range_default_club)
		_set_if_present(config, "display", "resolution_preset", app_settings.display_resolution_preset)
		_set_if_present(config, "display", "fullscreen", app_settings.display_fullscreen)
		_set_if_present(config, "game", "camera_orbit_distance", app_settings.camera_orbit_distance)
		_set_if_present(config, "game", "camera_follow_delay_seconds", app_settings.camera_follow_delay_seconds)
		_load_tcp_port(config, app_settings.tcp_port)
		_set_if_present(config, "game", "shot_recording_enabled", app_settings.shot_recording_enabled)
		_set_if_present(config, "game", "shot_recording_path", app_settings.shot_recording_path)
		_set_if_present(config, "launch_monitor", "enabled", app_settings.launch_monitor_enabled)
		_load_provider(config, app_settings.launch_monitor_provider)
		_set_if_present(config, "square", "device_id", app_settings.square_device_id)
		_set_if_present(config, "square", "club_code", app_settings.square_club_code)
		_set_if_present(config, "square", "handedness", app_settings.square_handedness)

	if save_version < SAVE_VERSION:
		_migrate_legacy_square(app_settings)


static func save(app_settings: AppSettings) -> void:
	if app_settings == null:
		return

	var config := ConfigFile.new()
	config.set_value("meta", "version", SAVE_VERSION)
	config.set_value("player", "name", app_settings.player_name.value)
	config.set_value("player", "test_shots_enabled", app_settings.test_shots_enabled.value)
	config.set_value("player", "range_default_club", app_settings.range_default_club.value)
	config.set_value("display", "resolution_preset", app_settings.display_resolution_preset.value)
	config.set_value("display", "fullscreen", app_settings.display_fullscreen.value)
	config.set_value("game", "camera_orbit_distance", app_settings.camera_orbit_distance.value)
	config.set_value("game", "camera_follow_delay_seconds", app_settings.camera_follow_delay_seconds.value)
	config.set_value("game", "tcp_port", app_settings.tcp_port.value)
	config.set_value("game", "shot_recording_enabled", app_settings.shot_recording_enabled.value)
	config.set_value("game", "shot_recording_path", app_settings.shot_recording_path.value)
	config.set_value("launch_monitor", "enabled", app_settings.launch_monitor_enabled.value)
	config.set_value("launch_monitor", "provider", app_settings.launch_monitor_provider.value)
	config.set_value("square", "device_id", app_settings.square_device_id.value)
	config.set_value("square", "club_code", app_settings.square_club_code.value)
	config.set_value("square", "handedness", app_settings.square_handedness.value)

	var error := config.save(SAVE_PATH)
	if error != OK:
		push_error("App settings could not be saved at %s." % SAVE_PATH)


static func _migrate_legacy_square(app_settings: AppSettings) -> void:
	var legacy := ConfigFile.new()
	if legacy.load(LEGACY_SQUARE_PATH) != OK:
		return

	if legacy.has_section_key("square", "device_id"):
		app_settings.square_device_id.set_value(str(legacy.get_value("square", "device_id", "")))
	if legacy.has_section_key("square", "club_code"):
		app_settings.square_club_code.set_value(str(legacy.get_value("square", "club_code", SquareClubCatalog.DEFAULT_CLUB_CODE)))
	if legacy.has_section_key("square", "handedness"):
		app_settings.square_handedness.set_value(int(legacy.get_value("square", "handedness", 0)))


static func _set_if_present(config: ConfigFile, section: String, key: String, setting: Setting) -> void:
	if setting == null or not config.has_section_key(section, key):
		return

	setting.set_value(config.get_value(section, key))


static func _load_tcp_port(config: ConfigFile, setting: Setting) -> void:
	if setting == null or not config.has_section_key("game", "tcp_port"):
		return

	var save_version := int(config.get_value("meta", "version", 0))
	var port := int(config.get_value("game", "tcp_port", AppSettings.DEFAULT_TCP_PORT))
	if save_version < SAVE_VERSION and port == OLD_DEFAULT_TCP_PORT:
		port = AppSettings.DEFAULT_TCP_PORT

	setting.set_value(port)


static func _load_provider(config: ConfigFile, setting: Setting) -> void:
	if setting == null or not config.has_section_key("launch_monitor", "provider"):
		return

	var raw := str(config.get_value("launch_monitor", "provider", ""))
	if not AppSettings.is_valid_provider(raw):
		push_warning("Unknown launch_monitor_provider '%s' in %s; falling back to default." % [raw, SAVE_PATH])
		setting.set_value(AppSettings.LAUNCH_MONITOR_PROVIDER_PITRAC)
		return

	setting.set_value(raw)
