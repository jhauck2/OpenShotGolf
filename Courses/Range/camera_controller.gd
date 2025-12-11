class_name CameraController
extends Node

enum CameraMode {
	BEHIND_BALL,
	DOWN_THE_LINE,
	FACE_ON,
	BIRDS_EYE,
	FOLLOW_BALL,
}

var current_mode: CameraMode = CameraMode.BEHIND_BALL
var phantom_camera: Node3D = null
var ball_target: Node3D = null
var target_distance: float = 150.0

const BEHIND_POSITION = Vector3(-5.0, 2.5, 0.0)
const BEHIND_LOOKAT = Vector3(50.0, 0.0, 0.0)

const DTL_POSITION = Vector3(-5.0, 3.0, -8.0)
const DTL_LOOKAT = Vector3(30.0, 0.0, 5.0)

const FACE_ON_POSITION = Vector3(-5.0, 3.0, 8.0)
const FACE_ON_LOOKAT = Vector3(30.0, 0.0, -5.0)

const BIRDS_EYE_OFFSET = Vector3(0.0, 0.0, 0.0)

const FOLLOW_OFFSET = Vector3(-8.0, 4.0, 0.0)


func _init(camera) -> void:
	phantom_camera = camera


func _ready() -> void:
	set_camera_mode(CameraMode.BEHIND_BALL)


func set_ball_target(ball: Node3D) -> void:
	ball_target = ball


func set_target_distance(distance_yards: float) -> void:
	target_distance = distance_yards
	if current_mode == CameraMode.BIRDS_EYE:
		_update_birds_eye_position()


func set_camera_mode(mode: CameraMode) -> void:
	current_mode = mode

	match mode:
		CameraMode.BEHIND_BALL:
			_set_camera_position(BEHIND_POSITION, BEHIND_LOOKAT)
		CameraMode.DOWN_THE_LINE:
			_set_camera_position(DTL_POSITION, DTL_LOOKAT)
		CameraMode.FACE_ON:
			_set_camera_position(FACE_ON_POSITION, FACE_ON_LOOKAT)
		CameraMode.BIRDS_EYE:
			_update_birds_eye_position()
		CameraMode.FOLLOW_BALL:
			pass


func next_camera() -> void:
	var next_mode = (current_mode + 1) % CameraMode.size()
	set_camera_mode(next_mode)


func previous_camera() -> void:
	var prev_mode = (current_mode - 1 + CameraMode.size()) % CameraMode.size()
	set_camera_mode(prev_mode)


func _set_camera_position(position: Vector3, lookat_target: Vector3) -> void:
	if not phantom_camera:
		return

	phantom_camera.position = position
	phantom_camera.look_at(lookat_target, Vector3.UP)


func _update_birds_eye_position() -> void:
	if not phantom_camera:
		return

	var distance_meters = target_distance * 0.9144
	var padding = max(distance_meters * 0.2, 20.0)
	var midpoint_x = distance_meters / 2.0
	var view_distance = distance_meters + padding
	var height = max(view_distance * 0.5, 40.0)

	phantom_camera.position = Vector3(midpoint_x, height, 0.0)
	phantom_camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)


func _process(_delta: float) -> void:
	if current_mode == CameraMode.FOLLOW_BALL and ball_target and phantom_camera:
		var ball_pos = ball_target.global_position
		var target_pos = ball_pos + FOLLOW_OFFSET

		phantom_camera.global_position = phantom_camera.global_position.lerp(target_pos, 0.08)
		phantom_camera.look_at(ball_pos, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_1"):
		_reset_camera_follow_toggle()
		set_camera_mode(CameraMode.BEHIND_BALL)
	elif event.is_action_pressed("ui_2"):
		_reset_camera_follow_toggle()
		set_camera_mode(CameraMode.DOWN_THE_LINE)
	elif event.is_action_pressed("ui_3"):
		_reset_camera_follow_toggle()
		set_camera_mode(CameraMode.FACE_ON)
	elif event.is_action_pressed("ui_4"):
		_reset_camera_follow_toggle()
		set_camera_mode(CameraMode.BIRDS_EYE)
	elif event.is_action_pressed("ui_5"):
		_reset_camera_follow_toggle(true)
		set_camera_mode(CameraMode.FOLLOW_BALL)
	elif event.is_action_pressed("ui_c"):
		_reset_camera_follow_toggle()
		next_camera()


func _reset_camera_follow_toggle(toggled_on: bool = false) -> void:
	GlobalSettings.range_settings.camera_follow_mode.set_value(toggled_on)


func get_current_camera_name() -> String:
	match current_mode:
		CameraMode.BEHIND_BALL:
			return "Behind Ball"
		CameraMode.DOWN_THE_LINE:
			return "Down the Line"
		CameraMode.FACE_ON:
			return "Face On"
		CameraMode.BIRDS_EYE:
			return "Bird's Eye"
		CameraMode.FOLLOW_BALL:
			return "Follow Ball"
		_:
			return "Unknown"


func get_current_mode() -> CameraMode:
	return current_mode


func get_active_camera() -> Node3D:
	return phantom_camera
