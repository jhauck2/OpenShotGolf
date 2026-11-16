extends Node

signal log_written(entry: String)
signal logging_state_changed(is_enabled: bool, path: String)

const DEFAULT_LOG_PATH := "user://debug.log"
const ENGINE_LOG_PATH := "user://logs/godot.log"

var _file: FileAccess = null
var _current_path: String = ""
var _is_active: bool = false
var _bytes_written: int = 0
var _line_count: int = 0
var _engine_log_offset: int = 0
var _engine_poll_timer: float = 0.0
var _last_sensor_log_time: float = 0.0

# In-memory recent logs buffer for quick inspection
var _recent_entries: Array[String] = []
const MAX_RECENT_ENTRIES := 200

# Critical files list for integrity analysis
const CRITICAL_FILES := [
	"res://project.godot",
	"res://export_presets.cfg",
	"res://addons/launch_monitors/launch_monitor_manager.gd",
	"res://addons/launch_monitors/common/bluetooth/apple/AppleBluetoothGattClient.cs",
	"res://addons/launch_monitors/common/bluetooth/apple/ObjCRuntime.cs",
	"res://addons/launch_monitors/common/bluetooth/windows/WindowsBluetoothGattClient.cs",
	"res://addons/launch_monitors/common/bluetooth/linux/LinuxBluetoothGattClient.cs",
	"res://addons/launch_monitors/common/bluetooth/android/AndroidBluetoothGattClient.cs",
	"res://addons/launch_monitors/common/tcp_server/TcpServer.cs",
	"res://addons/launch_monitors/square/SquareLaunchMonitor.cs",
	"res://addons/launch_monitors/square/SquareConnectionSession.cs",
	"res://addons/launch_monitors/square/SquareProtocol.cs",
	"res://addons/launch_monitors/square/SquareCommandBuilder.cs",
	"res://addons/launch_monitors/square/SquareShotDataMapper.cs",
	"res://addons/launch_monitors/garmin/GarminLaunchMonitor.cs",
	"res://addons/launch_monitors/garmin/GarminConnectionSession.cs",
	"res://addons/launch_monitors/garmin/GarminProtocol.cs",
	"res://Player/player.gd",
	"res://Utils/Settings/global_settings.gd",
	"res://Utils/Settings/range_settings.gd",
	"res://UI/Settings/RangeSettings/range_settings.gd",
	"res://Utils/debug_logger.gd",
	"user://global_settings.cfg",
	"user://square_launch_monitor.cfg",
	"user://logs/godot.log"
]

const MAX_LOG_FILE_BYTES := 10 * 1024 * 1024 # 10 MB per-session ceiling


func _ready() -> void:
	_connect_settings()
	_connect_launch_monitor()
	_connect_event_bus()
	_rotate_log_on_startup()
	_sync_state_from_settings()


func _rotate_log_on_startup() -> void:
	var path_to_rotate := get_effective_log_path()
	var resolved := ProjectSettings.globalize_path(path_to_rotate)
	if FileAccess.file_exists(resolved):
		var prev_path := resolved + ".previous"
		DirAccess.copy_absolute(resolved, prev_path)


func _process(delta: float) -> void:
	if not _is_active:
		return
	_engine_poll_timer += delta
	if _engine_poll_timer >= 0.5:
		_engine_poll_timer = 0.0
		_sync_engine_log()


func _connect_settings() -> void:
	if has_node("/root/GlobalSettings"):
		var gs = get_node("/root/GlobalSettings")
		if gs != null and "range_settings" in gs and gs.range_settings != null:
			var rs = gs.range_settings
			if rs.settings.has("debug_logging_enabled"):
				rs.debug_logging_enabled.setting_changed.connect(_on_setting_changed)
			if rs.settings.has("debug_log_path"):
				rs.debug_log_path.setting_changed.connect(_on_setting_changed)


func _connect_launch_monitor() -> void:
	if has_node("/root/LaunchMonitorManager"):
		var lm = get_node("/root/LaunchMonitorManager")
		if lm != null:
			if lm.has_signal("status_changed") and not lm.status_changed.is_connected(_on_lm_status_changed):
				lm.status_changed.connect(_on_lm_status_changed)
			if lm.has_signal("device_discovered") and not lm.device_discovered.is_connected(_on_lm_device_discovered):
				lm.device_discovered.connect(_on_lm_device_discovered)
			if lm.has_signal("error_occurred") and not lm.error_occurred.is_connected(_on_lm_error_occurred):
				lm.error_occurred.connect(_on_lm_error_occurred)
			if lm.has_signal("battery_changed") and not lm.battery_changed.is_connected(_on_lm_battery_changed):
				lm.battery_changed.connect(_on_lm_battery_changed)
			if lm.has_signal("firmware_changed") and not lm.firmware_changed.is_connected(_on_lm_firmware_changed):
				lm.firmware_changed.connect(_on_lm_firmware_changed)
			if lm.has_signal("ready_changed") and not lm.ready_changed.is_connected(_on_lm_ready_changed):
				lm.ready_changed.connect(_on_lm_ready_changed)
			if lm.has_signal("club_code_changed") and not lm.club_code_changed.is_connected(_on_lm_club_code_changed):
				lm.club_code_changed.connect(_on_lm_club_code_changed)
			if lm.has_signal("sensor_data_updated") and not lm.sensor_data_updated.is_connected(_on_lm_sensor_data_updated):
				lm.sensor_data_updated.connect(_on_lm_sensor_data_updated)
			if lm.has_signal("hit_ball") and not lm.hit_ball.is_connected(_on_lm_hit_ball):
				lm.hit_ball.connect(_on_lm_hit_ball)


func _connect_event_bus() -> void:
	if has_node("/root/EventBus"):
		var eb = get_node("/root/EventBus")
		if eb != null:
			if eb.has_signal("club_selected") and not eb.club_selected.is_connected(_on_eb_club_selected):
				eb.club_selected.connect(_on_eb_club_selected)


func _on_setting_changed(_new_val = null) -> void:
	_sync_state_from_settings()


func _sync_state_from_settings() -> void:
	var should_enable := false
	var target_path := DEFAULT_LOG_PATH

	if has_node("/root/GlobalSettings"):
		var gs = get_node("/root/GlobalSettings")
		if gs != null and "range_settings" in gs and gs.range_settings != null:
			var rs = gs.range_settings
			if rs.settings.has("debug_logging_enabled"):
				should_enable = bool(rs.debug_logging_enabled.value)
			if rs.settings.has("debug_log_path"):
				var custom_path = str(rs.debug_log_path.value).strip_edges()
				if not custom_path.is_empty():
					target_path = custom_path

	if should_enable:
		if not _is_active or _current_path != target_path:
			start_logging(target_path)
	else:
		if _is_active:
			stop_logging()


func get_effective_log_path() -> String:
	if not _current_path.is_empty():
		return _current_path
	if has_node("/root/GlobalSettings"):
		var gs = get_node("/root/GlobalSettings")
		if gs != null and "range_settings" in gs and gs.range_settings != null:
			var p = str(gs.range_settings.debug_log_path.value).strip_edges()
			if not p.is_empty():
				return p
	return DEFAULT_LOG_PATH


func get_global_log_path() -> String:
	return ProjectSettings.globalize_path(get_effective_log_path())


func is_logging_active() -> bool:
	return _is_active


func get_session_log_count() -> int:
	return _line_count


func get_bytes_written() -> int:
	return _bytes_written


func get_recent_entries() -> Array[String]:
	return _recent_entries.duplicate()


func get_all_logs_text(max_chars: int = 100000) -> String:
	# First try reading the custom/default debug log file if it exists and has content
	var effective_path := get_effective_log_path()
	var resolved := ProjectSettings.globalize_path(effective_path)
	var content := ""
	if FileAccess.file_exists(resolved):
		var f := FileAccess.open(resolved, FileAccess.READ)
		if f != null:
			content = f.get_as_text()
			f.close()

	# If debug log was empty or not active, try the standard engine log
	if content.strip_edges().is_empty():
		var engine_resolved := ProjectSettings.globalize_path(ENGINE_LOG_PATH)
		if FileAccess.file_exists(engine_resolved):
			var ef := FileAccess.open(engine_resolved, FileAccess.READ)
			if ef != null:
				content = ef.get_as_text()
				ef.close()

	# If files are still empty, fall back to in-memory recent entries buffer
	if content.strip_edges().is_empty() and not _recent_entries.is_empty():
		content = "\n".join(_recent_entries)

	if content.length() > max_chars:
		content = "... [truncated] ...\n" + content.substr(content.length() - max_chars)

	return content


func start_logging(target_path: String = "") -> void:
	if target_path.strip_edges().is_empty():
		target_path = get_effective_log_path()

	# Close previous file handle if open
	_close_file()

	_current_path = target_path
	var resolved_path := ProjectSettings.globalize_path(target_path)

	# Ensure parent directory exists
	var dir_path := resolved_path.get_base_dir()
	if not dir_path.is_empty() and not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	# Rotate previous session log to .previous before opening fresh file
	if FileAccess.file_exists(resolved_path):
		var prev_path := resolved_path + ".previous"
		DirAccess.copy_absolute(resolved_path, prev_path)

	# Open fresh session log file
	_file = FileAccess.open(resolved_path, FileAccess.WRITE)

	if _file == null:
		var err := FileAccess.get_open_error()
		push_error("[DebugLogger] Failed to open debug log file '%s': error %d" % [resolved_path, err])
		_is_active = false
		emit_signal("logging_state_changed", false, _current_path)
		return

	_is_active = true
	_bytes_written = 0
	_line_count = 0
	emit_signal("logging_state_changed", true, _current_path)

	# Write comprehensive diagnostic header and app analysis
	_write_session_header()


func stop_logging() -> void:
	if _is_active:
		log_info("=== DEBUG LOGGING SESSION STOPPED ===")
	_close_file()
	_is_active = false
	emit_signal("logging_state_changed", false, _current_path)


func _close_file() -> void:
	if _file != null:
		_file.flush()
		_file.close()
		_file = null


func refresh_logger() -> void:
	_sync_state_from_settings()


# --- Telemetry and Logging APIs ---

func log_info(message: String) -> void:
	_write_entry("INFO", message)


func log_bluetooth(message: String) -> void:
	_write_entry("BLE", message)


func log_shot(data: Dictionary) -> void:
	var summary := _format_shot_data(data)
	_write_entry("SHOT", summary)


func log_error(message: String) -> void:
	_write_entry("ERROR", message)


func log_warning(message: String) -> void:
	_write_entry("WARN", message)


func _format_shot_data(data: Dictionary) -> String:
	var parts: Array[String] = []
	parts.append("Shot Event Received:")

	# Ball Speed
	if data.has("BallSpeed"):
		parts.append("  BallSpeed: %s mph" % str(data["BallSpeed"]))
	elif data.has("Speed"):
		parts.append("  Speed: %s mph" % str(data["Speed"]))

	# Club Speed
	if data.has("ClubSpeed"):
		parts.append("  ClubSpeed: %s mph" % str(data["ClubSpeed"]))

	# Launch Angles
	if data.has("VLA"):
		parts.append("  VLA (Launch Angle): %s deg" % str(data["VLA"]))
	if data.has("HLA"):
		parts.append("  HLA (Direction): %s deg" % str(data["HLA"]))

	# Spins
	if data.has("TotalSpin"):
		parts.append("  TotalSpin: %s rpm" % str(data["TotalSpin"]))
	if data.has("BackSpin"):
		parts.append("  BackSpin: %s rpm" % str(data["BackSpin"]))
	if data.has("SideSpin"):
		parts.append("  SideSpin: %s rpm" % str(data["SideSpin"]))
	if data.has("SpinAxis"):
		parts.append("  SpinAxis: %s deg" % str(data["SpinAxis"]))

	# Distances
	if data.has("CarryDistance"):
		parts.append("  CarryDistance: %s" % str(data["CarryDistance"]))
	if data.has("Offline"):
		parts.append("  Offline: %s" % str(data["Offline"]))

	# Selected club
	if data.has("Club"):
		parts.append("  Club: %s" % str(data["Club"]))

	# Raw JSON payload
	parts.append("  Raw JSON: " + JSON.stringify(data))
	return "\n".join(parts)


func _write_entry(tag: String, message: String) -> void:
	var timestamp := Time.get_datetime_string_from_system(false, false)
	var formatted := "[%s] [%s] %s" % [timestamp, tag, message]

	_recent_entries.append(formatted)
	if _recent_entries.size() > MAX_RECENT_ENTRIES:
		_recent_entries.pop_front()

	emit_signal("log_written", formatted)

	if not _is_active or _file == null:
		return

	_file.store_line(formatted)
	_file.flush()
	_line_count += 1
	_bytes_written = _file.get_length()

	if _bytes_written >= MAX_LOG_FILE_BYTES:
		_rotate_oversized_log()


func _rotate_oversized_log() -> void:
	if _file == null:
		return
	var resolved_path := ProjectSettings.globalize_path(_current_path)
	_file.close()
	_file = FileAccess.open(resolved_path, FileAccess.WRITE)
	if _file != null:
		_bytes_written = 0
		_line_count = 0
		_write_session_header()
		log_warning("Log file reached maximum capacity (10 MB). Log was automatically reset to prevent excessive disk usage.")


func _write_raw(text: String) -> void:
	if not _is_active or _file == null:
		return
	_file.store_line(text)
	_file.flush()
	_bytes_written = _file.get_length()


# --- Session Header and System Analysis Report ---

func _write_session_header() -> void:
	var app_version := str(ProjectSettings.get_setting("application/config/version", "unknown"))
	var app_name := str(ProjectSettings.get_setting("application/config/name", "Heckle Golf Simulator"))
	var os_name := OS.get_name()
	var os_version := OS.get_version()
	var os_model := OS.get_model_name()
	var arch := Engine.get_architecture_name()
	var cpu_name := OS.get_processor_name()
	var cpu_count := OS.get_processor_count()
	var mem_static_mb := float(OS.get_static_memory_usage()) / (1024.0 * 1024.0)
	var mem_peak_mb := float(OS.get_static_memory_peak_usage()) / (1024.0 * 1024.0)
	var gpu_name := RenderingServer.get_video_adapter_name()
	var gpu_vendor := RenderingServer.get_video_adapter_vendor()
	var gpu_api := RenderingServer.get_video_adapter_api_version()
	var now_local := Time.get_datetime_string_from_system(false, false)
	var now_utc := Time.get_datetime_string_from_system(true, false)
	var user_dir := OS.get_user_data_dir()
	var exec_path := OS.get_executable_path()
	var csharp_support := ClassDB.class_exists("CSharpScript")
	var assembly_name := str(ProjectSettings.get_setting("dotnet/project/assembly_name", "None"))
	var engine_ver := Engine.get_version_info()
	var engine_ver_str := "Godot Engine v%d.%d.%d.%s (%s)" % [
		engine_ver.get("major", 0),
		engine_ver.get("minor", 0),
		engine_ver.get("patch", 0),
		engine_ver.get("status", ""),
		engine_ver.get("build", "")
	]

	_write_raw("================================================================================")
	_write_raw("                   %s - DIAGNOSTIC DEBUG LOG" % app_name.to_upper())
	_write_raw("================================================================================")
	_write_raw("App Name:             %s" % app_name)
	_write_raw("App Version:          %s" % app_version)
	_write_raw("Engine Version:       %s" % engine_ver_str)
	_write_raw("Session Timestamp:    %s (Local) / %s (UTC)" % [now_local, now_utc])
	_write_raw("Log Output Path:      %s" % get_global_log_path())
	_write_raw("Executable Path:      %s" % exec_path)
	_write_raw("User Data Directory:  %s" % user_dir)
	_write_raw("--------------------------------------------------------------------------------")
	_write_raw("SYSTEM & ENVIRONMENT SPECS:")
	_write_raw("  OS Platform:        %s" % os_name)
	_write_raw("  OS Version / Build: %s" % os_version)
	_write_raw("  Device / Model:     %s" % os_model)
	_write_raw("  Architecture:       %s" % arch)
	_write_raw("  Processor (CPU):    %s (%d logical threads)" % [cpu_name, cpu_count])
	_write_raw("  Static Memory:      %.2f MB (Peak: %.2f MB)" % [mem_static_mb, mem_peak_mb])
	_write_raw("  Video Adapter (GPU):%s (Vendor: %s)" % [gpu_name, gpu_vendor])
	_write_raw("  Graphics Driver/API:%s" % gpu_api)
	_write_raw("  Display Mode:       %s (Screen size: %s)" % [
		str(DisplayServer.window_get_mode()),
		str(DisplayServer.screen_get_size())
	])
	_write_raw("  C# / .NET Support:  %s (Assembly: %s)" % [str(csharp_support), assembly_name])

	# macOS Specific Diagnostic Checks
	if os_name == "macOS":
		_write_raw("--------------------------------------------------------------------------------")
		_write_raw("MACOS BLUETOOTH & SECURITY DIAGNOSTICS:")
		_write_raw("  Platform: macOS detected.")
		_write_raw("  CoreBluetooth Notes:")
		_write_raw("    - CoreBluetooth requires Bluetooth privacy permission on macOS 11+.")
		_write_raw("    - State 5 = CBManagerStatePoweredOn (Ready).")
		_write_raw("    - State 3 = CBManagerStateUnauthorized (Permission denied in System Settings -> Privacy & Security -> Bluetooth).")
		_write_raw("    - State 4 = CBManagerStatePoweredOff (Bluetooth switch is OFF in macOS Control Center).")
		_write_raw("    - State 2 = CBManagerStateUnsupported (BLE hardware unavailable).")

	# Launch Monitor Settings Snapshot
	_write_raw("--------------------------------------------------------------------------------")
	_write_raw("LAUNCH MONITOR CONFIGURATION SNAPSHOT:")
	if has_node("/root/LaunchMonitorManager"):
		var lm = get_node("/root/LaunchMonitorManager")
		if lm != null and "settings" in lm:
			_write_raw("  LM Enabled:         %s" % str(lm.settings.get("enabled", false)))
			_write_raw("  Configured Device:  %s (ID: %s, Type: %s)" % [
				str(lm.settings.get("device_name", "None")),
				str(lm.settings.get("device_id", "None")),
				str(lm.settings.get("device_type", "auto"))
			])
			_write_raw("  Current LM Status:  %s" % str(lm.status))
			_write_raw("  Club Code:          %s" % str(lm.settings.get("club_code", "0204")))
			_write_raw("  Handedness:         %s" % ("Right" if int(lm.settings.get("handedness", 0)) == 0 else "Left"))
	if has_node("/root/GlobalSettings"):
		var gs = get_node("/root/GlobalSettings")
		if gs != null and "range_settings" in gs and gs.range_settings != null:
			var rs = gs.range_settings
			_write_raw("  GSPro TCP Server:   %s:%s" % [
				str(rs.tcp_server_ip.value),
				str(rs.tcp_server_port.value)
			])
			_write_raw("  Foam Ball Boost:    %s (%.1f%%)" % [
				str(rs.foam_ball_boost_enabled.value),
				float(rs.foam_ball_boost_percent.value)
			])
			_write_raw("  Power Calibration:  %+.1f%%" % [
				float(rs.power_calibration_percent.value)
			])

	# File Integrity and Size Analysis
	_write_raw("--------------------------------------------------------------------------------")
	_write_raw("APPLICATION INTEGRITY & FILE SIZE ANALYSIS:")
	_write_raw("Checking critical application files, native libraries, and configurations:")

	var verified_count := 0
	var missing_count := 0

	# 1. Main executable
	if not exec_path.is_empty():
		if FileAccess.file_exists(exec_path):
			var exec_file := FileAccess.open(exec_path, FileAccess.READ)
			if exec_file != null:
				var sz := exec_file.get_length()
				exec_file.close()
				_write_raw("  [EXE] %s : %s (%d bytes)" % [exec_path.get_file(), _format_file_size(sz), sz])
				verified_count += 1
		else:
			_write_raw("  [EXE] %s : [NOT ACCESSIBLE / IN BUNDLE]" % exec_path.get_file())

	# 2. Critical project files
	for file_path: String in CRITICAL_FILES:
		if FileAccess.file_exists(file_path):
			var f := FileAccess.open(file_path, FileAccess.READ)
			if f != null:
				var sz := f.get_length()
				f.close()
				var display_name: String = file_path.replace("res://", "")
				_write_raw("  [FILE] %-60s : %s (%d bytes)" % [display_name, _format_file_size(sz), sz])
				verified_count += 1
			else:
				_write_raw("  [FILE] %-60s : [FOUND BUT UNREADABLE]" % file_path)
		elif ResourceLoader.exists(file_path) or (file_path == "res://project.godot" and FileAccess.file_exists("res://project.binary")):
			var display_name: String = file_path.replace("res://", "")
			_write_raw("  [RES ] %-60s : [COMPILED IN PCK BUNDLE]" % display_name)
			verified_count += 1
		else:
			var display_name: String = file_path.replace("res://", "")
			# user:// config files might legitimately not exist yet before first save
			if file_path.begins_with("user://"):
				_write_raw("  [USER] %-60s : [NOT YET CREATED]" % display_name)
			else:
				_write_raw("  [MISS] %-60s : [MISSING / NOT FOUND]" % display_name)
				missing_count += 1

	# 3. User directory inventory
	_write_raw("  User Directory Inventory (%s):" % user_dir)
	var dir := DirAccess.open(user_dir)
	if dir != null:
		dir.list_dir_begin()
		var item_name := dir.get_next()
		var count_user := 0
		while not item_name.is_empty():
			if not item_name.begins_with("."):
				if dir.current_is_dir():
					_write_raw("    -> [DIR] %-24s" % item_name)
					count_user += 1
					if item_name == "courses":
						var courses_path := user_dir.path_join("courses")
						var c_dir := DirAccess.open(courses_path)
						if c_dir != null:
							c_dir.list_dir_begin()
							var c_item := c_dir.get_next()
							while not c_item.is_empty():
								if not c_item.begins_with("."):
									var c_type := "[DIR]" if c_dir.current_is_dir() else "[FILE]"
									_write_raw("       -> %-6s %s" % [c_type, c_item])
								c_item = c_dir.get_next()
							c_dir.list_dir_end()
				else:
					var f_path := user_dir.path_join(item_name)
					var f := FileAccess.open(f_path, FileAccess.READ)
					if f != null:
						var sz := f.get_length()
						f.close()
						_write_raw("    -> %-30s : %s (%d bytes)" % [item_name, _format_file_size(sz), sz])
						count_user += 1
			item_name = dir.get_next()
		dir.list_dir_end()
		if count_user == 0:
			_write_raw("    -> (empty directory)")
	else:
		_write_raw("    -> Unable to open user directory.")

	_write_raw("Integrity Summary: %d files verified, %d missing critical files." % [verified_count, missing_count])
	_write_raw("================================================================================")
	_write_raw("REAL-TIME DIAGNOSTIC TELEMETRY BEGINS:")
	_write_raw("================================================================================")
	_file.flush()


func _format_file_size(bytes: int) -> String:
	if bytes < 1024:
		return "%d B" % bytes
	elif bytes < 1024 * 1024:
		return "%.1f KB" % (float(bytes) / 1024.0)
	elif bytes < 1024 * 1024 * 1024:
		return "%.2f MB" % (float(bytes) / (1024.0 * 1024.0))
	else:
		return "%.2f GB" % (float(bytes) / (1024.0 * 1024.0 * 1024.0))


# --- Engine Log File Synchronization ---

func _sync_engine_log() -> void:
	if not FileAccess.file_exists(ENGINE_LOG_PATH):
		return
	var eng_file := FileAccess.open(ENGINE_LOG_PATH, FileAccess.READ)
	if eng_file == null:
		return

	var file_len := eng_file.get_length()
	if file_len > _engine_log_offset:
		eng_file.seek(_engine_log_offset)
		while not eng_file.eof_reached():
			var line := eng_file.get_line()
			if not line.is_empty():
				# Avoid duplicating entries that were already written by DebugLogger directly
				if not line.begins_with("[") or (not line.contains("[BLE]") and not line.contains("[SHOT]")):
					if line.to_lower().contains("error") or line.to_lower().contains("fail") or line.to_lower().contains("exception"):
						_write_entry("ENGINE_ERR", line)
		_engine_log_offset = file_len
	eng_file.close()


# --- Signal Listeners for Automatic Telemetry ---

func _on_lm_status_changed(new_status: String) -> void:
	log_bluetooth("Launch Monitor status changed: '%s'" % new_status)


func _on_lm_device_discovered(device_id: String, dev_name: String, rssi: int) -> void:
	log_bluetooth("Discovered BLE peripheral: ID='%s', Name='%s', RSSI=%d dBm" % [device_id, dev_name, rssi])


func _on_lm_error_occurred(message: String) -> void:
	log_error("Launch Monitor error: %s" % message)


func _on_lm_battery_changed(level: int) -> void:
	log_bluetooth("Launch Monitor battery level update: %d%%" % level)


func _on_lm_firmware_changed(fw: String) -> void:
	log_bluetooth("Launch Monitor firmware update: %s" % fw)


func _on_lm_ready_changed(ready: bool) -> void:
	log_bluetooth("Launch Monitor ready state: %s" % ("READY" if ready else "NOT READY"))


func _on_lm_club_code_changed(code: String) -> void:
	log_bluetooth("Launch Monitor club code changed: %s" % code)


func _on_lm_sensor_data_updated(pos_x: int, pos_y: int, pos_z: int, ready: bool, detected: bool) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	# Throttle sensor raw updates to every 4 seconds unless ready or detected state changed
	if now - _last_sensor_log_time >= 4.0:
		_last_sensor_log_time = now
		log_bluetooth("Sensor state: Ready=%s, BallDetected=%s, BallPos=(%d, %d, %d)" % [
			str(ready), str(detected), pos_x, pos_y, pos_z
		])


func _on_lm_hit_ball(data: Dictionary) -> void:
	log_shot(data)


func _on_eb_club_selected(club_name: String) -> void:
	log_info("Club selected in simulator: %s" % club_name)
