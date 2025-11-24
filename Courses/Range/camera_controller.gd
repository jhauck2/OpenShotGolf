class_name CameraController
extends Node

## Controls multiple camera angles for the range
##
## Manages different camera perspectives and smooth transitions between them.
## Cameras can follow the ball or remain fixed.

signal camera_changed(camera_name: String)

## Camera modes
enum CameraMode {
	BEHIND_BALL,      # Looking down target line from behind (DEFAULT)
	DOWN_THE_LINE,    # Side view from left
	FACE_ON,          # Side view from right
	BIRDS_EYE,        # Overhead view
	FOLLOW_BALL,      # Camera tracks ball flight
}

var current_mode: CameraMode = CameraMode.BEHIND_BALL
var active_camera: Camera3D = null
var ball_target: Node3D = null
var target_distance: float = 150.0  # Current target distance in yards

## Camera nodes (will be created)
var camera_dtl: Camera3D       # Down the line
var camera_behind: Camera3D    # Behind ball
var camera_face_on: Camera3D   # Face on
var camera_overhead: Camera3D  # Birds eye
var camera_follow: Camera3D    # Follow ball

## Camera positions and settings
# Ball starts at origin (0,0,0), X+ is downrange, Z+ is right
const BEHIND_POSITION = Vector3(-5.0, 2.5, 0.0)  # Behind ball, default view
const BEHIND_ROTATION = Vector3(-10.0, 0.0, 0.0)

const DTL_POSITION = Vector3(-5.0, 3.0, -8.0)  # Down the line (side view from left)
const DTL_ROTATION = Vector3(-15.0, 90.0, 0.0)

const FACE_ON_POSITION = Vector3(-5.0, 3.0, 8.0)  # Face on (from right side)
const FACE_ON_ROTATION = Vector3(-15.0, -90.0, 0.0)

const OVERHEAD_POSITION = Vector3(125.0, 80.0, 0.0)  # Centered between tee and 250 yards
const OVERHEAD_ROTATION = Vector3(-90.0, 0.0, 0.0)

const FOLLOW_OFFSET = Vector3(-8.0, 4.0, 0.0)  # Behind and above ball

var transition_duration: float = 0.5


func _ready() -> void:
	_create_cameras()


## Create all camera nodes
func _create_cameras() -> void:
	# Behind ball camera (default) - looking forward down range
	camera_behind = _create_camera_with_lookat("CameraBehind", BEHIND_POSITION, Vector3(50.0, 0.0, 0.0))

	# Down the line camera (side view from left) - looking right of ball to see downrange
	# Ball will appear on left side of frame, showing more of the right/downrange area
	camera_dtl = _create_camera_with_lookat("CameraDTL", DTL_POSITION, Vector3(30.0, 0.0, 5.0))

	# Face on camera (side view from right) - looking left of ball to see downrange
	# Ball will appear on right side of frame, showing more of the left/downrange area
	camera_face_on = _create_camera_with_lookat("CameraFaceOn", FACE_ON_POSITION, Vector3(30.0, 0.0, -5.0))

	# Overhead camera
	camera_overhead = _create_camera("CameraOverhead", OVERHEAD_POSITION, OVERHEAD_ROTATION)

	# Follow ball camera
	camera_follow = _create_camera_with_lookat("CameraFollow", FOLLOW_OFFSET, Vector3(50.0, 0.0, 0.0))

	# Update overhead camera for initial target distance
	_update_overhead_camera()

	# Set default camera
	set_camera_mode(CameraMode.BEHIND_BALL)


## Create a camera node with position and rotation
func _create_camera(camera_name: String, pos: Vector3, rot: Vector3) -> Camera3D:
	var camera = Camera3D.new()
	camera.name = camera_name
	camera.position = pos
	camera.rotation_degrees = rot
	camera.current = false
	add_child(camera)
	return camera


## Create a camera node with position and look_at target
func _create_camera_with_lookat(camera_name: String, pos: Vector3, target: Vector3) -> Camera3D:
	var camera = Camera3D.new()
	camera.name = camera_name
	camera.position = pos
	camera.current = false
	add_child(camera)
	camera.look_at(target, Vector3.UP)
	return camera


## Set the ball target for camera following
func set_ball_target(ball: Node3D) -> void:
	ball_target = ball


## Set target distance and update overhead camera
func set_target_distance(distance_yards: float) -> void:
	target_distance = distance_yards
	_update_overhead_camera()


## Update overhead camera position based on target distance
func _update_overhead_camera() -> void:
	if not camera_overhead:
		return

	# Convert yards to meters
	var distance_meters = target_distance * 0.9144

	# Add padding (20% of distance or minimum 20m)
	var padding = max(distance_meters * 0.2, 20.0)

	# Position camera at midpoint between ball and target
	var midpoint_x = distance_meters / 2.0

	# Calculate height to see both ball and target comfortably
	# Use distance + padding to determine height
	var view_distance = distance_meters + padding
	var height = view_distance * 0.5  # 50% of view distance for good angle
	height = max(height, 40.0)  # Minimum 40m height

	camera_overhead.position = Vector3(midpoint_x, height, 0.0)
	camera_overhead.rotation_degrees = Vector3(-90.0, 0.0, 0.0)

	print("Overhead camera updated: target %.0f yds, position %s, height %.1fm" % [target_distance, camera_overhead.position, height])


## Switch to a different camera mode
func set_camera_mode(mode: CameraMode) -> void:
	current_mode = mode

	# Deactivate all cameras
	_deactivate_all_cameras()

	# Activate selected camera
	match mode:
		CameraMode.BEHIND_BALL:
			_activate_camera(camera_behind, "Behind Ball")
		CameraMode.DOWN_THE_LINE:
			_activate_camera(camera_dtl, "Down the Line")
		CameraMode.FACE_ON:
			_activate_camera(camera_face_on, "Face On")
		CameraMode.BIRDS_EYE:
			_activate_camera(camera_overhead, "Bird's Eye")
		CameraMode.FOLLOW_BALL:
			_activate_camera(camera_follow, "Follow Ball")


## Cycle to next camera
func next_camera() -> void:
	var next_mode = (current_mode + 1) % CameraMode.size()
	set_camera_mode(next_mode)


## Cycle to previous camera
func previous_camera() -> void:
	var prev_mode = (current_mode - 1 + CameraMode.size()) % CameraMode.size()
	set_camera_mode(prev_mode)


## Activate a specific camera
func _activate_camera(camera: Camera3D, camera_name: String) -> void:
	if camera:
		camera.current = true
		active_camera = camera

		emit_signal("camera_changed", camera_name)
		print("Camera switched to: %s" % camera_name)


## Deactivate all cameras
func _deactivate_all_cameras() -> void:
	if camera_dtl:
		camera_dtl.current = false
	if camera_behind:
		camera_behind.current = false
	if camera_face_on:
		camera_face_on.current = false
	if camera_overhead:
		camera_overhead.current = false
	if camera_follow:
		camera_follow.current = false


## Update camera positions (call in _process if following ball)
func _process(_delta: float) -> void:
	# Update follow camera to track ball
	if current_mode == CameraMode.FOLLOW_BALL and ball_target and camera_follow:
		# Calculate position behind ball based on ball's position
		var ball_pos = ball_target.global_position
		var target_pos = ball_pos + FOLLOW_OFFSET

		# Smoothly move camera
		camera_follow.global_position = camera_follow.global_position.lerp(target_pos, 0.08)

		# Always look at ball
		camera_follow.look_at(ball_pos, Vector3.UP)


## Get current camera name
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


## Get current camera mode
func get_current_mode() -> CameraMode:
	return current_mode


func get_active_camera() -> Camera3D:
	return active_camera
