extends Control

const GROUP_COLORS: Array[Color] = [
	Color(0.1, 0.85, 1.0),
	Color(1.0, 0.72, 0.12),
	Color(1.0, 0.3, 0.36),
	Color(0.4, 0.9, 0.42),
	Color(0.78, 0.45, 1.0),
	Color(1.0, 0.52, 0.2),
	Color(0.35, 0.95, 0.72),
	Color(0.95, 0.55, 0.72)
]

var _records: Array[Dictionary] = []
var _groups: Array[Dictionary] = []
var _show_best: bool = true


func set_analysis_data(records: Array[Dictionary], groups: Array[Dictionary], show_best: bool) -> void:
	_records = records
	_groups = groups
	_show_best = show_best
	queue_redraw()


func _draw() -> void:
	var width := size.x
	var height := size.y
	if width < 100.0 or height < 120.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.055, 0.07, 0.095))
	var font = ThemeDB.fallback_font
	var flight_bottom := height * 0.34
	draw_string(font, Vector2(16, 18), "FLIGHT PATH  ·  %s" % ("BEST SHOT" if _show_best else "GROUP AVERAGE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.84, 0.96))
	_draw_flight_chart(Rect2(18, 26, width - 36, flight_bottom - 38), font)
	draw_line(Vector2(12, flight_bottom), Vector2(width - 12, flight_bottom), Color(0.4, 0.48, 0.58, 0.8), 1.0)
	_draw_distance_ruler(Rect2(18, flight_bottom + 2, width - 36, 28), font)
	draw_string(font, Vector2(16, flight_bottom + 42), "LANDING DISPERSION  ·  DIMMED SHOTS ARE EXCLUDED FROM ANALYSIS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.84, 0.96))
	_draw_dispersion_chart(Rect2(18, flight_bottom + 48, width - 36, height - flight_bottom - 56), font)


func _draw_flight_chart(area: Rect2, font: Font) -> void:
	var max_apex := 5.0
	for group in _groups:
		var representative := _representative_shot(int(group["id"]))
		if not representative.is_empty():
			max_apex = maxf(max_apex, float(representative.get("Apex", 0.0)) * _distance_unit_factor())
	var scale_distance := _distance_scale_yards()
	var left := area.position.x + 48.0
	var right := area.end.x - 18.0
	var top := area.position.y + 16.0
	var bottom := area.end.y - 20.0
	if right <= left or bottom <= top:
		return
	var plot_width := right - left
	var plot_height := bottom - top
	for distance in range(0, int(scale_distance) + 1, 50):
		var x := _distance_x(distance, left, right, scale_distance)
		draw_line(Vector2(x, top), Vector2(x, bottom), Color(0.65, 0.72, 0.82, 0.2), 1.0)

	for group_index in range(_groups.size()):
		var group: Dictionary = _groups[group_index]
		var shot := _representative_shot(int(group["id"]))
		var color: Color = GROUP_COLORS[group_index % GROUP_COLORS.size()]
		var legend_columns := maxi(1, int(plot_width / 210.0))
		var legend_row := floori(float(group_index) / float(legend_columns))
		var label_x := left + 6.0 + float(group_index % legend_columns) * 200.0
		var label_y := top + 12.0 + float(legend_row) * 11.0
		draw_string(font, Vector2(label_x, label_y), str(group.get("label", "Group")), HORIZONTAL_ALIGNMENT_LEFT, 180, 9, color)
		if shot.is_empty():
			continue
		var carry_yards := _carry_yards(shot)
		if carry_yards <= 0.0:
			continue
		var points := _flight_points(shot)
		var projected := PackedVector2Array()
		var apex_screen := Vector2.ZERO
		var greatest_height := -1.0
		for point in points:
			var px := _distance_x(point.x, left, right, scale_distance)
			var py := bottom - clampf(point.y / (max_apex * 1.35), 0.0, 1.0) * (plot_height - 18.0)
			var screen_point := Vector2(px, py)
			projected.append(screen_point)
			if point.y > greatest_height:
				greatest_height = point.y
				apex_screen = screen_point
		if projected.size() > 1:
			draw_polyline(projected, color, 2.4, true)
		var landing_x := _distance_x(carry_yards, left, right, scale_distance)
		draw_circle(Vector2(landing_x, bottom), 3.5, color)
		var apex_height := _apex_display_height(shot) if shot.has("Apex") else greatest_height * (3.0 if _is_imperial_units() else 1.0)
		var apex_unit := "ft" if _is_imperial_units() else "m"
		draw_string(font, Vector2(apex_screen.x - 42, apex_screen.y - 4), "APEX %.0f %s" % [apex_height, apex_unit], HORIZONTAL_ALIGNMENT_CENTER, 84, 9, color)


func _draw_dispersion_chart(area: Rect2, font: Font) -> void:
	var left := area.position.x + 48.0
	var right := area.end.x - 18.0
	var top := area.position.y + 10.0
	var bottom := area.end.y - 8.0
	if right <= left or bottom <= top:
		return

	var max_lateral := 15.0
	for record in _records:
		var shot: Dictionary = record.get("shot", {})
		max_lateral = maxf(max_lateral, absf(_offline_yards(shot)))
	for group in _groups:
		var lateral_stats := _dispersion_axis_stats(int(group["id"]), false)
		max_lateral = maxf(max_lateral, absf(lateral_stats.x) + lateral_stats.y)
	max_lateral = maxf(ceil(max_lateral * 1.15 / 5.0) * 5.0, 15.0)
	var center_y := (top + bottom) * 0.5
	var max_distance := _distance_scale_yards()
	for distance in range(0, int(max_distance) + 1, 50):
		var x := _distance_x(distance, left, right, max_distance)
		draw_line(Vector2(x, top), Vector2(x, bottom), Color(0.65, 0.72, 0.82, 0.2), 1.0)
	draw_line(Vector2(left, center_y), Vector2(right, center_y), Color(0.9, 0.92, 0.96, 0.42), 1.2)
	draw_string(font, Vector2(left - 40, top + 10), "RIGHT", HORIZONTAL_ALIGNMENT_RIGHT, 36, 9, Color(0.7, 0.76, 0.84))
	draw_string(font, Vector2(left - 40, bottom), "LEFT", HORIZONTAL_ALIGNMENT_RIGHT, 36, 9, Color(0.7, 0.76, 0.84))

	for group_index in range(_groups.size()):
		var group_id := int(_groups[group_index]["id"])
		var active_points: Array[Vector2] = []
		for record in _records:
			if int(record.get("group_id", -1)) != group_id:
				continue
			var shot: Dictionary = record.get("shot", {})
			var x := _distance_x(_distance_yards(shot), left, right, max_distance)
			var y := center_y - clampf(_offline_yards(shot) / max_lateral, -1.0, 1.0) * ((bottom - top) * 0.5)
			var color: Color = GROUP_COLORS[group_index % GROUP_COLORS.size()]
			if bool(record.get("included", true)):
				color.a = 0.92
				active_points.append(Vector2(x, y))
			else:
				color.a = 0.2
			draw_circle(Vector2(x, y), 4.0 if bool(record.get("included", true)) else 3.5, color)
		if active_points.size() >= 2:
			_draw_dispersion_ellipse(active_points, GROUP_COLORS[group_index % GROUP_COLORS.size()], Rect2(Vector2(left, top), Vector2(right - left, bottom - top)))


func _draw_distance_ruler(area: Rect2, font: Font) -> void:
	var left := area.position.x + 48.0
	var right := area.end.x - 18.0
	var y := area.position.y + 1.0
	var max_distance := _distance_scale_yards()
	draw_line(Vector2(left, y), Vector2(right, y), Color(0.72, 0.8, 0.9, 0.65), 1.0)
	var distance_unit := "yd" if _is_imperial_units() else "m"
	for distance in range(0, int(max_distance) + 1, 50):
		var x := _distance_x(distance, left, right, max_distance)
		draw_line(Vector2(x, y - 3.0), Vector2(x, y + 3.0), Color(0.8, 0.86, 0.94, 0.8), 1.0)
		draw_string(font, Vector2(x - 18.0, y + 14.0), "%d %s" % [distance, distance_unit], HORIZONTAL_ALIGNMENT_CENTER, 36, 9, Color(0.78, 0.84, 0.92))


func _distance_scale_yards() -> float:
	var max_distance := 50.0
	for record in _records:
		var shot: Dictionary = record.get("shot", {})
		max_distance = maxf(max_distance, _distance_yards(shot))
	for group in _groups:
		var representative := _representative_shot(int(group["id"]))
		if not representative.is_empty():
			max_distance = maxf(max_distance, _carry_yards(representative))
		var dispersion_stats := _dispersion_axis_stats(int(group["id"]), true)
		max_distance = maxf(max_distance, dispersion_stats.x + dispersion_stats.y)
	return maxf(ceil(max_distance * 1.1 / 50.0) * 50.0, 50.0)


func _distance_x(yards: float, left: float, right: float, max_distance: float) -> float:
	return left + clampf(yards / max_distance, 0.0, 1.0) * (right - left)


func _representative_shot(group_id: int) -> Dictionary:
	var selected: Array[Dictionary] = []
	for record in _records:
		if int(record.get("group_id", -1)) == group_id and bool(record.get("included", true)):
			selected.append(record.get("shot", {}))
	if selected.is_empty():
		return {}
	if _show_best:
		var best: Dictionary = selected[0]
		for shot in selected:
			if _distance_yards(shot) > _distance_yards(best):
				best = shot
		return best

	var sums := {"CarryDistance": 0.0, "TotalDistance": 0.0, "Apex": 0.0}
	var counts := {"CarryDistance": 0, "TotalDistance": 0, "Apex": 0}
	for shot in selected:
		for key in sums.keys():
			if shot.has(key) and (typeof(shot[key]) == TYPE_INT or typeof(shot[key]) == TYPE_FLOAT):
				sums[key] += float(shot[key])
				counts[key] += 1
	var average := {}
	for key in sums.keys():
		if counts[key] > 0:
			average[key] = sums[key] / counts[key]
	if not average.has("CarryDistance"):
		average["CarryDistance"] = float(average.get("TotalDistance", 0.0))
	if not average.has("TotalDistance"):
		average["TotalDistance"] = float(average.get("CarryDistance", 0.0))
	return average


func _flight_points(shot: Dictionary) -> PackedVector2Array:
	var points := PackedVector2Array()
	var trace: Array = shot.get("tracer_points", [])
	if trace.size() >= 2 and trace[0] is Vector3:
		var start: Vector3 = trace[0]
		var max_height := 0.0
		for point in trace:
			if point is Vector3:
				max_height = maxf(max_height, point.y - start.y)
		if max_height > 0.0:
			for point in trace:
				if point is Vector3:
					var unit_factor := _distance_unit_factor()
					var horizontal := Vector2(point.x - start.x, point.z - start.z).length() * unit_factor
					points.append(Vector2(horizontal, maxf(point.y - start.y, 0.0) * unit_factor))
			if points.size() > 1:
				return points
	var carry_yards := _carry_yards(shot)
	var apex_yards := maxf(float(shot.get("Apex", 0.0)) * _distance_unit_factor(), 1.0)
	for index in range(25):
		var t := float(index) / 24.0
		points.append(Vector2(carry_yards * t, 4.0 * apex_yards * t * (1.0 - t)))
	return points


func _dispersion_axis_stats(group_id: int, use_distance: bool) -> Vector2:
	var values: Array[float] = []
	for record in _records:
		if int(record.get("group_id", -1)) != group_id or not bool(record.get("included", true)):
			continue
		var shot: Dictionary = record.get("shot", {})
		values.append(_distance_yards(shot) if use_distance else _offline_yards(shot))
	if values.is_empty():
		return Vector2.ZERO
	var mean := 0.0
	for value in values:
		mean += value
	mean /= values.size()
	var variance := 0.0
	for value in values:
		variance += pow(value - mean, 2.0)
	var radius := maxf(sqrt(variance / values.size()) * 2.0, 5.0)
	return Vector2(mean, radius)


func _bounded_ellipse_radii(points: Array[Vector2], bounds: Rect2) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var mean := Vector2.ZERO
	for point in points:
		mean += point
	mean /= points.size()
	var variance_x := 0.0
	var variance_y := 0.0
	for point in points:
		variance_x += pow(point.x - mean.x, 2.0)
		variance_y += pow(point.y - mean.y, 2.0)
	var radius_x := minf(maxf(sqrt(variance_x / points.size()) * 2.0, 5.0), maxf(minf(mean.x - bounds.position.x, bounds.end.x - mean.x) - 2.0, 0.0))
	var radius_y := minf(maxf(sqrt(variance_y / points.size()) * 2.0, 5.0), maxf(minf(mean.y - bounds.position.y, bounds.end.y - mean.y) - 2.0, 0.0))
	return Vector2(radius_x, radius_y)


func _draw_dispersion_ellipse(points: Array[Vector2], color: Color, bounds: Rect2) -> void:
	var mean := Vector2.ZERO
	for point in points:
		mean += point
	mean /= points.size()
	var radii := _bounded_ellipse_radii(points, bounds)
	if radii.x < 1.0 or radii.y < 1.0:
		return
	var ellipse := PackedVector2Array()
	for index in range(41):
		var angle := TAU * float(index) / 40.0
		ellipse.append(mean + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	var outline := Color(color.r, color.g, color.b, 0.72)
	var fill := Color(color.r, color.g, color.b, 0.08)
	draw_colored_polygon(ellipse, fill)
	draw_polyline(ellipse, outline, 1.6, true)


func _distance_yards(shot: Dictionary) -> float:
	var meters := float(shot.get("TotalDistance", shot.get("CarryDistance", 0.0)))
	return maxf(meters, 0.0) * _distance_unit_factor()


func _carry_yards(shot: Dictionary) -> float:
	var meters := float(shot.get("CarryDistance", shot.get("TotalDistance", 0.0)))
	return maxf(meters, 0.0) * _distance_unit_factor()


func _apex_feet(shot: Dictionary) -> float:
	return maxf(float(shot.get("Apex", 0.0)), 0.0) * 3.28084


func _apex_display_height(shot: Dictionary) -> float:
	return _apex_feet(shot) if _is_imperial_units() else maxf(float(shot.get("Apex", 0.0)), 0.0)


func _offline_yards(shot: Dictionary) -> float:
	var meters := float(shot.get("SideDistance", 0.0))
	if absf(meters) < 0.001:
		var trace: Array = shot.get("tracer_points", [])
		if trace.size() >= 2 and trace[0] is Vector3 and trace[-1] is Vector3:
			meters = trace[-1].z - trace[0].z
	return meters * _distance_unit_factor()


func _distance_unit_factor() -> float:
	return 1.09361 if _is_imperial_units() else 1.0


func _is_imperial_units() -> bool:
	var global_settings := get_node_or_null("/root/GlobalSettings")
	if global_settings == null:
		return true
	var range_settings: Variant = global_settings.get("range_settings")
	if range_settings == null:
		return true
	var range_units: Variant = range_settings.get("range_units")
	if range_units == null:
		return true
	return int(range_units.get("value")) == PhysicsEnums.Units.IMPERIAL
