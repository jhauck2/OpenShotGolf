extends Node3D

var track_points : bool = false
var trail_timer : float = 0.0
var trail_resolution : float = 0.1
var apex := 0
var ball_data: Dictionary = {"Distance": "---", "Carry": "---", "Offline": "---", "Apex": "---", "VLA": 0.0, "HLA": 0.0}
var ball_reset_time := 5.0
var auto_reset_enabled := false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$PhantomCamera3D.follow_target = $Player/Ball
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


func _on_tcp_client_hit_ball(data: Dictionary) -> void:
	ball_data = data.duplicate()


func _on_golf_ball_rest(_ball_data) -> void:
	if GlobalSettings.range_settings.auto_ball_reset.value:
		await get_tree().create_timer(GlobalSettings.range_settings.ball_reset_timer.value).timeout
		$Player.reset_ball()
		ball_data["HLA"] = 0.0
		ball_data["VLA"] = 0.0
		
func set_camera_follow_mode(value) -> void:
	if value:
		$PhantomCamera3D.follow_mode = 5 # Framed
		$PhantomCamera3D.follow_target = $Player/Ball
	else:
		$PhantomCamera3D.follow_mode = 0 # None
	
