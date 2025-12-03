extends Control

## Overview Layout - Immersive view with HUD overlays on 3D viewport
## Prioritizes the 3D environment with semi-transparent data overlays

signal layout_switch_requested(layout_name: String)
signal club_selected(club: String)
signal exit_pressed
signal camera_button_pressed
signal rec_button_pressed

# References to UI elements
var radar_view: Control = null
var metric_panels: Dictionary = {}  # Key = metric name, Value = MetricPanel node

# Ball data
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
	# Get references to important nodes
	if has_node("FloatingHUD/RightOverlay/RadarView"):
		radar_view = $FloatingHUD/RightOverlay/RadarView

	# Get references to metric panels in footer
	_setup_metric_panels()

	# Connect signals from range header
	if has_node("Header"):
		var header = $Header
		if header.has_signal("camera_pressed"):
			header.camera_pressed.connect(_on_camera_button_pressed)
		if header.has_signal("rec_button_pressed"):
			header.rec_button_pressed.connect(_on_rec_button_pressed)

	# Connect to range systems
	_connect_to_range_systems()

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
	# Get references to all metric panels in the footer
	var panel_paths = {
		"Speed": "TelemetryFooter/FooterContainer/SpeedPanel",
		"Launch": "TelemetryFooter/FooterContainer/LaunchPanel",
		"Spin": "TelemetryFooter/FooterContainer/SpinPanel",
		"Distance": "TelemetryFooter/FooterContainer/DistancePanel",
		"Deviation": "TelemetryFooter/FooterContainer/DeviationPanel",
	}

	for key in panel_paths:
		if has_node(panel_paths[key]):
			metric_panels[key] = get_node(panel_paths[key])

func update_data(data: Dictionary) -> void:
	ball_data = data

	# Update radar view
	if radar_view and data.has("Carry"):
		var carry = float(data.get("Carry", 0))
		var offline_str = str(data.get("Offline", "0"))
		var lateral = _parse_offline(offline_str)
		radar_view.set_shot_data(carry, lateral, float(data.get("Distance", 0)))

	# Update metric panels
	_update_metric_panels(data)

func _update_metric_panels(data: Dictionary) -> void:
	# Speed Panel: Club Speed (left) | Ball Speed (right)
	if metric_panels.has("Speed"):
		var ball_speed = data.get("BallSpeed", "---")
		var club_speed = data.get("ClubSpeed", "---")

		var ball_speed_text = "---"
		if ball_speed != "---":
			ball_speed_text = "%d mph" % int(ball_speed)

		var club_speed_text = "---"
		if club_speed != "---":
			club_speed_text = "Club: %d mph" % int(club_speed)

		metric_panels["Speed"].set_main_value(ball_speed_text)
		metric_panels["Speed"].set_secondary_value(club_speed_text)

	# Launch Angle Panel
	if metric_panels.has("Launch"):
		var vla = data.get("VLA", 0.0)
		metric_panels["Launch"].set_main_value("%.1f°" % vla)

	# Spin Panel: Total Spin (large) | Side Spin (small)
	if metric_panels.has("Spin"):
		var total_spin = data.get("TotalSpin", "---")
		var spin_axis = data.get("SpinAxis", "---")

		var total_spin_text = "---"
		if total_spin != "---":
			total_spin_text = str(int(total_spin))

		var spin_axis_text = "---"
		if spin_axis != "---":
			spin_axis_text = "Axis: %.1f°" % spin_axis

		metric_panels["Spin"].set_main_value(total_spin_text)
		metric_panels["Spin"].set_secondary_value(spin_axis_text)

	# Distance Panel: Carry (left) | Total (right)
	if metric_panels.has("Distance"):
		var carry = data.get("Carry", "---")
		var total = data.get("Distance", "---")

		var carry_text = "---"
		if carry != "---":
			carry_text = "%s yds" % carry

		var total_text = "---"
		if total != "---":
			total_text = "Total: %s" % total

		metric_panels["Distance"].set_main_value(carry_text)
		metric_panels["Distance"].set_secondary_value(total_text)

	# Deviation Panel: Lateral offset
	if metric_panels.has("Deviation"):
		var offline_str = str(data.get("Offline", "R0"))
		var lateral = _parse_offline(offline_str)
		var direction = "R" if lateral > 0 else "L"
		metric_panels["Deviation"].set_main_value("%s%.1f" % [direction, abs(lateral)])

func _parse_offline(offline_str: String) -> float:
	# Parse "R10" or "L5" format to float (positive = right, negative = left)
	var value = 0.0
	if offline_str.begins_with("R"):
		value = float(offline_str.substr(1))
	elif offline_str.begins_with("L"):
		value = -float(offline_str.substr(1))
	return value

func _on_view_mode_pressed() -> void:
	# Determine next layout to cycle to
	var next_layout = "Custom"

	# If the layout manager has told us what to request, use that
	if has_meta("next_layout"):
		next_layout = get_meta("next_layout")

	print("Overview layout: Layout switch pressed - requesting ", next_layout, " layout")
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
	if has_node("Header"):
		$Header.set_recording_state(value)

func _on_session_recorder_set_session(_user: String, _dir: String) -> void:
	pass
