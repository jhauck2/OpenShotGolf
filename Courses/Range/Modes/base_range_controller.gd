extends Node3D
class_name BaseRangeController

var player: Node3D
var range_ui: Control
var tcp_server: Node
var phantom_camera: Node3D


func _ready() -> void:
	player = $Player
	range_ui = $RangeUI
	tcp_server = $TCPServer
	phantom_camera = $PhantomCamera3D

	assert(player != null, "Player node not found")
	assert(range_ui != null, "RangeUI node not found")
	assert(tcp_server != null, "TCPServer node not found")
	assert(phantom_camera != null, "PhantomCamera3D node not found")

	_setup_signal_connections()
	phantom_camera.follow_target = player.get_node("Ball")
	_apply_surface_to_ball()
	_mode_ready()


func _process(delta: float) -> void:
	process_mode(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset"):
		on_manual_reset()


## Called when a shot is received from TCP or shot injector.
func on_shot_received(data: Dictionary) -> void:
	push_error("on_shot_received() not implemented in ", self.name)


## Called each frame while mode is active.
func process_mode(delta: float) -> void:
	push_error("process_mode() not implemented in ", self.name)


## Called when the ball comes to rest.
func on_ball_rest(ball_data: Dictionary) -> void:
	push_error("on_ball_rest() not implemented in ", self.name)


## Called when user presses the reset key.
func on_manual_reset() -> void:
	push_error("on_manual_reset() not implemented in ", self.name)


func _mode_ready() -> void:
	pass


func _setup_signal_connections() -> void:
	tcp_server.hit_ball.connect(_on_tcp_server_hit_ball)
	player.rest.connect(_on_player_rest)


func _on_tcp_server_hit_ball(data: Dictionary) -> void:
	on_shot_received(data)


func _on_player_rest(ball_data: Dictionary) -> void:
	on_ball_rest(ball_data)


func _apply_surface_to_ball() -> void:
	if player.has_node("Ball"):
		var ball = player.get_node("Ball")
		if ball.has_method("set_surface"):
			ball.set_surface(GlobalSettings.range_settings.surface_type.value)

	GlobalSettings.range_settings.surface_type.setting_changed.connect(_on_surface_type_changed)
	GlobalSettings.range_settings.camera_follow_mode.setting_changed.connect(_on_camera_follow_mode_changed)


func _on_surface_type_changed(value) -> void:
	if player.has_node("Ball"):
		var ball = player.get_node("Ball")
		if ball.has_method("set_surface"):
			ball.set_surface(value)


func _on_camera_follow_mode_changed(value: bool) -> void:
	if value:
		phantom_camera.follow_mode = 5
		phantom_camera.follow_target = player.get_node("Ball")
	else:
		phantom_camera.follow_mode = 0


## Format raw shot data for display with unit conversion.
func format_shot_display(
	raw_data: Dictionary,
	show_distance: bool,
	prev_data: Dictionary = {}
) -> Dictionary:
	var result = prev_data.duplicate() if prev_data.size() > 0 else {}

	if raw_data.is_empty():
		return result

	var m2yd = 1.09361
	var use_imperial = GlobalSettings.range_settings.range_units.value == Enums.Units.IMPERIAL

	if show_distance:
		var distance = get_ball_distance()
		result["Distance"] = str(int(distance * m2yd)) if use_imperial else str(distance)

	var carry = get_ball_carry()
	result["Carry"] = str(int(carry * m2yd)) if use_imperial else str(carry)

	var apex = get_ball_apex()
	result["Apex"] = str(int(apex * 3 * m2yd)) if use_imperial else str(apex)

	var offline = player.get_offline() if player.has_method("get_offline") else 0
	var offline_str = "R" if offline >= 0 else "L"
	offline_str += str(abs(int(offline * m2yd))) if use_imperial else str(abs(int(offline)))
	result["Offline"] = offline_str

	if raw_data.has("Speed"):
		result["Speed"] = str(raw_data["Speed"])
	if raw_data.has("BackSpin"):
		result["BackSpin"] = str(raw_data["BackSpin"])
	if raw_data.has("SideSpin"):
		result["SideSpin"] = str(raw_data["SideSpin"])
	if raw_data.has("TotalSpin"):
		result["TotalSpin"] = str(raw_data["TotalSpin"])
	if raw_data.has("SpinAxis"):
		result["SpinAxis"] = str(raw_data["SpinAxis"])
	if raw_data.has("VLA"):
		result["VLA"] = raw_data["VLA"]
	if raw_data.has("HLA"):
		result["HLA"] = raw_data["HLA"]

	return result


func reset_ball() -> void:
	player.reset_ball()


func get_ball_state() -> Enums.BallState:
	return player.get_ball_state()


func update_ui(data: Dictionary) -> void:
	range_ui.set_data(data)


func get_ball_distance() -> int:
	return player.get_distance()


func get_ball_side_distance() -> int:
	return player.get_side_distance()


func get_ball_apex() -> float:
	return player.apex


func get_ball_carry() -> float:
	return player.carry
