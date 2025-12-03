extends Panel

const PANEL_WIDTH = 200.0
const PANEL_HEIGHT = 400.0
const BACKGROUND_COLOR = Color(0.0, 0.0, 0.0, 0.5)
const MARGIN_TOP = 40.0
const MARGIN_BOTTOM = 60.0
const MAX_HISTORIC_SHOTS = 10
const DISTANCE_MARKERS = [50, 100, 150, 200, 250]
const LATERAL_SCALE = 50.0
const LATERAL_DISPLAY_WIDTH = 0.4
const ARC_SEGMENTS = 20
const ARC_ANGLE_RANGE = PI / 3.0

var shot_path: PackedVector2Array = []
var max_distance: float = 150.0
var lateral_deviation: float = 0.0
var shot_shape: String = "Straight"
var historic_shots: Array[Vector2] = []
var current_shot_index: int = -1


func _ready() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = BACKGROUND_COLOR
	add_theme_stylebox_override("panel", stylebox)


func _draw() -> void:
	var panel_size = size
	var center_x = panel_size.x / 2.0

	_draw_distance_markers(panel_size, center_x)
	_draw_center_line(center_x, panel_size)
	_draw_historic_shots(panel_size, center_x)

	if shot_path.size() > 0:
		_draw_shot_path(panel_size, center_x)

	_draw_shot_shape_label(panel_size, center_x)


func _draw_distance_markers(panel_size: Vector2, center_x: float) -> void:
	var marker_color = Color(1, 1, 1, 0.4)
	var available_height = panel_size.y - MARGIN_TOP - MARGIN_BOTTOM

	for distance in DISTANCE_MARKERS:
		if distance > max_distance:
			continue

		var y_pos = _world_to_screen_y(distance, available_height)
		_draw_distance_arc(center_x, y_pos, panel_size.x, marker_color)
		_draw_distance_label(distance, center_x, y_pos)


func _draw_distance_arc(center_x: float, y_pos: float, panel_width: float, color: Color) -> void:
	var arc_width = panel_width * LATERAL_DISPLAY_WIDTH
	var angle_start = -ARC_ANGLE_RANGE
	var angle_end = ARC_ANGLE_RANGE

	for i in range(ARC_SEGMENTS):
		var t1 = float(i) / ARC_SEGMENTS
		var t2 = float(i + 1) / ARC_SEGMENTS
		var angle1 = lerp(angle_start, angle_end, t1)
		var angle2 = lerp(angle_start, angle_end, t2)

		var x1 = center_x + cos(angle1) * arc_width
		var x2 = center_x + cos(angle2) * arc_width

		draw_line(Vector2(x1, y_pos), Vector2(x2, y_pos), color, 1.0)


func _draw_distance_label(distance: int, center_x: float, y_pos: float) -> void:
	if distance in DISTANCE_MARKERS:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(center_x - 15, y_pos - 5),
			str(distance),
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			20,
			Color(1, 1, 1, 0.8)
		)


func _draw_center_line(center_x: float, panel_size: Vector2) -> void:
	var bottom_y = panel_size.y - MARGIN_BOTTOM
	var top_y = MARGIN_TOP
	draw_line(Vector2(center_x, bottom_y), Vector2(center_x, top_y), Color(1, 1, 1, 0.3), 1.0)


func _draw_historic_shots(panel_size: Vector2, center_x: float) -> void:
	var available_height = panel_size.y - MARGIN_TOP - MARGIN_BOTTOM
	var historic_color = Color(0.6, 0.6, 0.6, 0.4)
	var current_color = Color(1.0, 0.8, 0.0, 0.6)

	for i in range(historic_shots.size()):
		var shot_point = historic_shots[i]
		var screen_x = _world_to_screen_x(shot_point.x, panel_size.x, center_x)
		var screen_y = _world_to_screen_y(shot_point.y, available_height)

		var color = current_color if i == current_shot_index else historic_color
		var radius = 4.0 if i == current_shot_index else 3.0

		draw_circle(Vector2(screen_x, screen_y), radius, color)


func _draw_shot_path(panel_size: Vector2, center_x: float) -> void:
	var path_color = Color(1.0, 0.6, 0.0)
	var available_height = panel_size.y - MARGIN_TOP - MARGIN_BOTTOM

	var screen_points: PackedVector2Array = []
	for point in shot_path:
		var screen_x = _world_to_screen_x(point.x, panel_size.x, center_x)
		var screen_y = _world_to_screen_y(point.y, available_height)
		screen_points.append(Vector2(screen_x, screen_y))

	if screen_points.size() > 1:
		for i in range(screen_points.size() - 1):
			draw_line(screen_points[i], screen_points[i + 1], path_color, 3.0)

	if screen_points.size() > 0:
		draw_circle(screen_points[-1], 5.0, path_color)


func _draw_shot_shape_label(panel_size: Vector2, center_x: float) -> void:
	var label_color = Color(1.0, 0.6, 0.0)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(center_x - panel_size.x / 2.0, panel_size.y - 20),
		shot_shape.to_upper(),
		HORIZONTAL_ALIGNMENT_CENTER,
		panel_size.x,
		28,
		label_color
	)


func set_shot_data(carry: float, lateral: float, _total: float = 0.0) -> void:
	max_distance = max(150.0, carry * 1.2)
	lateral_deviation = lateral
	shot_shape = _determine_shot_shape(lateral)
	_generate_shot_path(carry, lateral)
	queue_redraw()


func _determine_shot_shape(lateral: float) -> String:
	if abs(lateral) < 3.0:
		return "Straight"
	elif lateral < -10.0:
		return "Hook"
	elif lateral < 0:
		return "Draw"
	elif lateral > 10.0:
		return "Slice"
	else:
		return "Fade"


func _generate_shot_path(carry: float, lateral: float) -> void:
	shot_path.clear()
	var num_points = 30

	for i in range(num_points + 1):
		var t = float(i) / num_points
		var distance = carry * t
		var lateral_pos = lateral * (t * t)
		shot_path.append(Vector2(lateral_pos, distance))


func register_shot_landed(carry: float, lateral: float) -> void:
	var landing_point = Vector2(lateral, carry)
	historic_shots.push_front(landing_point)

	if historic_shots.size() > MAX_HISTORIC_SHOTS:
		historic_shots.resize(MAX_HISTORIC_SHOTS)

	current_shot_index = 0
	queue_redraw()


func set_current_shot_index(index: int) -> void:
	if index >= 0 and index < historic_shots.size():
		current_shot_index = index
		queue_redraw()


func clear_shot() -> void:
	shot_path.clear()
	shot_shape = "Straight"
	current_shot_index = -1
	queue_redraw()


func clear_historic_shots() -> void:
	historic_shots.clear()
	current_shot_index = -1
	queue_redraw()


func _world_to_screen_x(world_x: float, panel_width: float, center_x: float) -> float:
	return center_x + (world_x / LATERAL_SCALE) * (panel_width * LATERAL_DISPLAY_WIDTH)


func _world_to_screen_y(world_y: float, available_height: float) -> float:
	return (available_height + MARGIN_BOTTOM) - (world_y / max_distance) * available_height
