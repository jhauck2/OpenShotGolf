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
	if bool(settings.get("enabled", false)) and str(settings.get("device_id", "")) != "":
		connect_to_device(str(settings["device_id"]))


func start_scan() -> void:
	if _square == null:
		var message := _missing_support_message()
		_debug_error("start_scan blocked: %s" % message)
		_set_status(message)
		emit_signal("error_occurred", message)
		return
	_debug_log("start_scan requested")
	devices.clear()
	_square.call("StartScan")


func stop_scan() -> void:
	if _square != null:
		_debug_log("stop_scan requested")
		_square.call("StopScan")


func connect_to_device(device_id: String) -> void:
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
	if _square != null:
		_debug_log("disconnect_device requested")
		_square.call("DisconnectFromDevice")


func set_enabled(value: bool) -> void:
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


func _on_square_status_changed(value: String) -> void:
	_set_status(value)


func _on_square_error_occurred(message: String) -> void:
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


func _set_status(value: String) -> void:
	status = value
	emit_signal("status_changed", value)
	_debug_log("status -> %s" % value)


func _debug_log(message: String) -> void:
	print("%s %s" % [SQUARE_LOG_PREFIX, message])


func _debug_error(message: String) -> void:
	push_error("%s %s" % [SQUARE_LOG_PREFIX, message])


func _is_square_device_name(name: String) -> bool:
	return name.strip_edges().to_lower().begins_with(SQUARE_DEVICE_PREFIX)
