extends Control

const MAX_SHOT_HISTORY = 10
const BACKGROUND_COLOR = Color(0.1, 0.1, 0.1, 1.0)
const VIEWPORT_TRANSPARENT_COLOR = Color(0, 0, 0, 0)
const SHOT_ROW_HEIGHT = 30.0
const ROW_SEPARATOR_WIDTH = 0
const APEX_FEET_TO_YARDS = 3.0

const TRAJECTORY_GRAPH_PATH = "MainHBox/LeftPanel/TrajectoryGraph"
const RADAR_VIEW_PATH = "MainHBox/RightSideStatus/RightSidebar/RadarColumn/RadarView"
const VIEWPORT_PATH = "MainHBox/LeftPanel/ViewportPanel/CameraContainer/SubViewport"
const VIEWPORT_PANEL_PATH = "MainHBox/LeftPanel/ViewportPanel"
const DATA_ROWS_PATH = "MainHBox/RightSideStatus/DataTablePanel/MarginContainer/VBoxContainer/ScrollContainer/DataRows"
const SHOT_NAVIGATION_PATH = "MainHBox/RightSideStatus/RightSidebar/DataColumn/Navigation/ShotNavigation"

const DATA_TILE_PATHS = {
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

signal layout_switch_requested(layout_name: String)
signal club_selected(club: String)
signal exit_pressed
signal camera_button_pressed
signal rec_button_pressed
signal settings_pressed

var trajectory_graph: Control = null
var radar_view: Control = null
var data_tiles: Dictionary = {}
var shot_counter_label: Label = null
var current_shot: int = 1
var total_shots: int = 0
var data_rows_container: VBoxContainer = null
var sub_viewport: SubViewport = null
var detail_viewport_camera: Camera3D = null
var main_camera: Camera3D = null

var ball_data: Dictionary = {}
var shot_history: Array[Dictionary] = []
var range_ref: Node = null


func _ready() -> void:
	_setup_ui()


func set_range(range_node: Node) -> void:
	range_ref = range_node


func activate() -> void:
	visible = true
	setup_viewport_world()


func deactivate() -> void:
	visible = false
	cleanup_viewport_world()


func _process(_delta: float) -> void:
	_sync_viewport_camera()


func _setup_ui() -> void:
	_setup_graph_references()
	_setup_viewport()
	_setup_data_tiles()
	_setup_data_rows_container()
	_setup_club_selector()
	_setup_header_signals()
	_setup_shot_navigation()
	_create_background()


func _setup_graph_references() -> void:
	if has_node(TRAJECTORY_GRAPH_PATH):
		trajectory_graph = get_node(TRAJECTORY_GRAPH_PATH)

	if has_node(RADAR_VIEW_PATH):
		radar_view = get_node(RADAR_VIEW_PATH)


func _setup_viewport() -> void:
	if has_node(VIEWPORT_PATH):
		sub_viewport = get_node(VIEWPORT_PATH)

	if has_node(VIEWPORT_PANEL_PATH):
		var viewport_panel = get_node(VIEWPORT_PANEL_PATH)
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = VIEWPORT_TRANSPARENT_COLOR
		viewport_panel.add_theme_stylebox_override("panel", stylebox)


func _setup_data_rows_container() -> void:
	if has_node(DATA_ROWS_PATH):
		data_rows_container = get_node(DATA_ROWS_PATH)


func _setup_club_selector() -> void:
	var club_selector = get_node_or_null("ClubSelector")
	if club_selector and club_selector.has_signal("club_selected"):
		if not club_selector.is_connected("club_selected", Callable(self, "_on_club_selector_club_selected")):
			club_selector.club_selected.connect(_on_club_selector_club_selected)


func _setup_header_signals() -> void:
	if has_node("Header"):
		var header = $Header
		if header.has_signal("camera_pressed"):
			header.camera_pressed.connect(func(): emit_signal("camera_button_pressed"))
		if header.has_signal("rec_button_pressed"):
			header.rec_button_pressed.connect(func(): emit_signal("rec_button_pressed"))
		if header.has_signal("exit_pressed"):
			header.exit_pressed.connect(func(): emit_signal("exit_pressed"))
		if header.has_signal("settings_pressed"):
			header.settings_pressed.connect(func(): emit_signal("settings_pressed"))


func _create_background() -> void:
	var bg_rect = ColorRect.new()
	bg_rect.color = BACKGROUND_COLOR
	bg_rect.anchor_right = 1.0
	bg_rect.anchor_bottom = 1.0
	add_child(bg_rect)
	move_child(bg_rect, 0)


func _setup_data_tiles() -> void:
	for tile_name in DATA_TILE_PATHS:
		if has_node(DATA_TILE_PATHS[tile_name]):
			data_tiles[tile_name] = get_node(DATA_TILE_PATHS[tile_name])


func update_data(data: Dictionary) -> void:
	ball_data = data
	_update_trajectory_graph(data)
	_update_radar_view(data)
	_update_data_tiles(data)


func _update_trajectory_graph(data: Dictionary) -> void:
	if not trajectory_graph or not data.has("Carry") or not data.has("Apex"):
		return

	var carry = float(data.get("Carry", 0))
	var apex = float(data.get("Apex", 0)) / APEX_FEET_TO_YARDS
	trajectory_graph.set_trajectory_data(carry, apex, float(data.get("Distance", 0)))


func _update_radar_view(data: Dictionary) -> void:
	if not radar_view or not data.has("Carry"):
		return

	var carry = float(data.get("Carry", 0))
	var offline_str = str(data.get("Offline", "0"))
	var lateral = _parse_offline(offline_str)
	radar_view.set_shot_data(carry, lateral, float(data.get("Distance", 0)))


func _update_data_tiles(data: Dictionary) -> void:
	_update_power_tiles(data)
	_update_launch_tiles(data)
	_update_spin_tiles(data)


func _update_power_tiles(data: Dictionary) -> void:
	if data_tiles.has("Carry"):
		data_tiles["Carry"].set_data("Carry", str(data.get("Carry", "---")), "yds", "Red")
	if data_tiles.has("Total"):
		data_tiles["Total"].set_data("Total", str(data.get("Distance", "---")), "yds", "Red")
	if data_tiles.has("Roll"):
		var roll = float(data.get("Distance", 0)) - float(data.get("Carry", 0))
		data_tiles["Roll"].set_data("Roll", "%.1f" % roll, "yds", "Red")
	if data_tiles.has("BallSpeed"):
		data_tiles["BallSpeed"].set_data("Ball Spd", str(data.get("BallSpeed", "---")), "mph", "Red")
	if data_tiles.has("ClubSpeed"):
		data_tiles["ClubSpeed"].set_data("Club Spd", str(data.get("ClubSpeed", "---")), "mph", "Red")
	if data_tiles.has("Smash"):
		data_tiles["Smash"].set_data("Smash", str(data.get("Smash", "---")), "", "Red")


func _update_launch_tiles(data: Dictionary) -> void:
	if data_tiles.has("VLaunch"):
		data_tiles["VLaunch"].set_data("V. Launch", "%.1f" % data.get("VLA", 0.0), "°", "Green")
	if data_tiles.has("Height"):
		var apex_yards = float(data.get("Apex", 0)) / APEX_FEET_TO_YARDS
		data_tiles["Height"].set_data("Height", "%.1f" % apex_yards, "yds", "Green")
	if data_tiles.has("Descent"):
		data_tiles["Descent"].set_data("Descent", str(data.get("Descent", "---")), "°", "Green")
	if data_tiles.has("HLaunch"):
		data_tiles["HLaunch"].set_data("H. Launch", "%.1f" % data.get("HLA", 0.0), "°", "Green")
	if data_tiles.has("Lateral"):
		var lateral = _parse_offline(str(data.get("Offline", "0")))
		data_tiles["Lateral"].set_data("Lateral", "%.1f" % lateral, "yds", "Green")
	if data_tiles.has("Attack"):
		data_tiles["Attack"].set_data("Attack", str(data.get("Attack", "---")), "°", "Green")


func _update_spin_tiles(data: Dictionary) -> void:
	if data_tiles.has("Spin"):
		data_tiles["Spin"].set_data("Spin", str(data.get("TotalSpin", "---")), "rpm", "Blue")
	if data_tiles.has("SpinAxis"):
		data_tiles["SpinAxis"].set_data("Spin Axis", str(data.get("SpinAxis", "---")), "°", "Blue")


func _parse_offline(offline_str: String) -> float:
	if offline_str.begins_with("R"):
		return float(offline_str.substr(1))
	elif offline_str.begins_with("L"):
		return -float(offline_str.substr(1))
	return 0.0


func _setup_shot_navigation() -> void:
	if has_node(SHOT_NAVIGATION_PATH):
		var shot_nav = get_node(SHOT_NAVIGATION_PATH)
		if shot_nav.has_node("PrevButton"):
			shot_nav.get_node("PrevButton").pressed.connect(_on_prev_shot_pressed)
		if shot_nav.has_node("NextButton"):
			shot_nav.get_node("NextButton").pressed.connect(_on_next_shot_pressed)
		if shot_nav.has_node("ShotCounter"):
			shot_counter_label = shot_nav.get_node("ShotCounter")
			_update_shot_counter()


func _on_prev_shot_pressed() -> void:
	if current_shot < total_shots:
		current_shot += 1
		_update_shot_counter()


func _on_next_shot_pressed() -> void:
	if current_shot > 1:
		current_shot -= 1
		_update_shot_counter()


func _update_shot_counter() -> void:
	if shot_counter_label:
		shot_counter_label.text = "%d / %d" % [current_shot, total_shots]


func _on_view_mode_pressed() -> void:
	var next_layout = "Overview"
	if has_meta("next_layout"):
		next_layout = get_meta("next_layout")
	emit_signal("layout_switch_requested", next_layout)


func _on_exit_pressed() -> void:
	emit_signal("exit_pressed")


func _on_camera_button_pressed() -> void:
	emit_signal("camera_button_pressed")


func _on_rec_button_pressed() -> void:
	emit_signal("rec_button_pressed")


func _on_settings_button_pressed() -> void:
	pass


func _on_club_selector_club_selected(club: String) -> void:
	emit_signal("club_selected", club)


func set_shot_history(history: Array[Dictionary]) -> void:
	shot_history = history.duplicate()
	total_shots = shot_history.size()
	current_shot = total_shots
	_update_shot_table()
	_update_shot_counter()


func add_shot_to_history(shot_data: Dictionary) -> void:
	shot_history.push_front(shot_data)
	if shot_history.size() > MAX_SHOT_HISTORY:
		shot_history.resize(MAX_SHOT_HISTORY)

	total_shots = shot_history.size()
	current_shot = total_shots

	if radar_view and radar_view.has_method("register_shot_landed"):
		var carry = float(shot_data.get("Carry", 0))
		var lateral = _parse_offline(str(shot_data.get("Offline", "0")))
		radar_view.register_shot_landed(carry, lateral)

	_update_shot_table()
	_update_shot_counter()


func _update_shot_table() -> void:
	if not data_rows_container:
		return

	_clear_shot_rows()

	var shot_num = 1
	for shot in shot_history:
		_create_shot_row(shot, shot_num)
		shot_num += 1


func _clear_shot_rows() -> void:
	while data_rows_container.get_child_count() > 0:
		var child = data_rows_container.get_child(0)
		data_rows_container.remove_child(child)
		child.queue_free()


func _create_shot_row(shot: Dictionary, shot_num: int) -> void:
	var row_container = HBoxContainer.new()
	row_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_container.add_theme_constant_override("separation", ROW_SEPARATOR_WIDTH)

	var shot_details = [
		str(shot_num),
		str(shot.get("Club", "---")),
		str(shot.get("Carry", "---")),
		str(shot.get("Distance", "---")),
		str(shot.get("Roll", "---")),
		str(shot.get("Offline", "---")),
		str(shot.get("Points", "---"))
	]

	for detail in shot_details:
		var label = Label.new()
		label.text = detail
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.custom_minimum_size = Vector2(0, SHOT_ROW_HEIGHT)
		row_container.add_child(label)

	data_rows_container.add_child(row_container)


func setup_viewport_world() -> void:
	if not sub_viewport:
		return

	var main_world = get_tree().root.get_viewport().world_3d
	if main_world == null:
		return

	sub_viewport.world_3d = main_world
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub_viewport.transparent_bg = false

	_create_viewport_camera()


func _create_viewport_camera() -> void:
	if not sub_viewport:
		return

	var camera_in_viewport = sub_viewport.get_child(0) if sub_viewport.get_child_count() > 0 else null
	if not camera_in_viewport or not camera_in_viewport is Camera3D:
		var new_camera = Camera3D.new()
		new_camera.name = "DetailViewportCamera"
		sub_viewport.add_child(new_camera)
		new_camera.current = true
		detail_viewport_camera = new_camera


func cleanup_viewport_world() -> void:
	if sub_viewport:
		sub_viewport.world_3d = null

	if detail_viewport_camera:
		detail_viewport_camera.queue_free()
		detail_viewport_camera = null


func update_main_camera_reference(new_camera: Camera3D) -> void:
	self.main_camera = new_camera
	_replace_viewport_camera(new_camera)


func _replace_viewport_camera(new_camera: Camera3D) -> void:
	if detail_viewport_camera and sub_viewport:
		sub_viewport.remove_child(detail_viewport_camera)
		detail_viewport_camera.queue_free()
		detail_viewport_camera = null

	if new_camera and sub_viewport:
		var viewport_camera = new_camera.duplicate(true)
		viewport_camera.name = "DetailViewportCamera"
		viewport_camera.current = false
		sub_viewport.add_child(viewport_camera)
		viewport_camera.global_transform = new_camera.global_transform
		viewport_camera.current = true
		detail_viewport_camera = viewport_camera


func _sync_viewport_camera() -> void:
	if not detail_viewport_camera or not range_ref:
		return

	if range_ref.has_node("Camera3D"):
		var range_camera = range_ref.get_node("Camera3D")
		if range_camera:
			detail_viewport_camera.global_transform = range_camera.global_transform
