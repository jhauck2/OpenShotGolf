extends Control

const RADAR_VIEW_PATH = "FloatingHUD/RightOverlay/RadarView"
const HEADER_PATH = "Header"

const METRIC_PANEL_PATHS = {
	"Speed": "TelemetryFooter/FooterContainer/SpeedPanel",
	"Launch": "TelemetryFooter/FooterContainer/LaunchPanel",
	"Spin": "TelemetryFooter/FooterContainer/SpinPanel",
	"Distance": "TelemetryFooter/FooterContainer/DistancePanel",
	"Deviation": "TelemetryFooter/FooterContainer/DeviationPanel",
}

const MISSING_VALUE = "---"
const SPEED_UNIT = "mph"
const DISTANCE_UNIT = "yds"
const ANGLE_UNIT = "°"
const SPIN_UNIT = "rpm"

signal layout_switch_requested(layout_name: String)
signal club_selected(club: String)
signal exit_pressed
signal camera_button_pressed
signal rec_button_pressed

var radar_view: Control = null
var metric_panels: Dictionary = {}
var ball_data: Dictionary = {}
var range_ref: Node3D = null

func _ready() -> void:
	_setup_ui()

func set_range(range_node: Node3D) -> void:
	range_ref = range_node

func activate() -> void:
	visible = true

func deactivate() -> void:
	visible = false

func _setup_ui() -> void:
	_setup_radar_view()
	_setup_metric_panels()
	_setup_header_signals()
	_connect_to_range_systems()


func _setup_radar_view() -> void:
	if has_node(RADAR_VIEW_PATH):
		radar_view = get_node(RADAR_VIEW_PATH)


func _setup_header_signals() -> void:
	if has_node(HEADER_PATH):
		var header = get_node(HEADER_PATH)
		if header.has_signal("camera_pressed"):
			header.camera_pressed.connect(_on_camera_button_pressed)
		if header.has_signal("rec_button_pressed"):
			header.rec_button_pressed.connect(_on_rec_button_pressed)

func _connect_to_range_systems() -> void:
	if not range_ref:
		return

	var session_recorder = range_ref.get_node_or_null("SessionRecorder")
	if session_recorder:
		if has_node("Header"):
			$Header.rec_button_pressed.connect(session_recorder.toggle_recording)
		session_recorder.recording_state.connect(_on_session_recorder_recording_state)
		session_recorder.set_session.connect(_on_session_recorder_set_session)


func _setup_metric_panels() -> void:
	for panel_name in METRIC_PANEL_PATHS:
		if has_node(METRIC_PANEL_PATHS[panel_name]):
			metric_panels[panel_name] = get_node(METRIC_PANEL_PATHS[panel_name])

func update_data(data: Dictionary) -> void:
	ball_data = data
	_update_radar_view(data)
	_update_metric_panels(data)


func _update_radar_view(data: Dictionary) -> void:
	if not radar_view or not data.has("Carry"):
		return

	var carry = float(data.get("Carry", 0))
	var lateral = _parse_offline(str(data.get("Offline", "0")))
	radar_view.set_shot_data(carry, lateral, float(data.get("Distance", 0)))

func _update_metric_panels(data: Dictionary) -> void:
	_update_speed_panel(data)
	_update_launch_panel(data)
	_update_spin_panel(data)
	_update_distance_panel(data)
	_update_deviation_panel(data)


func _update_speed_panel(data: Dictionary) -> void:
	if not metric_panels.has("Speed"):
		return

	var ball_speed = data.get("BallSpeed", MISSING_VALUE)
	var club_speed = data.get("ClubSpeed", MISSING_VALUE)

	var ball_speed_text = MISSING_VALUE if ball_speed == MISSING_VALUE else "%d %s" % [int(ball_speed), SPEED_UNIT]
	var club_speed_text = MISSING_VALUE if club_speed == MISSING_VALUE else "Club: %d %s" % [int(club_speed), SPEED_UNIT]

	metric_panels["Speed"].set_main_value(ball_speed_text)
	metric_panels["Speed"].set_secondary_value(club_speed_text)


func _update_launch_panel(data: Dictionary) -> void:
	if not metric_panels.has("Launch"):
		return

	var vla = data.get("VLA", 0.0)
	metric_panels["Launch"].set_main_value("%.1f%s" % [vla, ANGLE_UNIT])


func _update_spin_panel(data: Dictionary) -> void:
	if not metric_panels.has("Spin"):
		return

	var total_spin = data.get("TotalSpin", MISSING_VALUE)
	var spin_axis = data.get("SpinAxis", MISSING_VALUE)

	var total_spin_text = MISSING_VALUE if total_spin == MISSING_VALUE else str(int(total_spin))
	var spin_axis_text = MISSING_VALUE if spin_axis == MISSING_VALUE else "Axis: %.1f%s" % [spin_axis, ANGLE_UNIT]

	metric_panels["Spin"].set_main_value(total_spin_text)
	metric_panels["Spin"].set_secondary_value(spin_axis_text)


func _update_distance_panel(data: Dictionary) -> void:
	if not metric_panels.has("Distance"):
		return

	var carry = data.get("Carry", MISSING_VALUE)
	var total = data.get("Distance", MISSING_VALUE)

	var carry_text = MISSING_VALUE if carry == MISSING_VALUE else "%s %s" % [carry, DISTANCE_UNIT]
	var total_text = MISSING_VALUE if total == MISSING_VALUE else "Total: %s" % total

	metric_panels["Distance"].set_main_value(carry_text)
	metric_panels["Distance"].set_secondary_value(total_text)


func _update_deviation_panel(data: Dictionary) -> void:
	if not metric_panels.has("Deviation"):
		return

	var lateral = _parse_offline(str(data.get("Offline", "R0")))
	var direction = "R" if lateral > 0 else "L"
	metric_panels["Deviation"].set_main_value("%s%.1f" % [direction, abs(lateral)])

func _parse_offline(offline_str: String) -> float:
	if offline_str.begins_with("R"):
		return float(offline_str.substr(1))
	elif offline_str.begins_with("L"):
		return -float(offline_str.substr(1))
	return 0.0

func _on_view_mode_pressed() -> void:
	var next_layout = "Custom"
	if has_meta("next_layout"):
		next_layout = get_meta("next_layout")
	emit_signal("layout_switch_requested", next_layout)

func _on_exit_pressed() -> void:
	emit_signal("exit_pressed")

func _on_camera_button_pressed() -> void:
	emit_signal("camera_button_pressed")

func _on_rec_button_pressed() -> void:
	emit_signal("rec_button_pressed")

func _on_club_selector_club_selected(club: String) -> void:
	emit_signal("club_selected", club)

func _on_session_recorder_recording_state(value: bool) -> void:
	if has_node(HEADER_PATH):
		get_node(HEADER_PATH).set_recording_state(value)

func _on_session_recorder_set_session(_user: String, _dir: String) -> void:
	pass
