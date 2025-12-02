class_name CameraController
extends Node

signal camera_changed(camera_name: String)

enum CameraMode {
	BEHIND_BALL,
	DOWN_THE_LINE,
	FACE_ON,
	BIRDS_EYE,
	FOLLOW_BALL,
}

var current_mode: CameraMode = CameraMode.BEHIND_BALL
var active_camera: Camera3D = null
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


func _ready() -> void:
	_initialize_camera()


func _initialize_camera() -> void:
	var camera = get_node_or_null("Camera3D")
	if not camera:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		add_child(camera)

	active_camera = camera
	active_camera.current = true
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
			emit_signal("camera_changed", "Behind Ball")
		CameraMode.DOWN_THE_LINE:
			_set_camera_position(DTL_POSITION, DTL_LOOKAT)
			emit_signal("camera_changed", "Down the Line")
		CameraMode.FACE_ON:
			_set_camera_position(FACE_ON_POSITION, FACE_ON_LOOKAT)
			emit_signal("camera_changed", "Face On")
		CameraMode.BIRDS_EYE:
			_update_birds_eye_position()
			emit_signal("camera_changed", "Bird's Eye")
		CameraMode.FOLLOW_BALL:
			emit_signal("camera_changed", "Follow Ball")


func next_camera() -> void:
	var next_mode = (current_mode + 1) % CameraMode.size()
	set_camera_mode(next_mode)


func previous_camera() -> void:
	var prev_mode = (current_mode - 1 + CameraMode.size()) % CameraMode.size()
	set_camera_mode(prev_mode)


func _set_camera_position(position: Vector3, lookat_target: Vector3) -> void:
	if not active_camera:
		return

	active_camera.position = position
	active_camera.look_at(lookat_target, Vector3.UP)


func _update_birds_eye_position() -> void:
	if not active_camera:
		return

	var distance_meters = target_distance * 0.9144
	var padding = max(distance_meters * 0.2, 20.0)
	var midpoint_x = distance_meters / 2.0
	var view_distance = distance_meters + padding
	var height = max(view_distance * 0.5, 40.0)

	active_camera.position = Vector3(midpoint_x, height, 0.0)
	active_camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)


func _process(_delta: float) -> void:
	if current_mode == CameraMode.FOLLOW_BALL and ball_target and active_camera:
		var ball_pos = ball_target.global_position
		var target_pos = ball_pos + FOLLOW_OFFSET

		active_camera.global_position = active_camera.global_position.lerp(target_pos, 0.08)
		active_camera.look_at(ball_pos, Vector3.UP)


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


func get_active_camera() -> Camera3D:
	return active_camera
