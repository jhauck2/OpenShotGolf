extends Panel

## Overhead "radar" view showing shot shape from above
## Displays distance markers, shot path, and shot shape label
## Stores historic shots as grayed-out dots for dispersion analysis

var shot_path: PackedVector2Array = []
var max_distance: float = 150.0  # yards
var lateral_deviation: float = 0.0  # positive = right, negative = left
var shot_shape: String = "Straight"  # "Draw", "Fade", "Straight", "Hook", "Slice"

# Historic shots storage for dispersion plots
var historic_shots: Array[Vector2] = []  # Stores landing positions of previous shots
var current_shot_index: int = -1  # Index of the current shot being displayed


func _ready() -> void:
	custom_minimum_size = Vector2(200, 400)
	# Semi-transparent dark background
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	add_theme_stylebox_override("panel", stylebox)


func _draw() -> void:
	var panel_size = size
	var center_x = panel_size.x / 2.0
	var margin_top = 40.0
	var margin_bottom = 60.0

	# Draw distance arc markers
	_draw_distance_markers(panel_size, center_x, margin_top, margin_bottom)

	# Draw center line (from bottom to top)
	draw_line(
		Vector2(center_x, panel_size.y - margin_bottom),
		Vector2(center_x, margin_top),
		Color(1, 1, 1, 0.3),
		1.0
	)

	# Draw historic shots as grayed-out dots
	_draw_historic_shots(panel_size, center_x, margin_top, margin_bottom)

	# Draw shot path if available
	if shot_path.size() > 0:
		_draw_shot_path(panel_size, center_x, margin_top, margin_bottom)

	# Draw shot shape label at bottom
	_draw_shot_shape_label(panel_size, center_x)


func _draw_distance_markers(panel_size: Vector2, center_x: float, margin_top: float, margin_bottom: float) -> void:
	var marker_color = Color(1, 1, 1, 0.4)
	var available_height = panel_size.y - margin_top - margin_bottom

	# Draw arcs at 50, 100, 150, 200, 250 yard marks
	var distance_marks = [50, 100, 150, 200, 250]
	for dist in distance_marks:
		if dist > max_distance:
			continue

		# Flip Y: start from bottom, increase upward
		var y_pos = (panel_size.y - margin_bottom) - (dist / max_distance) * available_height
		var arc_width = panel_size.x * 0.4

		# Draw arc (approximate with line segments)
		var num_segments = 20
		var angle_start = -PI / 3.0
		var angle_end = PI / 3.0
		for i in range(num_segments):
			var t1 = float(i) / num_segments
			var t2 = float(i + 1) / num_segments
			var angle1 = lerp(angle_start, angle_end, t1)
			var angle2 = lerp(angle_start, angle_end, t2)

			var x1 = center_x + cos(angle1) * arc_width
			var y1 = y_pos
			var x2 = center_x + cos(angle2) * arc_width
			var y2 = y_pos

			draw_line(Vector2(x1, y1), Vector2(x2, y2), marker_color, 1.0)

		# Draw distance label for 100, 200, 250
		if dist in [100, 200, 250]:
			draw_string(ThemeDB.fallback_font, Vector2(center_x - 15, y_pos - 5), str(dist), HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color(1, 1, 1, 0.8))


func _draw_historic_shots(panel_size: Vector2, center_x: float, margin_top: float, margin_bottom: float) -> void:
	"""Draw all historic shots as grayed-out dots"""
	var available_height = panel_size.y - margin_top - margin_bottom
	var historic_color = Color(0.6, 0.6, 0.6, 0.4)  # Gray, semi-transparent
	var current_color = Color(1.0, 0.8, 0.0, 0.6)  # Brighter yellow for current shot

	for i in range(historic_shots.size()):
		var shot_point = historic_shots[i]
		var x = center_x + (shot_point.x / 50.0) * (panel_size.x * 0.4)  # Lateral in yards
		var y = (panel_size.y - margin_bottom) - (shot_point.y / max_distance) * available_height  # Distance in yards

		# Use different color for current shot vs historic
		var color = current_color if i == current_shot_index else historic_color
		var radius = 4.0 if i == current_shot_index else 3.0

		draw_circle(Vector2(x, y), radius, color)


func _draw_shot_path(panel_size: Vector2, center_x: float, margin_top: float, margin_bottom: float) -> void:
	var path_color = Color(1.0, 0.6, 0.0)  # Orange
	var available_height = panel_size.y - margin_top - margin_bottom

	# Convert shot path to screen coordinates
	var screen_points: PackedVector2Array = []
	for point in shot_path:
		var x = center_x + (point.x / 50.0) * (panel_size.x * 0.4)  # Lateral in yards
		# Flip Y: start from bottom, increase upward
		var y = (panel_size.y - margin_bottom) - (point.y / max_distance) * available_height  # Distance in yards
		screen_points.append(Vector2(x, y))

	# Draw the path
	if screen_points.size() > 1:
		for i in range(screen_points.size() - 1):
			draw_line(screen_points[i], screen_points[i + 1], path_color, 3.0)

	# Draw end point
	if screen_points.size() > 0:
		draw_circle(screen_points[-1], 5.0, path_color)


func _draw_shot_shape_label(panel_size: Vector2, center_x: float) -> void:
	var label_color = Color(1.0, 0.6, 0.0)  # Orange

	# Draw shot shape text at bottom, centered
	# Use center_x - half the panel width to center the label properly
	draw_string(
		ThemeDB.fallback_font,
		Vector2(center_x - panel_size.x / 2.0, panel_size.y - 20),
		shot_shape.to_upper(),
		HORIZONTAL_ALIGNMENT_CENTER,
		panel_size.x,
		28,
		label_color
	)


func set_shot_data(carry: float, lateral: float, total: float = 0.0) -> void:
	"""Update display with current shot data (called every frame during flight)"""
	max_distance = max(150.0, carry * 1.2)
	lateral_deviation = lateral

	# Determine shot shape based on lateral deviation
	if abs(lateral) < 3.0:
		shot_shape = "Straight"
	elif lateral < -10.0:
		shot_shape = "Hook"
	elif lateral < 0:
		shot_shape = "Draw"
	elif lateral > 10.0:
		shot_shape = "Slice"
	else:
		shot_shape = "Fade"

	# Generate shot path (simple curve)
	shot_path.clear()
	var num_points = 30
	for i in range(num_points + 1):
		var t = float(i) / num_points
		var distance = carry * t
		# Lateral curve: starts at 0, ends at lateral_deviation
		var lateral_pos = lateral * (t * t)  # Quadratic curve for more realistic shape
		shot_path.append(Vector2(lateral_pos, distance))

	queue_redraw()


func register_shot_landed(carry: float, lateral: float) -> void:
	"""Called when ball lands - stores shot in historic shots"""
	var landing_point = Vector2(lateral, carry)
	historic_shots.push_front(landing_point)
	if historic_shots.size() > 10:
		historic_shots.resize(10)
	current_shot_index = 0  # New shot is always at index 0 (most recent)
	queue_redraw()


func set_current_shot_index(index: int) -> void:
	"""Update which historic shot is currently being displayed"""
	if index >= 0 and index < historic_shots.size():
		current_shot_index = index
		queue_redraw()


func clear_shot() -> void:
	shot_path.clear()
	shot_shape = "Straight"
	current_shot_index = -1
	queue_redraw()


func clear_historic_shots() -> void:
	"""Clear all historic shots (useful for starting a new session)"""
	historic_shots.clear()
	current_shot_index = -1
	queue_redraw()
