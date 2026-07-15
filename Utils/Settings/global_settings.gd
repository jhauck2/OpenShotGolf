class_name GlobalSettings
extends Node

signal settings_changed

const OPENFAIRWAY_LOG_LEVEL_INFO := 2

var range_settings: RangeSettings = RangeSettings.new()
var game_settings: GameSettings = GameSettings.new()
var app_settings: AppSettings = AppSettings.new()

var _suppress_save := false


func _ready() -> void:
	PhysicsLogger.SetLevel(OPENFAIRWAY_LOG_LEVEL_INFO)
	AppSettingsPersistenceService.load_into(app_settings)
	_connect_app_settings_signals()
	AppSettingsDisplayService.apply(app_settings, get_window())


func _exit_tree() -> void:
	_disconnect_app_settings_signals()


func reset_all_settings_to_defaults() -> void:
	_suppress_save = true
	range_settings.reset_defaults()
	game_settings.reset_defaults()
	app_settings.reset_defaults()
	_suppress_save = false
	save_app_settings()
	emit_signal("settings_changed")


func save_app_settings() -> void:
	AppSettingsPersistenceService.save(app_settings)


func _connect_app_settings_signals() -> void:
	var save_callback := Callable(self, "_on_any_app_setting_changed")
	for setting: Setting in app_settings.settings.values():
		if not setting.setting_changed.is_connected(save_callback):
			setting.setting_changed.connect(save_callback)

	var display_callback := Callable(self, "_on_display_setting_changed")
	if not app_settings.display_resolution_preset.setting_changed.is_connected(display_callback):
		app_settings.display_resolution_preset.setting_changed.connect(display_callback)
	if not app_settings.display_fullscreen.setting_changed.is_connected(display_callback):
		app_settings.display_fullscreen.setting_changed.connect(display_callback)


func _disconnect_app_settings_signals() -> void:
	var save_callback := Callable(self, "_on_any_app_setting_changed")
	for setting: Setting in app_settings.settings.values():
		if setting.setting_changed.is_connected(save_callback):
			setting.setting_changed.disconnect(save_callback)

	var display_callback := Callable(self, "_on_display_setting_changed")
	if app_settings.display_resolution_preset.setting_changed.is_connected(display_callback):
		app_settings.display_resolution_preset.setting_changed.disconnect(display_callback)
	if app_settings.display_fullscreen.setting_changed.is_connected(display_callback):
		app_settings.display_fullscreen.setting_changed.disconnect(display_callback)


func _on_any_app_setting_changed(_value: Variant) -> void:
	if _suppress_save:
		return
	save_app_settings()
	emit_signal("settings_changed")


func _on_display_setting_changed(_value: Variant) -> void:
	AppSettingsDisplayService.apply(app_settings, get_window())
