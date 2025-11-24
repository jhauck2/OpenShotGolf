extends Panel

## Trajectory graph displaying ball flight path
## Shows height (Y) vs distance (X) with bezier curve

var trajectory_points: PackedVector2Array = []
var max_height: float = 30.0  # yards
var max_distance: float = 200.0  # yards
var carry_distance: float = 0.0
var apex_height: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(400, 200)
	# Set dark background
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.13, 0.13, 0.13)  # #222
	add_theme_stylebox_override("panel", stylebox)


func _draw() -> void:
	var panel_size = size
	var margin = 30.0

	# Draw axes
	_draw_axes(panel_size, margin)

	# Draw trajectory curve if we have data
	if trajectory_points.size() > 0:
		_draw_trajectory(panel_size, margin)


func _draw_axes(panel_size: Vector2, margin: float) -> void:
	var axis_color = Color(1, 1, 1, 0.3)
	var text_color = Color(1, 1, 1, 0.7)

	# Y-axis (height)
	draw_line(
		Vector2(margin, margin),
		Vector2(margin, panel_size.y - margin),
		axis_color,
		1.0
	)

	# X-axis (distance)
	draw_line(
		Vector2(margin, panel_size.y - margin),
		Vector2(panel_size.x - margin, panel_size.y - margin),
		axis_color,
		1.0
	)

	# Draw tick marks and labels on X-axis (distance)
	var x_ticks = [0, 50, 100, 150, 200]
	for tick in x_ticks:
		if tick > max_distance:
			continue
		var x_pos = margin + (tick / max_distance) * (panel_size.x - 2 * margin)
		draw_line(
			Vector2(x_pos, panel_size.y - margin),
			Vector2(x_pos, panel_size.y - margin + 5),
			axis_color,
			1.0
		)
		# Draw tick label
		draw_string(ThemeDB.fallback_font, Vector2(x_pos - 10, panel_size.y - margin + 20), str(tick), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, text_color)

	# Draw tick marks on Y-axis (height)
	var y_ticks = [0, 10, 20, 30]
	for tick in y_ticks:
		if tick > max_height:
			continue
		var y_pos = panel_size.y - margin - (tick / max_height) * (panel_size.y - 2 * margin)
		draw_line(
			Vector2(margin - 5, y_pos),
			Vector2(margin, y_pos),
			axis_color,
			1.0
		)
		# Draw tick label
		draw_string(ThemeDB.fallback_font, Vector2(5, y_pos + 4), str(tick), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, text_color)


func _draw_trajectory(panel_size: Vector2, margin: float) -> void:
	var curve_color = Color(1.0, 0.6, 0.0)  # Orange #ff9800

	# Convert trajectory points to screen coordinates
	var screen_points: PackedVector2Array = []
	for point in trajectory_points:
		var x = margin + (point.x / max_distance) * (panel_size.x - 2 * margin)
		var y = panel_size.y - margin - (point.y / max_height) * (panel_size.y - 2 * margin)
		screen_points.append(Vector2(x, y))

	# Draw the curve
	if screen_points.size() > 1:
		for i in range(screen_points.size() - 1):
			draw_line(screen_points[i], screen_points[i + 1], curve_color, 2.0)

	# Draw end point marker
	if screen_points.size() > 0:
		draw_circle(screen_points[-1], 4.0, curve_color)


func set_trajectory_data(carry: float, apex: float, total: float = 0.0) -> void:
	carry_distance = carry
	apex_height = apex

	# Update max scales if needed
	max_distance = max(200.0, carry * 1.2)
	max_height = max(30.0, apex * 1.5)

	# Generate trajectory curve (simple parabola approximation)
	trajectory_points.clear()
	var num_points = 50
	for i in range(num_points + 1):
		var t = float(i) / num_points
		var x = carry * t
		# Parabolic height: h = 4 * apex * t * (1 - t)
		var y = 4.0 * apex * t * (1.0 - t)
		trajectory_points.append(Vector2(x, y))

	queue_redraw()


func clear_trajectory() -> void:
	trajectory_points.clear()
	queue_redraw()
