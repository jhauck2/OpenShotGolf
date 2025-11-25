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

	if has_node("GolfBall/Ball"):
		camera_controller.set_ball_target($GolfBall/Ball)

	camera_controller.camera_changed.connect(_on_camera_changed)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	var m2yd = 1.09361 # Meters to yards
	if GlobalSettings.range_settings.range_units.value == Enums.Units.IMPERIAL:
		ball_data["Distance"] = str(int($GolfBall.get_distance()*m2yd))
		ball_data["Carry"] = str(int($GolfBall.carry*m2yd))
		ball_data["Apex"] = str(int($GolfBall.apex*3*m2yd))
		var offline = int($GolfBall.get_offline()*m2yd)
		var offline_text := "R"
		if offline < 0:
			offline_text = "L"
		offline_text += str(abs(offline))
		ball_data["Offline"] = offline_text
	else:
		ball_data["Distance"] = str($GolfBall.get_distance())
		ball_data["Carry"] = str($GolfBall.carry)
		ball_data["Apex"] = str($GolfBall.apex)
		var offline = $GolfBall.get_offline()
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
		camera_controller.set_camera_mode(CameraController.CameraMode.BEHIND_BALL)
	elif Input.is_action_just_pressed("ui_2"):
		camera_controller.set_camera_mode(CameraController.CameraMode.DOWN_THE_LINE)
	elif Input.is_action_just_pressed("ui_3"):
		camera_controller.set_camera_mode(CameraController.CameraMode.FACE_ON)
	elif Input.is_action_just_pressed("ui_4"):
		camera_controller.set_camera_mode(CameraController.CameraMode.BIRDS_EYE)
	elif Input.is_action_just_pressed("ui_5"):
		camera_controller.set_camera_mode(CameraController.CameraMode.FOLLOW_BALL)
	elif Input.is_action_just_pressed("ui_c"):
		camera_controller.next_camera()


func _on_tcp_client_hit_ball(data: Dictionary) -> void:
	ball_data = data.duplicate()


func _on_golf_ball_rest(_ball_data) -> void:
	if GlobalSettings.range_settings.auto_ball_reset.value:
		await get_tree().create_timer(GlobalSettings.range_settings.ball_reset_timer.value).timeout
		$GolfBall.reset_ball()
		ball_data["HLA"] = 0.0
		ball_data["VLA"] = 0.0


func _on_camera_changed(camera_name: String) -> void:
	print("Camera switched to: %s" % camera_name)
