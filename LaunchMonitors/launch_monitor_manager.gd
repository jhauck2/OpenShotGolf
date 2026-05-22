extends Node

signal hit_ball(data: Dictionary)
signal device_discovered(device_id: String, name: String, rssi: int)
signal status_changed(status: String)
signal error_occurred(message: String)
signal battery_changed(level: int)
signal firmware_changed(firmware: String)
signal ready_changed(is_ready: bool)

const SETTINGS_PATH := "user://square_launch_monitor.cfg"
const DEFAULT_CLUB_CODE := "0204"
const SQUARE_CLASS_NAME := "SquareLaunchMonitor"
const SQUARE_SCRIPT_PATH := "res://LaunchMonitors/Square/SquareLaunchMonitor.cs"
const SQUARE_LOG_PREFIX := "[SquareLM]"
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
var settings := {
	"enabled": false,
	"device_id": "",
	"club_code": DEFAULT_CLUB_CODE,
	"handedness": 0
}

var _square: Node = null
var _config := ConfigFile.new()
var _linux_auto_connect_active := false
var _linux_auto_connect_target_address := ""
var _linux_auto_connect_timer: Timer = null


func _ready() -> void:
	_debug_log("Launch monitor ready. OS=%s, C# runtime class exists=%s, assembly=%s" % [
		OS.get_name(),
		str(ClassDB.class_exists("CSharpScript")),
		str(ProjectSettings.get_setting("dotnet/project/assembly_name", ""))
	])
	_load_settings()
	_create_square_monitor()
	if _square == null:
		_debug_error("Square monitor unavailable during startup: %s" % _square_init_error)
	if bool(settings.get("enabled", false)):
		_connect_saved_device_on_startup(str(settings.get("device_id", "")))


func start_scan() -> void:
	_cancel_linux_auto_connect_scan()
	_start_square_scan()


func stop_scan() -> void:
	_cancel_linux_auto_connect_scan()
	_stop_square_scan()


func connect_to_device(device_id: String) -> void:
	_cancel_linux_auto_connect_scan()
	if _square == null:
		var message := _missing_support_message()
		_debug_error("connect_to_device blocked: %s" % message)
		_set_status(message)
		emit_signal("error_occurred", message)
		return
	_debug_log("connect_to_device requested for %s" % device_id)
	settings["device_id"] = device_id
	_save_settings()
	_square.call("SetHandedness", int(settings.get("handedness", 0)))
	_square.call("SetClub", str(settings.get("club_code", DEFAULT_CLUB_CODE)))
	_square.call("ConnectToDevice", device_id)


func disconnect_device() -> void:
	_cancel_linux_auto_connect_scan()
	if _square != null:
		_debug_log("disconnect_device requested")
		_square.call("DisconnectFromDevice")


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
	if not value:
		_cancel_linux_auto_connect_scan()
	settings["enabled"] = value
	_save_settings()


func set_club_code(club_code: String) -> void:
	settings["club_code"] = club_code
	_save_settings()
	if _square != null:
		_square.call("SetClub", club_code)


func set_handedness(handedness: int) -> void:
	settings["handedness"] = handedness
	_save_settings()
	if _square != null:
		_square.call("SetHandedness", handedness)


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


func _load_settings() -> void:
	var err := _config.load(SETTINGS_PATH)
	if err != OK:
		return
	settings["enabled"] = bool(_config.get_value("square", "enabled", false))
	settings["device_id"] = str(_config.get_value("square", "device_id", ""))
	settings["club_code"] = str(_config.get_value("square", "club_code", DEFAULT_CLUB_CODE))
	settings["handedness"] = int(_config.get_value("square", "handedness", 0))


func _save_settings() -> void:
	_config.set_value("square", "enabled", bool(settings.get("enabled", false)))
	_config.set_value("square", "device_id", str(settings.get("device_id", "")))
	_config.set_value("square", "club_code", str(settings.get("club_code", DEFAULT_CLUB_CODE)))
	_config.set_value("square", "handedness", int(settings.get("handedness", 0)))
	var err := _config.save(SETTINGS_PATH)
	if err != OK:
		_debug_error("Failed to save Square settings file at %s" % SETTINGS_PATH)
		emit_signal("error_occurred", "Square settings could not be saved.")


func _on_square_device_discovered(device_id: String, name: String, rssi: int) -> void:
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
	_set_status(value)


func _on_square_error_occurred(message: String) -> void:
	if _is_transient_square_connect_error(message):
		_debug_log("Square runtime warning: %s" % message)
	else:
		_debug_error("Square runtime error: %s" % message)
	emit_signal("error_occurred", message)


func _on_square_battery_changed(level: int) -> void:
	_debug_log("battery changed: %d%%" % level)
	battery_level = level
	emit_signal("battery_changed", level)


func _on_square_firmware_changed(value: String) -> void:
	_debug_log("firmware changed: %s" % value)
	firmware = value
	emit_signal("firmware_changed", value)


func _on_square_ready_changed(value: bool) -> void:
	_debug_log("ready changed: %s" % str(value))
	is_ready = value
	emit_signal("ready_changed", value)


func _on_square_shot_received(data: Dictionary) -> void:
	_debug_log("shot received with %d fields" % data.size())
	emit_signal("hit_ball", data)


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


func _debug_log(message: String) -> void:
	print("%s %s" % [SQUARE_LOG_PREFIX, message])


func _debug_error(message: String) -> void:
	push_error("%s %s" % [SQUARE_LOG_PREFIX, message])


func _is_transient_square_connect_error(message: String) -> bool:
	var normalized := message.strip_edges().to_lower()
	for marker in TRANSIENT_CONNECT_ERROR_MARKERS:
		if normalized.contains(marker):
			return true
	return false


func _is_square_device_name(name: String) -> bool:
	return name.strip_edges().to_lower().begins_with(SQUARE_DEVICE_PREFIX)
