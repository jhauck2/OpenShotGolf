extends Panel

const PANEL_WIDTH = 400.0
const PANEL_HEIGHT = 200.0
const BACKGROUND_COLOR = Color(0.13, 0.13, 0.13)
const MARGIN = 30.0
const AXIS_COLOR = Color(1, 1, 1, 0.3)
const TEXT_COLOR = Color(1, 1, 1, 0.7)
const CURVE_COLOR = Color(1.0, 0.6, 0.0)
const CURVE_WIDTH = 2.0
const ENDPOINT_RADIUS = 4.0
const X_TICKS = [0, 50, 100, 150, 200]
const Y_TICKS = [0, 10, 20, 30]
const TRAJECTORY_POINTS_COUNT = 50
const MIN_HEIGHT = 30.0
const MIN_DISTANCE = 200.0

var trajectory_points: PackedVector2Array = []
var max_height: float = 60.0
var max_distance: float = 400.0
var carry_distance: float = 0.0
var apex_height: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = BACKGROUND_COLOR
	add_theme_stylebox_override("panel", stylebox)


func _draw() -> void:
	var panel_size = size
	_draw_axes(panel_size)

	if trajectory_points.size() > 0:
		_draw_trajectory(panel_size)


func _draw_axes(panel_size: Vector2) -> void:
	var chart_width = panel_size.x - 2 * MARGIN
	var chart_height = panel_size.y - 2 * MARGIN

	_draw_axis_lines(panel_size)
	_draw_x_axis_ticks(panel_size, chart_width)
	_draw_y_axis_ticks(panel_size, chart_height)


func _draw_axis_lines(panel_size: Vector2) -> void:
	var bottom = panel_size.y - MARGIN
	var right = panel_size.x - MARGIN

	draw_line(Vector2(MARGIN, MARGIN), Vector2(MARGIN, bottom), AXIS_COLOR, 1.0)
	draw_line(Vector2(MARGIN, bottom), Vector2(right, bottom), AXIS_COLOR, 1.0)


func _draw_x_axis_ticks(panel_size: Vector2, chart_width: float) -> void:
	var bottom = panel_size.y - MARGIN

	for tick in X_TICKS:
		if tick > max_distance:
			continue

		var x_pos = MARGIN + (tick / max_distance) * chart_width
		draw_line(Vector2(x_pos, bottom), Vector2(x_pos, bottom + 5), AXIS_COLOR, 1.0)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(x_pos - 10, bottom + 20),
			str(tick),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			TEXT_COLOR
		)


func _draw_y_axis_ticks(panel_size: Vector2, chart_height: float) -> void:
	var bottom = panel_size.y - MARGIN

	for tick in Y_TICKS:
		if tick > max_height:
			continue

		var y_pos = bottom - (tick / max_height) * chart_height
		draw_line(Vector2(MARGIN - 5, y_pos), Vector2(MARGIN, y_pos), AXIS_COLOR, 1.0)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(5, y_pos + 4),
			str(tick),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			TEXT_COLOR
		)


func _draw_trajectory(panel_size: Vector2) -> void:
	var chart_width = panel_size.x - 2 * MARGIN
	var chart_height = panel_size.y - 2 * MARGIN
	var screen_points = _convert_to_screen_coordinates(panel_size, chart_width, chart_height)

	_draw_trajectory_curve(screen_points)
	_draw_trajectory_endpoint(screen_points)


func _convert_to_screen_coordinates(panel_size: Vector2, chart_width: float, chart_height: float) -> PackedVector2Array:
	var screen_points: PackedVector2Array = []
	var bottom = panel_size.y - MARGIN

	for point in trajectory_points:
		var x = MARGIN + (point.x / max_distance) * chart_width
		var y = bottom - (point.y / max_height) * chart_height
		screen_points.append(Vector2(x, y))

	return screen_points


func _draw_trajectory_curve(screen_points: PackedVector2Array) -> void:
	if screen_points.size() > 1:
		for i in range(screen_points.size() - 1):
			draw_line(screen_points[i], screen_points[i + 1], CURVE_COLOR, CURVE_WIDTH)


func _draw_trajectory_endpoint(screen_points: PackedVector2Array) -> void:
	if screen_points.size() > 0:
		draw_circle(screen_points[-1], ENDPOINT_RADIUS, CURVE_COLOR)


func set_trajectory_data(carry: float, apex: float, _total: float = 0.0) -> void:
	carry_distance = carry
	apex_height = apex
	max_distance = max(MIN_DISTANCE, carry * 1.2)
	max_height = max(MIN_HEIGHT, apex * 1.5)
	_generate_parabolic_trajectory(carry, apex)
	queue_redraw()


func _generate_parabolic_trajectory(carry: float, apex: float) -> void:
	trajectory_points.clear()

	for i in range(TRAJECTORY_POINTS_COUNT + 1):
		var t = float(i) / TRAJECTORY_POINTS_COUNT
		var distance = carry * t
		var height = 4.0 * apex * t * (1.0 - t)
		trajectory_points.append(Vector2(distance, height))


func clear_trajectory() -> void:
	trajectory_points.clear()
	queue_redraw()
