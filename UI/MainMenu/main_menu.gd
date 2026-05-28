extends Control

@onready var _settings_button: Button = $VerticalLayout/TopStrip/HBoxContainer/SettingsButton
@onready var _exit_button: Button = $VerticalLayout/TopStrip/HBoxContainer/ExitButton
@onready var _courses_button: Button = $VerticalLayout/TilesRow/CoursesTile/CoursesTextBackdrop/CoursesButton
@onready var _range_button: Button = $VerticalLayout/TilesRow/RangeTile/RangeTextBackdrop/RangeButton
@onready var _version_label: Label = $BottomInfoBar/VersionLabel
@onready var _launch_monitor_status: HBoxContainer = $BottomInfoBar/LaunchMonitorStatus
@onready var _launch_monitor_status_label: Label = $BottomInfoBar/LaunchMonitorStatus/StatusLabel
@onready var _launch_monitor_battery_label: Label = $BottomInfoBar/LaunchMonitorStatus/BatteryLabel
@onready var _launch_monitor_firmware_label: Label = $BottomInfoBar/LaunchMonitorStatus/FirmwareLabel
@onready var _settings_panel: SettingsPanel = $SettingsPanel
var _version_fall_back: String = "dev"
var _version_setting_path: String = "application/config/version"
var _version_text: String


func _ready() -> void:
	_exit_button.pressed.connect(_on_exit_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_range_button.pressed.connect(_on_range_pressed)
	_courses_button.pressed.connect(_on_courses_pressed)
	_settings_panel.set_main_menu_button_visible(false)
	_connect_launch_monitor_status_signals()

	_update_version_label()
	_update_launch_monitor_status()
	SceneManager.current_scene = self


func _exit_tree() -> void:
	_disconnect_launch_monitor_status_signals()


func _on_range_pressed() -> void:
	SceneManager.change_scene("res://Courses/Range/range.tscn")


func _on_courses_pressed() -> void:
	SceneManager.change_scene("res://Courses/CourseSelector/course_selector.tscn")


func _update_version_label() -> void:
	_version_text = _version_fall_back
	if (ProjectSettings.has_setting(_version_setting_path)):
		var _configured_version = str(ProjectSettings.get_setting(_version_setting_path)).strip_edges()
		_version_text = _configured_version

	_version_label.text = "OSG Version %s" % _version_text


func _connect_launch_monitor_status_signals() -> void:
	var launch_monitor = (LaunchMonitorManager as LaunchMonitorManagerAutoload)
	if launch_monitor != null:
		if not launch_monitor.status_changed.is_connected(_on_launch_monitor_status_changed):
			launch_monitor.status_changed.connect(_on_launch_monitor_status_changed)
		if not launch_monitor.battery_changed.is_connected(_on_launch_monitor_battery_changed):
			launch_monitor.battery_changed.connect(_on_launch_monitor_battery_changed)
		if not launch_monitor.firmware_changed.is_connected(_on_launch_monitor_firmware_changed):
			launch_monitor.firmware_changed.connect(_on_launch_monitor_firmware_changed)

	var global_settings = (GlobalSettings as GlobalSettingsAutoload)
	if global_settings != null and global_settings.app_settings != null:
		var app_settings: AppSettings = global_settings.app_settings
		if not app_settings.launch_monitor_enabled.setting_changed.is_connected(_on_launch_monitor_setting_changed):
			app_settings.launch_monitor_enabled.setting_changed.connect(_on_launch_monitor_setting_changed)
		if not app_settings.launch_monitor_provider.setting_changed.is_connected(_on_launch_monitor_setting_changed):
			app_settings.launch_monitor_provider.setting_changed.connect(_on_launch_monitor_setting_changed)


func _disconnect_launch_monitor_status_signals() -> void:
	var launch_monitor = (LaunchMonitorManager as LaunchMonitorManagerAutoload)
	if launch_monitor != null:
		if launch_monitor.status_changed.is_connected(_on_launch_monitor_status_changed):
			launch_monitor.status_changed.disconnect(_on_launch_monitor_status_changed)
		if launch_monitor.battery_changed.is_connected(_on_launch_monitor_battery_changed):
			launch_monitor.battery_changed.disconnect(_on_launch_monitor_battery_changed)
		if launch_monitor.firmware_changed.is_connected(_on_launch_monitor_firmware_changed):
			launch_monitor.firmware_changed.disconnect(_on_launch_monitor_firmware_changed)

	var global_settings = (GlobalSettings as GlobalSettingsAutoload)
	if global_settings != null and global_settings.app_settings != null:
		var app_settings: AppSettings = global_settings.app_settings
		if app_settings.launch_monitor_enabled.setting_changed.is_connected(_on_launch_monitor_setting_changed):
			app_settings.launch_monitor_enabled.setting_changed.disconnect(_on_launch_monitor_setting_changed)
		if app_settings.launch_monitor_provider.setting_changed.is_connected(_on_launch_monitor_setting_changed):
			app_settings.launch_monitor_provider.setting_changed.disconnect(_on_launch_monitor_setting_changed)


func _on_launch_monitor_status_changed(_status: String) -> void:
	_update_launch_monitor_status()


func _on_launch_monitor_battery_changed(_level: int) -> void:
	_update_launch_monitor_status()


func _on_launch_monitor_firmware_changed(_firmware: String) -> void:
	_update_launch_monitor_status()


func _on_launch_monitor_setting_changed(_value: Variant) -> void:
	_update_launch_monitor_status()


func _update_launch_monitor_status() -> void:
	var global_settings = (GlobalSettings as GlobalSettingsAutoload)
	if global_settings == null or global_settings.app_settings == null:
		_launch_monitor_status.visible = false
		return

	var app_settings: AppSettings = global_settings.app_settings
	if not bool(app_settings.launch_monitor_enabled.value):
		_launch_monitor_status.visible = false
		return

	var launch_monitor = (LaunchMonitorManager as LaunchMonitorManagerAutoload)
	if launch_monitor == null:
		_launch_monitor_status.visible = false
		return

	_launch_monitor_status.visible = true
	var monitor_status := str(launch_monitor.status).strip_edges()
	if monitor_status.begins_with("PiTrac Listening on"):
		monitor_status = ""
	if monitor_status != "":
		_launch_monitor_status_label.text = "Status: %s" % monitor_status
	else:
		_launch_monitor_status_label.text = "Status: -"

	var battery := int(launch_monitor.battery_level)
	if battery >= 0:
		_launch_monitor_battery_label.text = "Battery: %d%%" % battery
	else:
		_launch_monitor_battery_label.text = "Battery: -"

	var firmware := str(launch_monitor.firmware).strip_edges()
	if firmware != "":
		_launch_monitor_firmware_label.text = "Firmware: %s" % firmware
	else:
		_launch_monitor_firmware_label.text = "Firmware: -"


func _on_settings_pressed() -> void:
	_settings_panel.show_panel()


func _on_exit_pressed() -> void:
	get_tree().quit()
