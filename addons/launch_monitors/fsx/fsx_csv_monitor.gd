class_name FsxCsvMonitor
extends Node

## FsxCsvMonitor
## Reads and monitors shot data CSV exports from Foresight Sports software
## (FSX Play, FSX 2020, FSX Pro) for Bushnell GC3, Launch Pro, GCQuad, and GC2.
## Enables players to connect Bushnell GC3 to Heckle Golf Simulator in real-time.

signal shot_received(shot_data: Dictionary)
signal status_changed(new_status: String)
signal error_occurred(message: String)
signal file_found(path: String)
signal new_shot_logged(summary: String)

const LOG_PREFIX := "[FsxCsvMonitor]"
const DEFAULT_POLL_INTERVAL := 0.25

const BALL_SPEED_KEYS := ["ballspeed", "speed", "ballspeedmph", "ballspeedkmh", "ball_speed", "ball speed", "ballspeed[mph]", "ballspeed(mph)"]
const LAUNCH_ANGLE_KEYS := ["launchangle", "verticallaunchangle", "vla", "launchangledeg", "vertangle", "launch_angle", "launch angle", "vertical launch angle", "verticalangle", "launchangle(deg)", "launchangle[deg]"]
const LAUNCH_DIRECTION_KEYS := ["launchdirection", "horizontallaunchangle", "hla", "sideangle", "sideangledeg", "launchdirectiondeg", "direction", "azimuth", "side_angle", "launch direction", "horizontal launch angle", "side angle", "launchdirection(deg)", "sideangle(deg)"]
const TOTAL_SPIN_KEYS := ["totalspin", "spin", "totalspinrpm", "spinrate", "total_spin", "total spin", "spin rate", "totalspin(rpm)", "totalspin[rpm]", "totalspinrpm"]
const SPIN_AXIS_KEYS := ["spinaxis", "spinaxisdeg", "tilt", "axis", "spin_axis", "spin axis", "spin axis (deg)", "spinaxis(deg)", "spinaxis[deg]", "spinaxisdeg"]
const BACK_SPIN_KEYS := ["backspin", "backspinrpm", "back_spin", "back spin", "backspin(rpm)", "backspin[rpm]", "backspinrpm"]
const SIDE_SPIN_KEYS := ["sidespin", "sidespinrpm", "side_spin", "side spin", "sidespin(rpm)", "sidespin[rpm]", "sidespinrpm"]
const CLUB_SPEED_KEYS := ["clubspeed", "clubspeedmph", "clubheadspeed", "chspeed", "club_speed", "club speed", "club head speed", "clubspeed(mph)", "clubspeed[mph]", "clubspeedmph"]
const CLUB_PATH_KEYS := ["clubpath", "path", "clubpathdeg", "club_path", "club path", "clubpath(deg)", "clubpath[deg]", "clubpathdeg"]
const ATTACK_ANGLE_KEYS := ["angleofattack", "attackangle", "aoa", "angleofattackdeg", "angle_of_attack", "angle of attack", "attack angle", "angleofattack(deg)", "attackangle(deg)", "angleofattackdeg"]
const FACE_ANGLE_KEYS := ["faceangle", "facetotarget", "faceangledeg", "face_angle", "face angle", "face to target", "faceangle(deg)", "facetotarget(deg)", "faceangledeg"]
const FACE_TO_PATH_KEYS := ["facetopath", "facetopathdeg", "face_to_path", "face to path", "facetopath(deg)", "facetopathdeg"]
const SMASH_FACTOR_KEYS := ["smashfactor", "efficiency", "smash", "smash_factor", "smash factor"]
const DYNAMIC_LOFT_KEYS := ["dynamicloft", "dynamicloftdeg", "dynamic_loft", "dynamic loft", "dynamicloft(deg)", "dynamicloftdeg"]
const CLUB_NAME_KEYS := ["club", "clubname", "clubtype", "club_name", "club type"]
const SHOT_ID_KEYS := ["shot", "shotnumber", "shotid", "id", "#", "shot_id", "shot number"]
const TIMESTAMP_KEYS := ["time", "timestamp", "date", "date/time", "datetime"]

@export var csv_path: String = ""
@export var poll_interval: float = DEFAULT_POLL_INTERVAL

var is_monitoring: bool = false
var status: String = "Disconnected"
var last_shot_summary: String = "None"
var last_shot_signature: String = ""

var _last_shot_signature: String = ""
var _poll_timer: Timer = null
var _last_line_count: int = 0
var _last_file_size: int = 0
var _last_modified_time: int = 0
var _header_indices: Dictionary = {}
var _header_line_index: int = -1
var _last_row_values: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_setup_timer()
	if _poll_timer != null and _poll_timer.get_parent() == null:
		add_child(_poll_timer)


func _exit_tree() -> void:
	stop_monitoring()


func _setup_timer() -> void:
	if _poll_timer == null:
		_poll_timer = Timer.new()
		_poll_timer.name = "FsxCsvPollTimer"
		_poll_timer.one_shot = false
		_poll_timer.wait_time = poll_interval
		_poll_timer.timeout.connect(_on_poll_timeout)
		if is_inside_tree():
			add_child(_poll_timer)


func set_poll_interval(interval: float) -> void:
	poll_interval = clampf(interval, 0.05, 5.0)
	if _poll_timer != null:
		_poll_timer.wait_time = poll_interval


## Starts monitoring the specified CSV file or folder.
## If path is empty, attempts to use the configured or auto-detected path.
func start_monitoring(path: String = "") -> bool:
	if path != "":
		csv_path = resolve_csv_path(path)
	elif csv_path == "":
		var candidates = find_default_fsx_csv_paths()
		if not candidates.is_empty():
			csv_path = candidates[0]
		else:
			csv_path = "C:/Program Files (x86)/Foresight Sports Experience/FSX Play/shots.csv"

	csv_path = csv_path.replace("\\", "/").strip_edges()
	_debug_log("Starting CSV monitoring on '%s' with poll interval %.2fs" % [csv_path, poll_interval])

	_header_indices.clear()
	_header_line_index = -1
	_last_line_count = 0
	_last_file_size = 0
	_last_modified_time = 0
	_last_shot_signature = ""

	if FileAccess.file_exists(csv_path):
		_read_initial_baseline()
		var file_name = csv_path.get_file()
		_set_status("Monitoring: %s" % file_name)
		emit_signal("file_found", csv_path)
	else:
		_set_status("Waiting for FSX to write %s" % csv_path.get_file())

	is_monitoring = true
	_setup_timer()
	if _poll_timer != null and is_inside_tree() and _poll_timer.is_inside_tree():
		_poll_timer.start()
	return true


## Stops polling and monitoring.
func stop_monitoring() -> void:
	if not is_monitoring:
		return
	is_monitoring = false
	if _poll_timer != null and not _poll_timer.is_stopped():
		_poll_timer.stop()
	_set_status("Disconnected")
	_debug_log("Stopped CSV monitoring")


func _read_initial_baseline() -> void:
	var file = FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		_debug_error("Cannot open '%s' (Error: %s)" % [csv_path, str(FileAccess.get_open_error())])
		return

	var lines: Array[String] = []
	while not file.eof_reached():
		var l = file.get_line().strip_edges()
		if not l.is_empty():
			lines.append(l)
	file.close()

	_last_line_count = lines.size()
	_last_file_size = FileAccess.get_file_as_bytes(csv_path).size()
	_last_modified_time = FileAccess.get_modified_time(csv_path)

	# Find header row
	_find_and_cache_header(lines)

	if lines.size() > 1 and _header_line_index >= 0 and lines.size() > _header_line_index + 1:
		var last_line = lines[lines.size() - 1]
		var tokens = parse_csv_row(last_line)
		_last_row_values = tokens
		_last_shot_signature = _generate_shot_signature(tokens)
		_debug_log("Baseline established with %d rows. Most recent shot signature: %s" % [lines.size(), _last_shot_signature])
	else:
		_debug_log("Baseline established with %d rows. Awaiting shots." % lines.size())


func _on_poll_timeout() -> void:
	if not is_monitoring:
		return
	poll_file()


## Checks the target file for updates or new shots.
func poll_file() -> void:
	if csv_path.is_empty():
		return

	if not FileAccess.file_exists(csv_path):
		if not status.begins_with("Waiting"):
			_set_status("Waiting for FSX to write %s" % csv_path.get_file())
		return

	var current_mtime = FileAccess.get_modified_time(csv_path)
	var current_size = FileAccess.get_file_as_bytes(csv_path).size()

	# If neither modified time nor size changed, nothing new
	if current_mtime == _last_modified_time and current_size == _last_file_size:
		return

	# File shrunk or reset -> session cleared or new file
	if current_size < _last_file_size:
		_debug_log("File size shrank from %d to %d bytes. Resetting line counter." % [_last_file_size, current_size])
		_last_line_count = 0
		_last_shot_signature = ""

	_last_modified_time = current_mtime
	_last_file_size = current_size

	var file = FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		return

	var lines: Array[String] = []
	while not file.eof_reached():
		var l = file.get_line().strip_edges()
		if not l.is_empty():
			lines.append(l)
	file.close()

	if lines.is_empty():
		return

	# If header was not cached or line count reset, re-cache header
	if _header_indices.is_empty() or _header_line_index < 0:
		_find_and_cache_header(lines)

	if _header_line_index < 0:
		# Header row not found yet
		return

	# Determine if this is a single-shot file (e.g. LastShot.csv has header + 1 data row)
	var is_single_shot_mode = (lines.size() == _header_line_index + 2)
	var start_idx = _last_line_count if not is_single_shot_mode else (_header_line_index + 1)
	if start_idx < _header_line_index + 1:
		start_idx = _header_line_index + 1

	for idx in range(start_idx, lines.size()):
		var raw_line = lines[idx]
		var tokens = parse_csv_row(raw_line)
		var sig = _generate_shot_signature(tokens)
		if sig != _last_shot_signature:
			_last_shot_signature = sig
			_last_row_values = tokens
			var parsed_shot = parse_csv_shot_data(tokens)
			if not parsed_shot.is_empty():
				_on_new_shot_parsed(parsed_shot)

	_last_line_count = lines.size()
	if not status.begins_with("Monitoring"):
		_set_status("Monitoring: %s" % csv_path.get_file())


func _on_new_shot_parsed(shot_data: Dictionary) -> void:
	var speed = float(shot_data.get("BallSpeed", shot_data.get("Speed", 0.0)))
	var vla = float(shot_data.get("VLA", 0.0))
	var spin = float(shot_data.get("TotalSpin", 0.0))
	var club = str(shot_data.get("Club", "Club"))
	last_shot_summary = "Last Shot: %s | %.1f mph | %.1f° VLA | %.0f rpm" % [club, speed, vla, spin]
	_debug_log("Emitting shot: %s" % last_shot_summary)
	emit_signal("new_shot_logged", last_shot_summary)
	emit_signal("shot_received", shot_data)


func _generate_shot_signature(tokens: PackedStringArray) -> String:
	if tokens.is_empty():
		return ""
	var joined = ",".join(tokens)
	return "%d:%s" % [joined.length(), joined.md5_text()]


func _find_and_cache_header(lines: Array[String]) -> void:
	_header_indices.clear()
	_header_line_index = -1

	# Inspect first 10 lines for header columns
	for i in range(mini(10, lines.size())):
		var tokens = parse_csv_row(lines[i])
		var mapping = _match_header_tokens(tokens)
		# A valid header must match at least ball speed or launch angle
		if mapping.has("BallSpeed") or (mapping.has("VLA") and mapping.has("TotalSpin")):
			_header_indices = mapping
			_header_line_index = i
			_debug_log("Header row identified at line %d with %d mapped metrics: %s" % [i, mapping.size(), str(mapping)])
			return


func _match_header_tokens(tokens: PackedStringArray) -> Dictionary:
	var mapping: Dictionary = {}
	for col_idx in range(tokens.size()):
		var cleaned = clean_header_name(tokens[col_idx])
		if cleaned.is_empty():
			continue

		if BALL_SPEED_KEYS.has(cleaned) and not mapping.has("BallSpeed"):
			mapping["BallSpeed"] = col_idx
		elif LAUNCH_ANGLE_KEYS.has(cleaned) and not mapping.has("VLA"):
			mapping["VLA"] = col_idx
		elif LAUNCH_DIRECTION_KEYS.has(cleaned) and not mapping.has("HLA"):
			mapping["HLA"] = col_idx
		elif TOTAL_SPIN_KEYS.has(cleaned) and not mapping.has("TotalSpin"):
			mapping["TotalSpin"] = col_idx
		elif SPIN_AXIS_KEYS.has(cleaned) and not mapping.has("SpinAxis"):
			mapping["SpinAxis"] = col_idx
		elif BACK_SPIN_KEYS.has(cleaned) and not mapping.has("BackSpin"):
			mapping["BackSpin"] = col_idx
		elif SIDE_SPIN_KEYS.has(cleaned) and not mapping.has("SideSpin"):
			mapping["SideSpin"] = col_idx
		elif CLUB_SPEED_KEYS.has(cleaned) and not mapping.has("ClubSpeed"):
			mapping["ClubSpeed"] = col_idx
		elif CLUB_PATH_KEYS.has(cleaned) and not mapping.has("ClubPath"):
			mapping["ClubPath"] = col_idx
		elif ATTACK_ANGLE_KEYS.has(cleaned) and not mapping.has("AttackAngle"):
			mapping["AttackAngle"] = col_idx
		elif FACE_ANGLE_KEYS.has(cleaned) and not mapping.has("FaceAngle"):
			mapping["FaceAngle"] = col_idx
		elif FACE_TO_PATH_KEYS.has(cleaned) and not mapping.has("FaceToPath"):
			mapping["FaceToPath"] = col_idx
		elif SMASH_FACTOR_KEYS.has(cleaned) and not mapping.has("SmashFactor"):
			mapping["SmashFactor"] = col_idx
		elif DYNAMIC_LOFT_KEYS.has(cleaned) and not mapping.has("DynamicLoft"):
			mapping["DynamicLoft"] = col_idx
		elif CLUB_NAME_KEYS.has(cleaned) and not mapping.has("Club"):
			mapping["Club"] = col_idx
		elif SHOT_ID_KEYS.has(cleaned) and not mapping.has("ShotId"):
			mapping["ShotId"] = col_idx
		elif TIMESTAMP_KEYS.has(cleaned) and not mapping.has("Timestamp"):
			mapping["Timestamp"] = col_idx
	return mapping


## Parses a row of string tokens into a game-compatible shot data dictionary.
func parse_csv_shot_data(tokens: PackedStringArray) -> Dictionary:
	if tokens.is_empty() or _header_indices.is_empty():
		return {}

	var shot: Dictionary = {}

	# 1. Ball Speed
	if _header_indices.has("BallSpeed"):
		var idx: int = _header_indices["BallSpeed"]
		if idx < tokens.size():
			var spd = parse_metric_float(tokens[idx])
			shot["BallSpeed"] = spd
			shot["Speed"] = spd

	# 2. Vertical Launch Angle (VLA)
	if _header_indices.has("VLA"):
		var idx: int = _header_indices["VLA"]
		if idx < tokens.size():
			shot["VLA"] = parse_metric_float(tokens[idx])

	# 3. Horizontal Launch Angle (HLA)
	if _header_indices.has("HLA"):
		var idx: int = _header_indices["HLA"]
		if idx < tokens.size():
			shot["HLA"] = parse_metric_float(tokens[idx])

	# 4. Spin Parameters
	var total_spin := 0.0
	var has_total_spin := false
	if _header_indices.has("TotalSpin"):
		var idx: int = _header_indices["TotalSpin"]
		if idx < tokens.size():
			total_spin = parse_metric_float(tokens[idx])
			has_total_spin = true
			shot["TotalSpin"] = total_spin

	var spin_axis := 0.0
	var has_spin_axis := false
	if _header_indices.has("SpinAxis"):
		var idx: int = _header_indices["SpinAxis"]
		if idx < tokens.size():
			spin_axis = parse_metric_float(tokens[idx])
			has_spin_axis = true
			shot["SpinAxis"] = spin_axis

	var back_spin := 0.0
	var has_back_spin := false
	if _header_indices.has("BackSpin"):
		var idx: int = _header_indices["BackSpin"]
		if idx < tokens.size():
			back_spin = parse_metric_float(tokens[idx])
			has_back_spin = true
			shot["BackSpin"] = back_spin

	var side_spin := 0.0
	var has_side_spin := false
	if _header_indices.has("SideSpin"):
		var idx: int = _header_indices["SideSpin"]
		if idx < tokens.size():
			side_spin = parse_metric_float(tokens[idx])
			has_side_spin = true
			shot["SideSpin"] = side_spin

	# Resolve Spin Relationships
	if has_total_spin and has_spin_axis:
		var rad = deg_to_rad(spin_axis)
		if not has_back_spin:
			shot["BackSpin"] = round(total_spin * cos(rad))
		if not has_side_spin:
			shot["SideSpin"] = round(total_spin * sin(rad))
	elif has_back_spin and has_side_spin:
		var comp_total = sqrt(back_spin * back_spin + side_spin * side_spin)
		if not has_total_spin:
			shot["TotalSpin"] = round(comp_total)
		if not has_spin_axis:
			shot["SpinAxis"] = rad_to_deg(atan2(side_spin, back_spin))
	elif has_total_spin and not has_spin_axis:
		shot["SpinAxis"] = 0.0
		if not has_back_spin:
			shot["BackSpin"] = total_spin
		if not has_side_spin:
			shot["SideSpin"] = 0.0

	# 5. Club Data
	if _header_indices.has("ClubSpeed"):
		var idx: int = _header_indices["ClubSpeed"]
		if idx < tokens.size():
			shot["ClubSpeed"] = parse_metric_float(tokens[idx])

	if _header_indices.has("ClubPath"):
		var idx: int = _header_indices["ClubPath"]
		if idx < tokens.size():
			shot["ClubPath"] = parse_metric_float(tokens[idx])

	if _header_indices.has("AttackAngle"):
		var idx: int = _header_indices["AttackAngle"]
		if idx < tokens.size():
			shot["AttackAngle"] = parse_metric_float(tokens[idx])

	if _header_indices.has("FaceAngle"):
		var idx: int = _header_indices["FaceAngle"]
		if idx < tokens.size():
			shot["FaceAngle"] = parse_metric_float(tokens[idx])

	if _header_indices.has("FaceToPath"):
		var idx: int = _header_indices["FaceToPath"]
		if idx < tokens.size():
			shot["FaceToPath"] = parse_metric_float(tokens[idx])

	if _header_indices.has("DynamicLoft"):
		var idx: int = _header_indices["DynamicLoft"]
		if idx < tokens.size():
			shot["DynamicLoft"] = parse_metric_float(tokens[idx])

	if _header_indices.has("SmashFactor"):
		var idx: int = _header_indices["SmashFactor"]
		if idx < tokens.size():
			shot["SmashFactor"] = parse_metric_float(tokens[idx])

	# Compute smash factor if missing but speeds present
	if not shot.has("SmashFactor") or float(shot.get("SmashFactor", 0.0)) <= 0.05:
		var b_spd = float(shot.get("BallSpeed", 0.0))
		var c_spd = float(shot.get("ClubSpeed", 0.0))
		if b_spd > 0.0 and c_spd > 0.0:
			shot["SmashFactor"] = b_spd / c_spd

	# 6. Metadata
	if _header_indices.has("Club"):
		var idx: int = _header_indices["Club"]
		if idx < tokens.size():
			shot["Club"] = tokens[idx].strip_edges().replace('"', '')

	if _header_indices.has("ShotId"):
		var idx: int = _header_indices["ShotId"]
		if idx < tokens.size():
			shot["ShotId"] = tokens[idx].strip_edges().replace('"', '')

	# Validate minimum requirements
	if not shot.has("BallSpeed") or float(shot["BallSpeed"]) <= 0.1:
		return {}

	return shot


## Simulates a test shot and notifies listeners.
func simulate_test_shot(club: String = "Dr", speed: float = 155.4, vla: float = 11.8, hla: float = 0.4, spin: float = 2450.0, axis: float = -1.2) -> Dictionary:
	var shot := {
		"BallSpeed": speed,
		"Speed": speed,
		"VLA": vla,
		"HLA": hla,
		"TotalSpin": spin,
		"SpinAxis": axis,
		"BackSpin": round(spin * cos(deg_to_rad(axis))),
		"SideSpin": round(spin * sin(deg_to_rad(axis))),
		"ClubSpeed": round(speed / 1.45 * 10.0) / 10.0,
		"ClubPath": 1.2,
		"AttackAngle": 2.2,
		"FaceAngle": 0.5,
		"FaceToPath": -0.7,
		"SmashFactor": 1.45,
		"Club": club
	}
	_on_new_shot_parsed(shot)
	return shot


## Resolves user input (which might be a folder or a file) to the target CSV file.
static func resolve_csv_path(input_path: String) -> String:
	var path = input_path.replace("\\", "/").strip_edges()
	if path.is_empty():
		return ""

	if DirAccess.dir_exists_absolute(path):
		# Look for shots.csv or LastShot.csv in directory
		var candidate1 = path.path_join("shots.csv")
		if FileAccess.file_exists(candidate1):
			return candidate1
		var candidate2 = path.path_join("LastShot.csv")
		if FileAccess.file_exists(candidate2):
			return candidate2

		# Find newest .csv in directory
		var dir = DirAccess.open(path)
		if dir != null:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			var newest_file = ""
			var newest_time = 0
			while file_name != "":
				if not dir.current_is_dir() and file_name.to_lower().ends_with(".csv"):
					var full_p = path.path_join(file_name)
					var mtime = FileAccess.get_modified_time(full_p)
					if mtime > newest_time:
						newest_time = mtime
						newest_file = full_p
				file_name = dir.get_next()
			dir.list_dir_end()
			if newest_file != "":
				return newest_file
		return path.path_join("shots.csv")

	return path


## Returns list of probable default FSX / Foresight CSV export paths on Windows and PC.
static func find_default_fsx_csv_paths() -> Array[String]:
	var paths: Array[String] = []

	var user_profile = OS.get_environment("USERPROFILE").replace("\\", "/")
	var app_data = OS.get_environment("APPDATA").replace("\\", "/")

	var candidates: Array[String] = [
		"C:/Program Files (x86)/Foresight Sports Experience/FSX Play/shots.csv",
		"C:/Program Files (x86)/Foresight Sports Experience/FSX Play/LastShot.csv",
		"C:/Program Files (x86)/Foresight Sports Experience/FSX 2020/shots.csv",
		"C:/Program Files (x86)/Foresight Sports Experience/FSX 2020/LastShot.csv",
		"C:/Program Files/Foresight Sports Experience/FSX Play/shots.csv",
		"C:/Program Files/Foresight Sports Experience/FSX 2020/shots.csv"
	]

	if not user_profile.is_empty():
		candidates.append(user_profile + "/Documents/FSX Play/shots.csv")
		candidates.append(user_profile + "/Documents/FSX Play/LastShot.csv")
		candidates.append(user_profile + "/Documents/FSX 2020/shots.csv")
		candidates.append(user_profile + "/Documents/FSX 2020/LastShot.csv")
		candidates.append(user_profile + "/Documents/Foresight Sports/shots.csv")
		candidates.append(user_profile + "/Documents/Foresight Sports/LastShot.csv")

	if not app_data.is_empty():
		candidates.append(app_data + "/ForesightSports/shots.csv")
		candidates.append(app_data + "/Foresight Sports/shots.csv")

	candidates.append("user://shots.csv")

	# Return existing files first
	for c in candidates:
		if FileAccess.file_exists(c) and not paths.has(c):
			paths.append(c)

	# If no existing found, provide the standard default candidates
	if paths.is_empty():
		paths.append("C:/Program Files (x86)/Foresight Sports Experience/FSX Play/shots.csv")
		paths.append("C:/Program Files (x86)/Foresight Sports Experience/FSX 2020/shots.csv")
		if not user_profile.is_empty():
			paths.append(user_profile + "/Documents/FSX Play/shots.csv")

	return paths


## RFC 4180 compliant CSV line parser supporting quoted strings and commas.
static func parse_csv_row(line: String) -> PackedStringArray:
	var result := PackedStringArray()
	var current := ""
	var in_quotes := false
	var i := 0
	while i < line.length():
		var ch := line[i]
		if ch == '"':
			if in_quotes and i + 1 < line.length() and line[i + 1] == '"':
				current += '"'
				i += 1
			else:
				in_quotes = not in_quotes
		elif ch == ',' and not in_quotes:
			result.append(current.strip_edges())
			current = ""
		else:
			current += ch
		i += 1
	result.append(current.strip_edges())
	return result


## Sanitizes and parses numeric values with potential units and directions ('R', 'L', 'Open', 'Closed').
static func parse_metric_float(raw: String) -> float:
	var s := raw.strip_edges()
	if s.is_empty() or s == "-" or s == "N/A" or s == "null":
		return 0.0

	if s.begins_with('"') and s.ends_with('"') and s.length() >= 2:
		s = s.substr(1, s.length() - 2).strip_edges()

	var lower := s.to_lower()
	var sign_multiplier := 1.0

	if lower.ends_with(" l") or lower.ends_with("l") or lower.contains("out-to-in") or lower.contains("closed"):
		sign_multiplier = -1.0
	elif lower.ends_with(" r") or lower.ends_with("r") or lower.contains("in-to-out") or lower.contains("open"):
		sign_multiplier = 1.0
	elif s.begins_with("-"):
		sign_multiplier = -1.0

	var cleaned := ""
	for i in range(s.length()):
		var c := s[i]
		if (c >= '0' and c <= '9') or c == '.' or c == '-':
			cleaned += c

	if cleaned.is_empty():
		return 0.0

	var val := cleaned.to_float()
	if sign_multiplier < 0.0:
		return -absf(val)
	elif sign_multiplier > 0.0 and (s.contains(" R") or s.contains(" r")):
		return absf(val)
	return val


## Strips non-alphanumeric characters for flexible header matching.
static func clean_header_name(header: String) -> String:
	var h := header.to_lower().strip_edges()
	var cleaned := ""
	for i in range(h.length()):
		var c := h[i]
		if (c >= 'a' and c <= 'z') or (c >= '0' and c <= '9'):
			cleaned += c
	return cleaned


func _set_status(value: String) -> void:
	status = value
	emit_signal("status_changed", value)
	_debug_log("Status -> %s" % value)


func _debug_log(message: String) -> void:
	print("%s %s" % [LOG_PREFIX, message])
	if is_inside_tree() and has_node("/root/DebugLogger"):
		get_node("/root/DebugLogger").log_bluetooth("%s %s" % [LOG_PREFIX, message])


func _debug_error(message: String) -> void:
	push_error("%s %s" % [LOG_PREFIX, message])
	if is_inside_tree() and has_node("/root/DebugLogger"):
		get_node("/root/DebugLogger").log_error("%s %s" % [LOG_PREFIX, message])
