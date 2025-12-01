extends Node3D

enum LayoutType {
	DEFAULT = 0,
	OVERVIEW = 1,
}

const LAYOUT_PATHS = {
	LayoutType.DEFAULT: "res://UI/Layouts/default_layout.tscn",
	LayoutType.OVERVIEW: "res://UI/Layouts/overview_layout.tscn",
}

const LAYOUT_NAMES = {
	LayoutType.DEFAULT: "default",
	LayoutType.OVERVIEW: "overview",
}

var track_points : bool = false
var trail_timer : float = 0.0
var trail_resolution : float = 0.1
var apex := 0
var ball_data: Dictionary = {"Distance": "---", "Carry": "---", "Offline": "---", "Apex": "---", "VLA": 0.0, "HLA": 0.0}
var ball_reset_time := 5.0
var auto_reset_enabled := false

var layout_container: Control = null
var current_layout_type: LayoutType = LayoutType.DEFAULT
var available_layout_types: Array[LayoutType] = [LayoutType.DEFAULT, LayoutType.OVERVIEW]
var current_layout_index: int = 0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$PhantomCamera3D.follow_target = $Player/Ball
	GlobalSettings.range_settings.camera_follow_mode.setting_changed.connect(set_camera_follow_mode)

	_setup_layout_system()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_L:
			_cycle_layout()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	var m2yd = 1.09361 # Meters to yards
	if GlobalSettings.range_settings.range_units.value == Enums.Units.IMPERIAL:
		ball_data["Distance"] = str(int($Player.get_distance()*m2yd))
		ball_data["Carry"] = str(int($Player.carry*m2yd))
		ball_data["Apex"] = str(int($Player.apex*3*m2yd))
		var offline = int($Player.get_offline()*m2yd)
		var offline_text := "R"
		if offline < 0:
			offline_text = "L"
		offline_text += str(abs(offline))
		ball_data["Offline"] = offline_text
	else:
		ball_data["Distance"] = str($Player.get_distance())
		ball_data["Carry"] = str($Player.carry)
		ball_data["Apex"] = str($Player.apex)
		var offline = $Player.get_offline()
		var offline_text := "R"
		if offline < 0:
			offline_text = "L"
		offline_text += str(abs(offline))
		ball_data["Offline"] = offline_text
	
	update_layout_data(ball_data)


func _on_tcp_client_hit_ball(data: Dictionary) -> void:
	ball_data = data.duplicate()


func _on_golf_ball_rest(_ball_data) -> void:
	if GlobalSettings.range_settings.auto_ball_reset.value:
		await get_tree().create_timer(GlobalSettings.range_settings.ball_reset_timer.value).timeout
		$Player.reset_ball()
		ball_data["HLA"] = 0.0
		ball_data["VLA"] = 0.0
		
func set_camera_follow_mode() -> void:
	if GlobalSettings.range_settings.camera_follow_mode.value:
		$PhantomCamera3D.follow_mode = 5 # Framed
		$PhantomCamera3D.follow_target = $Player/Ball
	else:
		$PhantomCamera3D.follow_mode = 0 # None


func _setup_layout_system() -> void:
	if not has_node("LayoutContainer"):
		layout_container = Control.new()
		layout_container.name = "LayoutContainer"
		layout_container.layout_mode = 1
		layout_container.anchors_preset = Control.PRESET_FULL_RECT
		add_child(layout_container)
	else:
		layout_container = $LayoutContainer

	for layout_type in available_layout_types:
		var layout_path = LAYOUT_PATHS[layout_type]
		var layout_name = LAYOUT_NAMES[layout_type]

		var layout_scene = load(layout_path)
		var layout = layout_scene.instantiate()
		layout.name = layout_name.capitalize() + "Layout"

		if layout.has_method("set_range"):
			layout.set_range(self)

		layout_container.add_child(layout)
		layout.hide()

	_switch_active_layout(LayoutType.DEFAULT)


func _switch_active_layout(layout_type: LayoutType) -> void:
	if layout_type not in available_layout_types:
		push_error("Layout type '%s' not found" % layout_type)
		return

	var current_layout_name = LAYOUT_NAMES[current_layout_type]
	if current_layout_name != "":
		var current_layout_node = layout_container.get_node_or_null(current_layout_name.capitalize() + "Layout")
		if current_layout_node:
			if current_layout_node.has_method("deactivate"):
				current_layout_node.deactivate()
			current_layout_node.hide()

	var new_layout_name = LAYOUT_NAMES[layout_type]
	var new_layout_node = layout_container.get_node_or_null(new_layout_name.capitalize() + "Layout")
	if new_layout_node:
		if new_layout_node.has_method("activate"):
			new_layout_node.activate()
		new_layout_node.show()

	current_layout_type = layout_type
	print("Switched to layout: %s" % new_layout_name)


func switch_layout(layout_type: LayoutType) -> void:
	_switch_active_layout(layout_type)


func _cycle_layout() -> void:
	current_layout_index = (current_layout_index + 1) % available_layout_types.size()
	var next_layout_type = available_layout_types[current_layout_index]
	_switch_active_layout(next_layout_type)


func _on_layout_club_selected(club: String) -> void:
	print("Club selected from layout: %s" % club)


func _get_active_layout() -> Control:
	var layout_name = LAYOUT_NAMES[current_layout_type]
	return layout_container.get_node_or_null(layout_name.capitalize() + "Layout")


func update_layout_data(data: Dictionary) -> void:
	var active_layout = _get_active_layout()
	if active_layout and active_layout.has_method("update_data"):
		active_layout.update_data(data)
