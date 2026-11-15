extends Node

const RainPhysics = preload("res://Utils/rain_physics.gd")

# Monitor implementations live in sibling folders (e.g. `square/`); shared transports and external receivers live under `common/`.

signal hit_ball(data: Dictionary)
signal device_discovered(device_id: String, name: String, rssi: int)
signal status_changed(status: String)
signal error_occurred(message: String)
signal battery_changed(level: int)
signal firmware_changed(firmware: String)
signal ready_changed(is_ready: bool)
signal club_code_changed(club_code: String)
signal sensor_data_updated(pos_x: int, pos_y: int, pos_z: int, is_ready: bool, is_detected: bool)

const SETTINGS_PATH := "user://square_launch_monitor.cfg"
const DEFAULT_CLUB_CODE := "0204"
const SQUARE_CLASS_NAME := "SquareLaunchMonitor"
const SQUARE_SCRIPT_PATH := "res://addons/launch_monitors/square/SquareLaunchMonitor.cs"
const SQUARE_LOG_PREFIX := "[SquareLM]"
const SQUARE_DEVICE_PREFIX := "squaregolf"
const GARMIN_CLASS_NAME := "GarminLaunchMonitor"
const GARMIN_SCRIPT_PATH := "res://addons/launch_monitors/garmin/GarminLaunchMonitor.cs"
const GARMIN_LOG_PREFIX := "[GarminLM]"
const RAINMAKER_CLASS_NAME := "RainmakerLaunchMonitor"
const RAINMAKER_SCRIPT_PATH := "res://addons/launch_monitors/rainmaker/RainmakerLaunchMonitor.cs"
const RAINMAKER_LOG_PREFIX := "[RainmakerLM]"
const FSX_CSV_CLASS_NAME := "FsxCsvMonitor"
const FSX_CSV_SCRIPT_PATH := "res://addons/launch_monitors/fsx/fsx_csv_monitor.gd"
const FSX_CSV_LOG_PREFIX := "[BushnellFSX]"
const BLUEZ_DEVICE_SEGMENT_PREFIX := "/dev_"
const LINUX_AUTO_CONNECT_SCAN_SECONDS := 15.0
const TRANSIENT_CONNECT_ERROR_MARKERS := [
	"not ready yet",
	"could not open the selected bluetooth device",
	"unreachable"
]

var devices: Dictionary = {}
var status := "Disconnected"
var battery_level := -1
var _session_warned_battery_25 := false
var _session_warned_battery_10 := false
var _battery_warning_modal: Node = null
var firmware := ""
var is_ready := false
var last_sensor_data := {"pos_x": 0, "pos_y": 0, "pos_z": 0, "ready": false, "detected": false}
var _square_init_error := ""
var _garmin_init_error := ""
var _rainmaker_init_error := ""
var _fsx_csv_init_error := ""
var _active_driver := "" # "square", "garmin", "rainmaker", or "bushnell_fsx"
var settings := {
	"enabled": false,
	"remember_device": false,
	"device_id": "",
	"device_name": "",
	"device_type": "auto", # "auto", "square", "garmin", "rainmaker", "bushnell_fsx"
	"pairing_code": "",
	"club_code": DEFAULT_CLUB_CODE,
	"handedness": 0,
	"ready_ding_enabled": true,
	"ready_indicator_enabled": true,
	"ball_placement_guide_enabled": true,
	"fsx_csv_path": "",
	"fsx_poll_interval": 0.25
}

var _square: Node = null
var _garmin: Node = null
var _rainmaker: Node = null
var _fsx_csv: Node = null
var _config := ConfigFile.new()
var _linux_auto_connect_active := false
var _linux_auto_connect_target_address := ""
var _linux_auto_connect_timer: Timer = null
var _auto_reconnect_timer: Timer = null
const MAX_AUTO_RECONNECT_ATTEMPTS := 5
var _auto_reconnect_attempts := 0
var _current_club_name := ""
var _ready_audio_player: AudioStreamPlayer = null
var _ready_hud: CanvasLayer = null
var _is_manual_connect := false
var _is_auto_connecting_default := false
var _fallback_scan_active := false
var _fallback_scan_timer: Timer = null
const FALLBACK_SCAN_TIMEOUT_SECONDS := 12.0
var _default_connect_timer: Timer = null
const DEFAULT_CONNECT_TIMEOUT_SECONDS := 12.0



func _ready() -> void:
	_debug_log("Launch monitor ready. OS=%s, C# runtime class exists=%s, assembly=%s" % [
		OS.get_name(),
		str(ClassDB.class_exists("CSharpScript")),
		str(ProjectSettings.get_setting("dotnet/project/assembly_name", ""))
	])
	_load_settings()
	_setup_audio_player()
	_setup_ready_hud()
	_create_square_monitor()
	_create_garmin_monitor()
	_create_rainmaker_monitor()
	_create_fsx_csv_monitor()
	if _square == null and _garmin == null and _rainmaker == null and _fsx_csv == null:
		_debug_error("No launch monitors could be loaded: Square='%s', Garmin='%s', Rainmaker='%s', FSX='%s'" % [_square_init_error, _garmin_init_error, _rainmaker_init_error, _fsx_csv_init_error])
	var should_auto_connect := bool(settings.get("remember_device", false)) and bool(settings.get("enabled", true)) and str(settings.get("device_id", "")).strip_edges() != ""
	if DisplayServer.get_name() != "headless" and should_auto_connect:
		call_deferred("_connect_saved_device_on_startup", str(settings.get("device_id", "")))
	
	if EventBus.has_signal("club_selected"):
		EventBus.club_selected.connect(_on_club_selected)
	battery_changed.connect(_check_battery_warning)
	_connect_multiplayer_signals()
	call_deferred("_connect_multiplayer_signals")


func _setup_audio_player() -> void:
	_ready_audio_player = AudioStreamPlayer.new()
	_ready_audio_player.name = "ReadyDingPlayer"
	_ready_audio_player.bus = "Master"
	add_child(_ready_audio_player)
	
	var ding_path := "res://assets/audio/sfx/ready_ding.wav"
	if ResourceLoader.exists(ding_path):
		var stream = load(ding_path) as AudioStream
		if stream != null:
			_ready_audio_player.stream = stream
			return
	_ready_audio_player.stream = _generate_fallback_ding_stream()


func _generate_fallback_ding_stream() -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.stereo = false
	var sample_rate := 44100.0
	var duration := 0.22
	var num_samples := int(sample_rate * duration)
	var byte_array := PackedByteArray()
	byte_array.resize(num_samples * 2)

	var attack_samples := float(sample_rate * 0.006)
	var fadeout_samples := float(sample_rate * 0.010)

	var p0_f := 1046.50; var p0_w := 0.65; var p0_d := 18.0
	var p1_f := 1567.98; var p1_w := 0.25; var p1_d := 28.0
	var p2_f := 2637.02; var p2_w := 0.08; var p2_d := 55.0
	var p3_f := 523.25;  var p3_w := 0.15; var p3_d := 22.0

	for i in range(num_samples):
		var t := float(i) / sample_rate
		var env_attack: float = (float(i) / attack_samples) ** 2 if i < attack_samples else 1.0
		var env_fade: float = float(num_samples - 1 - i) / fadeout_samples if i >= (num_samples - int(fadeout_samples)) else 1.0

		var val := (sin(2.0 * PI * p0_f * t) * p0_w * exp(-p0_d * t) + \
				sin(2.0 * PI * p1_f * t) * p1_w * exp(-p1_d * t) + \
				sin(2.0 * PI * p2_f * t) * p2_w * exp(-p2_d * t) + \
				sin(2.0 * PI * p3_f * t) * p3_w * exp(-p3_d * t)) * env_attack * env_fade * 0.42
		val = clampf(val, -1.0, 1.0)
		var sample := int(val * 32767.0)
		byte_array.encode_s16(i * 2, sample)
	wav.data = byte_array
	return wav


func _setup_ready_hud() -> void:
	var hud_script_path := "res://UI/ReadyIndicator/ready_indicator_hud.gd"
	var script := load(hud_script_path) as Script
	if script != null and script.can_instantiate():
		_ready_hud = script.new() as CanvasLayer
		if _ready_hud != null:
			add_child(_ready_hud)
			_update_hud_display()


func play_ready_ding() -> void:
	if not bool(settings.get("ready_ding_enabled", true)):
		return
	if _ready_audio_player != null and _ready_audio_player.stream != null:
		_ready_audio_player.play()


func set_ready_ding_enabled(enabled: bool) -> void:
	settings["ready_ding_enabled"] = enabled
	_save_settings()


func set_ready_indicator_enabled(enabled: bool) -> void:
	settings["ready_indicator_enabled"] = enabled
	_save_settings()
	_update_hud_display()


func set_device_type(type_name: String) -> void:
	settings["device_type"] = type_name
	_save_settings()


func is_garmin_device_name(name: String) -> bool:
	var n := name.strip_edges().to_lower()
	if n == "":
		return false
	return n.contains("approach") or n.contains("r10") or n.contains("garmin")


func is_square_device_name(name: String) -> bool:
	var n := name.strip_edges().to_lower()
	if n == "":
		return false
	var stripped := n.replace(" ", "").replace("-", "").replace("_", "")
	return (
		stripped.begins_with(SQUARE_DEVICE_PREFIX) or
		stripped.contains("square") or
		stripped.begins_with("sgo") or
		stripped.begins_with("exgolf") or
		stripped.begins_with("exg") or
		stripped.begins_with("sq") or
		stripped.begins_with("omni")
	)


func is_rainmaker_device_name(name: String) -> bool:
	var n := name.strip_edges().to_lower()
	if n == "":
		return false
	return n.contains("rainmaker") or n.contains("blue tees") or n.contains("bluetees")


func is_auto_connecting() -> bool:
	return _is_auto_connecting_default or _fallback_scan_active


func detect_device_type(device_id: String, device_name: String = "") -> String:
	if device_id == "bushnell_fsx_csv" or device_id == "bushnell_fsx" or device_id.to_lower().contains("fsx"):
		return "bushnell_fsx"
	if device_name.to_lower().contains("bushnell") or device_name.to_lower().contains("fsx"):
		return "bushnell_fsx"
	if devices.has(device_id):
		var dev: Dictionary = devices[device_id]
		var dev_type := str(dev.get("type", ""))
		if dev_type == "garmin" or dev_type == "square" or dev_type == "rainmaker" or dev_type == "bushnell_fsx":
			return dev_type
		var dname := str(dev.get("name", ""))
		if is_rainmaker_device_name(dname):
			return "rainmaker"
		if is_square_device_name(dname):
			return "square"
		if is_garmin_device_name(dname):
			return "garmin"
	if device_name != "":
		if is_rainmaker_device_name(device_name):
			return "rainmaker"
		if is_square_device_name(device_name):
			return "square"
		if is_garmin_device_name(device_name):
			return "garmin"
	var explicit_type := str(settings.get("device_type", "auto"))
	if explicit_type == "square" or explicit_type == "garmin" or explicit_type == "rainmaker" or explicit_type == "bushnell_fsx":
		return explicit_type
	return "square"


func start_scan() -> void:
	_cancel_linux_auto_connect_scan()
	devices.clear()
	var dev_type := str(settings.get("device_type", "auto"))
	_set_status("Scanning")
	if dev_type == "garmin":
		_start_garmin_scan()
	elif dev_type == "square":
		_start_square_scan()
	elif dev_type == "rainmaker":
		_start_rainmaker_scan()
	else:
		_start_square_scan()
		if OS.get_name() == "Android" or OS.get_name() == "macOS" or OS.get_name() == "iOS":
			get_tree().create_timer(0.2).timeout.connect(_start_garmin_scan)
		else:
			_start_garmin_scan()


func stop_scan() -> void:
	_cancel_default_connect_timer()
	_cancel_linux_auto_connect_scan()
	_stop_square_scan()
	_stop_garmin_scan()
	_stop_rainmaker_scan()
	if status == "Scanning":
		_set_status("Disconnected")


func connect_to_device(device_id: String, is_auto: bool = false, pairing_code: String = "") -> void:
	_is_manual_connect = not is_auto
	if _is_manual_connect:
		_auto_reconnect_attempts = 0
		_is_auto_connecting_default = false
	_cancel_default_connect_timer()
	_stop_fallback_scan()
	_cancel_linux_auto_connect_scan()
	_debug_log("connect_to_device requested for %s (auto=%s, codeProvided=%s)" % [device_id, str(is_auto), str(pairing_code != "")])
	settings["device_id"] = device_id
	if pairing_code != "":
		settings["pairing_code"] = pairing_code
	var device_name := ""
	var detected_type := ""
	if devices.has(device_id):
		device_name = str(devices[device_id].get("name", ""))
		detected_type = str(devices[device_id].get("type", ""))
	
	if detected_type == "":
		detected_type = detect_device_type(device_id, device_name)

	if device_name != "":
		if detected_type == "square" and is_garmin_device_name(device_name):
			device_name = "Square Golf"
		elif detected_type == "garmin" and is_square_device_name(device_name):
			device_name = "Garmin Approach R10"
		elif detected_type == "rainmaker":
			device_name = "Blue Tees Rainmaker"
		settings["device_name"] = device_name
	elif str(settings.get("device_name", "")) != "":
		var prev_name := str(settings.get("device_name", ""))
		if detected_type == "square" and is_garmin_device_name(prev_name):
			device_name = "Square Golf"
		elif detected_type == "garmin" and is_square_device_name(prev_name):
			device_name = "Garmin Approach R10"
		elif detected_type == "rainmaker":
			device_name = "Blue Tees Rainmaker"
		else:
			device_name = prev_name
		settings["device_name"] = device_name
	else:
		if detected_type == "garmin":
			device_name = "Garmin Approach R10"
		elif detected_type == "rainmaker":
			device_name = "Blue Tees Rainmaker"
		else:
			device_name = "Square Golf"
		settings["device_name"] = device_name

	_active_driver = detected_type
	stop_scan()

	if detected_type == "bushnell_fsx":
		if _square != null:
			_square.call("DisconnectFromDevice")
		if _garmin != null:
			_garmin.call("DisconnectFromDevice")
		if _rainmaker != null:
			_rainmaker.call("DisconnectFromDevice")
		settings["device_type"] = "bushnell_fsx"
		settings["device_id"] = "bushnell_fsx_csv"
		settings["device_name"] = "Bushnell GC3 (FSX)"
		_save_settings()
		start_fsx_csv_monitoring(str(settings.get("fsx_csv_path", "")))
		return
	elif detected_type == "rainmaker":
		if _square != null:
			_square.call("DisconnectFromDevice")
		if _garmin != null:
			_garmin.call("DisconnectFromDevice")
		settings["device_type"] = "rainmaker"
		_save_settings()
		if not devices.has(device_id):
			devices[device_id] = { "name": device_name, "rssi": 0, "type": "rainmaker" }
		if _rainmaker == null:
			var msg := "Rainmaker support is unavailable in this build."
			_set_status(msg)
			if _is_manual_connect:
				emit_signal("error_occurred", msg)
			return
		var code_to_use := pairing_code if pairing_code != "" else str(settings.get("pairing_code", ""))
		_rainmaker.call("ConnectToDevice", device_id, code_to_use)
	elif detected_type == "garmin":
		if _square != null:
			_square.call("DisconnectFromDevice")
		if _rainmaker != null:
			_rainmaker.call("DisconnectFromDevice")
		if device_name == "":
			device_name = "Garmin Approach R10"
			settings["device_name"] = device_name
		if str(settings.get("device_type", "auto")) != "auto":
			settings["device_type"] = "garmin"
		_save_settings()
		if not devices.has(device_id):
			devices[device_id] = { "name": device_name, "rssi": 0, "type": "garmin" }
		if _garmin == null:
			var msg := "Garmin support is unavailable in this build."
			_set_status(msg)
			if _is_manual_connect:
				emit_signal("error_occurred", msg)
			return
		_update_garmin_weather_config()
		_garmin.call("ConnectToDevice", device_id)
	else:
		if _garmin != null:
			_garmin.call("DisconnectFromDevice")
		if _rainmaker != null:
			_rainmaker.call("DisconnectFromDevice")
		if device_name == "":
			device_name = "Square Golf"
			settings["device_name"] = device_name
		if str(settings.get("device_type", "auto")) != "auto":
			settings["device_type"] = "square"
		_save_settings()
		if not devices.has(device_id):
			devices[device_id] = { "name": device_name, "rssi": 0, "type": "square" }
		if _square == null:
			var msg := _missing_support_message()
			_set_status(msg)
			if _is_manual_connect:
				emit_signal("error_occurred", msg)
			return
		var cur_hand := int(settings.get("handedness", 0))
		var mp = _get_multiplayer_manager()
		if mp != null and mp.has_method("get_active_player"):
			var ap = mp.get_active_player()
			if not ap.is_empty():
				cur_hand = int(ap.get("handedness", cur_hand))
		settings["handedness"] = cur_hand
		_square.call("SetHandedness", cur_hand)
		_square.call("SetClub", str(settings.get("club_code", DEFAULT_CLUB_CODE)))
		_square.call("ConnectToDevice", device_id)


func disconnect_device() -> void:
	_cancel_default_connect_timer()
	_cancel_linux_auto_connect_scan()
	_cancel_auto_reconnect()
	_stop_fallback_scan()
	_is_auto_connecting_default = false
	_auto_reconnect_attempts = 0
	settings["enabled"] = false
	_save_settings()
	_debug_log("disconnect_device requested")
	if _square != null:
		_square.call("DisconnectFromDevice")
	if _garmin != null:
		_garmin.call("DisconnectFromDevice")
	if _rainmaker != null:
		_rainmaker.call("DisconnectFromDevice")
	if _fsx_csv != null:
		_fsx_csv.call("stop_monitoring")
	_active_driver = ""


func _start_rainmaker_scan() -> void:
	if _rainmaker != null:
		_debug_log("Rainmaker start_scan requested")
		_rainmaker.call("StartScan")


func _stop_rainmaker_scan() -> void:
	if _rainmaker != null:
		_debug_log("Rainmaker stop_scan requested")
		_rainmaker.call("StopScan")


func _start_square_scan() -> void:
	if _square != null:
		_debug_log("Square start_scan requested")
		_square.call("StartScan")


func _stop_square_scan() -> void:
	if _square != null:
		_debug_log("Square stop_scan requested")
		_square.call("StopScan")


func _start_garmin_scan() -> void:
	if _garmin != null:
		_debug_log("Garmin start_scan requested")
		_garmin.call("StartScan")


func _stop_garmin_scan() -> void:
	if _garmin != null:
		_debug_log("Garmin stop_scan requested")
		_garmin.call("StopScan")


func set_enabled(value: bool) -> void:
	if not value:
		_cancel_linux_auto_connect_scan()
	settings["enabled"] = value
	_save_settings()


func set_remember_device(value: bool) -> void:
	settings["remember_device"] = value
	_save_settings()


func is_remember_device_enabled() -> bool:
	return bool(settings.get("remember_device", false))


func set_club_code(club_code: String) -> void:
	settings["club_code"] = club_code
	_save_settings()
	if _square != null:
		_square.call("SetClub", club_code)
	emit_signal("club_code_changed", club_code)


func set_handedness(handedness: int) -> void:
	settings["handedness"] = handedness
	_save_settings()
	if _square != null:
		_square.call("SetHandedness", handedness)


func get_handedness() -> int:
	return int(settings.get("handedness", 0))


func _get_multiplayer_manager() -> Node:
	if is_inside_tree() and has_node("/root/MultiplayerManager"):
		return get_node("/root/MultiplayerManager")
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree and main_loop.root != null and main_loop.root.has_node("MultiplayerManager"):
		return main_loop.root.get_node("MultiplayerManager")
	return null


func _connect_multiplayer_signals() -> void:
	var mp = _get_multiplayer_manager()
	if mp != null and mp.has_signal("active_player_changed") and not mp.active_player_changed.is_connected(_on_active_player_changed):
		mp.active_player_changed.connect(_on_active_player_changed)
		var cur_p = mp.get_active_player() if mp.has_method("get_active_player") else {}
		if not cur_p.is_empty():
			_on_active_player_changed(cur_p)


func _on_active_player_changed(player: Dictionary) -> void:
	if player.is_empty():
		return
	var hand: int = 0
	if player.has("handedness"):
		hand = int(player.get("handedness", 0))
	else:
		var mp = _get_multiplayer_manager()
		var p_name = str(player.get("name", ""))
		if not p_name.is_empty() and mp != null and mp.has_method("get_player_handedness"):
			hand = mp.get_player_handedness(p_name)
	set_handedness(hand)


var _pending_ready_ding := false


func is_ball_in_flight() -> bool:
	if _ready_hud != null and _ready_hud.has_method("is_ball_in_flight"):
		return bool(_ready_hud.call("is_ball_in_flight"))
	return false


func notify_shot_started() -> void:
	is_ready = false
	_pending_ready_ding = false
	if _ready_hud != null and _ready_hud.has_method("notify_shot_started"):
		_ready_hud.call("notify_shot_started")


func notify_ball_at_rest() -> void:
	if _ready_hud != null and _ready_hud.has_method("notify_ball_at_rest"):
		_ready_hud.call("notify_ball_at_rest")
	if is_ready and _pending_ready_ding:
		_pending_ready_ding = false
		play_ready_ding()
	_update_hud_display()


func set_ready() -> void:
	_debug_log("set_ready requested")
	if _active_driver == "garmin" and _garmin != null:
		_garmin.call("SetReady")
	elif _active_driver == "square" and _square != null:
		_square.call("SetReady")
	else:
		if _garmin != null:
			_garmin.call("SetReady")
		if _square != null:
			_square.call("SetReady")


func rearm() -> void:
	_debug_log("rearm requested")
	if _active_driver == "garmin" and _garmin != null:
		_garmin.call("SetReady")
	elif _active_driver == "square" and _square != null:
		_square.call("SetReady")
	else:
		if _garmin != null:
			_garmin.call("SetReady")
		if _square != null:
			_square.call("SetReady")


func calibrate_garmin_tilt() -> void:
	_debug_log("calibrate_garmin_tilt requested")
	if _garmin != null:
		_garmin.call("CalibrateTilt")


func _update_garmin_weather_config() -> void:
	if _garmin == null:
		return
	var temp := 72.0
	var alt := 0.0
	var tee := 7.0
	if has_node("/root/GlobalSettings"):
		var gs = get_node("/root/GlobalSettings")
		if gs.get("range_settings") != null:
			if "temperature" in gs.range_settings:
				temp = float(gs.range_settings.temperature.value)
			if "altitude" in gs.range_settings:
				alt = float(gs.range_settings.altitude.value)
	_debug_log("Sending shot config to Garmin R10: Temp=%.1f F, Alt=%.1f ft, Tee=%.1f ft" % [temp, alt, tee])
	_garmin.call("SetShotConfig", temp, alt, tee)


func _create_square_monitor() -> void:
	_square_init_error = ""
	_debug_log("Attempting to load script %s" % SQUARE_SCRIPT_PATH)
	var square_script := load(SQUARE_SCRIPT_PATH) as Script
	if square_script == null:
		_square_init_error = "Square script could not be loaded at %s." % SQUARE_SCRIPT_PATH
		_debug_error(_square_init_error)
		return

	if not square_script.can_instantiate():
		_square_init_error = "%s script is loaded but cannot instantiate." % SQUARE_CLASS_NAME
		_debug_error(_square_init_error)
		return

	_square = square_script.new() as Node
	if _square == null:
		_square_init_error = "%s could not be created from %s." % [SQUARE_CLASS_NAME, SQUARE_SCRIPT_PATH]
		_debug_error(_square_init_error)
		return

	add_child(_square)
	_debug_log("%s instantiated and signals connected." % SQUARE_CLASS_NAME)
	_square.connect("DeviceDiscovered", _on_square_device_discovered)
	_square.connect("StatusChanged", _on_square_status_changed)
	_square.connect("ErrorOccurred", _on_square_error_occurred)
	_square.connect("BatteryChanged", _on_square_battery_changed)
	_square.connect("FirmwareChanged", _on_square_firmware_changed)
	_square.connect("ReadyChanged", _on_square_ready_changed)
	if _square.has_signal("SensorDataReceived"):
		_square.connect("SensorDataReceived", _on_square_sensor_data_received)
	_square.connect("ShotReceived", _on_square_shot_received)


func _create_garmin_monitor() -> void:
	_garmin_init_error = ""
	_debug_log("Attempting to load script %s" % GARMIN_SCRIPT_PATH)
	var garmin_script := load(GARMIN_SCRIPT_PATH) as Script
	if garmin_script == null:
		_garmin_init_error = "Garmin script could not be loaded at %s." % GARMIN_SCRIPT_PATH
		_debug_error(_garmin_init_error)
		return

	if not garmin_script.can_instantiate():
		_garmin_init_error = "%s script is loaded but cannot instantiate." % GARMIN_CLASS_NAME
		_debug_error(_garmin_init_error)
		return

	_garmin = garmin_script.new() as Node
	if _garmin == null:
		_garmin_init_error = "%s could not be created from %s." % [GARMIN_CLASS_NAME, GARMIN_SCRIPT_PATH]
		_debug_error(_garmin_init_error)
		return

	add_child(_garmin)
	_debug_log("%s instantiated and signals connected." % GARMIN_CLASS_NAME)
	_garmin.connect("DeviceDiscovered", _on_garmin_device_discovered)
	_garmin.connect("StatusChanged", _on_garmin_status_changed)
	_garmin.connect("ErrorOccurred", _on_garmin_error_occurred)
	_garmin.connect("BatteryChanged", _on_garmin_battery_changed)
	_garmin.connect("FirmwareChanged", _on_garmin_firmware_changed)
	_garmin.connect("ReadyChanged", _on_garmin_ready_changed)
	_garmin.connect("ShotReceived", _on_garmin_shot_received)


func _create_rainmaker_monitor() -> void:
	_rainmaker_init_error = ""
	_debug_log("Attempting to load script %s" % RAINMAKER_SCRIPT_PATH)
	var rainmaker_script := load(RAINMAKER_SCRIPT_PATH) as Script
	if rainmaker_script == null:
		_rainmaker_init_error = "Rainmaker script could not be loaded at %s." % RAINMAKER_SCRIPT_PATH
		_debug_error(_rainmaker_init_error)
		return

	if not rainmaker_script.can_instantiate():
		_rainmaker_init_error = "%s script is loaded but cannot instantiate." % RAINMAKER_CLASS_NAME
		_debug_error(_rainmaker_init_error)
		return

	_rainmaker = rainmaker_script.new() as Node
	if _rainmaker == null:
		_rainmaker_init_error = "%s could not be created from %s." % [RAINMAKER_CLASS_NAME, RAINMAKER_SCRIPT_PATH]
		_debug_error(_rainmaker_init_error)
		return

	add_child(_rainmaker)
	_debug_log("%s instantiated and signals connected." % RAINMAKER_CLASS_NAME)
	_rainmaker.connect("DeviceDiscovered", _on_rainmaker_device_discovered)
	_rainmaker.connect("StatusChanged", _on_rainmaker_status_changed)
	_rainmaker.connect("ErrorOccurred", _on_rainmaker_error_occurred)
	_rainmaker.connect("BatteryChanged", _on_rainmaker_battery_changed)
	_rainmaker.connect("FirmwareChanged", _on_rainmaker_firmware_changed)
	_rainmaker.connect("ReadyChanged", _on_rainmaker_ready_changed)
	_rainmaker.connect("ShotReceived", _on_rainmaker_shot_received)


func _create_fsx_csv_monitor() -> void:
	_fsx_csv_init_error = ""
	_debug_log("Attempting to load script %s" % FSX_CSV_SCRIPT_PATH)
	var fsx_script := load(FSX_CSV_SCRIPT_PATH) as Script
	if fsx_script == null:
		_fsx_csv_init_error = "FSX CSV script could not be loaded at %s." % FSX_CSV_SCRIPT_PATH
		_debug_error(_fsx_csv_init_error)
		return

	if not fsx_script.can_instantiate():
		_fsx_csv_init_error = "%s script is loaded but cannot instantiate." % FSX_CSV_CLASS_NAME
		_debug_error(_fsx_csv_init_error)
		return

	_fsx_csv = fsx_script.new() as Node
	if _fsx_csv == null:
		_fsx_csv_init_error = "%s could not be created from %s." % [FSX_CSV_CLASS_NAME, FSX_CSV_SCRIPT_PATH]
		_debug_error(_fsx_csv_init_error)
		return

	add_child(_fsx_csv)
	_debug_log("%s instantiated and signals connected." % FSX_CSV_CLASS_NAME)
	_fsx_csv.connect("shot_received", _on_fsx_shot_received)
	_fsx_csv.connect("status_changed", _on_fsx_status_changed)
	_fsx_csv.connect("error_occurred", _on_fsx_error_occurred)

	var saved_path := str(settings.get("fsx_csv_path", ""))
	if saved_path != "" and "csv_path" in _fsx_csv:
		_fsx_csv.set("csv_path", saved_path)


func start_fsx_csv_monitoring(path: String = "") -> void:
	_stop_square_scan()
	_stop_garmin_scan()
	_stop_rainmaker_scan()
	if _square != null:
		_square.call("DisconnectFromDevice")
	if _garmin != null:
		_garmin.call("DisconnectFromDevice")
	if _rainmaker != null:
		_rainmaker.call("DisconnectFromDevice")

	_active_driver = "bushnell_fsx"
	settings["device_type"] = "bushnell_fsx"
	settings["device_id"] = "bushnell_fsx_csv"
	settings["device_name"] = "Bushnell GC3 (FSX)"
	if path != "":
		settings["fsx_csv_path"] = path
	_save_settings()

	if _fsx_csv != null:
		var target_path = path if path != "" else str(settings.get("fsx_csv_path", ""))
		_fsx_csv.call("start_monitoring", target_path)
		var s = str(_fsx_csv.get("status"))
		_set_status(s)
		is_ready = true
		emit_signal("ready_changed", true)
		_update_hud_display()


func stop_fsx_csv_monitoring() -> void:
	if _fsx_csv != null:
		_fsx_csv.call("stop_monitoring")
	if _active_driver == "bushnell_fsx":
		_set_status("Disconnected")
		is_ready = false
		emit_signal("ready_changed", false)
		_update_hud_display()


func get_fsx_csv_monitor() -> Node:
	return _fsx_csv


func _on_fsx_shot_received(data: Dictionary) -> void:
	if _active_driver != "bushnell_fsx":
		return
	if not _is_valid_shot_data(data):
		_debug_log("Bushnell/FSX practice swing or stationary ball ignored")
		return
	if status == "Connecting" or status.begins_with("Found") or status == "Disconnected" or status.begins_with("Waiting"):
		_set_status("Connected")
	_debug_log("Bushnell/FSX shot received with %d fields" % data.size())
	RainPhysics.apply_rain_shot_reduction(data)
	FoamBallBoost.apply_boost(data, _current_club_name)
	notify_shot_started()
	emit_signal("hit_ball", data)
	_update_hud_display()
	play_ready_ding()


func _on_fsx_status_changed(value: String) -> void:
	if _active_driver != "bushnell_fsx":
		return
	_set_status(value)
	var became_ready = value == "Connected" or value.begins_with("Monitoring") or value.begins_with("Waiting")
	if is_ready != became_ready:
		is_ready = became_ready
		emit_signal("ready_changed", is_ready)
		_update_hud_display()


func _on_fsx_error_occurred(message: String) -> void:
	if _active_driver != "bushnell_fsx":
		return
	_debug_error("FSX CSV error: %s" % message)
	emit_signal("error_occurred", message)


func set_ball_placement_guide_enabled(enabled: bool) -> void:
	settings["ball_placement_guide_enabled"] = enabled
	_save_settings()
	_update_hud_display()


func _load_settings() -> void:
	var err := _config.load(SETTINGS_PATH)
	if err != OK:
		return
	settings["enabled"] = bool(_config.get_value("square", "enabled", false))
	settings["remember_device"] = bool(_config.get_value("square", "remember_device", false))
	settings["device_id"] = str(_config.get_value("square", "device_id", ""))
	settings["device_name"] = str(_config.get_value("square", "device_name", ""))
	settings["device_type"] = str(_config.get_value("square", "device_type", "auto"))
	settings["pairing_code"] = str(_config.get_value("square", "pairing_code", ""))
	settings["club_code"] = str(_config.get_value("square", "club_code", DEFAULT_CLUB_CODE))
	settings["handedness"] = int(_config.get_value("square", "handedness", 0))
	settings["ready_ding_enabled"] = bool(_config.get_value("square", "ready_ding_enabled", true))
	settings["ready_indicator_enabled"] = bool(_config.get_value("square", "ready_indicator_enabled", true))
	settings["ball_placement_guide_enabled"] = bool(_config.get_value("square", "ball_placement_guide_enabled", true))
	settings["fsx_csv_path"] = str(_config.get_value("square", "fsx_csv_path", ""))
	settings["fsx_poll_interval"] = float(_config.get_value("square", "fsx_poll_interval", 0.25))


func _save_settings() -> void:
	_config.set_value("square", "enabled", bool(settings.get("enabled", false)))
	_config.set_value("square", "remember_device", bool(settings.get("remember_device", false)))
	_config.set_value("square", "device_id", str(settings.get("device_id", "")))
	_config.set_value("square", "device_name", str(settings.get("device_name", "")))
	_config.set_value("square", "device_type", str(settings.get("device_type", "auto")))
	_config.set_value("square", "pairing_code", str(settings.get("pairing_code", "")))
	_config.set_value("square", "club_code", str(settings.get("club_code", DEFAULT_CLUB_CODE)))
	_config.set_value("square", "handedness", int(settings.get("handedness", 0)))
	_config.set_value("square", "ready_ding_enabled", bool(settings.get("ready_ding_enabled", true)))
	_config.set_value("square", "ready_indicator_enabled", bool(settings.get("ready_indicator_enabled", true)))
	_config.set_value("square", "ball_placement_guide_enabled", bool(settings.get("ball_placement_guide_enabled", true)))
	_config.set_value("square", "fsx_csv_path", str(settings.get("fsx_csv_path", "")))
	_config.set_value("square", "fsx_poll_interval", float(settings.get("fsx_poll_interval", 0.25)))
	var err := _config.save(SETTINGS_PATH)
	if err != OK:
		_debug_error("Failed to save launch monitor settings file at %s" % SETTINGS_PATH)
		emit_signal("error_occurred", "Launch monitor settings could not be saved.")


func _on_square_device_discovered(device_id: String, name: String, rssi: int) -> void:
	if not _fallback_scan_active and str(settings.get("device_type", "auto")) == "garmin":
		return
	if not is_square_device_name(name):
		return
	var is_live := (rssi <= -10 and rssi >= -120) or (rssi != 0 and rssi != -1)
	var is_new := not devices.has(device_id)
	var prev_live := bool(devices.get(device_id, {}).get("is_discovered", false)) if not is_new else false
	devices[device_id] = {
		"name": name,
		"rssi": rssi,
		"type": "square",
		"is_discovered": is_live
	}
	if is_new or (is_live and not prev_live):
		_debug_log("Square device discovered: %s (%s) RSSI=%d live=%s" % [name, device_id, rssi, str(is_live)])
		if device_id == str(settings.get("device_id", "")):
			settings["device_name"] = name
			_save_settings()
		emit_signal("device_discovered", device_id, name, rssi)
		if _fallback_scan_active:
			var saved_id := str(settings.get("device_id", ""))
			if device_id == saved_id and not is_live:
				_debug_log("Fallback scan ignoring offline cached default device %s" % device_id)
			elif is_live:
				_debug_log("Fallback auto-discovery found Square device: %s (%s). Auto-connecting..." % [name, device_id])
				_stop_fallback_scan()
				_set_status("Found %s. Connecting..." % name)
				connect_to_device(device_id, true)
				return
		if _is_linux_auto_connect_match(device_id) and is_live:
			_debug_log("saved Linux Square discovered; connecting automatically")
			connect_to_device(device_id, true)


func _on_rainmaker_device_discovered(device_id: String, name: String, rssi: int) -> void:
	var display_name := name.strip_edges()
	var is_live := (rssi <= -10 and rssi >= -120) or (rssi != 0 and rssi != -1)
	var is_new := not devices.has(device_id)
	var prev_live := bool(devices.get(device_id, {}).get("is_discovered", false)) if not is_new else false
	devices[device_id] = {
		"name": display_name,
		"rssi": rssi,
		"type": "rainmaker",
		"is_discovered": is_live
	}
	if is_new or (is_live and not prev_live):
		_debug_log("Rainmaker device discovered: %s (%s) RSSI=%d live=%s" % [display_name, device_id, rssi, str(is_live)])
		if device_id == str(settings.get("device_id", "")):
			settings["device_name"] = display_name
			_save_settings()
		emit_signal("device_discovered", device_id, display_name, rssi)


func _on_garmin_device_discovered(device_id: String, name: String, rssi: int) -> void:
	if not _fallback_scan_active and str(settings.get("device_type", "auto")) == "square":
		return
	if not is_garmin_device_name(name):
		return
	var display_name := name.strip_edges()
	var is_live := (rssi <= -10 and rssi >= -120) or (rssi != 0 and rssi != -1)
	var is_new := not devices.has(device_id)
	var prev_live := bool(devices.get(device_id, {}).get("is_discovered", false)) if not is_new else false
	devices[device_id] = {
		"name": display_name,
		"rssi": rssi,
		"type": "garmin",
		"is_discovered": is_live
	}
	if is_new or (is_live and not prev_live):
		_debug_log("Garmin device discovered: %s (%s) RSSI=%d live=%s" % [display_name, device_id, rssi, str(is_live)])
		if device_id == str(settings.get("device_id", "")):
			settings["device_name"] = display_name
			_save_settings()
		emit_signal("device_discovered", device_id, display_name, rssi)
		if _fallback_scan_active:
			var saved_id := str(settings.get("device_id", ""))
			if device_id == saved_id and not is_live:
				_debug_log("Fallback scan ignoring offline cached default device %s" % device_id)
			elif is_live:
				_debug_log("Fallback auto-discovery found Garmin device: %s (%s). Auto-connecting..." % [display_name, device_id])
				_stop_fallback_scan()
				_set_status("Found %s. Connecting..." % display_name)
				connect_to_device(device_id, true)
				return
		if _is_linux_auto_connect_match(device_id) and is_live:
			_debug_log("saved Linux Garmin discovered; connecting automatically")
			connect_to_device(device_id, true)


func _on_square_status_changed(value: String) -> void:
	if _active_driver != "square" and _active_driver != "":
		return
	_set_status(value)
	if value == "Disconnected":
		_cancel_default_connect_timer()
		if _is_auto_connecting_default:
			_is_auto_connecting_default = false
			_start_fallback_auto_discovery()
		elif bool(settings.get("enabled", false)) and str(settings.get("device_id", "")) != "" and _active_driver == "square" and not _fallback_scan_active:
			_schedule_auto_reconnect()
	elif value == "Connected" or value == "Connecting" or value == "Ready":
		_cancel_auto_reconnect()
		if value == "Connected" or value == "Ready":
			_cancel_default_connect_timer()
			_auto_reconnect_attempts = 0
			_is_auto_connecting_default = false
			_stop_fallback_scan()


func _on_rainmaker_status_changed(value: String) -> void:
	if _active_driver != "rainmaker" and _active_driver != "":
		return
	_set_status(value)


func _on_rainmaker_error_occurred(message: String) -> void:
	if _active_driver != "rainmaker" and _active_driver != "":
		return
	_debug_error("Rainmaker runtime error: %s" % message)
	emit_signal("error_occurred", message)


func _on_rainmaker_battery_changed(level: int) -> void:
	if _active_driver != "rainmaker":
		return
	_debug_log("Rainmaker battery changed: %d%%" % level)
	battery_level = level
	emit_signal("battery_changed", level)


func _on_rainmaker_firmware_changed(value: String) -> void:
	if _active_driver != "rainmaker":
		return
	_debug_log("Rainmaker firmware changed: %s" % value)
	firmware = value
	emit_signal("firmware_changed", value)


func _on_rainmaker_ready_changed(value: bool) -> void:
	if _active_driver != "rainmaker":
		return
	_debug_log("Rainmaker ready changed: %s" % str(value))
	var became_ready := value and not is_ready
	is_ready = value
	if value and (status == "Connecting" or status.begins_with("Found") or status == "Disconnected"):
		_set_status("Connected")
	if became_ready:
		if is_ball_in_flight():
			_pending_ready_ding = true
		else:
			_pending_ready_ding = false
			play_ready_ding()
	elif not value:
		_pending_ready_ding = false
	emit_signal("ready_changed", value)
	_update_hud_display()


func _on_rainmaker_shot_received(data: Dictionary) -> void:
	if _active_driver != "rainmaker":
		return
	if not _is_valid_shot_data(data):
		_debug_log("Rainmaker practice swing or stationary ball ignored")
		return
	if status == "Connecting" or status.begins_with("Found") or status == "Disconnected":
		_set_status("Connected")
	_debug_log("Rainmaker shot received with %d fields" % data.size())
	RainPhysics.apply_rain_shot_reduction(data)
	FoamBallBoost.apply_boost(data, _current_club_name)
	notify_shot_started()
	emit_signal("hit_ball", data)
	_update_hud_display()


func _on_garmin_status_changed(value: String) -> void:
	if _active_driver != "garmin" and _active_driver != "":
		return
	_set_status(value)
	if value == "Disconnected":
		_cancel_default_connect_timer()
		if _is_auto_connecting_default:
			_is_auto_connecting_default = false
			_start_fallback_auto_discovery()
		elif bool(settings.get("enabled", false)) and str(settings.get("device_id", "")) != "" and _active_driver == "garmin" and not _fallback_scan_active:
			_schedule_auto_reconnect()
	elif value == "Connected" or value == "Connecting" or value == "Ready":
		_cancel_auto_reconnect()
		if value == "Connected" or value == "Ready":
			_cancel_default_connect_timer()
			_auto_reconnect_attempts = 0
			_is_auto_connecting_default = false
			_stop_fallback_scan()


func _on_garmin_error_occurred(message: String) -> void:
	if _active_driver != "garmin" and _active_driver != "":
		return
	_cancel_auto_reconnect()
	if _is_auto_connecting_default or _fallback_scan_active:
		_debug_log("Garmin auto-connect suppressed error during startup/fallback: %s" % message)
		return
	_debug_error("Garmin runtime error: %s" % message)
	emit_signal("error_occurred", message)


func _on_garmin_battery_changed(level: int) -> void:
	if _active_driver != "garmin":
		return
	_debug_log("Garmin battery changed: %d%%" % level)
	battery_level = level
	if status == "Connecting" or status.begins_with("Found"):
		_set_status("Connected")
	emit_signal("battery_changed", level)


func _on_garmin_firmware_changed(value: String) -> void:
	if _active_driver != "garmin":
		return
	_debug_log("Garmin firmware changed: %s" % value)
	firmware = value
	if status == "Connecting" or status.begins_with("Found"):
		_set_status("Connected")
	emit_signal("firmware_changed", value)


func _on_garmin_ready_changed(value: bool) -> void:
	if _active_driver != "garmin":
		return
	_debug_log("Garmin ready changed: %s" % str(value))
	var became_ready := value and not is_ready
	is_ready = value
	if value and (status == "Connecting" or status.begins_with("Found") or status == "Disconnected"):
		_set_status("Connected")
	if became_ready:
		if is_ball_in_flight():
			_pending_ready_ding = true
		else:
			_pending_ready_ding = false
			play_ready_ding()
	elif not value:
		_pending_ready_ding = false
	emit_signal("ready_changed", value)
	_update_hud_display()


func _is_valid_shot_data(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	var speed: float = float(data.get("BallSpeed", data.get("Speed", 0.0)))
	if speed <= 0.1:
		return false
	var shot_type = data.get("ShotType", "")
	if str(shot_type).to_lower() == "practice":
		return false
	return true


func _on_garmin_shot_received(data: Dictionary) -> void:
	if _active_driver != "garmin":
		return
	if not _is_valid_shot_data(data):
		_debug_log("Garmin practice swing or stationary ball ignored (speed=%.1f mph)" % float(data.get("BallSpeed", data.get("Speed", 0.0))))
		return
	if status == "Connecting" or status.begins_with("Found") or status == "Disconnected":
		_set_status("Connected")
	_debug_log("Garmin shot received with %d fields" % data.size())
	RainPhysics.apply_rain_shot_reduction(data)
	FoamBallBoost.apply_boost(data, _current_club_name)
	notify_shot_started()
	emit_signal("hit_ball", data)
	_update_hud_display()


func _schedule_auto_reconnect() -> void:
	_cancel_auto_reconnect()
	if _auto_reconnect_attempts >= MAX_AUTO_RECONNECT_ATTEMPTS:
		_debug_log("Max auto-reconnect attempts (%d) reached. Stopping auto-reconnect." % MAX_AUTO_RECONNECT_ATTEMPTS)
		return
	_auto_reconnect_attempts += 1
	var delays := [3.0, 5.0, 8.0, 12.0, 18.0]
	var delay: float = delays[mini(_auto_reconnect_attempts - 1, delays.size() - 1)]
	_auto_reconnect_timer = Timer.new()
	_auto_reconnect_timer.one_shot = true
	_auto_reconnect_timer.wait_time = delay
	_auto_reconnect_timer.timeout.connect(_on_auto_reconnect_timeout)
	add_child(_auto_reconnect_timer)
	_auto_reconnect_timer.start()
	_debug_log("Auto-reconnect attempt %d/%d scheduled in %.1f seconds." % [
		_auto_reconnect_attempts, MAX_AUTO_RECONNECT_ATTEMPTS, delay
	])


func _on_auto_reconnect_timeout() -> void:
	_cancel_auto_reconnect()
	var dev_id := str(settings.get("device_id", ""))
	if bool(settings.get("enabled", false)) and dev_id != "" and status == "Disconnected":
		_debug_log("Attempting automatic reconnection to saved device %s" % dev_id)
		connect_to_device(dev_id, true)


func _cancel_auto_reconnect() -> void:
	if _auto_reconnect_timer != null:
		if _auto_reconnect_timer.timeout.is_connected(_on_auto_reconnect_timeout):
			_auto_reconnect_timer.timeout.disconnect(_on_auto_reconnect_timeout)
		_auto_reconnect_timer.stop()
		_auto_reconnect_timer.queue_free()
		_auto_reconnect_timer = null


func _on_square_error_occurred(message: String) -> void:
	if _active_driver != "square" and _active_driver != "":
		return
	if _is_auto_connecting_default or _fallback_scan_active:
		_debug_log("Square auto-connect suppressed error during startup/fallback: %s" % message)
		return
	var is_transient := _is_transient_square_connect_error(message)
	if not _is_manual_connect and is_transient:
		_debug_log("Square auto-connect suppressed error: %s" % message)
		return
	if is_transient:
		_debug_log("Square runtime warning: %s" % message)
	else:
		_debug_error("Square runtime error: %s" % message)
	emit_signal("error_occurred", message)


func _on_square_battery_changed(level: int) -> void:
	if _active_driver != "square":
		return
	_debug_log("battery changed: %d%%" % level)
	battery_level = level
	emit_signal("battery_changed", level)


func _check_battery_warning(level: int) -> void:
	if level <= 0 or level > 100:
		return

	if level <= 10:
		if not _session_warned_battery_10:
			_session_warned_battery_10 = true
			_session_warned_battery_25 = true
			_show_battery_warning_modal(level)
	elif level <= 25:
		if not _session_warned_battery_25:
			_session_warned_battery_25 = true
			_show_battery_warning_modal(level)


func _show_battery_warning_modal(level: int) -> void:
	call_deferred("_deferred_show_battery_warning_modal", level)


func _deferred_show_battery_warning_modal(level: int) -> void:
	if _battery_warning_modal != null and is_instance_valid(_battery_warning_modal):
		if _battery_warning_modal.has_method("set_battery_level"):
			_battery_warning_modal.call("set_battery_level", level)
		return

	var modal_scene = load("res://UI/BatteryWarningModal/battery_warning_modal.tscn")
	if modal_scene == null:
		push_error("Could not load battery_warning_modal.tscn")
		return

	var modal = modal_scene.instantiate()
	if modal == null:
		return

	modal.name = "BatteryWarningModal"
	if modal.has_method("set_battery_level"):
		modal.call("set_battery_level", level)

	_battery_warning_modal = modal
	var tree := get_tree()
	if tree != null and tree.root != null:
		tree.root.add_child(modal)
	else:
		add_child(modal)


func reset_battery_warning_session() -> void:
	_session_warned_battery_25 = false
	_session_warned_battery_10 = false
	if _battery_warning_modal != null and is_instance_valid(_battery_warning_modal):
		_battery_warning_modal.queue_free()
		_battery_warning_modal = null


func trigger_test_battery_warning(level: int) -> void:
	_check_battery_warning(level)


func _on_square_firmware_changed(value: String) -> void:
	if _active_driver != "square":
		return
	_debug_log("firmware changed: %s" % value)
	firmware = value
	emit_signal("firmware_changed", value)


func _on_square_ready_changed(value: bool) -> void:
	if _active_driver != "square":
		return
	_debug_log("ready changed: %s" % str(value))
	var became_ready := value and not is_ready
	is_ready = value
	if became_ready:
		if is_ball_in_flight():
			_pending_ready_ding = true
		else:
			_pending_ready_ding = false
			play_ready_ding()
	elif not value:
		_pending_ready_ding = false
	emit_signal("ready_changed", value)
	_update_hud_display()


func _on_square_sensor_data_received(pos_x: int, pos_y: int, pos_z: int, ready: bool, detected: bool) -> void:
	if _active_driver != "square":
		return
	last_sensor_data = {
		"pos_x": pos_x,
		"pos_y": pos_y,
		"pos_z": pos_z,
		"ready": ready,
		"detected": detected
	}
	emit_signal("sensor_data_updated", pos_x, pos_y, pos_z, ready, detected)
	if _ready_hud != null and _ready_hud.has_method("set_sensor_position"):
		_ready_hud.call("set_sensor_position", pos_x, pos_y, pos_z, ready, detected)


func _on_square_shot_received(data: Dictionary) -> void:
	if _active_driver != "square":
		return
	if not _is_valid_shot_data(data):
		_debug_log("Square practice swing or stationary ball ignored (speed=%.1f mph)" % float(data.get("BallSpeed", data.get("Speed", 0.0))))
		return
	_debug_log("Square shot received: speed=%.1f mph, VLA=%.1f°, HLA=%.1f°, TotalSpin=%.0f rpm, SpinAxis=%.1f°, BackSpin=%.0f rpm, SideSpin=%.0f rpm" % [
		float(data.get("BallSpeed", data.get("Speed", 0.0))),
		float(data.get("VLA", 0.0)),
		float(data.get("HLA", 0.0)),
		float(data.get("TotalSpin", 0.0)),
		float(data.get("SpinAxis", 0.0)),
		float(data.get("BackSpin", 0.0)),
		float(data.get("SideSpin", 0.0))
	])
	RainPhysics.apply_rain_shot_reduction(data)
	FoamBallBoost.apply_boost(data, _current_club_name)
	notify_shot_started()
	emit_signal("hit_ball", data)
	_update_hud_display()


func _missing_support_message() -> String:
	if _square_init_error != "":
		return "Square support is unavailable in this build. %s" % _square_init_error
	if _garmin_init_error != "":
		return "Garmin support is unavailable in this build. %s" % _garmin_init_error
	return "Launch monitor support is unavailable in this build."


func _connect_saved_device_on_startup(device_id: String) -> void:
	if device_id == "":
		_debug_log("Launch monitor enabled on startup with no saved device_id. Starting auto-discovery...")
		_start_fallback_auto_discovery()
		return
	var saved_name := str(settings.get("device_name", ""))
	var saved_type := str(settings.get("device_type", "auto"))
	if saved_type == "bushnell_fsx" or device_id == "bushnell_fsx_csv":
		_is_auto_connecting_default = false
		connect_to_device(device_id, true)
		return
	if saved_name == "":
		saved_name = "Square Golf" if saved_type != "garmin" else "Garmin Approach R10"
	if not devices.has(device_id):
		devices[device_id] = {
			"name": saved_name,
			"rssi": 0,
			"type": saved_type if saved_type != "auto" else detect_device_type(device_id, saved_name),
			"is_discovered": false
		}
	_is_auto_connecting_default = true
	_start_default_connect_timer()
	if OS.get_name() != "Linux":
		connect_to_device(device_id, true)
		return
	_start_linux_auto_connect_scan(device_id)


func _start_default_connect_timer() -> void:
	_cancel_default_connect_timer()
	_default_connect_timer = Timer.new()
	_default_connect_timer.name = "DefaultConnectTimer"
	_default_connect_timer.one_shot = true
	_default_connect_timer.wait_time = DEFAULT_CONNECT_TIMEOUT_SECONDS
	_default_connect_timer.timeout.connect(_on_default_connect_timeout)
	add_child(_default_connect_timer)
	_default_connect_timer.start()


func _on_default_connect_timeout() -> void:
	if not _is_auto_connecting_default:
		return
	_debug_log("Default launch monitor connection timed out (%.1fs). Starting fallback auto-discovery..." % DEFAULT_CONNECT_TIMEOUT_SECONDS)
	_is_auto_connecting_default = false
	_cancel_default_connect_timer()
	if _square != null:
		_square.call("DisconnectFromDevice")
	if _garmin != null:
		_garmin.call("DisconnectFromDevice")
	_active_driver = ""
	_start_fallback_auto_discovery()


func _cancel_default_connect_timer() -> void:
	if _default_connect_timer != null:
		if _default_connect_timer.timeout.is_connected(_on_default_connect_timeout):
			_default_connect_timer.timeout.disconnect(_on_default_connect_timeout)
		_default_connect_timer.stop()
		_default_connect_timer.queue_free()
		_default_connect_timer = null


func _start_linux_auto_connect_scan(device_id: String) -> void:
	_cancel_linux_auto_connect_scan()
	var target_address := _normalize_bluetooth_address(device_id)
	if target_address == "":
		_debug_log("saved Linux Bluetooth id cannot be matched automatically; starting fallback auto-discovery")
		_start_fallback_auto_discovery()
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
	_debug_log("saved Linux launch monitor was not found during startup scan")
	_linux_auto_connect_active = false
	_linux_auto_connect_target_address = ""
	_clear_linux_auto_connect_timer()
	_stop_square_scan()
	if _is_auto_connecting_default:
		_is_auto_connecting_default = false
		_start_fallback_auto_discovery()
	elif status == "Scanning":
		_set_status("Disconnected")


func _start_fallback_auto_discovery() -> void:
	_stop_fallback_scan()
	_cancel_auto_reconnect()
	_cancel_default_connect_timer()
	_auto_reconnect_attempts = 0

	if not bool(settings.get("enabled", false)):
		return
	if status == "Connected" or status == "Ready" or is_ready:
		return

	var saved_name := str(settings.get("device_name", "Default Launch Monitor"))
	_debug_log("Default launch monitor '%s' not found. Starting auto-discovery for alternative launch monitors..." % saved_name)

	_fallback_scan_active = true
	_set_status("Default monitor not found. Searching for available launch monitors...")

	devices.clear()
	# Always scan all supported monitor types in fallback mode
	_start_square_scan()
	_start_garmin_scan()

	_start_fallback_scan_timer()


func _start_fallback_scan_timer() -> void:
	_clear_fallback_scan_timer()
	_fallback_scan_timer = Timer.new()
	_fallback_scan_timer.name = "FallbackScanTimer"
	_fallback_scan_timer.one_shot = true
	_fallback_scan_timer.wait_time = FALLBACK_SCAN_TIMEOUT_SECONDS
	_fallback_scan_timer.timeout.connect(_on_fallback_scan_timeout)
	add_child(_fallback_scan_timer)
	_fallback_scan_timer.start()


func _on_fallback_scan_timeout() -> void:
	if not _fallback_scan_active:
		return
	_debug_log("Fallback auto-discovery scan timed out. No active launch monitors found.")
	_stop_fallback_scan()
	stop_scan()
	_set_status("No launch monitors found")


func _stop_fallback_scan() -> void:
	_fallback_scan_active = false
	_clear_fallback_scan_timer()


func _clear_fallback_scan_timer() -> void:
	if _fallback_scan_timer != null:
		if _fallback_scan_timer.timeout.is_connected(_on_fallback_scan_timeout):
			_fallback_scan_timer.timeout.disconnect(_on_fallback_scan_timeout)
		_fallback_scan_timer.stop()
		_fallback_scan_timer.queue_free()
		_fallback_scan_timer = null


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
	_update_hud_display()


func _update_hud_display() -> void:
	if _ready_hud != null and _ready_hud.has_method("set_ready_status"):
		var hud_enabled := bool(settings.get("ready_indicator_enabled", true))
		var guide_enabled := bool(settings.get("ball_placement_guide_enabled", true))
		if _active_driver == "garmin" or _active_driver == "bushnell_fsx":
			guide_enabled = false
		if _ready_hud.has_method("set_placement_guide_enabled"):
			_ready_hud.call("set_placement_guide_enabled", guide_enabled)
		_ready_hud.call("set_ready_status", is_ready, status, hud_enabled)


func _debug_log(message: String) -> void:
	print("%s %s" % [SQUARE_LOG_PREFIX, message])
	if has_node("/root/DebugLogger"):
		get_node("/root/DebugLogger").log_bluetooth("%s %s" % [SQUARE_LOG_PREFIX, message])


func _debug_error(message: String) -> void:
	push_error("%s %s" % [SQUARE_LOG_PREFIX, message])
	if has_node("/root/DebugLogger"):
		get_node("/root/DebugLogger").log_error("%s %s" % [SQUARE_LOG_PREFIX, message])


func _is_transient_square_connect_error(message: String) -> bool:
	var normalized := message.strip_edges().to_lower()
	for marker in TRANSIENT_CONNECT_ERROR_MARKERS:
		if normalized.contains(marker):
			return true
	return false


func _is_square_device_name(name: String) -> bool:
	return is_square_device_name(name)


func _on_club_selected(club_name: String) -> void:
	_current_club_name = club_name
	var code := _map_in_game_club_to_square_code(club_name)
	_debug_log("In-game club changed to %s (code: %s)" % [club_name, code])
	set_club_code(code)


func _map_in_game_club_to_square_code(club_name: String) -> String:
	match club_name:
		"Dr": return "0204"
		"3w": return "0305"
		"5w": return "0505"
		"2H", "3H", "4H", "1i", "2i", "3i": return "0305" # Fallback to 3 Wood/Hybrids
		"4i": return "0406"
		"5i": return "0506"
		"6i": return "0606"
		"7i": return "0706"
		"8i": return "0806"
		"9i": return "0906"
		"Pw": return "0a06"
		"Gw": return "0b06"
		"Sw": return "0c06"
		"Lw": return "0b06"
		"Pt": return "0107"
		_: return "0204" # Default to Driver
