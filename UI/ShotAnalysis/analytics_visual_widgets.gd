class_name AnalyticsVisualWidgets
extends RefCounted

## Custom-drawn vector analytics widgets for in-game shot analysis, swing replay, and player trends.
## All widgets are dark-themed, DPI-clean, and headless-safe (null font / zero-size guarded).


class BulletGaugeBar extends Control:
	var label_text: String = ""
	var value: float = 0.0
	var target_min: float = 0.0
	var target_max: float = 1.0
	var scale_min: float = 0.0
	var scale_max: float = 10.0
	var unit: String = ""
	var show_label: bool = true

	func _draw() -> void:
		if size.x < 8.0 or size.y < 8.0:
			return
		var font: Font = ThemeDB.fallback_font
		var pad_l: float = 0.0
		var pad_r: float = 4.0
		var value_w: float = 64.0 if show_label else 0.0
		if show_label and not label_text.is_empty():
			pad_l = minf(120.0, size.x * 0.36)
		var bar_x: float = pad_l + 4.0
		var bar_w: float = maxf(24.0, size.x - bar_x - value_w - pad_r)
		var bar_h: float = minf(10.0, size.y * 0.48)
		var bar_y: float = (size.y - bar_h) * 0.5

		# Track background
		draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.11, 0.14, 0.20, 1.0))
		draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.24, 0.30, 0.42, 0.7), false, 1.0)

		var span: float = maxf(0.0001, scale_max - scale_min)
		var lo: float = minf(target_min, target_max)
		var hi: float = maxf(target_min, target_max)
		var t_x0: float = bar_x + clampf((lo - scale_min) / span, 0.0, 1.0) * bar_w
		var t_x1: float = bar_x + clampf((hi - scale_min) / span, 0.0, 1.0) * bar_w
		var t_w: float = maxf(3.0, t_x1 - t_x0)

		# Optimal green target window
		draw_rect(Rect2(t_x0, bar_y - 1.5, t_w, bar_h + 3.0), Color(0.16, 0.78, 0.46, 0.34))
		draw_rect(Rect2(t_x0, bar_y - 1.5, t_w, bar_h + 3.0), Color(0.24, 0.90, 0.56, 0.8), false, 1.0)

		# Midpoint target tick
		var t_mid: float = t_x0 + t_w * 0.5
		draw_line(Vector2(t_mid, bar_y - 3.0), Vector2(t_mid, bar_y + bar_h + 3.0), Color(0.65, 0.95, 0.78, 0.65), 1.0)

		# Marker color by distance from target band
		var half_band: float = maxf(0.001, (hi - lo) * 0.5)
		var dist: float = 0.0
		if value < lo:
			dist = lo - value
		elif value > hi:
			dist = value - hi
		var marker_col: Color = Color(0.22, 0.90, 0.52, 1.0)
		if dist > half_band * 1.4:
			marker_col = Color(0.95, 0.34, 0.34, 1.0)
		elif dist > 0.0001:
			marker_col = Color(0.98, 0.74, 0.22, 1.0)

		var m_x: float = bar_x + clampf((value - scale_min) / span, 0.0, 1.0) * bar_w
		var cy: float = bar_y + bar_h * 0.5
		draw_circle(Vector2(m_x, cy), maxf(4.5, bar_h * 0.58), marker_col)
		draw_circle(Vector2(m_x, cy), maxf(4.5, bar_h * 0.58), Color(0.06, 0.08, 0.12, 0.9), false, 1.5)

		if font != null:
			var f_size: int = 11
			if show_label and not label_text.is_empty():
				draw_string(font, Vector2(2.0, size.y * 0.5 + 4.0), label_text, HORIZONTAL_ALIGNMENT_LEFT, pad_l - 4.0, f_size, Color(0.84, 0.88, 0.95, 1.0))
			if show_label:
				var fmt: String = ("%.2f" % value) if absf(scale_max - scale_min) < 2.0 else ("%.0f" % value if unit == "RPM" else "%.1f" % value)
				var val_str: String = (fmt + (" " + unit if not unit.is_empty() else "")).strip_edges()
				draw_string(font, Vector2(bar_x + bar_w + 6.0, size.y * 0.5 + 4.0), val_str, HORIZONTAL_ALIGNMENT_LEFT, value_w - 4.0, f_size, marker_col)


class DPlaneMatrixChart extends Control:
	var flight_counts: Dictionary = {}
	var total_shots: int = 0
	var is_lefty: bool = false

	const GRID_CELLS: Array = [
		[
			{"key": "Pull-Hook", "label": "Pull-Hook", "stock": false},
			{"key": "Straight-Pull", "label": "Straight Pull", "stock": false},
			{"key": "Pull-Fade", "label": "Pull-Fade", "stock": true}
		],
		[
			{"key": "Straight-Draw", "label": "Str-Draw", "stock": true},
			{"key": "Straight", "label": "Pure Straight", "stock": true},
			{"key": "Straight-Fade", "label": "Str-Fade", "stock": true}
		],
		[
			{"key": "Push-Draw", "label": "Push-Draw", "stock": true},
			{"key": "Straight-Push", "label": "Straight Push", "stock": false},
			{"key": "Push-Slice", "label": "Push-Slice", "stock": false}
		]
	]

	func _draw() -> void:
		if size.x < 40.0 or size.y < 40.0:
			return
		var font: Font = ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.11, 0.16, 1.0))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.20, 0.26, 0.36, 0.8), false, 1.0)

		var pad_l: float = 58.0
		var pad_r: float = 10.0
		var pad_t: float = 34.0
		var pad_b: float = 10.0
		var gw: float = maxf(60.0, size.x - pad_l - pad_r)
		var gh: float = maxf(60.0, size.y - pad_t - pad_b)
		var cw: float = gw / 3.0
		var ch: float = gh / 3.0

		var denom: int = maxi(1, total_shots)
		var row_labels: Array[String] = ["Pull (R)" if is_lefty else "Pull (L)", "On Line", "Push (L)" if is_lefty else "Push (R)"]
		var col_labels: Array[String] = ["Hook / Draw", "Straight", "Fade / Slice"]

		if font != null:
			draw_string(font, Vector2(pad_l, 14.0), "D-Plane 9-Shot Flight Matrix (%d shots)" % total_shots, HORIZONTAL_ALIGNMENT_LEFT, gw, 12, Color(0.90, 0.94, 1.0, 1.0))
			for c in range(3):
				draw_string(font, Vector2(pad_l + c * cw + 4.0, 29.0), col_labels[c], HORIZONTAL_ALIGNMENT_CENTER, cw - 8.0, 10, Color(0.68, 0.76, 0.88, 1.0))

		for r in range(3):
			if font != null:
				draw_string(font, Vector2(4.0, pad_t + r * ch + ch * 0.5 + 4.0), row_labels[r], HORIZONTAL_ALIGNMENT_LEFT, pad_l - 8.0, 10, Color(0.68, 0.76, 0.88, 1.0))
			for c in range(3):
				var cell: Dictionary = GRID_CELLS[r][c]
				var key: String = str(cell["key"])
				var cnt: int = int(flight_counts.get(key, 0))
				var pct: float = (float(cnt) / float(denom)) * 100.0
				var is_stock: bool = bool(cell["stock"])
				var rect: Rect2 = Rect2(pad_l + c * cw + 2.0, pad_t + r * ch + 2.0, cw - 4.0, ch - 4.0)

				var fill: Color = Color(0.12, 0.16, 0.23, 1.0)
				if cnt > 0:
					var intensity: float = clampf(0.22 + (pct / 100.0) * 0.70, 0.22, 0.88)
					if is_stock:
						fill = Color(0.12, 0.45 + intensity * 0.35, 0.28, 0.85)
					else:
						fill = Color(0.55 + intensity * 0.30, 0.22, 0.22, 0.78)
				elif is_stock:
					fill = Color(0.10, 0.18, 0.16, 0.85)

				draw_rect(rect, fill)
				var border_col: Color = Color(0.24, 0.82, 0.52, 0.65) if is_stock else Color(0.25, 0.32, 0.42, 0.65)
				draw_rect(rect, border_col, false, 1.5 if key == "Straight" else 1.0)

				if font != null:
					draw_string(font, Vector2(rect.position.x + 4.0, rect.position.y + 13.0), str(cell["label"]), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 8.0, 9, Color(0.84, 0.90, 0.96, 0.9))
					var stat_txt: String = ("%d (%.0f%%)" % [cnt, pct]) if cnt > 0 else "0"
					draw_string(font, Vector2(rect.position.x + 4.0, rect.position.y + rect.size.y - 7.0), stat_txt, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 8.0, 11, Color(1.0, 1.0, 1.0, 0.95) if cnt > 0 else Color(0.45, 0.52, 0.62, 0.8))


class BagGappingChart extends Control:
	var gapping_rows: Array = []

	func _draw() -> void:
		if size.x < 60.0 or size.y < 40.0:
			return
		var font: Font = ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.11, 0.16, 1.0))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.20, 0.26, 0.36, 0.8), false, 1.0)

		if gapping_rows.is_empty():
			if font != null:
				draw_string(font, Vector2(12.0, size.y * 0.5), "Hit 2+ clubs to visualize bag carry gapping.", HORIZONTAL_ALIGNMENT_LEFT, size.x - 24.0, 12, Color(0.65, 0.72, 0.82, 1.0))
			return

		var pad_l: float = 96.0
		var pad_r: float = 92.0
		var pad_t: float = 28.0
		var pad_b: float = 12.0
		var usable_w: float = maxf(60.0, size.x - pad_l - pad_r)
		var usable_h: float = maxf(40.0, size.y - pad_t - pad_b)

		var max_total: float = 100.0
		for row in gapping_rows:
			max_total = maxf(max_total, float(row.get("total_yds", row.get("carry_yds", 100.0))))
		max_total *= 1.08

		if font != null:
			draw_string(font, Vector2(10.0, 18.0), "Bag Yardage Ladder (Carry + Rollout & Inter-Club Gaps)", HORIZONTAL_ALIGNMENT_LEFT, size.x - 20.0, 12, Color(0.92, 0.96, 1.0, 1.0))

		var count: int = gapping_rows.size()
		var row_h: float = usable_h / float(maxi(1, count))
		var bar_h: float = clampf(row_h * 0.56, 8.0, 18.0)

		for i in range(count):
			var row: Dictionary = gapping_rows[i]
			var y: float = pad_t + i * row_h + (row_h - bar_h) * 0.5
			var carry: float = float(row.get("carry_yds", 0.0))
			var total: float = maxf(carry, float(row.get("total_yds", carry)))
			var gap: float = float(row.get("gap_yds", 0.0))
			var status: String = str(row.get("status", "optimal"))

			var carry_w: float = (carry / max_total) * usable_w
			var roll_w: float = maxf(0.0, ((total - carry) / max_total) * usable_w)

			var carry_col: Color = Color(0.24, 0.68, 0.96, 0.92)
			if status == "overlap":
				carry_col = Color(0.96, 0.62, 0.20, 0.94)
			elif status == "large_gap":
				carry_col = Color(0.92, 0.34, 0.34, 0.92)

			draw_rect(Rect2(pad_l, y, maxf(2.0, carry_w), bar_h), carry_col)
			if roll_w > 1.0:
				draw_rect(Rect2(pad_l + carry_w, y + 2.0, roll_w, maxf(4.0, bar_h - 4.0)), Color(carry_col.r, carry_col.g, carry_col.b, 0.35))

			if font != null:
				draw_string(font, Vector2(8.0, y + bar_h * 0.5 + 4.0), str(row.get("display_name", row.get("club", ""))), HORIZONTAL_ALIGNMENT_LEFT, pad_l - 12.0, 10, Color(0.86, 0.91, 0.98, 1.0))
				var val_txt: String = "%.0f/%.0fy" % [carry, total]
				if i > 0 and gap > 0.0:
					var flag: String = ""
					if status == "overlap":
						flag = " OVERLAP"
					elif status == "large_gap":
						flag = " GAP"
					val_txt += " (-%.0f%s)" % [gap, flag]
				elif i > 0 and gap <= 0.0:
					val_txt += " (%.0f OVERLAP)" % gap
				var txt_col: Color = Color(0.75, 0.85, 0.95, 1.0)
				if status == "overlap":
					txt_col = Color(0.98, 0.72, 0.26, 1.0)
				elif status == "large_gap":
					txt_col = Color(0.98, 0.45, 0.45, 1.0)
				draw_string(font, Vector2(pad_l + carry_w + roll_w + 6.0, y + bar_h * 0.5 + 4.0), val_txt, HORIZONTAL_ALIGNMENT_LEFT, size.x - (pad_l + carry_w + roll_w + 8.0), 10, txt_col)


class LaunchOptimizerChart extends Control:
	var shots: Array = []
	var benchmark: Dictionary = {}

	func _draw() -> void:
		if size.x < 50.0 or size.y < 50.0:
			return
		var font: Font = ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.11, 0.16, 1.0))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.20, 0.26, 0.36, 0.8), false, 1.0)

		var v_min_b: float = float(benchmark.get("vla_min", 10.5))
		var v_max_b: float = float(benchmark.get("vla_max", 15.0))
		var s_min_b: float = float(benchmark.get("spin_min", 2000.0))
		var s_max_b: float = float(benchmark.get("spin_max", 2800.0))

		var x_min: float = minf(v_min_b - 6.0, 5.0)
		var x_max: float = maxf(v_max_b + 6.0, 22.0)
		var y_min: float = maxf(400.0, s_min_b - 1800.0)
		var y_max: float = s_max_b + 2000.0

		var valid_pts: Array[Vector2] = []
		for sh in shots:
			if sh is Dictionary:
				var v: float = float(sh.get("vla", sh.get("VLA", NAN)))
				var sp: float = float(sh.get("total_spin", sh.get("TotalSpin", NAN)))
				if not is_nan(v) and not is_nan(sp) and sp > 100.0:
					valid_pts.append(Vector2(v, sp))
					x_min = minf(x_min, v - 2.0)
					x_max = maxf(x_max, v + 2.0)
					y_min = minf(y_min, sp - 500.0)
					y_max = maxf(y_max, sp + 500.0)
		y_min = maxf(0.0, y_min)

		var pad_l: float = 48.0
		var pad_r: float = 14.0
		var pad_t: float = 24.0
		var pad_b: float = 24.0
		var pw: float = maxf(40.0, size.x - pad_l - pad_r)
		var ph: float = maxf(40.0, size.y - pad_t - pad_b)

		var to_px := func(vla_val: float, spin_val: float) -> Vector2:
			var nx: float = clampf((vla_val - x_min) / maxf(0.01, x_max - x_min), 0.0, 1.0)
			var ny: float = clampf((spin_val - y_min) / maxf(1.0, y_max - y_min), 0.0, 1.0)
			return Vector2(pad_l + nx * pw, pad_t + (1.0 - ny) * ph)

		# Optimal launch-spin window rectangle
		var p_tl: Vector2 = to_px.call(v_min_b, s_max_b)
		var p_br: Vector2 = to_px.call(v_max_b, s_min_b)
		var opt_rect: Rect2 = Rect2(p_tl, Vector2(maxf(4.0, p_br.x - p_tl.x), maxf(4.0, p_br.y - p_tl.y)))
		draw_rect(opt_rect, Color(0.18, 0.78, 0.48, 0.22))
		draw_rect(opt_rect, Color(0.25, 0.88, 0.56, 0.78), false, 1.5)

		draw_line(Vector2(pad_l, pad_t), Vector2(pad_l, pad_t + ph), Color(0.35, 0.42, 0.54, 0.8), 1.0)
		draw_line(Vector2(pad_l, pad_t + ph), Vector2(pad_l + pw, pad_t + ph), Color(0.35, 0.42, 0.54, 0.8), 1.0)

		var mean_x: float = 0.0
		var mean_y: float = 0.0
		for pt in valid_pts:
			var px: Vector2 = to_px.call(pt.x, pt.y)
			var inside: bool = pt.x >= v_min_b and pt.x <= v_max_b and pt.y >= s_min_b and pt.y <= s_max_b
			draw_circle(px, 4.0, Color(0.30, 0.92, 0.58, 0.9) if inside else Color(0.95, 0.65, 0.28, 0.88))
			mean_x += pt.x
			mean_y += pt.y

		if not valid_pts.is_empty():
			mean_x /= float(valid_pts.size())
			mean_y /= float(valid_pts.size())
			var m_px: Vector2 = to_px.call(mean_x, mean_y)
			draw_line(m_px + Vector2(-7, 0), m_px + Vector2(7, 0), Color.WHITE, 2.0)
			draw_line(m_px + Vector2(0, -7), m_px + Vector2(0, 7), Color.WHITE, 2.0)

		if font != null:
			draw_string(font, Vector2(pad_l, 15.0), "Launch Optimizer (VLA vs Spin)", HORIZONTAL_ALIGNMENT_LEFT, pw, 11, Color(0.90, 0.95, 1.0, 1.0))
			draw_string(font, Vector2(4.0, pad_t + 10.0), "%.0fk" % (y_max / 1000.0), HORIZONTAL_ALIGNMENT_LEFT, pad_l - 6.0, 9, Color(0.65, 0.72, 0.82, 1.0))
			draw_string(font, Vector2(4.0, pad_t + ph), "%.0fk" % (y_min / 1000.0), HORIZONTAL_ALIGNMENT_LEFT, pad_l - 6.0, 9, Color(0.65, 0.72, 0.82, 1.0))
			draw_string(font, Vector2(pad_l, size.y - 6.0), "%.0f° VLA" % x_min, HORIZONTAL_ALIGNMENT_LEFT, 60.0, 9, Color(0.65, 0.72, 0.82, 1.0))
			draw_string(font, Vector2(size.x - 62.0, size.y - 6.0), "%.0f°" % x_max, HORIZONTAL_ALIGNMENT_RIGHT, 52.0, 9, Color(0.65, 0.72, 0.82, 1.0))


class TrendSparklineChart extends Control:
	var points: Array = []
	var title_text: String = "Trend"
	var unit: String = ""
	var target_min: float = 0.0
	var target_max: float = 0.0

	func _draw() -> void:
		if size.x < 40.0 or size.y < 36.0:
			return
		var font: Font = ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.11, 0.16, 1.0))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.20, 0.26, 0.36, 0.8), false, 1.0)

		var clean_vals: Array[float] = []
		for v in points:
			var f: float = float(v)
			if not is_nan(f):
				clean_vals.append(f)

		if font != null:
			var head: String = title_text
			if not clean_vals.is_empty():
				head += " (Latest: %.2f %s)" % [clean_vals[-1], unit] if absf(clean_vals[-1]) < 3.0 else " (Latest: %.1f %s)" % [clean_vals[-1], unit]
			draw_string(font, Vector2(10.0, 15.0), head.strip_edges(), HORIZONTAL_ALIGNMENT_LEFT, size.x - 20.0, 11, Color(0.90, 0.95, 1.0, 1.0))

		if clean_vals.size() < 2:
			if font != null:
				draw_string(font, Vector2(10.0, size.y * 0.58), "Need 2+ shots to plot trend.", HORIZONTAL_ALIGNMENT_LEFT, size.x - 20.0, 10, Color(0.60, 0.68, 0.78, 1.0))
			return

		var pad_l: float = 10.0
		var pad_r: float = 10.0
		var pad_t: float = 24.0
		var pad_b: float = 10.0
		var pw: float = maxf(20.0, size.x - pad_l - pad_r)
		var ph: float = maxf(20.0, size.y - pad_t - pad_b)

		var lo: float = minf(target_min, target_max)
		var hi: float = maxf(target_min, target_max)
		for v in clean_vals:
			lo = minf(lo, v)
			hi = maxf(hi, v)
		var pad_y: float = maxf(0.15, (hi - lo) * 0.15)
		lo -= pad_y
		hi += pad_y
		var span: float = maxf(0.01, hi - lo)

		# Target shaded zone
		if target_max > target_min:
			var y_top: float = pad_t + (1.0 - clampf((target_max - lo) / span, 0.0, 1.0)) * ph
			var y_bot: float = pad_t + (1.0 - clampf((target_min - lo) / span, 0.0, 1.0)) * ph
			draw_rect(Rect2(pad_l, y_top, pw, maxf(2.0, y_bot - y_top)), Color(0.18, 0.78, 0.46, 0.18))

		var pts: PackedVector2Array = PackedVector2Array()
		for i in range(clean_vals.size()):
			var nx: float = float(i) / float(clean_vals.size() - 1)
			var ny: float = clampf((clean_vals[i] - lo) / span, 0.0, 1.0)
			pts.append(Vector2(pad_l + nx * pw, pad_t + (1.0 - ny) * ph))

		for i in range(pts.size() - 1):
			draw_line(pts[i], pts[i + 1], Color(0.32, 0.76, 0.98, 0.92), 2.0)

		# 5-shot rolling average overlay
		if clean_vals.size() >= 3:
			var roll_pts: PackedVector2Array = PackedVector2Array()
			for i in range(clean_vals.size()):
				var start_i: int = maxi(0, i - 4)
				var s_sum: float = 0.0
				for j in range(start_i, i + 1):
					s_sum += clean_vals[j]
				var avg_v: float = s_sum / float(i - start_i + 1)
				var nx: float = float(i) / float(clean_vals.size() - 1)
				var ny: float = clampf((avg_v - lo) / span, 0.0, 1.0)
				roll_pts.append(Vector2(pad_l + nx * pw, pad_t + (1.0 - ny) * ph))
			for i in range(roll_pts.size() - 1):
				draw_line(roll_pts[i], roll_pts[i + 1], Color(0.98, 0.78, 0.24, 0.95), 2.0)

		draw_circle(pts[-1], 3.5, Color.WHITE)


static func create_bullet_gauge(label_text: String, value: float, target_min: float, target_max: float, scale_min: float, scale_max: float, unit: String = "", min_size: Vector2 = Vector2(220, 26), show_label: bool = true) -> Control:
	var g := BulletGaugeBar.new()
	g.label_text = label_text
	g.value = value
	g.target_min = target_min
	g.target_max = target_max
	g.scale_min = scale_min
	g.scale_max = scale_max
	g.unit = unit
	g.show_label = show_label
	g.custom_minimum_size = min_size
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return g


static func create_d_plane_matrix(flight_counts: Dictionary, total_shots: int, is_lefty: bool = false, min_size: Vector2 = Vector2(280, 180)) -> Control:
	var c := DPlaneMatrixChart.new()
	c.flight_counts = flight_counts
	c.total_shots = total_shots
	c.is_lefty = is_lefty
	c.custom_minimum_size = min_size
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func create_bag_gapping_chart(gapping_rows: Array, min_size: Vector2 = Vector2(420, 200)) -> Control:
	var c := BagGappingChart.new()
	c.gapping_rows = gapping_rows
	var dyn_h: float = maxf(min_size.y, 44.0 + float(gapping_rows.size()) * 24.0)
	c.custom_minimum_size = Vector2(min_size.x, dyn_h)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func create_launch_optimizer(shots: Array, benchmark: Dictionary, min_size: Vector2 = Vector2(280, 190)) -> Control:
	var c := LaunchOptimizerChart.new()
	c.shots = shots
	c.benchmark = benchmark
	c.custom_minimum_size = min_size
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func create_trend_sparkline(points: Array, title_text: String, unit: String, target_min: float, target_max: float, min_size: Vector2 = Vector2(260, 120)) -> Control:
	var c := TrendSparklineChart.new()
	c.points = points
	c.title_text = title_text
	c.unit = unit
	c.target_min = target_min
	c.target_max = target_max
	c.custom_minimum_size = min_size
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c
