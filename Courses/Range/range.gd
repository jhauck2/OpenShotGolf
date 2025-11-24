extends Node3D

var track_points : bool = false
var trail_timer : float = 0.0
var trail_resolution : float = 0.1
var apex := 0
var ball_data: Dictionary = {"Distance": "---", "Carry": "---", "Offline": "---", "Apex": "---", "VLA": 0.0, "HLA": 0.0, "Points": "---"}
var ball_reset_time := 5.0
var auto_reset_enabled := false

## Stats panel (target practice grid element)
var stats_panel: Control = null
var points_panel: Control = null  # Points data panel for grid
var shot_history_panel: Control = null  # Shot history list

## Target practice system
var target_manager: TargetManager
var current_landing_marker: LandingMarker = null
var last_shot_result: Dictionary = {}
var target_panel: Control = null
var mode_indicator: Control = null

## Camera system
var camera_controller: CameraController = null

## Range modes (use GameState RangeMode enum)
var current_mode: int = 0  # 0 = FREE_PRACTICE, 1 = TARGET_PRACTICE
var ui_overlays_visible: bool = false
var current_club: String = "Driver"  # Track currently selected club


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Initialize target system
	_setup_target_system()

	# Initialize camera system
	_setup_camera_system()

	# Connect settings
	if GlobalSettings and GlobalSettings.range_settings:
		GlobalSettings.range_settings.auto_ball_reset.setting_changed.connect(_on_auto_reset_setting_changed)

	# Connect UI signals
	if has_node("LayoutManager"):
		$LayoutManager.toggle_overlay_pressed.connect(_on_toggle_overlay_pressed)
		$LayoutManager.club_selected.connect(_on_club_selected)
		$LayoutManager.camera_button_pressed.connect(_on_camera_button_pressed)
		$LayoutManager.exit_pressed.connect(_on_exit_pressed)
		# Wait a frame then try to connect - layout manager may not be fully initialized yet
		await get_tree().process_frame
		_setup_layout_manager_signals()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	var m2yd = 1.09361
	var use_imperial = GlobalSettings and GlobalSettings.range_settings and GlobalSettings.range_settings.range_units.value == Enums.Units.IMPERIAL

	if use_imperial:
		ball_data["Distance"] = str(int($GolfBall.get_distance() * m2yd))
		ball_data["Carry"] = str(int($GolfBall.carry * m2yd))
		ball_data["Apex"] = str(int($GolfBall.apex * 3 * m2yd))
		var offline = int($GolfBall.get_offline() * m2yd)
		var offline_text := "R"
		if offline < 0:
			offline_text = "L"
		offline_text += str(abs(offline))
		ball_data["Offline"] = offline_text
	else:
		ball_data["Distance"] = str($GolfBall.get_distance())
		ball_data["Carry"] = str($GolfBall.carry)
		ball_data["Apex"] = str($GolfBall.apex * 3)
		var offline = $GolfBall.get_offline()
		var offline_text := "R"
		if offline < 0:
			offline_text = "L"
		offline_text += str(abs(offline))
		ball_data["Offline"] = offline_text

	# Send data to UI
	$LayoutManager.update_data(ball_data)


func _on_tcp_client_hit_ball(data: Dictionary) -> void:
	# Clear previous shot data first
	_clear_shot_data()
	# Update with new launch monitor data
	ball_data.merge(data)


func _on_golf_ball_rest(_ball_data) -> void:
	# Register shot to history
	_register_shot_to_history()

	# Process shot result (for target practice)
	_process_shot_result()

	var use_auto_reset = GlobalSettings and GlobalSettings.range_settings and GlobalSettings.range_settings.auto_ball_reset.value
	if use_auto_reset:
		var reset_time = GlobalSettings.range_settings.ball_reset_timer.value if GlobalSettings and GlobalSettings.range_settings else ball_reset_time
		await get_tree().create_timer(reset_time).timeout
		$GolfBall.reset_ball()
		ball_data["HLA"] = 0.0
		ball_data["VLA"] = 0.0


## Setup the target practice system
func _setup_target_system() -> void:
	# Create target manager (but don't create targets yet)
	target_manager = TargetManager.new()
	target_manager.name = "TargetManager"
	add_child(target_manager)

	# Connect signals
	target_manager.shot_scored.connect(_on_shot_scored)
	target_manager.target_selected.connect(_on_target_selected)

	# Connect to GameState signals for mode and target changes from other sources (buttons, etc)
	if GameState:
		GameState.mode_changed.connect(_on_gamestate_mode_changed)
		GameState.target_changed.connect(_on_gamestate_target_changed)

	# Note: Mode indicator and target panel are only created in Custom layout
	# The layout manager will handle UI for Detail and Overview layouts

	# Set initial mode (this will create targets if needed)
	_set_range_mode(current_mode)



## Setup the camera system
func _setup_camera_system() -> void:
	# Disable PhantomCamera3D if it exists
	if has_node("PhantomCamera3D"):
		$PhantomCamera3D.queue_free()

	# Create camera controller
	camera_controller = CameraController.new()
	camera_controller.name = "CameraController"
	add_child(camera_controller)

	# Set ball as target for follow camera
	if has_node("GolfBall/Ball"):
		camera_controller.set_ball_target($GolfBall/Ball)

	# Connect camera changed signal
	camera_controller.camera_changed.connect(_on_camera_changed)



## Create the target panel UI (now just a simple label)
func _create_target_panel() -> void:
	# Create a simple label for target info at top center
	target_panel = Label.new()
	target_panel.name = "TargetLabel"
	target_panel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_panel.add_theme_font_size_override("font_size", 20)
	target_panel.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	target_panel.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	target_panel.add_theme_constant_override("outline_size", 8)

	# Position at top center (higher to be visible above ground plane)
	target_panel.anchor_left = 0.5
	target_panel.anchor_top = 0.0
	target_panel.anchor_right = 0.5
	target_panel.anchor_bottom = 0.0
	target_panel.offset_left = -200
	target_panel.offset_right = 200
	target_panel.offset_top = 120  # Higher position to be visible above ground
	target_panel.offset_bottom = 150

	# Add to RangeUI
	if has_node("RangeUI"):
		$RangeUI.add_child(target_panel)

		# Update with initial target info
		_update_target_display()
	else:
		push_error("RangeUI node not found - cannot add target label")


## Add stats panel to grid canvas
func _add_stats_panel() -> void:
	# Only for Custom layout
	if not _is_using_custom_layout():
		return

	var grid_canvas_path = "LayoutManager/LayoutManager/CustomLayout/RangeUI/GridCanvas"

	# Check if already exists
	if has_node(grid_canvas_path + "/StatsPanel"):
		stats_panel = get_node(grid_canvas_path + "/StatsPanel")
		return

	# Load the stats_panel scene
	var StatsPanelScene = load("res://UI/stats_panel.tscn")
	if StatsPanelScene == null:
		push_error("Could not load stats_panel.tscn")
		return

	stats_panel = StatsPanelScene.instantiate()
	stats_panel.name = "StatsPanel"

	if has_node(grid_canvas_path):
		get_node(grid_canvas_path).add_child(stats_panel)

		# Load saved position from config, or use default
		var config = ConfigFile.new()
		var default_position = Vector2(0, 575)  # Below Points panel default

		if config.load("user://layout.cfg") == OK:
			if config.has_section_key("positions", "StatsPanel"):
				stats_panel.position = config.get_value("positions", "StatsPanel")
			else:
				stats_panel.position = default_position
		elif config.load("res://UI/default_layout.cfg") == OK:
			if config.has_section_key("positions", "StatsPanel"):
				stats_panel.position = config.get_value("positions", "StatsPanel")
			else:
				stats_panel.position = default_position
		else:
			stats_panel.position = default_position

		# Connect drag signals
		var grid_canvas = get_node(grid_canvas_path)
		stats_panel.drag_started.connect(grid_canvas._on_panel_drag_started)
		stats_panel.drag_ended.connect(grid_canvas._on_panel_drag_ended)



## Remove stats panel from grid canvas
func _remove_stats_panel() -> void:
	# Only for Custom layout
	if not _is_using_custom_layout():
		return

	var grid_canvas_path = "LayoutManager/LayoutManager/CustomLayout/RangeUI/GridCanvas"

	if has_node(grid_canvas_path + "/StatsPanel"):
		var panel = get_node(grid_canvas_path + "/StatsPanel")
		panel.queue_free()
		stats_panel = null


## Add shot history panel to grid canvas
func _add_shot_history_panel() -> void:
	# Only for Custom layout
	if not _is_using_custom_layout():
		return

	var grid_canvas_path = "LayoutManager/LayoutManager/CustomLayout/RangeUI/GridCanvas"

	# Check if already exists
	if has_node(grid_canvas_path + "/ShotHistoryPanel"):
		shot_history_panel = get_node(grid_canvas_path + "/ShotHistoryPanel")
		return

	# Load the shot_history_panel scene
	var ShotHistoryPanelScene = load("res://UI/shot_history_panel.tscn")
	if ShotHistoryPanelScene == null:
		push_error("Could not load shot_history_panel.tscn")
		return

	shot_history_panel = ShotHistoryPanelScene.instantiate()
	shot_history_panel.name = "ShotHistoryPanel"

	if has_node(grid_canvas_path):
		get_node(grid_canvas_path).add_child(shot_history_panel)

		# Load saved position from config, or use default
		var config = ConfigFile.new()
		var default_position = Vector2(280, 200)  # Right of stats panel

		if config.load("user://layout.cfg") == OK:
			if config.has_section_key("positions", "ShotHistoryPanel"):
				shot_history_panel.position = config.get_value("positions", "ShotHistoryPanel")
			else:
				shot_history_panel.position = default_position
		elif config.load("res://UI/default_layout.cfg") == OK:
			if config.has_section_key("positions", "ShotHistoryPanel"):
				shot_history_panel.position = config.get_value("positions", "ShotHistoryPanel")
			else:
				shot_history_panel.position = default_position
		else:
			shot_history_panel.position = default_position

		# Connect drag signals
		var grid_canvas = get_node(grid_canvas_path)
		shot_history_panel.drag_started.connect(grid_canvas._on_panel_drag_started)
		shot_history_panel.drag_ended.connect(grid_canvas._on_panel_drag_ended)



## Remove shot history panel from grid canvas
func _remove_shot_history_panel() -> void:
	# Only for Custom layout
	if not _is_using_custom_layout():
		return

	var grid_canvas_path = "LayoutManager/LayoutManager/CustomLayout/RangeUI/GridCanvas"

	if has_node(grid_canvas_path + "/ShotHistoryPanel"):
		var panel = get_node(grid_canvas_path + "/ShotHistoryPanel")
		panel.queue_free()
		shot_history_panel = null


## Create the mode indicator UI
func _create_mode_indicator() -> void:
	# Load the mode indicator script
	var ModeIndicatorScript = load("res://UI/ModeIndicator/mode_indicator.gd")
	mode_indicator = ModeIndicatorScript.new()
	mode_indicator.name = "ModeIndicator"

	# Position it in top-right corner
	mode_indicator.position = Vector2(20, 20)

	# Add to RangeUI
	if has_node("RangeUI"):
		$RangeUI.add_child(mode_indicator)
	else:
		push_error("RangeUI node not found - cannot add ModeIndicator")


## Set the range mode
func _set_range_mode(mode: int) -> void:
	current_mode = mode

	# Update GameState to keep everything in sync
	if GameState:
		GameState.current_mode = mode

	match mode:
		0:  # FREE_PRACTICE
			_enable_free_practice_mode()
		1:  # TARGET_PRACTICE
			_enable_target_practice_mode()



## Enable free practice mode (no targets)
func _enable_free_practice_mode() -> void:
	if target_manager:
		target_manager.set_targets_visible(false)

	if target_panel:
		target_panel.visible = false

	# Update unified header
	if has_node("LayoutManager") and $LayoutManager.has_method("update_mode_display"):
		$LayoutManager.update_mode_display("FREE PRACTICE", "")

	# These UI updates only apply to Custom layout (when in RangeUI mode)
	# Detail and Overview layouts handle their own UI
	if _is_using_custom_layout():
		if mode_indicator:
			mode_indicator.visible = ui_overlays_visible
			if mode_indicator.has_method("show_free_practice_mode"):
				mode_indicator.show_free_practice_mode()

		# Update mode label
		if has_node("LayoutManager/LayoutManager/CustomLayout/RangeUI/HBoxContainer/ModeContainer/ModeLabel"):
			var label = get_node("LayoutManager/LayoutManager/CustomLayout/RangeUI/HBoxContainer/ModeContainer/ModeLabel")
			label.text = "FREE PRACTICE"

		# Clear target label
		if has_node("LayoutManager/LayoutManager/CustomLayout/RangeUI/HBoxContainer/ModeContainer/TargetLabel"):
			var label = get_node("LayoutManager/LayoutManager/CustomLayout/RangeUI/HBoxContainer/ModeContainer/TargetLabel")
			label.text = ""

		# Update shot history mode to free practice
		if shot_history_panel:
			shot_history_panel.set_mode(false)

		# Remove Points panel, stats panel, and shot history from grid
		_remove_points_panel()
		_remove_stats_panel()
		_remove_shot_history_panel()


## Enable target practice mode
func _enable_target_practice_mode() -> void:
	if target_manager:
		# Create targets if not already created
		target_manager.create_targets()
		# Show only the active target (in case we're toggling back from free practice)
		var active = target_manager.get_active_target()
		if active:
			active.set_target_visible(true)

	# These UI updates only apply to Custom layout
	if _is_using_custom_layout():
		if target_panel:
			target_panel.visible = ui_overlays_visible
			_update_target_display()

		if mode_indicator:
			mode_indicator.visible = ui_overlays_visible
			if mode_indicator.has_method("show_target_practice_mode"):
				mode_indicator.show_target_practice_mode()

		# Update mode label
		if has_node("LayoutManager/LayoutManager/CustomLayout/RangeUI/HBoxContainer/ModeContainer/ModeLabel"):
			var label = get_node("LayoutManager/LayoutManager/CustomLayout/RangeUI/HBoxContainer/ModeContainer/ModeLabel")
			label.text = "TARGET PRACTICE"

		# Update target label with current target
		_update_center_target_display()

		# Add Points panel, stats panel, and shot history to grid
		_add_points_panel()
		_add_stats_panel()
		_add_shot_history_panel()
		_update_stats_panel()

		# Update shot history mode to target practice
		if shot_history_panel:
			shot_history_panel.set_mode(true)


## Process shot when ball comes to rest
func _process_shot_result() -> void:
	# Only process targets in TARGET_PRACTICE mode
	if current_mode != 1:  # TARGET_PRACTICE
		return

	if target_manager == null:
		return

	var ball_position = $GolfBall/Ball.global_position
	last_shot_result = target_manager.process_shot(ball_position)

	# Update Points display with current shot score
	if not last_shot_result.is_empty():
		ball_data["Points"] = str(last_shot_result.get("score", 0))
	else:
		ball_data["Points"] = "0"

	# Create landing marker
	_create_landing_marker(ball_position)


## Clear shot data between shots
func _clear_shot_data() -> void:
	ball_data["Distance"] = "---"
	ball_data["Carry"] = "---"
	ball_data["Offline"] = "---"
	ball_data["Apex"] = "---"
	ball_data["VLA"] = 0.0
	ball_data["HLA"] = 0.0
	ball_data["Points"] = "---"


## Register shot to history panel
func _register_shot_to_history() -> void:
	var shot_data_entry: Dictionary = {
		"Club": current_club,
		"Carry": int($GolfBall.carry),
		"Distance": int($GolfBall.get_distance()),
		"Offline": ball_data.get("Offline", "---"),
		"Roll": int($GolfBall.get_distance() - $GolfBall.carry) if $GolfBall.get_distance() > $GolfBall.carry else 0,
		"Points": int(ball_data.get("Points", 0))
	}

	# Add to custom layout's shot history panel if it exists
	if shot_history_panel:
		shot_history_panel.add_shot(shot_data_entry)

	# Add to GameState so all layouts (Detail, Overview) can access it
	if GameState:
		GameState.add_to_history(shot_data_entry)


## Create visual marker at landing position
func _create_landing_marker(position: Vector3) -> void:
	# Remove previous marker if exists
	if current_landing_marker:
		current_landing_marker.queue_free()

	# Create new marker
	current_landing_marker = LandingMarker.new()

	# Set marker color based on scoring zone
	if not last_shot_result.is_empty() and last_shot_result.has("zone"):
		var zone_color = LandingMarker.get_zone_color(last_shot_result.zone)
		current_landing_marker.marker_color = zone_color

	add_child(current_landing_marker)

	# Set marker data
	var distance_to_target = last_shot_result.get("distance", -1.0)
	var carry = $GolfBall.carry
	current_landing_marker.set_marker_data(position, distance_to_target, carry)


## Handle shot scored event
func _on_shot_scored(target_name: String, distance: float, score: int, zone: String) -> void:

	# Update ball_data with current shot points
	ball_data["Points"] = str(score)

	# Update stats panel
	_update_stats_panel()


## Handle target selection event
func _on_target_selected(target: TargetGreen) -> void:

	# Update GameState with new target
	if GameState:
		GameState.set_target(target.target_name, target.target_distance)

	# Update UI to show active target
	_update_target_display()

	# Update overhead camera to frame this target
	if camera_controller:
		camera_controller.set_target_distance(target.target_distance)


## Update score display in UI
func _update_score_display(target_name: String, distance: float, score: int, zone: String) -> void:
	# Just print to console for now
	pass


## Update target info display
func _update_target_display() -> void:
	# Update target label if it exists
	if target_panel and target_manager != null:
		var active_target = target_manager.get_active_target()

		if active_target:
			var offset_text = ""
			if abs(active_target.lateral_offset) > 0.1:
				offset_text = " (%.0f yds %s)" % [abs(active_target.lateral_offset), "R" if active_target.lateral_offset > 0 else "L"]
			target_panel.text = "%s - %.0f yards%s" % [active_target.target_name, active_target.target_distance, offset_text]
		else:
			target_panel.text = ""

	# Also update the center display
	_update_center_target_display()


## Update center target display (under mode label)
func _update_center_target_display() -> void:
	# Update unified header
	if target_manager == null or current_mode != 1:  # TARGET_PRACTICE
		if has_node("LayoutManager") and $LayoutManager.has_method("update_mode_display"):
			$LayoutManager.update_mode_display("FREE PRACTICE", "")
		return

	var active_target = target_manager.get_active_target()
	if active_target:
		var offset_text = ""
		if abs(active_target.lateral_offset) > 0.1:
			offset_text = " (%.0f yds %s)" % [abs(active_target.lateral_offset), "R" if active_target.lateral_offset > 0 else "L"]
		var target_text = "%.0f yards%s" % [active_target.target_distance, offset_text]

		if has_node("LayoutManager") and $LayoutManager.has_method("update_mode_display"):
			$LayoutManager.update_mode_display("TARGET PRACTICE", target_text)
	else:
		if has_node("LayoutManager") and $LayoutManager.has_method("update_mode_display"):
			$LayoutManager.update_mode_display("TARGET PRACTICE", "")


## Update stats panel with session statistics
func _update_stats_panel() -> void:
	if stats_panel == null or target_manager == null:
		return

	var stats = target_manager.get_session_stats()
	stats_panel.set_stats(stats)


## Add Points panel to grid canvas
func _add_points_panel() -> void:
	# Only for Custom layout
	if not _is_using_custom_layout():
		return

	var grid_canvas_path = "LayoutManager/LayoutManager/CustomLayout/RangeUI/GridCanvas"

	# Check if already exists
	if has_node(grid_canvas_path + "/Points"):
		points_panel = get_node(grid_canvas_path + "/Points")
		return

	# Load the data_panel scene
	var DataPanelScene = load("res://UI/data_panel.tscn")
	if DataPanelScene == null:
		push_error("Could not load data_panel.tscn")
		return

	points_panel = DataPanelScene.instantiate()
	points_panel.name = "Points"
	points_panel.label = "Last Shot"
	points_panel.units = "pts"
	points_panel.custom_minimum_size = Vector2(100, 0)  # Match Distance panel width

	if has_node(grid_canvas_path):
		get_node(grid_canvas_path).add_child(points_panel)

		# Load saved position from config, or use default
		var config = ConfigFile.new()
		var default_position = Vector2(0, 200)

		if config.load("user://layout.cfg") == OK:
			if config.has_section_key("positions", "Points"):
				points_panel.position = config.get_value("positions", "Points")
			else:
				points_panel.position = default_position
		elif config.load("res://UI/default_layout.cfg") == OK:
			if config.has_section_key("positions", "Points"):
				points_panel.position = config.get_value("positions", "Points")
			else:
				points_panel.position = default_position
		else:
			points_panel.position = default_position

		# Connect drag signals
		var grid_canvas = get_node(grid_canvas_path)
		points_panel.drag_started.connect(grid_canvas._on_panel_drag_started)
		points_panel.drag_ended.connect(grid_canvas._on_panel_drag_ended)

		ball_data["Points"] = "---"


## Remove Points panel from grid canvas
func _remove_points_panel() -> void:
	# Only for Custom layout
	if not _is_using_custom_layout():
		return

	var grid_canvas_path = "LayoutManager/LayoutManager/CustomLayout/RangeUI/GridCanvas"

	if has_node(grid_canvas_path + "/Points"):
		var panel = get_node(grid_canvas_path + "/Points")
		panel.queue_free()
		points_panel = null
		ball_data["Points"] = "---"


## Input handling for target cycling, mode switching, and camera control
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# Mode switching with M key
		if event.keycode == KEY_M:
			_toggle_range_mode()

		# Toggle UI overlays with T key
		if event.keycode == KEY_T:
			_toggle_ui_overlays()

		# Reset stats with Ctrl+R
		if event.keycode == KEY_R and event.ctrl_pressed:
			_reset_session_stats()

		# Camera controls with number keys 1-5
		if camera_controller:
			if event.keycode == KEY_1:
				camera_controller.set_camera_mode(CameraController.CameraMode.BEHIND_BALL)
			elif event.keycode == KEY_2:
				camera_controller.set_camera_mode(CameraController.CameraMode.DOWN_THE_LINE)
			elif event.keycode == KEY_3:
				camera_controller.set_camera_mode(CameraController.CameraMode.FACE_ON)
			elif event.keycode == KEY_4:
				camera_controller.set_camera_mode(CameraController.CameraMode.BIRDS_EYE)
			elif event.keycode == KEY_5:
				camera_controller.set_camera_mode(CameraController.CameraMode.FOLLOW_BALL)
			# Camera cycling with C key
			elif event.keycode == KEY_C:
				camera_controller.next_camera()

		# Target cycling (only in TARGET_PRACTICE mode)
		if current_mode == 1 and target_manager != null:
			if event.keycode == KEY_BRACKETLEFT:  # [
				target_manager.previous_target()
			elif event.keycode == KEY_BRACKETRIGHT:  # ]
				target_manager.next_target()
			# Aim adjustment with arrow keys
			elif event.keycode == KEY_LEFT:
				target_manager.adjust_aim(-5.0)  # 5 yards left
				_update_target_display()
			elif event.keycode == KEY_RIGHT:
				target_manager.adjust_aim(5.0)  # 5 yards right
				_update_target_display()
			elif event.keycode == KEY_DOWN:
				target_manager.reset_aim()  # Reset to center
				_update_target_display()


## Toggle between range modes
func _toggle_range_mode() -> void:
	match current_mode:
		0:  # FREE_PRACTICE
			_set_range_mode(1)  # TARGET_PRACTICE
		1:  # TARGET_PRACTICE
			_set_range_mode(0)  # FREE_PRACTICE


## Toggle UI overlays visibility
func _toggle_ui_overlays() -> void:
	ui_overlays_visible = not ui_overlays_visible

	if target_panel:
		target_panel.visible = ui_overlays_visible and current_mode == 1

	if mode_indicator:
		mode_indicator.visible = ui_overlays_visible



## Handle camera changed event
func _on_camera_changed(camera_name: String) -> void:
	var layout_manager = get_node_or_null("LayoutManager")
	if layout_manager and camera_controller:
		# Assume controller has a method to get the active camera.
		if camera_controller.has_method("get_active_camera"):
			var new_cam = camera_controller.get_active_camera()
			if new_cam and layout_manager.has_method("on_active_camera_changed"):
				layout_manager.on_active_camera_changed(new_cam)


## Reset session statistics
func _reset_session_stats() -> void:
	if target_manager:
		target_manager.reset_session_stats()
		ball_data["Points"] = "---"
		_update_stats_panel()


## Handle club selection change
func _on_club_selected(club: String) -> void:
	current_club = club


## Handle toggle overlay button press
func _on_toggle_overlay_pressed() -> void:
	_toggle_ui_overlays()


## Handle camera button press
func _on_camera_button_pressed() -> void:
	if camera_controller:
		camera_controller.next_camera()


## Handle exit button press - return to main menu
func _on_exit_pressed() -> void:
	SceneManager.change_scene("res://UI/MainMenu/main_menu.tscn")


## Check if currently using Custom layout
func _is_using_custom_layout() -> bool:
	# Check if the LayoutManager exists and is in Custom mode
	if has_node("LayoutManager/LayoutManager"):
		var layout_manager = $LayoutManager/LayoutManager
		if layout_manager.has_method("get_current_layout_name"):
			return layout_manager.get_current_layout_name() == "Custom"
	return false


## Handle GameState mode changes (from buttons, header, etc)
func _on_gamestate_mode_changed(mode: int) -> void:
	"""When GameState mode changes, sync range.gd"""
	_set_range_mode(mode)


## Handle GameState target changes
func _on_gamestate_target_changed(target_name: String, distance: float) -> void:
	"""When GameState target changes, update display"""
	_update_target_display()


func _setup_layout_manager_signals() -> void:
	"""Setup layout manager signal connections after initialization"""
	if has_node("LayoutManager"):
		var lm = $LayoutManager
		if lm.get_child_count() > 0:
			var custom = lm.get_child(0)
			if custom.has_signal("layout_switch_requested"):
				custom.layout_switch_requested.connect(_on_layout_switch_requested)


func _on_layout_switch_requested(layout_name: String) -> void:
	"""Handle layout switch request from layout"""
	if has_node("LayoutManager"):
		var layout_manager_container = $LayoutManager
		var layout_type = 0
		match layout_name:
			"Custom":
				layout_type = 0
			"Detail":
				layout_type = 1
			"Overview":
				layout_type = 2
		layout_manager_container.switch_to_layout(layout_type)


## Public methods for target navigation (called by header buttons)
func select_previous_target() -> void:
	"""Select previous target (called by header < button)"""
	if target_manager and current_mode == 1:  # TARGET_PRACTICE
		target_manager.previous_target()


func select_next_target() -> void:
	"""Select next target (called by header > button)"""
	if target_manager and current_mode == 1:  # TARGET_PRACTICE
		target_manager.next_target()


func _on_auto_reset_setting_changed() -> void:
	"""Settings callback for auto reset changes"""
	pass  # The actual auto reset is handled in _on_golf_ball_rest
