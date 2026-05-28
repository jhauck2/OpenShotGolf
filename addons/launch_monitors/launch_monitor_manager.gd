class_name LaunchMonitorManagerAutoload
extends Node

# Monitor implementations live in sibling folders (e.g. `square/`); shared transports and external receivers live under `common/`.

signal hit_ball(data: Dictionary)
signal device_discovered(device_id: String, name: String, rssi: int)
signal status_changed(status: String)
signal error_occurred(message: String)
signal battery_changed(level: int)
signal firmware_changed(firmware: String)
signal ready_changed(is_ready: bool)

const SETTINGS_PATH := "user://square_launch_monitor.cfg"
const DEFAULT_CLUB_CODE := SquareClubCatalog.DEFAULT_CLUB_CODE
const PROVIDER_PITRAC := AppSettings.LAUNCH_MONITOR_PROVIDER_PITRAC
const PROVIDER_SQUARE := AppSettings.LAUNCH_MONITOR_PROVIDER_SQUARE
const SQUARE_CLASS_NAME := "SquareLaunchMonitor"
const SQUARE_SCRIPT_PATH := "res://addons/launch_monitors/square/SquareLaunchMonitor.cs"
const TCP_SERVER_CLASS_NAME := "TcpServer"
const TCP_SERVER_SCRIPT_PATH := "res://addons/launch_monitors/common/tcp_server/TcpServer.cs"
const LMONITOR_LOG_PREFIX := "[LMonitor]"
const SQUARE_DEVICE_PREFIX := "squaregolf"
const BLUEZ_DEVICE_SEGMENT_PREFIX := "/dev_"
const LINUX_AUTO_CONNECT_SCAN_SECONDS := 15.0
const TRANSIENT_CONNECT_ERROR_MARKERS := [
	"not ready yet",
	"could not open the selected bluetooth device"
]

var devices: Dictionary = {}
var status := "Disconnected"
var battery_level := -1
var firmware := ""
var is_ready := false
var _square_init_error := ""
var _square_runtime_enabled := false

var _square: Node = null
var _config := ConfigFile.new()
var _linux_auto_connect_active := false
var _linux_auto_connect_target_address := ""
var _linux_auto_connect_timer: Timer = null
var _tcp_server: Node = null
var _tcp_init_error := ""
var _app_settings: AppSettings = null
var _active_provider := ""


func _ready() -> void:
	_debug_log("Launch monitor ready. OS=%s, C# runtime class exists=%s, assembly=%s" % [
		OS.get_name(),
		str(ClassDB.class_exists("CSharpScript")),
		str(ProjectSettings.get_setting("dotnet/project/assembly_name", ""))
	])
	_load_runtime_enabled()
	_create_square_monitor()
	if _square == null:
		_debug_error("Square monitor unavailable during startup: %s" % _square_init_error)
	_app_settings = _get_app_settings()
	_connect_launch_monitor_settings()
	_apply_launch_monitor_settings()


func _exit_tree() -> void:
	_disconnect_launch_monitor_settings()
	_stop_pitrac()


func start_scan() -> void:
	if not _is_provider_active(PROVIDER_SQUARE):
		_set_status("Select Square")
		return
	_cancel_linux_auto_connect_scan()
	_start_square_scan()


func stop_scan() -> void:
	_cancel_linux_auto_connect_scan()
	_stop_square_scan()


func connect_to_device(device_id: String) -> void:
	if not _is_provider_active(PROVIDER_SQUARE):
		_set_status("Select Square")
		return
	_cancel_linux_auto_connect_scan()
	if _square == null:
		var message := _missing_support_message()
		_debug_error("connect_to_device blocked: %s" % message)
		_set_status(message)
		emit_signal("error_occurred", message)
		return
	_debug_log("connect_to_device requested for %s" % device_id)
	if _app_settings != null:
		_app_settings.square_device_id.set_value(device_id)
	_square.call("SetHandedness", get_square_handedness())
	_square.call("SetClub", get_square_club_code())
	_square.call("ConnectToDevice", device_id)


func disconnect_device() -> void:
	_cancel_linux_auto_connect_scan()
	if _square != null:
		_debug_log("disconnect_device requested")
		_square.call("DisconnectFromDevice")
	_clear_monitor_details()


func _start_square_scan() -> void:
	if _square == null:
		var message := _missing_support_message()
		_debug_error("start_scan blocked: %s" % message)
		_set_status(message)
		emit_signal("error_occurred", message)
		return
	_debug_log("start_scan requested")
	devices.clear()
	_square.call("StartScan")


func _stop_square_scan() -> void:
	if _square != null:
		_debug_log("stop_scan requested")
		_square.call("StopScan")


func set_enabled(value: bool) -> void:
	if _square_runtime_enabled == value:
		return
	if not value:
		_cancel_linux_auto_connect_scan()
	_square_runtime_enabled = value
	_save_runtime_enabled()


func set_club_code(club_code: String) -> void:
	if _app_settings != null:
		_app_settings.square_club_code.set_value(club_code)
	if _square != null:
		_square.call("SetClub", club_code)


func set_handedness(handedness: int) -> void:
	if _app_settings != null:
		_app_settings.square_handedness.set_value(handedness)
	if _square != null:
		_square.call("SetHandedness", handedness)


func get_square_club_code() -> String:
	if _app_settings == null:
		return DEFAULT_CLUB_CODE
	return str(_app_settings.square_club_code.value)


func get_square_handedness() -> int:
	if _app_settings == null:
		return 0
	return int(_app_settings.square_handedness.value)


func get_selected_device_id() -> String:
	if _app_settings == null:
		return ""
	return str(_app_settings.square_device_id.value)


func set_ready() -> void:
	if _square != null:
		_debug_log("set_ready requested")
		_square.call("SetReady")


func _create_square_monitor() -> void:
	_square_init_error = ""
	_debug_log("Attempting to load script %s" % SQUARE_SCRIPT_PATH)
	var square_script := load(SQUARE_SCRIPT_PATH) as Script
	if square_script == null:
		_square_init_error = "Square script could not be loaded at %s." % SQUARE_SCRIPT_PATH
		_set_status(_square_init_error)
		emit_signal("error_occurred", _square_init_error)
		_debug_error(_square_init_error)
		return

	if not square_script.can_instantiate():
		_square_init_error = "%s script is loaded but cannot instantiate. Ensure C# build succeeds and class name matches filename." % SQUARE_CLASS_NAME
		_set_status(_square_init_error)
		emit_signal("error_occurred", _square_init_error)
		_debug_error(_square_init_error)
		return

	_square = square_script.new() as Node
	if _square == null:
		_square_init_error = "%s could not be created from %s. Check C# build output for load errors." % [SQUARE_CLASS_NAME, SQUARE_SCRIPT_PATH]
		_set_status(_square_init_error)
		emit_signal("error_occurred", _square_init_error)
		_debug_error(_square_init_error)
		return

	add_child(_square)
	_set_status("Disconnected")
	_debug_log("%s instantiated and signals connected." % SQUARE_CLASS_NAME)
	_square.connect("DeviceDiscovered", _on_square_device_discovered)
	_square.connect("StatusChanged", _on_square_status_changed)
	_square.connect("ErrorOccurred", _on_square_error_occurred)
	_square.connect("BatteryChanged", _on_square_battery_changed)
	_square.connect("FirmwareChanged", _on_square_firmware_changed)
	_square.connect("ReadyChanged", _on_square_ready_changed)
	_square.connect("ShotReceived", _on_square_shot_received)


func _load_runtime_enabled() -> void:
	if _config.load(SETTINGS_PATH) != OK:
		return
	_square_runtime_enabled = bool(_config.get_value("square", "enabled", false))


func _save_runtime_enabled() -> void:
	_config.set_value("square", "enabled", _square_runtime_enabled)
	var err := _config.save(SETTINGS_PATH)
	if err != OK:
		_debug_error("Failed to save Square runtime flag at %s" % SETTINGS_PATH)
		emit_signal("error_occurred", "Square settings could not be saved.")


func _on_square_device_discovered(device_id: String, name: String, rssi: int) -> void:
	if not _is_provider_active(PROVIDER_SQUARE):
		return
	if not _is_square_device_name(name):
		_debug_log("ignoring non-square device discovery: %s (%s)" % [name, device_id])
		return
	_debug_log("device discovered: %s (%s) RSSI=%d" % [name, device_id, rssi])
	devices[device_id] = {
		"name": name,
		"rssi": rssi
	}
	emit_signal("device_discovered", device_id, name, rssi)
	if _is_linux_auto_connect_match(device_id):
		_debug_log("saved Linux Square discovered; connecting automatically")
		connect_to_device(device_id)


func _on_square_status_changed(value: String) -> void:
	if not _is_provider_active(PROVIDER_SQUARE):
		return
	_set_status(_normalize_square_status(value))


func _on_square_error_occurred(message: String) -> void:
	if not _is_provider_active(PROVIDER_SQUARE):
		return
	if _is_transient_square_connect_error(message):
		_debug_log("Square runtime warning: %s" % message)
	else:
		_debug_error("Square runtime error: %s" % message)
	emit_signal("error_occurred", message)


func _on_square_battery_changed(level: int) -> void:
	if not _is_provider_active(PROVIDER_SQUARE):
		return
	_debug_log("battery changed: %d%%" % level)
	battery_level = level
	emit_signal("battery_changed", level)


func _on_square_firmware_changed(value: String) -> void:
	if not _is_provider_active(PROVIDER_SQUARE):
		return
	_debug_log("firmware changed: %s" % value)
	firmware = value
	emit_signal("firmware_changed", value)


func _on_square_ready_changed(value: bool) -> void:
	if not _is_provider_active(PROVIDER_SQUARE):
		return
	_debug_log("ready changed: %s" % str(value))
	is_ready = value
	emit_signal("ready_changed", value)


func _on_square_shot_received(data: Dictionary) -> void:
	if not _is_provider_active(PROVIDER_SQUARE):
		return
	_debug_log("shot received with %d fields" % data.size())
	emit_signal("hit_ball", data)


func _get_app_settings() -> AppSettings:
	if GlobalSettings == null:
		return null
	return GlobalSettings.app_settings


func _connect_launch_monitor_settings() -> void:
	if _app_settings == null:
		return

	var callback := Callable(self, "_on_launch_monitor_setting_changed")
	if not _app_settings.launch_monitor_enabled.setting_changed.is_connected(callback):
		_app_settings.launch_monitor_enabled.setting_changed.connect(callback)
	if not _app_settings.launch_monitor_provider.setting_changed.is_connected(callback):
		_app_settings.launch_monitor_provider.setting_changed.connect(callback)
	if not _app_settings.tcp_port.setting_changed.is_connected(callback):
		_app_settings.tcp_port.setting_changed.connect(callback)


func _disconnect_launch_monitor_settings() -> void:
	if _app_settings == null:
		return

	var callback := Callable(self, "_on_launch_monitor_setting_changed")
	if _app_settings.launch_monitor_enabled.setting_changed.is_connected(callback):
		_app_settings.launch_monitor_enabled.setting_changed.disconnect(callback)
	if _app_settings.launch_monitor_provider.setting_changed.is_connected(callback):
		_app_settings.launch_monitor_provider.setting_changed.disconnect(callback)
	if _app_settings.tcp_port.setting_changed.is_connected(callback):
		_app_settings.tcp_port.setting_changed.disconnect(callback)


func _on_launch_monitor_setting_changed(_value: Variant) -> void:
	_apply_launch_monitor_settings()


func _apply_launch_monitor_settings() -> void:
	if _app_settings == null or not bool(_app_settings.launch_monitor_enabled.value):
		_disable_launch_monitors()
		return

	var provider := _get_selected_provider()
	if provider == PROVIDER_SQUARE:
		_start_square_provider()
	else:
		_start_pitrac_provider()


func _get_selected_provider() -> String:
	if _app_settings == null:
		return PROVIDER_PITRAC

	return AppSettings.normalize_provider(str(_app_settings.launch_monitor_provider.value))


func _is_provider_active(provider: String) -> bool:
	return _app_settings != null and bool(_app_settings.launch_monitor_enabled.value) and _get_selected_provider() == provider


func _disable_launch_monitors() -> void:
	_stop_pitrac()
	_stop_square_provider()
	_active_provider = ""
	_clear_monitor_details()
	_set_status("Disabled")


func _start_square_provider() -> void:
	if _active_provider != PROVIDER_SQUARE:
		_stop_pitrac()
		_active_provider = PROVIDER_SQUARE
		set_enabled(true)
		if status == "Disabled" or status.begins_with(PROVIDER_PITRAC):
			_set_status("Disconnected")
		_connect_saved_device_on_startup(get_selected_device_id())
	else:
		set_enabled(true)


func _stop_square_provider() -> void:
	var should_stop_runtime := _active_provider == PROVIDER_SQUARE or _linux_auto_connect_active
	_cancel_linux_auto_connect_scan()
	set_enabled(false)
	if not should_stop_runtime:
		_clear_monitor_details()
		return

	_stop_square_scan()
	disconnect_device()


func _start_pitrac_provider() -> void:
	if _active_provider != PROVIDER_PITRAC:
		_stop_square_provider()
		_active_provider = PROVIDER_PITRAC
	_clear_monitor_details()
	_start_pitrac(int(_app_settings.tcp_port.value))


func _start_pitrac(port: int) -> void:
	if _tcp_server == null:
		_create_pitrac_tcp_server()
	if _tcp_server == null:
		_set_status(_tcp_init_error)
		return

	if bool(_tcp_server.call("GetIsListening")):
		_tcp_server.call("StopListening")
		await get_tree().process_frame

	_tcp_server.call("StartListening", port)


func _stop_pitrac() -> void:
	if _tcp_server == null:
		return
	_tcp_server.call("StopListening")


func _create_pitrac_tcp_server() -> void:
	_tcp_init_error = ""
	var tcp_script := load(TCP_SERVER_SCRIPT_PATH) as Script
	if tcp_script == null:
		_tcp_init_error = "%s script could not be loaded at %s." % [TCP_SERVER_CLASS_NAME, TCP_SERVER_SCRIPT_PATH]
		_debug_error(_tcp_init_error)
		return

	if not tcp_script.can_instantiate():
		_tcp_init_error = "%s script is loaded but cannot instantiate. Ensure C# build succeeds and class name matches filename." % TCP_SERVER_CLASS_NAME
		_debug_error(_tcp_init_error)
		return

	_tcp_server = tcp_script.new() as Node
	if _tcp_server == null:
		_tcp_init_error = "%s could not be created from %s. Check C# build output for load errors." % [TCP_SERVER_CLASS_NAME, TCP_SERVER_SCRIPT_PATH]
		_debug_error(_tcp_init_error)
		return

	add_child(_tcp_server)
	_tcp_server.connect("HitBall", _on_pitrac_hit_ball)
	_tcp_server.connect("StatusChanged", _on_pitrac_status_changed)


func _on_pitrac_hit_ball(data: Dictionary) -> void:
	_debug_log("PiTrac shot received with %d fields" % data.size())
	emit_signal("hit_ball", data)


func _on_pitrac_status_changed(value: String) -> void:
	if _active_provider != PROVIDER_PITRAC or not _is_provider_active(PROVIDER_PITRAC):
		return

	_set_status("%s %s" % [PROVIDER_PITRAC, value])


func _clear_monitor_details() -> void:
	if battery_level != -1:
		battery_level = -1
		emit_signal("battery_changed", battery_level)
	if firmware != "":
		firmware = ""
		emit_signal("firmware_changed", firmware)


func _missing_support_message() -> String:
	if _square_init_error != "":
		return "Square support is unavailable in this build. %s" % _square_init_error
	return "Square support is unavailable in this build."


func _connect_saved_device_on_startup(device_id: String) -> void:
	if device_id == "":
		return
	if _square == null:
		connect_to_device(device_id)
		return
	if OS.get_name() != "Linux":
		connect_to_device(device_id)
		return
	_start_linux_auto_connect_scan(device_id)


func _start_linux_auto_connect_scan(device_id: String) -> void:
	_cancel_linux_auto_connect_scan()
	var target_address := _normalize_bluetooth_address(device_id)
	if target_address == "":
		_debug_log("saved Linux Bluetooth id cannot be matched automatically")
		return
	_linux_auto_connect_active = true
	_linux_auto_connect_target_address = target_address
	_debug_log("starting saved Linux Square scan")
	_start_square_scan()
	_start_linux_auto_connect_timer()


func _start_linux_auto_connect_timer() -> void:
	_clear_linux_auto_connect_timer()
	_linux_auto_connect_timer = Timer.new()
	_linux_auto_connect_timer.one_shot = true
	_linux_auto_connect_timer.wait_time = LINUX_AUTO_CONNECT_SCAN_SECONDS
	_linux_auto_connect_timer.timeout.connect(_on_linux_auto_connect_timeout)
	add_child(_linux_auto_connect_timer)
	_linux_auto_connect_timer.start()


func _on_linux_auto_connect_timeout() -> void:
	if not _linux_auto_connect_active:
		return
	_debug_log("saved Linux Square was not found during startup scan")
	_linux_auto_connect_active = false
	_linux_auto_connect_target_address = ""
	_clear_linux_auto_connect_timer()
	_stop_square_scan()
	if status == "Scanning":
		_set_status("Disconnected")


func _cancel_linux_auto_connect_scan() -> void:
	_linux_auto_connect_active = false
	_linux_auto_connect_target_address = ""
	_clear_linux_auto_connect_timer()


func _clear_linux_auto_connect_timer() -> void:
	if _linux_auto_connect_timer == null:
		return
	if _linux_auto_connect_timer.timeout.is_connected(_on_linux_auto_connect_timeout):
		_linux_auto_connect_timer.timeout.disconnect(_on_linux_auto_connect_timeout)
	_linux_auto_connect_timer.stop()
	_linux_auto_connect_timer.queue_free()
	_linux_auto_connect_timer = null


func _is_linux_auto_connect_match(device_id: String) -> bool:
	if not _linux_auto_connect_active or _linux_auto_connect_target_address == "":
		return false
	return _normalize_bluetooth_address(device_id) == _linux_auto_connect_target_address


func _normalize_bluetooth_address(value: String) -> String:
	var normalized := value.strip_edges()
	if normalized == "":
		return ""
	var device_segment_index := normalized.rfind(BLUEZ_DEVICE_SEGMENT_PREFIX)
	if device_segment_index >= 0:
		normalized = normalized.substr(device_segment_index + BLUEZ_DEVICE_SEGMENT_PREFIX.length())
		var child_path_index := normalized.find("/")
		if child_path_index >= 0:
			normalized = normalized.substr(0, child_path_index)
	normalized = normalized.replace("-", ":").replace("_", ":").to_upper()
	if normalized.length() == 12 and not normalized.contains(":"):
		var parts := PackedStringArray()
		for index in range(0, normalized.length(), 2):
			parts.append(normalized.substr(index, 2))
		normalized = ":".join(parts)
	if not _is_bluetooth_address(normalized):
		return ""
	return normalized


func _is_bluetooth_address(value: String) -> bool:
	var parts := value.split(":")
	if parts.size() != 6:
		return false
	for part in parts:
		if part.length() != 2:
			return false
		for index in range(part.length()):
			if not _is_hex_digit_code(part.unicode_at(index)):
				return false
	return true


func _is_hex_digit_code(value: int) -> bool:
	return (value >= 48 and value <= 57) or (value >= 65 and value <= 70)


func _set_status(value: String) -> void:
	status = value
	emit_signal("status_changed", value)
	_debug_log("status -> %s" % value)


func _normalize_square_status(value: String) -> String:
	var normalized := value.strip_edges()
	if normalized == "Ready":
		return "Connected"
	return normalized


func _debug_log(message: String) -> void:
	print("%s %s" % [LMONITOR_LOG_PREFIX, message])


func _debug_error(message: String) -> void:
	push_error("%s %s" % [LMONITOR_LOG_PREFIX, message])


func _is_transient_square_connect_error(message: String) -> bool:
	var normalized := message.strip_edges().to_lower()
	for marker in TRANSIENT_CONNECT_ERROR_MARKERS:
		if normalized.contains(marker):
			return true
	return false


func _is_square_device_name(name: String) -> bool:
	return name.strip_edges().to_lower().begins_with(SQUARE_DEVICE_PREFIX)
