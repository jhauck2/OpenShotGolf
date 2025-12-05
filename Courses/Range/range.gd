extends Node3D

var track_points : bool = false
var trail_timer : float = 0.0
var trail_resolution : float = 0.1
var apex := 0
var display_data: Dictionary = {
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
var last_display: Dictionary = {}


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$PhantomCamera3D.follow_target = $Player/Ball
	GlobalSettings.range_settings.camera_follow_mode.setting_changed.connect(set_camera_follow_mode)
	GlobalSettings.range_settings.surface_type.setting_changed.connect(_on_surface_changed)
	_apply_surface_to_ball()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset"):
		_reset_display_data()
		$RangeUI.set_data(display_data)


func _on_tcp_client_hit_ball(data: Dictionary) -> void:
	raw_ball_data = data.duplicate()
	_update_ball_display()


func _process(_delta: float) -> void:
	# Refresh UI during flight/rollout so carry/apex update live; distance updates only at rest.
	if $Player.get_ball_state() != Enums.BallState.REST:
		_update_ball_display()


func _on_golf_ball_rest(_ball_data) -> void:
	raw_ball_data = _ball_data.duplicate()
	# Show final shot numbers immediately on rest
	_update_ball_display()
	# Show final total distance once ball is fully at rest. Good indicator ball stopped.
	if display_data.has("Distance"):
		$RangeUI.set_total_distance("Total Distance " + str(display_data["Distance"]))
	
	if GlobalSettings.range_settings.auto_ball_reset.value:
		await get_tree().create_timer(GlobalSettings.range_settings.ball_reset_timer.value).timeout
		_reset_display_data()
		$RangeUI.set_data(display_data)
		$Player.reset_ball()
		return
	
	# No auto reset: leave final numbers visible

func set_camera_follow_mode(value) -> void:
	if value:
		$PhantomCamera3D.follow_mode = 5 # Framed
		$PhantomCamera3D.follow_target = $Player/Ball
	else:
		$PhantomCamera3D.follow_mode = 0 # None


func _on_range_ui_hit_shot(data: Dictionary) -> void:
	# For local injected shots, prime the display immediately with the payload data.
	raw_ball_data = data.duplicate()
	_update_ball_display()
	$RangeUI.clear_total_distance()


func _apply_surface_to_ball() -> void:
	if $Player.has_node("Ball"):
		$Player/Ball.set_surface(GlobalSettings.range_settings.surface_type.value)


func _on_surface_changed(value) -> void:
	if $Player.has_node("Ball"):
		$Player/Ball.set_surface(value)


func _reset_display_data() -> void:
	raw_ball_data.clear()
	last_display.clear()
	display_data["Distance"] = "---"
	display_data["Carry"] = "---"
	display_data["Offline"] = "---"
	display_data["Apex"] = "---"
	display_data["VLA"] = 0.0
	display_data["HLA"] = 0.0
	display_data["Speed"] = "---"
	display_data["BackSpin"] = "---"
	display_data["SideSpin"] = "---"
	display_data["TotalSpin"] = "---"
	display_data["SpinAxis"] = "---"
	$RangeUI.clear_total_distance()


func _update_ball_display() -> void:
	# Show distance continuously (updates during flight/rollout, final at rest)
	var show_distance: bool = true
	display_data = ShotFormatter.format_ball_display(raw_ball_data, $Player, GlobalSettings.range_settings.range_units.value, show_distance, display_data)
	last_display = display_data.duplicate()
	$RangeUI.set_data(display_data)
	
