class_name ClubDeliveryVisuals
extends RefCounted

# =============================================================================
# ClubDeliveryVisuals
# Realistic 2D canvas drawing widgets for golf club delivery:
# 1. ClubFaceAngleVisual: Top-down view of realistic clubhead rotating relative to target line.
# 2. ImpactLocationVisual: Front-on view of realistic clubface (Driver, Iron with grooves, etc.)
#    with sweet spot crosshair and single-shot bloom or multi-shot heatmap.
# 3. ClubPathVisual: Top-down view showing swing path vector arrow relative to target line.
# 4. ClubDeliveryVisualsPanel: Container laying out all 3 cards side-by-side with
#    launch monitor availability checks and placeholder messages.
# =============================================================================

const TEX_IRON_FACE = preload("res://assets/images/clubs/iron_face.png")
const TEX_DRIVER_FACE = preload("res://assets/images/clubs/driver_face.png")
const TEX_IRON_TOP = preload("res://assets/images/clubs/iron_top.png")
const TEX_DRIVER_TOP = preload("res://assets/images/clubs/driver_top.png")
const ShotAnalyticsEngineScript = preload("res://Utils/shot_analytics_engine.gd")

static func create_panel(data: Dictionary = {}, is_profile: bool = false, is_lefty: Variant = null) -> PanelContainer:
	return ClubDeliveryVisualsPanel.new(data, is_profile, is_lefty)


static func is_left_handed(data: Dictionary = {}) -> bool:
	if data.has("is_lefty"):
		return bool(data["is_lefty"])
	if data.has("is_left_handed"):
		return bool(data["is_left_handed"])
	if data.has("handedness"):
		return int(data["handedness"]) == 1
	var p_name = str(data.get("Player", data.get("player", "")))
	if Engine.has_singleton("MultiplayerManager"):
		var mp = Engine.get_singleton("MultiplayerManager")
		if mp != null:
			if not p_name.is_empty() and mp.has_method("get_player_handedness"):
				return mp.get_player_handedness(p_name) == 1
			if mp.has_method("get_active_player"):
				var ap = mp.get_active_player()
				if ap.has("handedness"):
					return int(ap.get("handedness", 0)) == 1
	elif Engine.get_main_loop() != null and Engine.get_main_loop().root != null:
		var root = Engine.get_main_loop().root
		if root.has_node("MultiplayerManager"):
			var mp = root.get_node("MultiplayerManager")
			if not p_name.is_empty() and mp.has_method("get_player_handedness"):
				return mp.get_player_handedness(p_name) == 1
			if mp.has_method("get_active_player"):
				var ap = mp.get_active_player()
				if ap.has("handedness"):
					return int(ap.get("handedness", 0)) == 1
		if root.has_node("LaunchMonitorManager"):
			var lm = root.get_node("LaunchMonitorManager")
			if lm.has_method("get_handedness"):
				return lm.get_handedness() == 1
	return false


# -----------------------------------------------------------------------------
# 1. CLUB FACE ANGLE VISUAL (Realistic Top-Down Rotating Clubhead)
# -----------------------------------------------------------------------------
class ClubFaceAngleVisual extends Control:
	var face_angle: float = 0.0 # Degrees: positive = Open, negative = Closed, 0 = Square
	var is_average: bool = false
	var sample_count: int = 0
	var club_category: String = "driver"
	var is_lefty: bool = false

	func _init(angle: float = 0.0, is_avg: bool = false, count: int = 0, cat: String = "driver", lefty: bool = false) -> void:
		face_angle = angle
		is_average = is_avg
		sample_count = count
		club_category = cat
		is_lefty = lefty
		custom_minimum_size = Vector2(140, 135)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL

	func set_data(angle: float, is_avg: bool = false, count: int = 0, cat: String = "driver", lefty: bool = false) -> void:
		face_angle = angle
		is_average = is_avg
		sample_count = count
		club_category = cat
		is_lefty = lefty
		queue_redraw()

	func _draw() -> void:
		var w = size.x
		var h = size.y
		if w < 10 or h < 10:
			return

		var center = Vector2(w * 0.5, h * 0.43)

		# 1. Background radar rings
		draw_arc(center, 42.0, 0, TAU, 32, Color(0.18, 0.28, 0.38, 0.25), 1.0)
		draw_arc(center, 24.0, 0, TAU, 24, Color(0.18, 0.28, 0.38, 0.2), 1.0)

		# 2. Target line (dashed vertical line pointing UP)
		var t_start = Vector2(center.x, h - 28)
		var t_end = Vector2(center.x, 14)
		_draw_dashed_line(t_start, t_end, Color(0.5, 0.7, 0.9, 0.45), 1.5, 4.0, 3.0)

		# Target arrowhead
		var arr_col = Color(0.6, 0.85, 1.0, 0.85)
		draw_polyline(PackedVector2Array([
			Vector2(center.x - 5, 20),
			Vector2(center.x, 12),
			Vector2(center.x + 5, 20)
		]), arr_col, 2.0, true)

		var font = ThemeDB.fallback_font
		if font != null:
			draw_string(font, Vector2(center.x - 22, 10), "TARGET", HORIZONTAL_ALIGNMENT_CENTER, 44, 9, Color(0.6, 0.8, 0.95, 0.7))

		# 3. Square reference line (orange/gold line perpendicular to target line, extends beyond clubhead)
		var ref_extent = min(w * 0.46, 76.0)
		var ref_left = Vector2(center.x - ref_extent, center.y)
		var ref_right = Vector2(center.x + ref_extent, center.y)
		var square_col = Color(1.0, 0.60, 0.15, 0.95)
		draw_line(ref_left, ref_right, square_col, 2.2, true)
		if font != null:
			if not is_lefty:
				draw_string(font, Vector2(center.x + ref_extent - 28, center.y - 4), "0° SQ", HORIZONTAL_ALIGNMENT_RIGHT, 30, 8, Color(1.0, 0.70, 0.25, 0.9))
			else:
				draw_string(font, Vector2(center.x - ref_extent, center.y - 4), "0° SQ", HORIZONTAL_ALIGNMENT_LEFT, 30, 8, Color(1.0, 0.70, 0.25, 0.9))

		# 4. Realistic Rotating Club Image (Shaft on Left for righty, Shaft on Right for lefty; Face Up)
		var rot_deg = clamp(face_angle, -25.0, 25.0)
		var eff_rot_deg = -rot_deg if is_lefty else rot_deg
		var rot_rad = deg_to_rad(eff_rot_deg)
		var is_wood = club_category in ["driver", "wood", "hybrid"]
		var tex = TEX_DRIVER_TOP if is_wood else TEX_IRON_TOP

		var sc = clamp(w / 1100.0, 0.08, 0.13)
		var pivot = Vector2(512.0, 512.0)
		var scale_x = -sc if is_lefty else sc

		draw_set_transform(center, rot_rad, Vector2(scale_x, sc))
		draw_texture(tex, -pivot)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# 5. Club Face Angle Line (purple/magenta line along rotated face, extends beyond clubhead)
		var abs_ang = abs(face_angle)
		if abs_ang >= 0.2:
			var dir = Vector2(cos(rot_rad), sin(rot_rad))
			var face_line_start = center - dir * ref_extent
			var face_line_end = center + dir * ref_extent
			var angle_col = Color(0.85, 0.45, 0.98, 0.95)
			draw_line(face_line_start, face_line_end, angle_col, 2.2, true)

			# Angle measurement arc between square line (0° for righty, PI for lefty) and face line
			var arc_r = min(ref_extent * 0.65, 44.0)
			if not is_lefty:
				var start_ang = 0.0 if rot_rad >= 0 else rot_rad
				var end_ang = rot_rad if rot_rad >= 0 else 0.0
				draw_arc(center, arc_r, min(start_ang, end_ang), max(start_ang, end_ang), 16, angle_col, 2.0)
				draw_circle(center + Vector2(arc_r, 0), 2.0, Color(1.0, 0.65, 0.2, 0.8))
			else:
				var start_ang = PI if rot_rad <= 0 else (PI + rot_rad)
				var end_ang = (PI + rot_rad) if rot_rad <= 0 else PI
				draw_arc(center, arc_r, min(start_ang, end_ang), max(start_ang, end_ang), 16, angle_col, 2.0)
				draw_circle(center + Vector2(-arc_r, 0), 2.0, Color(1.0, 0.65, 0.2, 0.8))


		# 6. Golf Ball at address
		var ball_pos = Vector2(center.x, center.y - 12)
		var ball_radius = 7.0
		draw_circle(ball_pos + Vector2(1, 1), ball_radius, Color(0, 0, 0, 0.4))
		draw_circle(ball_pos, ball_radius, Color(0.92, 0.94, 0.96))
		draw_arc(ball_pos, ball_radius, 0, TAU, 24, Color(0.6, 0.65, 0.72), 1.2, true)
		draw_circle(ball_pos + Vector2(-2, -2), 1.5, Color(1, 1, 1, 0.8))

		# 7. Bottom Degree Label (Placed in dedicated pill at bottom to never overlap lines)
		var face_stroke_col = Color(0.35, 0.95, 0.6) if abs_ang <= 1.2 else (Color(1.0, 0.75, 0.3) if abs_ang <= 3.5 else Color(1.0, 0.38, 0.38))

		if font != null:
			var status_str: String
			if abs_ang < 0.2:
				status_str = "SQUARE (0.0°)"
			elif face_angle > 0.0:
				status_str = "%.1f° OPEN" % face_angle
			else:
				status_str = "%.1f° CLOSED" % abs(face_angle)

			if is_average:
				status_str = "Avg " + status_str

			var badge_w = min(w - 16.0, 114.0)
			var badge_h = 20.0
			var badge_x = (w - badge_w) * 0.5
			var badge_y = h - 23.0
			var badge_rect = Rect2(Vector2(badge_x, badge_y), Vector2(badge_w, badge_h))
			draw_rect(badge_rect, Color(0.04, 0.07, 0.12, 0.88), true, 4.0)
			draw_rect(badge_rect, Color(face_stroke_col.r, face_stroke_col.g, face_stroke_col.b, 0.45), false, 1.0, 4.0)
			draw_string(font, Vector2(badge_x, badge_y + 14), status_str, HORIZONTAL_ALIGNMENT_CENTER, int(badge_w), 10, face_stroke_col)


	func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash_len: float, gap_len: float) -> void:
		var total_len = from.distance_to(to)
		if total_len <= 0.001:
			return
		var dir = (to - from).normalized()
		var curr = 0.0
		while curr < total_len:
			var next_end = min(curr + dash_len, total_len)
			draw_line(from + dir * curr, from + dir * next_end, color, width)
			curr += dash_len + gap_len


# -----------------------------------------------------------------------------
# 2. IMPACT LOCATION VISUAL (Realistic Photorealistic Clubface & Heatmap)
# -----------------------------------------------------------------------------
class ImpactLocationVisual extends Control:
	var club_name: String = "Driver"
	var club_category: String = "driver"
	var horizontal_mm: float = 0.0 # Positive = Toe, Negative = Heel
	var vertical_mm: float = 0.0   # Positive = High, Negative = Low
	var impact_points: Array = []  # Array of { "h": float, "v": float } for multi-shot heatmap
	var is_heatmap_mode: bool = false

	func _init(c_name: String = "Driver", h_mm: float = 0.0, v_mm: float = 0.0, points: Array = [], heatmap_mode: bool = false) -> void:
		set_data(c_name, h_mm, v_mm, points, heatmap_mode)
		custom_minimum_size = Vector2(140, 135)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL

	func set_data(c_name: String, h_mm: float = 0.0, v_mm: float = 0.0, points: Array = [], heatmap_mode: bool = false) -> void:
		club_name = c_name
		club_category = GolfSwingAnalyzer._classify_club(c_name)
		horizontal_mm = h_mm
		vertical_mm = v_mm
		impact_points = points
		is_heatmap_mode = heatmap_mode or (not points.is_empty())
		queue_redraw()

	func _draw() -> void:
		var w = size.x
		var h = size.y
		if w < 10 or h < 10:
			return

		var font = ThemeDB.fallback_font
		if font != null:
			var disp_club = GolfSwingAnalyzer.get_club_display_name(club_name)
			draw_string(font, Vector2(6, 12), disp_club.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, int(w - 12), 10, Color(0.6, 0.8, 0.95, 0.75))

		# Select realistic clubface texture
		var is_wood = club_category in ["driver", "wood", "hybrid"]
		var tex = TEX_DRIVER_FACE if is_wood else TEX_IRON_FACE

		# Fit realistic club image into card width (4:3 ratio)
		var tex_w = min(w * 0.96, (h - 26.0) * (1200.0 / 896.0))
		var tex_h = tex_w * (896.0 / 1200.0)
		var tex_pos = Vector2((w - tex_w) * 0.5, (h - 20.0 - tex_h) * 0.5 + 10.0)
		var dest_rect = Rect2(tex_pos, Vector2(tex_w, tex_h))

		# Draw the photorealistic clubface image
		draw_texture_rect(tex, dest_rect, false)

		# Sweet spot coordinates on the realistic texture:
		var sweet_spot = Vector2.ZERO
		var mm_scale = 1.0

		if is_wood:
			# Driver sweet spot center (laser-etched circle center)
			sweet_spot = tex_pos + Vector2(tex_w * 0.492, tex_h * 0.478)
			mm_scale = (tex_w * 0.38) / 54.0 # ~54mm face width
		else:
			# Iron sweet spot center matching user-specified location (groove 3-4 center)
			sweet_spot = tex_pos + Vector2(tex_w * 0.400, tex_h * 0.670)
			mm_scale = (tex_w * 0.36) / 48.0 # ~48mm groove width

		# Sweet spot crosshairs (dashed lines intersecting at sweet spot)
		var ch_len = 16.0
		_draw_dashed_line(sweet_spot - Vector2(ch_len, 0), sweet_spot + Vector2(ch_len, 0), Color(0.35, 0.75, 1.0, 0.45), 1.0, 3.0, 2.0)
		_draw_dashed_line(sweet_spot - Vector2(0, ch_len), sweet_spot + Vector2(0, ch_len), Color(0.35, 0.75, 1.0, 0.45), 1.0, 3.0, 2.0)
		draw_circle(sweet_spot, 1.8, Color(0.4, 0.85, 1.0, 0.8))

		# Strike / Heatmap:
		# In front view of iron & driver: Toe is on LEFT (-X), Heel is on RIGHT (+X).
		# High is UP (-Y), Low is DOWN (+Y).
		if is_heatmap_mode and not impact_points.is_empty():
			var px_pts: Array[Vector2] = []
			for pt in impact_points:
				var h_offset = -float(pt.get("h", 0.0)) * mm_scale
				var v_offset = -float(pt.get("v", 0.0)) * mm_scale
				var pt_pos = sweet_spot + Vector2(h_offset, v_offset)
				px_pts.append(pt_pos)

				# Translucent multi-hit heat bloom
				draw_circle(pt_pos, 15.0, Color(0.1, 0.45, 0.9, 0.12))
				draw_circle(pt_pos, 9.0, Color(0.3, 0.85, 0.3, 0.22))
				draw_circle(pt_pos, 4.5, Color(1.0, 0.35, 0.1, 0.48))
				draw_circle(pt_pos, 2.2, Color(1.0, 0.9, 0.3, 0.78))

			if px_pts.size() >= 3:
				var ell: Dictionary = ShotAnalyticsEngineScript.compute_covariance_ellipse(px_pts)
				if bool(ell.get("valid", false)):
					var mean_pos: Vector2 = ell.get("mean", sweet_spot)
					var rx: float = clampf(float(ell.get("std_major", 4.0)) * 1.515, 4.0, w * 0.42)
					var ry: float = clampf(float(ell.get("std_minor", 4.0)) * 1.515, 4.0, h * 0.42)
					var ang: float = float(ell.get("angle_rad", 0.0))
					var poly: PackedVector2Array = PackedVector2Array()
					for s_idx in range(33):
						var th: float = (float(s_idx) / 32.0) * TAU
						var lx: float = cos(th) * rx
						var ly: float = sin(th) * ry
						var r_pt: Vector2 = Vector2(lx * cos(ang) - ly * sin(ang), lx * sin(ang) + ly * cos(ang))
						poly.append(mean_pos + r_pt)
					draw_colored_polygon(poly, Color(0.25, 0.88, 0.65, 0.14))
					draw_polyline(poly, Color(0.35, 0.95, 0.75, 0.75), 1.5, true)
					draw_line(mean_pos + Vector2(-6.0, 0.0), mean_pos + Vector2(6.0, 0.0), Color.WHITE, 1.8)
					draw_line(mean_pos + Vector2(0.0, -6.0), mean_pos + Vector2(0.0, 6.0), Color.WHITE, 1.8)

			if font != null:
				var hit_text = "%d SHOTS HEATMAP" % impact_points.size()
				var badge_w = min(w - 16.0, 114.0)
				var badge_h = 20.0
				var badge_x = (w - badge_w) * 0.5
				var badge_y = h - 23.0
				var badge_rect = Rect2(Vector2(badge_x, badge_y), Vector2(badge_w, badge_h))
				draw_rect(badge_rect, Color(0.04, 0.07, 0.12, 0.88), true, 4.0)
				draw_rect(badge_rect, Color(1.0, 0.85, 0.4, 0.45), false, 1.0, 4.0)
				draw_string(font, Vector2(badge_x, badge_y + 14), hit_text, HORIZONTAL_ALIGNMENT_CENTER, int(badge_w), 10, Color(1.0, 0.85, 0.4))
		else:
			var strike_pos = sweet_spot + Vector2(-horizontal_mm * mm_scale, -vertical_mm * mm_scale)

			# 4-layer glowing heat bloom
			draw_circle(strike_pos, 16.0, Color(0.1, 0.55, 1.0, 0.22)) # Cyan outer halo
			draw_circle(strike_pos, 10.5, Color(0.25, 0.85, 0.35, 0.42)) # Green mid glow
			draw_circle(strike_pos, 6.0, Color(1.0, 0.75, 0.15, 0.75)) # Yellow inner ring
			draw_circle(strike_pos, 3.2, Color(1.0, 0.25, 0.1, 0.95)) # Red hot core
			draw_circle(strike_pos, 1.4, Color(1.0, 1.0, 1.0, 0.95)) # White ping

			if font != null:
				var desc = _get_strike_description(horizontal_mm, vertical_mm)
				var dist = strike_pos.distance_to(sweet_spot)
				var desc_col = Color(0.35, 0.95, 0.6) if dist < (6.0 * mm_scale) else (Color(1.0, 0.75, 0.3) if dist < (14.0 * mm_scale) else Color(1.0, 0.38, 0.38))
				var badge_w = min(w - 16.0, 120.0)
				var badge_h = 20.0
				var badge_x = (w - badge_w) * 0.5
				var badge_y = h - 23.0
				var badge_rect = Rect2(Vector2(badge_x, badge_y), Vector2(badge_w, badge_h))
				draw_rect(badge_rect, Color(0.04, 0.07, 0.12, 0.88), true, 4.0)
				draw_rect(badge_rect, Color(desc_col.r, desc_col.g, desc_col.b, 0.45), false, 1.0, 4.0)
				draw_string(font, Vector2(badge_x, badge_y + 14), desc, HORIZONTAL_ALIGNMENT_CENTER, int(badge_w), 9, desc_col)


	func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash_len: float, gap_len: float) -> void:
		var total_len = from.distance_to(to)
		if total_len <= 0.001:
			return
		var dir = (to - from).normalized()
		var curr = 0.0
		while curr < total_len:
			var next_end = min(curr + dash_len, total_len)
			draw_line(from + dir * curr, from + dir * next_end, color, width)
			curr += dash_len + gap_len

	func _get_strike_description(h_val: float, v_val: float) -> String:
		var abs_h = abs(h_val)
		var abs_v = abs(v_val)

		if abs_h < 3.0 and abs_v < 3.0:
			return "SWEET SPOT (CENTER)"

		var h_str = ""
		if abs_h >= 3.0:
			h_str = "%.0fmm %s" % [abs_h, "TOE" if h_val > 0 else "HEEL"]

		var v_str = ""
		if abs_v >= 3.0:
			v_str = "%.0fmm %s" % [abs_v, "HIGH" if v_val > 0 else "LOW (THIN)"]

		if not h_str.is_empty() and not v_str.is_empty():
			return "%s / %s" % [h_str, v_str]
		elif not h_str.is_empty():
			return h_str
		elif not v_str.is_empty():
			return v_str
		return "CENTER"


# -----------------------------------------------------------------------------
# 3. CLUB PATH VISUAL (Directional Vector Arrow & Angle)
# -----------------------------------------------------------------------------
class ClubPathVisual extends Control:
	var club_path: float = 0.0 # Degrees: positive = In-to-Out, negative = Out-to-In
	var is_average: bool = false
	var sample_count: int = 0
	var club_category: String = "driver"
	var is_lefty: bool = false

	func _init(path_deg: float = 0.0, is_avg: bool = false, count: int = 0, cat: String = "driver", lefty: bool = false) -> void:
		club_path = path_deg
		is_average = is_avg
		sample_count = count
		club_category = cat
		is_lefty = lefty
		custom_minimum_size = Vector2(140, 135)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL

	func set_data(path_deg: float, is_avg: bool = false, count: int = 0, cat: String = "driver", lefty: bool = false) -> void:
		club_path = path_deg
		is_average = is_avg
		sample_count = count
		club_category = cat
		is_lefty = lefty
		queue_redraw()

	func _draw() -> void:
		var w = size.x
		var h = size.y
		if w < 10 or h < 10:
			return

		var center = Vector2(w * 0.5, h * 0.50)

		# 1. Background radar circles
		draw_arc(center, 42.0, 0, TAU, 32, Color(0.18, 0.28, 0.38, 0.25), 1.0)
		draw_arc(center, 24.0, 0, TAU, 24, Color(0.18, 0.28, 0.38, 0.2), 1.0)

		# 2. Target Line (dashed vertical line pointing UP)
		var t_start = Vector2(center.x, h - 18)
		var t_end = Vector2(center.x, 14)
		_draw_dashed_line(t_start, t_end, Color(0.5, 0.7, 0.9, 0.45), 1.5, 4.0, 3.0)

		# Target arrowhead
		draw_polyline(PackedVector2Array([
			Vector2(center.x - 5, 20),
			Vector2(center.x, 12),
			Vector2(center.x + 5, 20)
		]), Color(0.6, 0.85, 1.0, 0.85), 2.0, true)

		var font = ThemeDB.fallback_font
		if font != null:
			draw_string(font, Vector2(center.x - 22, 10), "TARGET", HORIZONTAL_ALIGNMENT_CENTER, 44, 9, Color(0.6, 0.8, 0.95, 0.7))

		# 3. Realistic Clubhead at address behind the ball (Shaft on Left for righty, Shaft on Right for lefty; Face Up)
		var is_wood = club_category in ["driver", "wood", "hybrid"]
		var tex = TEX_DRIVER_TOP if is_wood else TEX_IRON_TOP

		var sc = clamp(w / 1150.0, 0.07, 0.12)
		var pivot = Vector2(512.0, 512.0)
		var scale_x = -sc if is_lefty else sc
		draw_set_transform(center + Vector2(0, 10), 0.0, Vector2(scale_x, sc))
		draw_texture(tex, -pivot)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# 4. Ball at impact
		var ball_radius = 7.0
		draw_circle(center + Vector2(1, 1), ball_radius, Color(0, 0, 0, 0.4))
		draw_circle(center, ball_radius, Color(0.92, 0.94, 0.96))
		draw_arc(center, ball_radius, 0, TAU, 24, Color(0.6, 0.65, 0.72), 1.2, true)
		draw_circle(center + Vector2(-2, -2), 1.5, Color(1, 1, 1, 0.8))

		# 5. Dynamic Path Vector Arrow (Flipped for lefty)
		var eff_path = -club_path if is_lefty else club_path
		var path_rad = deg_to_rad(clamp(eff_path, -25.0, 25.0))
		var dir_forward = Vector2(sin(path_rad), -cos(path_rad))

		var abs_path = abs(club_path)
		var path_col = Color(0.35, 0.95, 0.6) if abs_path <= 1.5 else (Color(1.0, 0.75, 0.3) if abs_path <= 4.0 else Color(1.0, 0.35, 0.35))

		var arrow_len = 48.0
		var p_arrow_start = center - dir_forward * (arrow_len * 0.8)
		var p_arrow_end = center + dir_forward * (arrow_len * 0.88)

		# Main path line
		draw_line(p_arrow_start, p_arrow_end, path_col, 3.5, true)

		# Arrowhead at path end
		var normal_path = Vector2(-dir_forward.y, dir_forward.x)
		var head_len = 12.0
		var head_w = 7.0
		var tip = p_arrow_end
		var left_wing = tip - dir_forward * head_len + normal_path * head_w
		var right_wing = tip - dir_forward * head_len - normal_path * head_w
		var arrow_poly = PackedVector2Array([tip, left_wing, right_wing])
		draw_colored_polygon(arrow_poly, path_col)

		# 6. Path deviation angle arc
		if abs_path >= 0.4:
			var arc_r = 34.0
			var base_ang = -PI * 0.5
			var target_ang = base_ang + path_rad
			draw_arc(center, arc_r, min(base_ang, target_ang), max(base_ang, target_ang), 16, path_col, 2.0)

		# 7. Bottom Path Readout Badge (Dedicated pill at bottom)
		if font != null:
			var status_str: String
			if abs_path < 0.2:
				status_str = "STRAIGHT (0.0°)"
			elif club_path > 0.0:
				status_str = "%.1f° IN-TO-OUT" % club_path
			else:
				status_str = "%.1f° OUT-TO-IN" % abs(club_path)

			if is_average:
				status_str = "Avg " + status_str

			var badge_w = min(w - 16.0, 114.0)
			var badge_h = 20.0
			var badge_x = (w - badge_w) * 0.5
			var badge_y = h - 23.0
			var badge_rect = Rect2(Vector2(badge_x, badge_y), Vector2(badge_w, badge_h))
			draw_rect(badge_rect, Color(0.04, 0.07, 0.12, 0.88), true, 4.0)
			draw_rect(badge_rect, Color(path_col.r, path_col.g, path_col.b, 0.45), false, 1.0, 4.0)
			draw_string(font, Vector2(badge_x, badge_y + 14), status_str, HORIZONTAL_ALIGNMENT_CENTER, int(badge_w), 10, path_col)


	func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash_len: float, gap_len: float) -> void:
		var total_len = from.distance_to(to)
		if total_len <= 0.001:
			return
		var dir = (to - from).normalized()
		var curr = 0.0
		while curr < total_len:
			var next_end = min(curr + dash_len, total_len)
			draw_line(from + dir * curr, from + dir * next_end, color, width)
			curr += dash_len + gap_len


# -----------------------------------------------------------------------------
# 4. MAIN PANEL CONTAINER (3 Side-by-Side Cards)
# -----------------------------------------------------------------------------
class ClubDeliveryVisualsPanel extends PanelContainer:
	var face_visual: ClubFaceAngleVisual = null
	var impact_visual: ImpactLocationVisual = null
	var path_visual: ClubPathVisual = null

	var has_face_data: bool = false
	var has_impact_data: bool = false
	var has_path_data: bool = false
	var is_lefty: bool = false

	func _init(shot_data: Dictionary = {}, is_player_profile_mode: bool = false, lefty: Variant = null) -> void:
		setup(shot_data, is_player_profile_mode, lefty)

	func setup(data: Dictionary, is_player_profile_mode: bool = false, lefty: Variant = null) -> void:
		for c in get_children():
			c.queue_free()

		if lefty != null:
			is_lefty = bool(lefty)
		else:
			is_lefty = ClubDeliveryVisuals.is_left_handed(data)

		var panel_style = StyleBoxFlat.new()
		panel_style.bg_color = Color(0.06, 0.09, 0.14, 0.94)
		panel_style.corner_radius_top_left = 10
		panel_style.corner_radius_top_right = 10
		panel_style.corner_radius_bottom_left = 10
		panel_style.corner_radius_bottom_right = 10
		panel_style.border_width_left = 1
		panel_style.border_width_top = 1
		panel_style.border_width_right = 1
		panel_style.border_width_bottom = 1
		panel_style.border_color = Color(0.2, 0.38, 0.55, 0.75)
		panel_style.content_margin_left = 10
		panel_style.content_margin_top = 8
		panel_style.content_margin_right = 10
		panel_style.content_margin_bottom = 8
		add_theme_stylebox_override("panel", panel_style)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var main_vbox = VBoxContainer.new()
		main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main_vbox.add_theme_constant_override("separation", 6)

		# Header Title
		var title_hbox = HBoxContainer.new()
		title_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var title_lbl = Label.new()
		title_lbl.text = "⚡ CLUB DELIVERY & IMPACT ANALYSIS" if not is_player_profile_mode else "🏌 CLUB DELIVERY AVERAGES & STRIKE TENDENCIES"
		title_lbl.add_theme_font_size_override("font_size", 12)
		title_lbl.add_theme_color_override("font_color", Color(0.45, 0.85, 1.0))
		title_hbox.add_child(title_lbl)
		main_vbox.add_child(title_hbox)

		# 3 Cards Side-by-Side in an HBoxContainer
		var cards_hbox = HBoxContainer.new()
		cards_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cards_hbox.add_theme_constant_override("separation", 8)

		var club_name = str(data.get("Club", data.get("club", "Driver")))
		var club_cat = GolfSwingAnalyzer._classify_club(club_name)

		# 1. Face angle parsing
		var face_val: float = 0.0
		has_face_data = false
		if data.has("RawFaceAngle"):
			face_val = float(data["RawFaceAngle"])
			has_face_data = true
		elif data.has("FaceAngle") or data.has("ClubFaceAngle") or data.has("FaceToTarget") or data.has("avg_face_angle"):
			var raw_val = data.get("FaceAngle", data.get("ClubFaceAngle", data.get("FaceToTarget", data.get("avg_face_angle", 0.0))))
			var fa_str = str(raw_val).strip_edges()
			if fa_str == "---" or fa_str.is_empty():
				has_face_data = false
			elif fa_str.ends_with("C") or fa_str.ends_with("Closed"):
				face_val = -absf(float(fa_str))
				has_face_data = true
			elif fa_str.ends_with("O") or fa_str.ends_with("Open"):
				face_val = absf(float(fa_str))
				has_face_data = true
			elif fa_str.ends_with("Sq"):
				face_val = 0.0
				has_face_data = true
			elif fa_str.is_valid_float():
				face_val = float(fa_str)
				has_face_data = true
		elif data.get("has_face_angle", false):
			face_val = float(data.get("avg_face_angle", 0.0))
			has_face_data = true

		# 2. Impact location parsing
		var h_val: float = 0.0
		var v_val: float = 0.0
		var points_arr: Array = data.get("impact_points", [])
		has_impact_data = (not points_arr.is_empty()) or data.get("has_impact_data", false)

		if data.has("HorizontalFaceImpact"):
			h_val = float(data["HorizontalFaceImpact"])
			has_impact_data = true
		elif data.has("impact_offset_horizontal"):
			h_val = float(data["impact_offset_horizontal"])
			has_impact_data = true
		elif data.has("ImpactLocationX"):
			h_val = float(data["ImpactLocationX"])
			has_impact_data = true

		if data.has("VerticalFaceImpact"):
			v_val = float(data["VerticalFaceImpact"])
			has_impact_data = true
		elif data.has("impact_offset_vertical"):
			v_val = float(data["impact_offset_vertical"])
			has_impact_data = true
		elif data.has("ImpactLocationY"):
			v_val = float(data["ImpactLocationY"])
			has_impact_data = true

		# 3. Club path parsing
		var path_val: float = 0.0
		has_path_data = false
		if data.has("RawClubPath"):
			path_val = float(data["RawClubPath"])
			has_path_data = true
		elif data.has("ClubPath") or data.has("Path") or data.has("avg_club_path"):
			var raw_path = data.get("ClubPath", data.get("Path", data.get("avg_club_path", 0.0)))
			var cp_str = str(raw_path).strip_edges()
			if cp_str == "---" or cp_str.is_empty():
				has_path_data = false
			elif cp_str.ends_with("Out-In") or cp_str.ends_with("O-I") or cp_str.to_lower().ends_with("out-in") or cp_str.to_lower().ends_with("o-i"):
				path_val = -absf(float(cp_str))
				has_path_data = true
			elif cp_str.ends_with("In-Out") or cp_str.ends_with("I-O") or cp_str.to_lower().ends_with("in-out") or cp_str.to_lower().ends_with("i-o"):
				path_val = absf(float(cp_str))
				has_path_data = true
			elif cp_str.ends_with("Str"):
				path_val = 0.0
				has_path_data = true
			elif cp_str.is_valid_float():
				path_val = float(cp_str)
				has_path_data = true
		elif data.get("has_club_path", false):
			path_val = float(data.get("avg_club_path", 0.0))
			has_path_data = true


		# Card 1: Face Angle
		var card_1 = _create_card_shell("CLUB FACE ANGLE")
		if has_face_data:
			var sample_cnt = int(data.get("face_angle_count", 0))
			face_visual = ClubFaceAngleVisual.new(face_val, is_player_profile_mode, sample_cnt, club_cat, is_lefty)
			card_1.add_child(face_visual)
		else:
			card_1.add_child(_create_unavailable_placeholder())
		cards_hbox.add_child(card_1)

		# Card 2: Impact Location
		var disp_club = GolfSwingAnalyzer.get_club_display_name(club_name)
		var card_2 = _create_card_shell("IMPACT: %s" % disp_club.to_upper())
		if has_impact_data:
			impact_visual = ImpactLocationVisual.new(club_name, h_val, v_val, points_arr, is_player_profile_mode)
			card_2.add_child(impact_visual)
		else:
			card_2.add_child(_create_unavailable_placeholder())
		cards_hbox.add_child(card_2)

		# Card 3: Club Path
		var card_3 = _create_card_shell("CLUB PATH")
		if has_path_data:
			var sample_cnt = int(data.get("club_path_count", 0))
			path_visual = ClubPathVisual.new(path_val, is_player_profile_mode, sample_cnt, club_cat, is_lefty)
			card_3.add_child(path_visual)
		else:
			card_3.add_child(_create_unavailable_placeholder())
		cards_hbox.add_child(card_3)

		main_vbox.add_child(cards_hbox)
		add_child(main_vbox)

	func _create_card_shell(header_text: String) -> PanelContainer:
		var shell = PanelContainer.new()
		shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		shell.custom_minimum_size = Vector2(110, 155)

		var st = StyleBoxFlat.new()
		st.bg_color = Color(0.04, 0.06, 0.09, 0.9)
		st.corner_radius_top_left = 8
		st.corner_radius_top_right = 8
		st.corner_radius_bottom_left = 8
		st.corner_radius_bottom_right = 8
		st.border_width_left = 1
		st.border_width_top = 1
		st.border_width_right = 1
		st.border_width_bottom = 1
		st.border_color = Color(0.18, 0.28, 0.40, 0.8)
		st.content_margin_left = 8
		st.content_margin_top = 8
		st.content_margin_right = 8
		st.content_margin_bottom = 8
		shell.add_theme_stylebox_override("panel", st)

		var vb = VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vb.add_theme_constant_override("separation", 4)

		var h_lbl = Label.new()
		h_lbl.text = header_text
		h_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h_lbl.add_theme_font_size_override("font_size", 11)
		h_lbl.add_theme_color_override("font_color", Color(0.7, 0.82, 0.92))
		vb.add_child(h_lbl)

		shell.add_child(vb)
		return shell

	func _create_unavailable_placeholder() -> Control:
		var center_box = CenterContainer.new()
		center_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		center_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		center_box.custom_minimum_size = Vector2(110, 120)

		var vb = VBoxContainer.new()
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 6)

		var icon_lbl = Label.new()
		icon_lbl.text = "ℹ️"
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.add_theme_font_size_override("font_size", 20)
		vb.add_child(icon_lbl)

		var msg_lbl = Label.new()
		msg_lbl.text = "Data not available for this launch monitor"
		msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		msg_lbl.custom_minimum_size = Vector2(115, 0)
		msg_lbl.add_theme_font_size_override("font_size", 11)
		msg_lbl.add_theme_color_override("font_color", Color(0.55, 0.65, 0.75))
		vb.add_child(msg_lbl)

		center_box.add_child(vb)
		return center_box
