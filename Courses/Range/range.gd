extends Node3D

var track_points : bool = false
var trail_timer : float = 0.0
var trail_resolution : float = 0.1
var apex := 0
var ball_data: Dictionary = {
	"Distance": "---",
	"Carry": "---",
	"Offline": "---",
	"Apex": "---",
	"VLA": 0.0,
	"HLA": 0.0,
	"Speed": "---",
	"BackSpin": "---",
	"SideSpin": "---",
	"TotalSpin": "---",
	"SpinAxis": "---"
}
var ball_reset_time := 5.0
var auto_reset_enabled := false
var raw_ball_data: Dictionary = {}


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$PhantomCamera3D.follow_target = $Player/Ball
	GlobalSettings.range_settings.camera_follow_mode.setting_changed.connect(set_camera_follow_mode)
	GlobalSettings.range_settings.surface_type.setting_changed.connect(_on_surface_changed)
	_apply_surface_to_ball()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	var m2yd = 1.09361 # Meters to yards
	var backspin: float = raw_ball_data.get("BackSpin", raw_ball_data.get("TotalSpin", 0.0)) as float
	var sidespin: float = raw_ball_data.get("SideSpin", 0.0) as float
	var total_spin: float = raw_ball_data.get("TotalSpin", 0.0) as float
	if total_spin == 0.0 and (backspin != 0.0 or sidespin != 0.0):
		total_spin = sqrt(backspin*backspin + sidespin*sidespin)
	var spin_axis: float = raw_ball_data.get("SpinAxis", 0.0) as float
	if spin_axis == 0.0 and (backspin != 0.0 or sidespin != 0.0):
		spin_axis = rad_to_deg(atan2(sidespin, backspin))

	if GlobalSettings.range_settings.range_units.value == Enums.Units.IMPERIAL:
		ball_data["Distance"] = str(int($Player.get_distance()*m2yd))
		ball_data["Carry"] = str(int($Player.carry*m2yd))
		ball_data["Apex"] = str(int($Player.apex*3.28084))
		var offline = int($Player.get_offline()*m2yd)
		var offline_text := "R"
		if offline < 0:
			offline_text = "L"
		offline_text += str(abs(offline))
		ball_data["Offline"] = offline_text
		# Ball speed expected in mph from LM; keep as-is
		ball_data["Speed"] = "%3.1f" % raw_ball_data.get("Speed", 0.0)
	else:
		ball_data["Distance"] = str($Player.get_distance())
		ball_data["Carry"] = str(int($Player.carry))
		ball_data["Apex"] = str(int($Player.apex))
		var offline = $Player.get_offline()
		var offline_text := "R"
		if offline < 0:
			offline_text = "L"
		offline_text += str(abs(offline))
		ball_data["Offline"] = offline_text
		# Convert mph -> m/s for display
		ball_data["Speed"] = "%3.1f" % (raw_ball_data.get("Speed", 0.0) * 0.44704)
		
	ball_data["BackSpin"] = str(int(backspin))
	ball_data["SideSpin"] = str(int(sidespin))
	ball_data["TotalSpin"] = str(int(total_spin))
	ball_data["SpinAxis"] = "%3.1f" % spin_axis
	
	$RangeUI.set_data(ball_data)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset"):
		_reset_display_data()
		$RangeUI.set_data(ball_data)


func _on_tcp_client_hit_ball(data: Dictionary) -> void:
	raw_ball_data = data.duplicate()
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


func _apply_surface_to_ball() -> void:
	if $Player.has_node("Ball"):
		$Player/Ball.set_surface(GlobalSettings.range_settings.surface_type.value)


func _on_surface_changed(value) -> void:
	if $Player.has_node("Ball"):
		$Player/Ball.set_surface(value)


func _reset_display_data() -> void:
	raw_ball_data.clear()
	ball_data["Distance"] = "---"
	ball_data["Carry"] = "---"
	ball_data["Offline"] = "---"
	ball_data["Apex"] = "---"
	ball_data["VLA"] = 0.0
	ball_data["HLA"] = 0.0
	ball_data["Speed"] = "---"
	ball_data["BackSpin"] = "---"
	ball_data["SideSpin"] = "---"
	ball_data["TotalSpin"] = "---"
	ball_data["SpinAxis"] = "---"
	
