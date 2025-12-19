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
	"VLA": "---",
	"HLA": "---",
	"Speed": "---",
	"BackSpin": "---",
	"SideSpin": "---",
	"TotalSpin": "---",
	"SpinAxis": "---"
}
var raw_ball_data: Dictionary = {}
var last_display: Dictionary = {}


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GlobalSettings.range_settings.camera_follow_mode.setting_changed.connect(set_camera_follow_mode)
	set_camera_follow_mode(GlobalSettings.range_settings.camera_follow_mode.value)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset"):
		_reset_display_data()
		$RangeUI.set_data(display_data)


func _on_tcp_client_hit_ball(data: Dictionary) -> void:
	raw_ball_data = data.duplicate()
	_update_ball_display()

	# Re-enable camera follow if the setting is on
	if GlobalSettings.range_settings.camera_follow_mode.value:
		set_camera_follow_mode(true)


func _process(_delta: float) -> void:
	# Refresh UI during flight/rollout so carry/apex update live; distance updates only at rest.
	if $Player.get_ball_state() != GolfBall.BallState.REST:
		_update_ball_display()


func _on_golf_ball_rest(_ball_data) -> void:
	raw_ball_data = _ball_data.duplicate()
	# Show final shot numbers immediately on rest
	_update_ball_display()

	# Return camera to starting position if follow mode is enabled
	if GlobalSettings.range_settings.camera_follow_mode.value:
		var camera_reset_delay: float = GlobalSettings.range_settings.ball_reset_timer.value
		await get_tree().create_timer(camera_reset_delay).timeout
		reset_camera_to_start()

	if GlobalSettings.range_settings.auto_ball_reset.value:
		await get_tree().create_timer(GlobalSettings.range_settings.ball_reset_timer.value).timeout
		_reset_display_data()
		$RangeUI.set_data(display_data)
		$Player.reset_ball()
		return

	# No auto reset: leave final numbers visible

func set_camera_follow_mode(value) -> void:
	if value:
		$PhantomCamera3D.follow_mode = PhantomCamera3D.FollowMode.FRAMED
		$PhantomCamera3D.follow_target = $Player.ball
	else:
		$PhantomCamera3D.follow_mode = PhantomCamera3D.FollowMode.NONE

func reset_camera_to_start() -> void:
	# Temporarily disable follow mode
	$PhantomCamera3D.follow_mode = PhantomCamera3D.FollowMode.NONE

	# Tween camera back to starting position
	var start_pos := Vector3(-2.5, 1.5, 0)  # Starting camera offset from ball at origin
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($PhantomCamera3D, "global_position", start_pos, 1.5)

	await tween.finished

	# Reset ball to starting position
	$Player.ball.reset()


func _on_range_ui_hit_shot(data: Dictionary) -> void:
	# For local injected shots, prime the display immediately with the payload data.
	raw_ball_data = data.duplicate()
	_update_ball_display()

	# Re-enable camera follow if the setting is on
	if GlobalSettings.range_settings.camera_follow_mode.value:
		set_camera_follow_mode(true)


func _on_player_manual_hit() -> void:
	# Re-enable camera follow if the setting is on
	if GlobalSettings.range_settings.camera_follow_mode.value:
		set_camera_follow_mode(true)



func _reset_display_data() -> void:
	raw_ball_data.clear()
	last_display.clear()
	display_data["Distance"] = "---"
	display_data["Carry"] = "---"
	display_data["Offline"] = "---"
	display_data["Apex"] = "---"
	display_data["VLA"] = "---"
	display_data["HLA"] = "---"
	display_data["Speed"] = "---"
	display_data["BackSpin"] = "---"
	display_data["SideSpin"] = "---"
	display_data["TotalSpin"] = "---"
	display_data["SpinAxis"] = "---"


func _update_ball_display() -> void:
	# Show distance continuously (updates during flight/rollout, final at rest)
	var show_distance: bool = true
	display_data = ShotFormatter.format_ball_display(raw_ball_data, $Player, GlobalSettings.range_settings.range_units.value, show_distance, display_data)
	last_display = display_data.duplicate()
	$RangeUI.set_data(display_data)
	
