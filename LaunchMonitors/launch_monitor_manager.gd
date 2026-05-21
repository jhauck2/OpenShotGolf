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

var devices: Dictionary = {}
var status := "Disconnected"
var battery_level := -1
var firmware := ""
var is_ready := false
var settings := {
	"enabled": false,
	"device_id": "",
	"club_code": DEFAULT_CLUB_CODE,
	"handedness": 0
}

var _square: Node = null
var _config := ConfigFile.new()


func _ready() -> void:
	_load_settings()
	_create_square_monitor()
	if bool(settings.get("enabled", false)) and str(settings.get("device_id", "")) != "":
		connect_to_device(str(settings["device_id"]))


func start_scan() -> void:
	if _square == null:
		emit_signal("error_occurred", "Square support is unavailable in this build.")
		return
	devices.clear()
	_square.call("StartScan")


func stop_scan() -> void:
	if _square != null:
		_square.call("StopScan")


func connect_to_device(device_id: String) -> void:
	if _square == null:
		emit_signal("error_occurred", "Square support is unavailable in this build.")
		return
	settings["device_id"] = device_id
	_save_settings()
	_square.call("SetHandedness", int(settings.get("handedness", 0)))
	_square.call("SetClub", str(settings.get("club_code", DEFAULT_CLUB_CODE)))
	_square.call("ConnectToDevice", device_id)


func disconnect_device() -> void:
	if _square != null:
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
		_square.call("SetReady")


func _create_square_monitor() -> void:
	if not ClassDB.class_exists("SquareLaunchMonitor"):
		emit_signal("error_occurred", "SquareLaunchMonitor was not found.")
		return

	_square = ClassDB.instantiate("SquareLaunchMonitor") as Node
	if _square == null:
		emit_signal("error_occurred", "SquareLaunchMonitor could not be created.")
		return

	add_child(_square)
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
		emit_signal("error_occurred", "Square settings could not be saved.")


func _on_square_device_discovered(device_id: String, name: String, rssi: int) -> void:
	devices[device_id] = {
		"name": name,
		"rssi": rssi
	}
	emit_signal("device_discovered", device_id, name, rssi)


func _on_square_status_changed(value: String) -> void:
	status = value
	emit_signal("status_changed", value)


func _on_square_error_occurred(message: String) -> void:
	emit_signal("error_occurred", message)


func _on_square_battery_changed(level: int) -> void:
	battery_level = level
	emit_signal("battery_changed", level)


func _on_square_firmware_changed(value: String) -> void:
	firmware = value
	emit_signal("firmware_changed", value)


func _on_square_ready_changed(value: bool) -> void:
	is_ready = value
	emit_signal("ready_changed", value)


func _on_square_shot_received(data: Dictionary) -> void:
	emit_signal("hit_ball", data)

