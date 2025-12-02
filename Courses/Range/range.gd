extends Node3D

var track_points : bool = false
var trail_timer : float = 0.0
var trail_resolution : float = 0.1
var apex := 0
var ball_data: Dictionary = {"Distance": "---", "Carry": "---", "Offline": "---", "Apex": "---", "VLA": 0.0, "HLA": 0.0}
var ball_reset_time := 5.0
var auto_reset_enabled := false

var camera_controller: CameraController = null


func _ready() -> void:
	_setup_camera_system()


func _setup_camera_system() -> void:
	if has_node("PhantomCamera3D"):
		$PhantomCamera3D.queue_free()

	camera_controller = CameraController.new()
	camera_controller.name = "CameraController"
	add_child(camera_controller)

	if has_node("Player/Ball"):
		camera_controller.set_ball_target($Player/Ball)

	camera_controller.camera_changed.connect(_on_camera_changed)
	GlobalSettings.range_settings.camera_follow_mode.setting_changed.connect(set_camera_follow_mode)


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
	
	$RangeUI.set_data(ball_data)

	_handle_camera_input()


func _handle_camera_input() -> void:
	if not camera_controller:
		return

	if Input.is_action_just_pressed("ui_1"):
		_reset_camera_toggle()
		camera_controller.set_camera_mode(CameraController.CameraMode.BEHIND_BALL)
	elif Input.is_action_just_pressed("ui_2"):
		_reset_camera_toggle()
		camera_controller.set_camera_mode(CameraController.CameraMode.DOWN_THE_LINE)
	elif Input.is_action_just_pressed("ui_3"):
		_reset_camera_toggle()
		camera_controller.set_camera_mode(CameraController.CameraMode.FACE_ON)
	elif Input.is_action_just_pressed("ui_4"):
		_reset_camera_toggle()
		camera_controller.set_camera_mode(CameraController.CameraMode.BIRDS_EYE)
	elif Input.is_action_just_pressed("ui_5"):
		_reset_camera_toggle(true)
		camera_controller.set_camera_mode(CameraController.CameraMode.FOLLOW_BALL)
	elif Input.is_action_just_pressed("ui_c"):
		_reset_camera_toggle()
		camera_controller.next_camera()


func _on_tcp_client_hit_ball(data: Dictionary) -> void:
	ball_data = data.duplicate()


func _on_golf_ball_rest(_ball_data) -> void:
	if GlobalSettings.range_settings.auto_ball_reset.value:
		await get_tree().create_timer(GlobalSettings.range_settings.ball_reset_timer.value).timeout
		$Player.reset_ball()
		ball_data["HLA"] = 0.0
		ball_data["VLA"] = 0.0


func _reset_camera_toggle(toggled_on: bool = false) -> void:
	GlobalSettings.range_settings.camera_follow_mode.set_value(toggled_on)

func _on_camera_changed(_camera_name: String) -> void:
	pass
		

func set_camera_follow_mode(_value) -> void:
	if GlobalSettings.range_settings.camera_follow_mode.value:
		camera_controller.set_camera_mode(CameraController.CameraMode.FOLLOW_BALL)
	else:
		camera_controller.set_camera_mode(CameraController.CameraMode.BEHIND_BALL)
	
