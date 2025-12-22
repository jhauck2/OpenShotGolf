extends Node3D
class_name BaseRangeController

## Base controller for all range practice modes.
## Provides common functionality for shot tracking, UI updates, and ball physics.
## Child classes must implement mode-specific behavior via abstract methods.

@onready var player: Node3D = $Player
@onready var range_ui: Control = $RangeUI
@onready var tcp_server: Node = $TCPServer
@onready var phantom_camera: Node3D = $PhantomCamera3D


# --- Lifecycle ---

func _ready() -> void:
	_validate_scene_structure()
	phantom_camera.follow_target = player.get_node("Ball")
	_apply_surface_to_ball()
	_mode_ready()


func _process(delta: float) -> void:
	process_mode(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset"):
		on_manual_reset()


# --- Abstract Methods (must override in child classes) ---

func on_shot_received(_data: Dictionary) -> void:
	push_error("on_shot_received() not implemented in ", self.name)


func process_mode(_delta: float) -> void:
	push_error("process_mode() not implemented in ", self.name)


func on_ball_rest(_ball_data: Dictionary) -> void:
	push_error("on_ball_rest() not implemented in ", self.name)


func on_manual_reset() -> void:
	push_error("on_manual_reset() not implemented in ", self.name)


func _mode_ready() -> void:
	pass


# --- Signal Handlers ---

func _on_tcp_client_hit_ball(data: Dictionary) -> void:
	on_shot_received(data)


func _on_golf_ball_rest(ball_data: Dictionary) -> void:
	on_ball_rest(ball_data)


# --- Settings Handlers ---

func _apply_surface_to_ball() -> void:
	var ball = _get_ball()
	if ball and ball.has_method("set_surface"):
		ball.set_surface(GlobalSettings.range_settings.surface_type.value)

	GlobalSettings.range_settings.surface_type.setting_changed.connect(_on_surface_type_changed)
	GlobalSettings.range_settings.camera_follow_mode.setting_changed.connect(_on_camera_follow_mode_changed)


func _on_surface_type_changed(value: Enums.Surface) -> void:
	var ball = _get_ball()
	if ball and ball.has_method("set_surface"):
		ball.set_surface(value)


func _on_camera_follow_mode_changed(is_enabled: bool) -> void:
	if is_enabled:
		phantom_camera.follow_mode = 5
		phantom_camera.follow_target = _get_ball()
	else:
		phantom_camera.follow_mode = 0


# --- Data Formatting ---

const METERS_TO_YARDS := 1.09361

func format_shot_display(
	raw_data: Dictionary,
	should_show_distance: bool,
	prev_data: Dictionary = {}
) -> Dictionary:
	var result := prev_data.duplicate() if not prev_data.is_empty() else {}

	if raw_data.is_empty():
		return result

	var is_imperial := _is_using_imperial_units()

	if should_show_distance:
		result["Distance"] = _format_distance(get_ball_distance(), is_imperial)

	result["Carry"] = _format_distance(get_ball_carry(), is_imperial)
	result["Apex"] = _format_apex(get_ball_apex(), is_imperial)
	result["Offline"] = _format_offline_distance(get_ball_side_distance(), is_imperial)

	_add_spin_data(result, raw_data)
	_add_angle_data(result, raw_data)

	return result


# --- Helper Methods ---

func _validate_scene_structure() -> void:
	assert(player != null, "Player node not found")
	assert(range_ui != null, "RangeUI node not found")
	assert(tcp_server != null, "TCPServer node not found")
	assert(phantom_camera != null, "PhantomCamera3D node not found")


func _get_ball() -> Node:
	return player.get_node_or_null("Ball")


func _is_using_imperial_units() -> bool:
	return GlobalSettings.range_settings.range_units.value == Enums.Units.IMPERIAL


func _format_distance(meters: float, is_imperial: bool) -> String:
	if is_imperial:
		return str(int(meters * METERS_TO_YARDS))
	return str(int(meters))


func _format_apex(meters: float, is_imperial: bool) -> String:
	if is_imperial:
		return str(int(meters * 3 * METERS_TO_YARDS))
	return str(int(meters))


func _format_offline_distance(meters: float, is_imperial: bool) -> String:
	var direction := "R" if meters >= 0 else "L"
	var value: int = abs(int(meters * METERS_TO_YARDS if is_imperial else meters))
	return direction + str(value)


func _add_spin_data(result: Dictionary, raw_data: Dictionary) -> void:
	var spin_keys := ["Speed", "BackSpin", "SideSpin", "TotalSpin", "SpinAxis"]
	for key in spin_keys:
		if raw_data.has(key):
			result[key] = str(raw_data[key])


func _add_angle_data(result: Dictionary, raw_data: Dictionary) -> void:
	if raw_data.has("VLA"):
		result["VLA"] = raw_data["VLA"]
	if raw_data.has("HLA"):
		result["HLA"] = raw_data["HLA"]


# --- Ball State Accessors ---

func reset_ball() -> void:
	player.reset_ball()


func get_ball_state() -> Enums.BallState:
	return player.get_ball_state()


func get_ball_distance() -> int:
	return player.get_distance()


func get_ball_side_distance() -> int:
	return player.get_offline()


func get_ball_apex() -> float:
	return player.apex


func get_ball_carry() -> float:
	return player.carry


# --- UI Updates ---

func update_ui(data: Dictionary) -> void:
	range_ui.set_data(data)
