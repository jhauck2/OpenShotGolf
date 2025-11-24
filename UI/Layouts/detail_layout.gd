extends Control

## Detail Layout - Full data view with 3D viewport, trajectory, table, and data tiles
## This is the "data-heavy" layout similar to TrackMan/FlightScope

signal layout_switch_requested(layout_name: String)
signal club_selected(club: String)
signal exit_pressed
signal camera_button_pressed
signal rec_button_pressed

# References to UI elements
var trajectory_graph: Control = null
var radar_view: Control = null
var data_tiles: Dictionary = {}  # Key = metric name, Value = DataTile node
var shot_counter_label: Label = null
var current_shot: int = 1
var total_shots: int = 0
var data_rows_container: VBoxContainer = null
var sub_viewport: SubViewport = null
var detail_viewport_camera: Camera3D = null  # Duplicate camera for SubViewport
var main_camera: Camera3D = null  # Reference to main Range camera for syncing

# Ball data
var ball_data: Dictionary = {}
var shot_history: Array[Dictionary] = []  # Global shot history


func _ready() -> void:
	_setup_ui()

	# Connect to GameState signals for live shot updates
	if GameState:
		GameState.shot_recorded.connect(_on_gamestate_shot_recorded)


func _process(_delta: float) -> void:
	# Sync viewport camera with main camera if both exist
	if detail_viewport_camera and main_camera:
		detail_viewport_camera.global_transform = main_camera.global_transform


func _setup_ui() -> void:
	# The structure is already defined in the .tscn file
	# Just get references to important nodes

	if has_node("MainHBox/LeftPanel/TrajectoryGraph"):
		trajectory_graph = $MainHBox/LeftPanel/TrajectoryGraph

	if has_node("MainHBox/RightSideStatus/RightSidebar/RadarColumn/RadarView"):
		radar_view = get_node("MainHBox/RightSideStatus/RightSidebar/RadarColumn/RadarView")

	# Get reference to SubViewport
	if has_node("MainHBox/LeftPanel/ViewportPanel/CameraContainer/SubViewport"):
		sub_viewport = $MainHBox/LeftPanel/ViewportPanel/CameraContainer/SubViewport
		# Make the container panel transparent so the viewport can be seen
		if has_node("MainHBox/LeftPanel/ViewportPanel"):
			var viewport_panel = get_node("MainHBox/LeftPanel/ViewportPanel")
			var stylebox_override = StyleBoxFlat.new()
			stylebox_override.bg_color = Color(0, 0, 0, 0)
			viewport_panel.add_theme_stylebox_override("panel", stylebox_override)

	# Get references to all data tiles
	_setup_data_tiles()

	# Get reference to data rows container
	var data_rows_path = "MainHBox/RightSideStatus/DataTablePanel/MarginContainer/VBoxContainer/ScrollContainer/DataRows"
	if has_node(data_rows_path):
		data_rows_container = get_node(data_rows_path)

	# Connect club selector - it's placed at the root level of the scene
	var club_selector = get_node_or_null("ClubSelector")
	if club_selector and club_selector.has_signal("club_selected"):
		club_selector.club_selected.connect(_on_club_selector_club_selected)

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

	# Setup shot navigation buttons
	_setup_shot_navigation()

	# Create a solid background to overlay the main 3D scene
	var bg_rect = ColorRect.new()
	bg_rect.color = Color(0.1, 0.1, 0.1, 1.0) # Dark grey, opaque
	bg_rect.anchor_right = 1.0
	bg_rect.anchor_bottom = 1.0
	add_child(bg_rect)
	move_child(bg_rect, 0) # Move to the back so it doesn't cover other UI


func _setup_data_tiles() -> void:
	# Get references to all the data tiles in the grid
	var tile_paths = {
		"Carry": "MainHBox/RightSideStatus/RightSidebar/DataColumn/Navigation/DataGrid/CarryTile",
		"Total": "MainHBox/RightSideStatus/RightSidebar/DataColumn/Navigation/DataGrid/TotalTile",
		"Roll": "MainHBox/RightSideStatus/RightSidebar/DataColumn/Navigation/DataGrid/RollTile",
		"BallSpeed": "MainHBox/RightSideStatus/RightSidebar/DataColumn/Navigation/DataGrid/BallSpeedTile",
		"ClubSpeed": "MainHBox/RightSideStatus/RightSidebar/DataColumn/Navigation/DataGrid/ClubSpeedTile",
		"Smash": "MainHBox/RightSideStatus/RightSidebar/DataColumn/Navigation/DataGrid/SmashTile",
		"VLaunch": "MainHBox/RightSideStatus/RightSidebar/DataColumn/Navigation/DataGrid/VLaunchTile",
		"Height": "MainHBox/RightSideStatus/RightSidebar/DataColumn/Navigation/DataGrid/HeightTile",
		"Descent": "MainHBox/RightSideStatus/RightSidebar/DataColumn/Navigation/DataGrid/DescentTile",
		"HLaunch": "MainHBox/RightSideStatus/RightSidebar/DataColumn/Navigation/DataGrid/HLaunchTile",
		"Lateral": "MainHBox/RightSideStatus/RightSidebar/DataColumn/Navigation/DataGrid/LateralTile",
		"Attack": "MainHBox/RightSideStatus/RightSidebar/DataColumn/Navigation/DataGrid/AttackTile",
		"Spin": "MainHBox/RightSideStatus/RightSidebar/DataColumn/Navigation/DataGrid/SpinTile",
		"SpinAxis": "MainHBox/RightSideStatus/RightSidebar/DataColumn/Navigation/DataGrid/SpinAxisTile",
	}

	for key in tile_paths:
		if has_node(tile_paths[key]):
			data_tiles[key] = get_node(tile_paths[key])


func update_data(data: Dictionary) -> void:
	ball_data = data

	# Update trajectory graph
	if trajectory_graph:
		if data.has("Carry") and data.has("Apex"):
			var carry = float(data.get("Carry", 0))
			var apex = float(data.get("Apex", 0)) / 3.0  # Convert feet to yards
			trajectory_graph.set_trajectory_data(carry, apex, float(data.get("Distance", 0)))

	# Update radar view
	if radar_view:
		if data.has("Carry"):
			var carry = float(data.get("Carry", 0))
			var offline_str = str(data.get("Offline", "0"))
			var lateral = _parse_offline(offline_str)
			radar_view.set_shot_data(carry, lateral, float(data.get("Distance", 0)))

	# Update data tiles
	_update_data_tiles(data)


func _update_data_tiles(data: Dictionary) -> void:
	# Red section (Power)
	if data_tiles.has("Carry"):
		data_tiles["Carry"].set_data("Carry", str(data.get("Carry", "---")), "yds", "Red")
	if data_tiles.has("Total"):
		data_tiles["Total"].set_data("Total", str(data.get("Distance", "---")), "yds", "Red")
	if data_tiles.has("Roll"):
		var carry = float(data.get("Carry", 0))
		var total = float(data.get("Distance", 0))
		var roll = total - carry
		data_tiles["Roll"].set_data("Roll", "%.1f" % roll, "yds", "Red")
	if data_tiles.has("BallSpeed"):
		data_tiles["BallSpeed"].set_data("Ball Spd", str(data.get("BallSpeed", "---")), "mph", "Red")
	if data_tiles.has("ClubSpeed"):
		data_tiles["ClubSpeed"].set_data("Club Spd", str(data.get("ClubSpeed", "---")), "mph", "Red")
	if data_tiles.has("Smash"):
		data_tiles["Smash"].set_data("Smash", str(data.get("Smash", "---")), "", "Red")

	# Green section (Launch)
	if data_tiles.has("VLaunch"):
		data_tiles["VLaunch"].set_data("V. Launch", "%.1f" % data.get("VLA", 0.0), "°", "Green")
	if data_tiles.has("Height"):
		var apex_ft = float(data.get("Apex", 0))
		data_tiles["Height"].set_data("Height", "%.1f" % (apex_ft / 3.0), "yds", "Green")
	if data_tiles.has("Descent"):
		data_tiles["Descent"].set_data("Descent", str(data.get("Descent", "---")), "°", "Green")
	if data_tiles.has("HLaunch"):
		data_tiles["HLaunch"].set_data("H. Launch", "%.1f" % data.get("HLA", 0.0), "°", "Green")
	if data_tiles.has("Lateral"):
		var offline_str = str(data.get("Offline", "0"))
		var lateral = _parse_offline(offline_str)
		data_tiles["Lateral"].set_data("Lateral", "%.1f" % lateral, "yds", "Green")
	if data_tiles.has("Attack"):
		data_tiles["Attack"].set_data("Attack", str(data.get("Attack", "---")), "°", "Green")

	# Blue section (Spin/Club)
	if data_tiles.has("Spin"):
		data_tiles["Spin"].set_data("Spin", str(data.get("TotalSpin", "---")), "rpm", "Blue")
	if data_tiles.has("SpinAxis"):
		data_tiles["SpinAxis"].set_data("Spin Axis", str(data.get("SpinAxis", "---")), "°", "Blue")


func _parse_offline(offline_str: String) -> float:
	# Parse "R10" or "L5" format to float (positive = right, negative = left)
	var value = 0.0
	if offline_str.begins_with("R"):
		value = float(offline_str.substr(1))
	elif offline_str.begins_with("L"):
		value = -float(offline_str.substr(1))
	return value


func _setup_shot_navigation() -> void:
	"""Setup shot navigation buttons and counter"""
	# Get shot navigation nodes
	var nav_path = "MainHBox/RightSideStatus/RightSidebar/DataColumn/Navigation/ShotNavigation"
	if has_node(nav_path):
		var shot_nav = get_node(nav_path)
		if shot_nav.has_node("PrevButton"):
			shot_nav.get_node("PrevButton").pressed.connect(_on_prev_shot_pressed)
		if shot_nav.has_node("NextButton"):
			shot_nav.get_node("NextButton").pressed.connect(_on_next_shot_pressed)
		if shot_nav.has_node("ShotCounter"):
			shot_counter_label = shot_nav.get_node("ShotCounter")
			_update_shot_counter()


func _on_prev_shot_pressed() -> void:
	"""Navigate to previous shot (left arrow = older shots, higher index numbers in array)"""
	if current_shot < total_shots:  # Can go older if not at oldest shot
		current_shot += 1
		_update_shot_counter()


func _on_next_shot_pressed() -> void:
	"""Navigate to next shot (right arrow = newer shots, lower index numbers in array)"""
	if current_shot > 1:  # Can go newer if not at newest shot
		current_shot -= 1
		_update_shot_counter()


func _update_shot_counter() -> void:
	"""Update the shot counter label"""
	if shot_counter_label:
		# Read directly from GameState as source of truth
		var total = GameState.shot_history.size() if GameState else total_shots
		shot_counter_label.text = "%d / %d" % [current_shot, total]


func _on_view_mode_pressed() -> void:
	var next_layout = "Overview"

	# If the layout manager has told us what to request, use that
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


func set_shot_history(history: Array[Dictionary]) -> void:
	"""Set the entire shot history from layout_manager (called on layout load)"""
	# Use GameState as source of truth instead of maintaining separate copy
	if GameState:
		shot_history = GameState.shot_history.duplicate()
	else:
		shot_history = history.duplicate()  # Fallback if GameState not available

	total_shots = shot_history.size()
	current_shot = total_shots  # Start at the most recent shot

	# Update the UI to display the history
	_update_shot_table()
	_update_shot_counter()


func add_shot_to_history(shot_data: Dictionary) -> void:
	# Sync with GameState as the source of truth
	if GameState:
		shot_history = GameState.shot_history.duplicate()
	else:
		# Fallback: add to local history if GameState not available
		shot_history.push_front(shot_data)
		if shot_history.size() > 10:
			shot_history.resize(10)

	total_shots = shot_history.size()
	current_shot = total_shots  # Set to the latest shot

	# Register this shot in the radar's historic shots (now that ball has landed)
	if radar_view and radar_view.has_method("register_shot_landed"):
		var carry = float(shot_data.get("Carry", 0))
		var offline_str = str(shot_data.get("Offline", "0"))
		var lateral = _parse_offline(offline_str)
		radar_view.register_shot_landed(carry, lateral)

	_update_shot_table()
	_update_shot_counter()  # Update the counter display


func _update_shot_table() -> void:
	if not data_rows_container:
		return

	# Clear all existing data rows (DataRows container has no static children)
	while data_rows_container.get_child_count() > 0:
		var child = data_rows_container.get_child(0)
		data_rows_container.remove_child(child)
		child.queue_free()

	# Read directly from GameState as source of truth (not local copy)
	var history_to_display = GameState.shot_history if GameState else shot_history

	# Show all shots in the history (most recent first)
	var shot_num = 1
	for shot in history_to_display:
		# Create a horizontal container for this shot row
		var row_container = HBoxContainer.new()
		row_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_container.add_theme_constant_override("separation", 0)  # No space between cells

		# Data to be added to the grid (using actual available fields)
		var shot_details = [
			str(shot_num),  # Shot number (1 = most recent)
			str(shot.get("Club", "---")),
			str(shot.get("Carry", "---")),
			str(shot.get("Distance", "---")),
			str(shot.get("Roll", "---")),
			str(shot.get("Offline", "---")),
			str(shot.get("Points", "---"))
		]

		# Add each detail as a label in this row
		for detail in shot_details:
			var label = Label.new()
			label.text = detail
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.custom_minimum_size = Vector2(0, 30)  # Ensure consistent height
			row_container.add_child(label)

		# Add the row to the data rows container
		data_rows_container.add_child(row_container)
		shot_num += 1


func setup_viewport_camera(camera: Camera3D) -> void:
	"""Configure the camera to render to this layout's SubViewport"""
	if not sub_viewport:
		return

	if not camera:
		return

	# CRITICAL: Share the main world with this SubViewport so it sees the game world
	var main_world = get_tree().root.get_viewport().world_3d
	if main_world == null:
		return

	sub_viewport.world_3d = main_world

	# Configure SubViewport rendering
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub_viewport.transparent_bg = false

	# Store the camera transform before duplicating
	var camera_transform = camera.global_transform

	# Create a duplicate camera for the SubViewport instead of moving the main camera
	# This keeps the main viewport showing the range and avoids issues with camera parenting
	var viewport_camera = camera.duplicate(true)
	viewport_camera.name = "DetailViewportCamera"
	viewport_camera.current = false  # Don't make it current yet

	# Add to SubViewport FIRST, then set the transform
	# (global_transform requires the node to be in the tree)
	sub_viewport.add_child(viewport_camera)

	# Now set the transform after it's in the tree
	viewport_camera.global_transform = camera_transform

	viewport_camera.current = true  # Now make it current for this viewport

	# Store references for cleanup and syncing later
	detail_viewport_camera = viewport_camera
	main_camera = camera



func cleanup_viewport_camera() -> void:
	"""Remove the duplicate camera from SubViewport"""
	if detail_viewport_camera:
		detail_viewport_camera.queue_free()
		detail_viewport_camera = null

	main_camera = null

	if sub_viewport:
		# Reset SubViewport world
		sub_viewport.world_3d = null


func update_main_camera_reference(new_camera: Camera3D) -> void:
	self.main_camera = new_camera

	# If we have an old viewport camera, remove it and create a new one from the new main camera
	if detail_viewport_camera and sub_viewport:
		sub_viewport.remove_child(detail_viewport_camera)
		detail_viewport_camera.queue_free()
		detail_viewport_camera = null

	# Create a new duplicate camera for the SubViewport from the new main camera
	if new_camera and sub_viewport:
		var camera_transform = new_camera.global_transform
		var viewport_camera = new_camera.duplicate(true)
		viewport_camera.name = "DetailViewportCamera"
		viewport_camera.current = false

		# Add to SubViewport FIRST, then set the transform
		sub_viewport.add_child(viewport_camera)
		viewport_camera.global_transform = camera_transform
		viewport_camera.current = true

		detail_viewport_camera = viewport_camera


func _on_gamestate_shot_recorded(shot_data: Dictionary) -> void:
	"""Handle shots recorded from GameState"""
	add_shot_to_history(shot_data)
