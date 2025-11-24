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


func _ready() -> void:
	_setup_ui()


func _setup_ui() -> void:
	# Get references to important nodes
	if has_node("FloatingHUD/RightOverlay/RadarView"):
		radar_view = $FloatingHUD/RightOverlay/RadarView

	# Get references to metric panels in footer
	_setup_metric_panels()

	# Connect signals from unified header
	if has_node("TopBar"):
		var header = $TopBar
		if header.has_signal("layout_switch_pressed"):
			header.layout_switch_pressed.connect(_on_view_mode_pressed)
		if header.has_signal("camera_pressed"):
			header.camera_pressed.connect(_on_camera_button_pressed)
		if header.has_signal("rec_button_pressed"):
			header.rec_button_pressed.connect(_on_rec_button_pressed)
		if header.has_signal("exit_pressed"):
			header.exit_pressed.connect(_on_exit_pressed)

	# Connect exit button from floating HUD
	if has_node("FloatingHUD/LeftControls/ControlButtons/ExitButton"):
		$FloatingHUD/LeftControls/ControlButtons/ExitButton.pressed.connect(_on_exit_pressed)


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
		var club_speed = data.get("ClubSpeed", 0)
		var ball_speed = data.get("BallSpeed", 0)
		metric_panels["Speed"].main_value = "%d mph" % int(ball_speed)
		metric_panels["Speed"].secondary_value = "Club: %d mph" % int(club_speed)

	# Launch Angle Panel
	if metric_panels.has("Launch"):
		var vla = data.get("VLA", 0.0)
		metric_panels["Launch"].main_value = "%.1f°" % vla

	# Spin Panel: Total Spin (large) | Side Spin (small)
	if metric_panels.has("Spin"):
		var total_spin = data.get("TotalSpin", 0)
		var spin_axis = data.get("SpinAxis", 0)
		metric_panels["Spin"].main_value = str(int(total_spin))
		metric_panels["Spin"].secondary_value = "Axis: %.1f°" % spin_axis
		# Rotate indicator based on spin axis
		metric_panels["Spin"].indicator_rotation = spin_axis

	# Distance Panel: Carry (left) | Total (right)
	if metric_panels.has("Distance"):
		var carry = data.get("Carry", 0)
		var total = data.get("Distance", 0)
		metric_panels["Distance"].main_value = "%d yds" % int(carry)
		metric_panels["Distance"].secondary_value = "Total: %d" % int(total)

	# Deviation Panel: Lateral offset
	if metric_panels.has("Deviation"):
		var offline_str = str(data.get("Offline", "0"))
		var lateral = _parse_offline(offline_str)
		var direction = "R" if lateral > 0 else "L"
		metric_panels["Deviation"].main_value = "%s%.1f" % [direction, abs(lateral)]


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
