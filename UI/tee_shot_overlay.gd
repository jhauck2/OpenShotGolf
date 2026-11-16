class_name TeeShotFlightOverlay
extends Control

class BallMarker extends Control:
	var marker_position := Vector2.ZERO
	var has_position := false

	func set_marker_position(new_position: Vector2) -> void:
		if has_position and marker_position.is_equal_approx(new_position):
			return
		marker_position = new_position
		has_position = true
		queue_redraw()

	func clear_marker() -> void:
		has_position = false
		queue_redraw()

	func _draw() -> void:
		if not has_position:
			return
		draw_circle(marker_position, 6.0, Color.BLACK)
		draw_circle(marker_position, 4.0, Color(1.0, 0.98, 0.88, 1.0))
		draw_circle(marker_position, 1.5, Color(0.12, 0.12, 0.12, 1.0))


const TRACER_COLOR := Color(1.0, 0.2, 0.045, 1.0)
const TEE_COLOR := Color(0.98, 0.9, 0.38, 1.0)
const BALL_COLOR := Color(1.0, 0.98, 0.88, 1.0)
const TRACER_WIDTH := 3.5

var _camera: Camera3D
var _points: Array[Vector3] = []
var _projected_points := PackedVector2Array()
var _tee_position := Vector3.ZERO
var _projected_tee_position := Vector2.ZERO
var _projected_viewport_size := Vector2.ZERO
var _ball_marker: BallMarker


func _ready() -> void:
	_ball_marker = BallMarker.new()
	_ball_marker.name = "BallMarker"
	_ball_marker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ball_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ball_marker.z_index = 1
	add_child(_ball_marker)


func set_flight_path(camera: Camera3D, points: Array[Vector3], tee_position: Vector3) -> void:
	var camera_changed := _camera != camera
	var tee_changed := _tee_position != tee_position
	_camera = camera
	var first_changed := 0 if camera_changed or _points.size() != points.size() else points.size()
	if first_changed > 0:
		for i in range(points.size()):
			if _points[i] != points[i]:
				first_changed = i
				break
	var points_changed := first_changed < points.size()
	if points_changed:
		_points = points.duplicate()
	_tee_position = tee_position
	var camera_viewport := _camera.get_viewport() if is_instance_valid(_camera) else null
	var viewport_size := camera_viewport.get_visible_rect().size if camera_viewport != null else Vector2.ZERO
	var overlay_size_changed := _projected_viewport_size != viewport_size or _projected_points.size() != _points.size()
	if camera_changed or overlay_size_changed:
		_projected_points.resize(_points.size())
		first_changed = 0
	elif points_changed:
		_projected_points.resize(_points.size())
	if points_changed or camera_changed or overlay_size_changed:
		for i in range(first_changed, _points.size()):
			_projected_points[i] = _project_world_position(_points[i], viewport_size)
		_projected_viewport_size = viewport_size
	if tee_changed or camera_changed or overlay_size_changed:
		_projected_tee_position = _project_world_position(_tee_position, viewport_size)
	if points_changed or tee_changed or camera_changed or overlay_size_changed:
		queue_redraw()


func clear_flight_path() -> void:
	_points.clear()
	_projected_points.clear()
	_tee_position = Vector3.ZERO
	_projected_tee_position = Vector2.ZERO
	_projected_viewport_size = Vector2.ZERO
	if _ball_marker != null:
		_ball_marker.clear_marker()
	queue_redraw()


func set_ball_position(world_position: Vector3) -> void:
	if _ball_marker == null or _camera == null or not is_instance_valid(_camera):
		return
	var camera_viewport := _camera.get_viewport()
	if camera_viewport == null:
		return
	var viewport_size := camera_viewport.get_visible_rect().size
	_ball_marker.set_marker_position(_project_world_position(world_position, viewport_size))


func _project_world_position(world_position: Vector3, viewport_size: Vector2) -> Vector2:
	if _camera == null or not is_instance_valid(_camera) or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2.ZERO
	var point := _camera.unproject_position(world_position)
	point.x *= size.x / viewport_size.x
	point.y *= size.y / viewport_size.y
	return point


func _draw() -> void:
	if _camera == null or not is_instance_valid(_camera) or _points.is_empty():
		return
	if _projected_points.size() >= 2:
		draw_polyline(_projected_points, TRACER_COLOR, TRACER_WIDTH, true)
	draw_line(_projected_tee_position + Vector2(0.0, 5.0), _projected_tee_position + Vector2(0.0, 11.0), TEE_COLOR, 2.5, true)
	draw_circle(_projected_tee_position, 4.0, Color.BLACK)
	draw_circle(_projected_tee_position, 2.5, BALL_COLOR)
