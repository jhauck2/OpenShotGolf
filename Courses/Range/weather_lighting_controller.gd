extends Node
class_name WeatherLightingController

## WeatherLightingController
## Manages the top HUD Time-of-Day/Lighting Slider (Moon to Sun)
## and the Weather Toggle (Sun / Rain graphical setting).
## Includes Night Golf visuals (glow ball, illuminated cup, blue fairway/green edge lights)
## and soft rain ambient audio.

signal lighting_changed(time_ratio: float)
signal weather_changed(is_rain: bool)

# SVG Icons
const MOON_ICON_PATH := "res://UI/Assets/Icons/weather_moon.svg"
const SUN_ICON_PATH := "res://UI/Assets/Icons/weather_sun.svg"
const RAIN_ICON_PATH := "res://UI/Assets/Icons/weather_rain.svg"

const MOON_SVG_BACKUP := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" width="32" height="32"><path d="M22.5 16c0 6.627-5.373 12-12 12-.76 0-1.503-.07-2.222-.205 5.568-1.517 9.68-6.626 9.68-12.795 0-6.17-4.112-11.278-9.68-12.795.719-.135 1.462-.205 2.222-.205 6.627 0 12 5.373 12 12z" fill="#d8e8f8"/></svg>'
const SUN_SVG_BACKUP := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" width="32" height="32"><circle cx="16" cy="16" r="6.5" fill="#ffcc00"/><g stroke="#ffaa00" stroke-width="2.2" stroke-linecap="round"><line x1="16" y1="3" x2="16" y2="6.5"/><line x1="16" y1="25.5" x2="16" y2="29"/><line x1="3" y1="16" x2="6.5" y2="16"/><line x1="25.5" y1="16" x2="29" y2="16"/><line x1="6.8" y1="6.8" x2="9.3" y2="9.3"/><line x1="22.7" y1="22.7" x2="25.2" y2="25.2"/><line x1="6.8" y1="25.2" x2="9.3" y2="22.7"/><line x1="22.7" y1="9.3" x2="25.2" y2="6.8"/></g></svg>'
const RAIN_SVG_BACKUP := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" width="32" height="32"><path d="M10 19h13a4.5 4.5 0 0 0 .9-8.9A5.8 5.8 0 0 0 12.8 7.5a4.8 4.8 0 0 0-3.3 1.8A4.2 4.2 0 0 0 10 19z" fill="#78909c"/><g stroke="#29b6f6" stroke-width="2.2" stroke-linecap="round"><line x1="10.5" y1="21.5" x2="8.5" y2="27.5"/><line x1="16" y1="21.5" x2="14" y2="27.5"/><line x1="21.5" y1="21.5" x2="19.5" y2="27.5"/></g></svg>'

# Scene References
var _course_root: Node = null
var _canvas_layer: CanvasLayer = null

# UI Nodes
var weather_bar: Control = null
var moon_texture_rect: TextureRect = null
var time_slider: HSlider = null
var sun_texture_rect: TextureRect = null
var weather_toggle_btn: Button = null
var pill_panel: Panel = null
var pill_indicator: Panel = null
var pill_sun_icon: TextureRect = null
var pill_rain_icon: TextureRect = null

# Cached Textures
var _tex_moon: Texture2D = null
var _tex_sun: Texture2D = null
var _tex_rain: Texture2D = null

# Weather State
static var _active_controller: WeatherLightingController = null
var _current_time_ratio: float = 1.0 # 0.0 = Moon/Night, 1.0 = Sun/Day
var _is_rain: bool = false

# Rain 3D Particle Nodes (dense raindrops, zero ground splash-back)
var _rain_particles: CPUParticles3D = null

# Night Golf Visual Elements
var _night_lights_root: Node3D = null
var _night_lights_material: StandardMaterial3D = null
var _ground_glow_material: StandardMaterial3D = null
var _puck_multimesh: MultiMeshInstance3D = null
var _custom_cup_glow: Node3D = null
var _night_elements_built: bool = false
var _cached_hole_id: String = ""
var _cached_hole_pos: Vector3 = Vector3.INF

# Original Scene Environment Settings Cache
var _cached_sky_settings: Dictionary = {}
var _cached_env_settings: Dictionary = {}
var _cached_light_settings: Dictionary = {}


func _enter_tree() -> void:
	_active_controller = self


func _ready() -> void:
	_active_controller = self
	set_process(true)


func _exit_tree() -> void:
	if _active_controller == self:
		_active_controller = null
	if weather_bar != null and is_instance_valid(weather_bar):
		weather_bar.queue_free()
		weather_bar = null
	if _rain_particles != null and is_instance_valid(_rain_particles):
		_rain_particles.queue_free()
		_rain_particles = null
	if _night_lights_root != null and is_instance_valid(_night_lights_root):
		_night_lights_root.queue_free()
		_night_lights_root = null
	if _custom_cup_glow != null and is_instance_valid(_custom_cup_glow):
		_custom_cup_glow.queue_free()
		_custom_cup_glow = null
	_night_elements_built = false


func initialize(course_root: Node, canvas: CanvasLayer) -> void:
	_course_root = course_root
	_canvas_layer = canvas
	_load_textures()
	_cache_original_settings()
	_build_ui()
	_setup_rain_particles()
	# Night golf elements (ribbons, pucks, cup glow) are built lazily when night lighting activates (ratio < 0.28)
	# Apply initial default state (Daytime Sun, Rain Off)
	_apply_lighting_time(_current_time_ratio)
	_apply_weather_state(_is_rain)
	if has_node("/root/GlobalSettings"):
		var gs = get_node("/root/GlobalSettings")
		if gs.has_method("set_rain_mode"):
			gs.call("set_rain_mode", _is_rain)
		elif gs.has_method("set_rain_ambient"):
			gs.call("set_rain_ambient", _is_rain)


func _load_textures() -> void:
	_tex_moon = _load_svg_texture(MOON_ICON_PATH, MOON_SVG_BACKUP)
	_tex_sun = _load_svg_texture(SUN_ICON_PATH, SUN_SVG_BACKUP)
	_tex_rain = _load_svg_texture(RAIN_ICON_PATH, RAIN_SVG_BACKUP)


func _load_svg_texture(file_path: String, backup_svg: String) -> Texture2D:
	if ResourceLoader.exists(file_path):
		var res = ResourceLoader.load(file_path)
		if res is Texture2D:
			return res
	var img = Image.new()
	var err = img.load_svg_from_string(backup_svg, 1.0)
	if err == OK:
		return ImageTexture.create_from_image(img)
	return null


func _cache_original_settings() -> void:
	if _course_root == null:
		return

	# Cache Sky3D / Skydome properties
	var skydome = _course_root.get_node_or_null("Sky3D/Skydome")
	if skydome != null:
		_cached_sky_settings = {
			"clouds_cumulus_coverage": skydome.get("clouds_cumulus_coverage"),
			"clouds_cumulus_day_color": skydome.get("clouds_cumulus_day_color"),
			"clouds_cumulus_thickness": skydome.get("clouds_cumulus_thickness"),
			"clouds_cumulus_visible": skydome.get("clouds_cumulus_visible"),
			"clouds_visible": skydome.get("clouds_visible"),
			"fog_density": skydome.get("fog_density")
		}

	# Cache WorldEnvironment properties
	var sky3d = _course_root.get_node_or_null("Sky3D")
	var env: Environment = null
	if sky3d is WorldEnvironment and sky3d.environment != null:
		env = sky3d.environment
	else:
		for child in _course_root.get_children():
			if child is WorldEnvironment and child.environment != null:
				env = child.environment
				break

	if env != null:
		_cached_env_settings = {
			"fog_enabled": env.fog_enabled,
			"fog_mode": env.fog_mode,
			"fog_light_color": env.fog_light_color,
			"fog_density": env.fog_density,
			"fog_sky_affect": env.fog_sky_affect,
			"ambient_light_color": env.ambient_light_color,
			"ambient_light_energy": env.ambient_light_energy
		}

	# Cache SunLight properties
	var sun = _course_root.get_node_or_null("Sky3D/SunLight")
	if sun is DirectionalLight3D:
		_cached_light_settings = {
			"light_energy": sun.light_energy,
			"light_color": sun.light_color,
			"shadow_enabled": sun.shadow_enabled
		}


func _build_ui() -> void:
	if _canvas_layer == null:
		return

	# Single Unified Section: Controls row embedded directly inside the Aim Distance Badge
	weather_bar = Control.new()
	weather_bar.name = "WeatherLightingBar"

	# Positioned in the lower half of AimDistanceBadge (top 18 to 76, compact height 58px)
	weather_bar.anchor_left = 0.5
	weather_bar.anchor_right = 0.5
	weather_bar.offset_left = -246
	weather_bar.offset_top = 46
	weather_bar.offset_right = 246
	weather_bar.offset_bottom = 72
	weather_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH

	var hbox = HBoxContainer.new()
	hbox.name = "HBox"
	hbox.anchor_right = 1.0
	hbox.anchor_bottom = 1.0
	hbox.offset_left = 6
	hbox.offset_right = -6
	hbox.add_theme_constant_override("separation", 8)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	weather_bar.add_child(hbox)

	# 1. Moon Icon (Left of slider)
	moon_texture_rect = TextureRect.new()
	moon_texture_rect.name = "MoonIcon"
	moon_texture_rect.texture = _tex_moon
	moon_texture_rect.custom_minimum_size = Vector2(16, 16)
	moon_texture_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	moon_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	moon_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	moon_texture_rect.tooltip_text = "Night / Moon"
	hbox.add_child(moon_texture_rect)

	# 2. Time-of-Day / Lighting Slider (Long, expanded slider spanning across the badge)
	time_slider = HSlider.new()
	time_slider.name = "TimeOfDaySlider"
	time_slider.custom_minimum_size = Vector2(240, 16)
	time_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	time_slider.focus_mode = Control.FOCUS_ALL
	time_slider.min_value = 0.0
	time_slider.max_value = 1.0
	time_slider.step = 0.05
	time_slider.value = _current_time_ratio
	time_slider.tooltip_text = "Adjust Time of Day & Lighting (Night to Day)"
	time_slider.value_changed.connect(_on_time_slider_value_changed)
	time_slider.gui_input.connect(_on_time_slider_gui_input)

	# High visibility focus outline for controller navigation
	var slider_focus_sb = StyleBoxFlat.new()
	slider_focus_sb.bg_color = Color(1.0, 1.0, 1.0, 0.04)
	slider_focus_sb.border_width_left = 2
	slider_focus_sb.border_width_top = 2
	slider_focus_sb.border_width_right = 2
	slider_focus_sb.border_width_bottom = 2
	slider_focus_sb.border_color = Color(1.0, 0.84, 0.2, 0.95)
	slider_focus_sb.corner_radius_top_left = 6
	slider_focus_sb.corner_radius_top_right = 6
	slider_focus_sb.corner_radius_bottom_left = 6
	slider_focus_sb.corner_radius_bottom_right = 6
	slider_focus_sb.expand_margin_left = 4
	slider_focus_sb.expand_margin_top = 4
	slider_focus_sb.expand_margin_right = 4
	slider_focus_sb.expand_margin_bottom = 4
	time_slider.add_theme_stylebox_override("focus", slider_focus_sb)
	hbox.add_child(time_slider)

	# 3. Sun Icon (Right of slider)
	sun_texture_rect = TextureRect.new()
	sun_texture_rect.name = "SunIcon"
	sun_texture_rect.texture = _tex_sun
	sun_texture_rect.custom_minimum_size = Vector2(16, 16)
	sun_texture_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sun_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sun_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sun_texture_rect.tooltip_text = "Day / Sun"
	hbox.add_child(sun_texture_rect)

	# 4. Sun / Rain Weather Left/Right Pill Toggle Switch
	# Sleek compact pill switch (48x20px, corner radius 10px)
	# Sun on left, Rain on right. Active side illuminated; inactive side faded.
	weather_toggle_btn = Button.new()
	weather_toggle_btn.name = "WeatherToggleButton"
	weather_toggle_btn.custom_minimum_size = Vector2(48, 20)
	weather_toggle_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	weather_toggle_btn.focus_mode = Control.FOCUS_ALL
	weather_toggle_btn.flat = true
	weather_toggle_btn.clip_contents = true

	# Empty flat styleboxes so button draws no duplicate icon or gray rectangle
	var empty_sb = StyleBoxEmpty.new()
	weather_toggle_btn.add_theme_stylebox_override("normal", empty_sb)
	weather_toggle_btn.add_theme_stylebox_override("hover", empty_sb)
	weather_toggle_btn.add_theme_stylebox_override("pressed", empty_sb)

	# High visibility focus outline for controller navigation
	var toggle_focus_sb = StyleBoxFlat.new()
	toggle_focus_sb.bg_color = Color(0, 0, 0, 0)
	toggle_focus_sb.border_width_left = 2
	toggle_focus_sb.border_width_top = 2
	toggle_focus_sb.border_width_right = 2
	toggle_focus_sb.border_width_bottom = 2
	toggle_focus_sb.border_color = Color(1.0, 0.84, 0.2, 0.95)
	toggle_focus_sb.corner_radius_top_left = 10
	toggle_focus_sb.corner_radius_top_right = 10
	toggle_focus_sb.corner_radius_bottom_left = 10
	toggle_focus_sb.corner_radius_bottom_right = 10
	toggle_focus_sb.expand_margin_left = 2
	toggle_focus_sb.expand_margin_top = 2
	toggle_focus_sb.expand_margin_right = 2
	toggle_focus_sb.expand_margin_bottom = 2
	weather_toggle_btn.add_theme_stylebox_override("focus", toggle_focus_sb)

	# Outer Capsule Pill Panel
	pill_panel = Panel.new()
	pill_panel.name = "PillPanel"
	pill_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pill_bg_style = StyleBoxFlat.new()
	pill_bg_style.bg_color = Color(0.10, 0.11, 0.14, 0.92)
	pill_bg_style.border_width_left = 1
	pill_bg_style.border_width_top = 1
	pill_bg_style.border_width_right = 1
	pill_bg_style.border_width_bottom = 1
	pill_bg_style.border_color = Color(0.85, 0.70, 0.20, 0.55)
	pill_bg_style.corner_radius_top_left = 10
	pill_bg_style.corner_radius_top_right = 10
	pill_bg_style.corner_radius_bottom_left = 10
	pill_bg_style.corner_radius_bottom_right = 10
	pill_panel.add_theme_stylebox_override("panel", pill_bg_style)
	weather_toggle_btn.add_child(pill_panel)

	# Active glowing highlight indicator (slides between left and right)
	pill_indicator = Panel.new()
	pill_indicator.name = "PillIndicator"
	pill_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_indicator.size = Vector2(22, 16)
	pill_indicator.position = Vector2(2, 2)
	var ind_style = StyleBoxFlat.new()
	ind_style.bg_color = Color(0.95, 0.75, 0.15, 0.35)
	ind_style.border_width_left = 1
	ind_style.border_width_top = 1
	ind_style.border_width_right = 1
	ind_style.border_width_bottom = 1
	ind_style.border_color = Color(1.0, 0.85, 0.25, 0.85)
	ind_style.corner_radius_top_left = 8
	ind_style.corner_radius_top_right = 8
	ind_style.corner_radius_bottom_left = 8
	ind_style.corner_radius_bottom_right = 8
	pill_indicator.add_theme_stylebox_override("panel", ind_style)
	weather_toggle_btn.add_child(pill_indicator)

	# Left icon: Sun (☀️) - comfortably scaled inside the pill slot
	pill_sun_icon = TextureRect.new()
	pill_sun_icon.name = "PillSunIcon"
	pill_sun_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_sun_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pill_sun_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pill_sun_icon.texture = _tex_sun
	pill_sun_icon.custom_minimum_size = Vector2(10, 10)
	pill_sun_icon.size = Vector2(10, 10)
	pill_sun_icon.position = Vector2(8, 5)
	weather_toggle_btn.add_child(pill_sun_icon)

	# Right icon: Rain (🌧️) - comfortably scaled inside the pill slot
	pill_rain_icon = TextureRect.new()
	pill_rain_icon.name = "PillRainIcon"
	pill_rain_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_rain_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pill_rain_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pill_rain_icon.texture = _tex_rain
	pill_rain_icon.custom_minimum_size = Vector2(10, 10)
	pill_rain_icon.size = Vector2(10, 10)
	pill_rain_icon.position = Vector2(30, 5)
	weather_toggle_btn.add_child(pill_rain_icon)

	# Clicking anywhere on the button toggles between Sun and Rain
	weather_toggle_btn.pressed.connect(_on_weather_toggle_pressed)
	hbox.add_child(weather_toggle_btn)

	_update_weather_pill_ui()

	_canvas_layer.add_child(weather_bar)


func update_bar_width(half_w: float) -> void:
	if weather_bar != null and is_instance_valid(weather_bar):
		weather_bar.offset_left = -half_w + 14
		weather_bar.offset_right = half_w - 14


func _setup_rain_particles() -> void:
	if _course_root == null:
		return

	# Dense 3D Falling Rain Precipitation System (2400 drops, no ground splash back-up)
	_rain_particles = CPUParticles3D.new()
	_rain_particles.name = "RainParticles3D"
	_rain_particles.emitting = false
	_rain_particles.visible = false
	_rain_particles.amount = 2400
	_rain_particles.lifetime = 0.75
	_rain_particles.speed_scale = 1.0

	_rain_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain_particles.emission_box_extents = Vector3(32.0, 4.0, 32.0)

	_rain_particles.direction = Vector3(-0.12, -1.0, -0.04)
	_rain_particles.spread = 4.0
	_rain_particles.gravity = Vector3(-4.0, -38.0, -1.5)
	_rain_particles.initial_velocity_min = 22.0
	_rain_particles.initial_velocity_max = 28.0

	var streak_mesh = BoxMesh.new()
	streak_mesh.size = Vector3(0.012, 0.45, 0.012)
	var rain_mat = StandardMaterial3D.new()
	rain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rain_mat.albedo_color = Color(0.82, 0.88, 0.96, 0.62)
	streak_mesh.material = rain_mat
	_rain_particles.mesh = streak_mesh

	_course_root.add_child(_rain_particles)


func _ensure_night_golf_elements() -> void:
	if _night_elements_built:
		return
	if _course_root == null or not _course_root.is_inside_tree():
		return
	_night_elements_built = true
	_setup_night_golf_elements()


func _setup_night_golf_elements() -> void:
	if _course_root == null:
		return

	if _night_lights_root == null:
		_night_lights_root = Node3D.new()
		_night_lights_root.name = "NightCourseLights"
		_course_root.add_child(_night_lights_root)

	# Shared vibrant electric blue emissive material for night boundary lights
	_night_lights_material = StandardMaterial3D.new()
	_night_lights_material.albedo_color = Color(0.12, 0.78, 1.0)
	_night_lights_material.emission_enabled = true
	_night_lights_material.emission = Color(0.12, 0.82, 1.0)
	_night_lights_material.emission_energy_multiplier = 4.8
	_night_lights_material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	_night_lights_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_build_fairway_and_green_edge_lights()
	_build_custom_cup_glow()


func _get_terrain_height(x: float, z: float) -> float:
	if _course_root != null and _course_root.has_method("get_height"):
		return _course_root.call("get_height", x, z)
	return 0.0


func _densify_path(points: Array[Vector3], max_step: float = 2.5) -> Array[Vector3]:
	if points.size() < 2:
		return points
	var result: Array[Vector3] = []
	for i in range(points.size() - 1):
		var p0 = points[i]
		var p1 = points[i + 1]
		var seg_len = Vector2(p1.x - p0.x, p1.z - p0.z).length()
		var steps = maxi(1, int(ceil(seg_len / max_step)))
		for s in range(steps):
			var t = float(s) / float(steps)
			var x = lerpf(p0.x, p1.x, t)
			var z = lerpf(p0.z, p1.z, t)
			var y = _get_terrain_height(x, z)
			result.append(Vector3(x, y, z))
	var last = points[points.size() - 1]
	result.append(Vector3(last.x, _get_terrain_height(last.x, last.z), last.z))
	return result


func _dist_to_segment_2d(p: Vector2, s0: Vector2, s1: Vector2) -> float:
	var seg = s1 - s0
	var seg_len_sq = seg.length_squared()
	if seg_len_sq < 0.0001:
		return p.distance_to(s0)
	var t = clampf((p - s0).dot(seg) / seg_len_sq, 0.0, 1.0)
	var proj = s0 + seg * t
	return p.distance_to(proj)


func _dist_to_path_2d(p: Vector2, path_pts: Array[Vector3]) -> float:
	var min_d := 999999.0
	for i in range(path_pts.size() - 1):
		var s0 = Vector2(path_pts[i].x, path_pts[i].z)
		var s1 = Vector2(path_pts[i + 1].x, path_pts[i + 1].z)
		var d = _dist_to_segment_2d(p, s0, s1)
		if d < min_d:
			min_d = d
	return min_d


func _get_body_bounds_2d(body: StaticBody3D) -> Rect2:
	var min_x := 999999.0
	var max_x := -999999.0
	var min_z := 999999.0
	var max_z := -999999.0
	var found := false
	var trans: Transform3D = body.global_transform if body.is_inside_tree() else body.transform
	for child in body.get_children():
		if child is CollisionShape3D:
			var cs = child as CollisionShape3D
			if cs.shape is ConcavePolygonShape3D:
				var faces: PackedVector3Array = (cs.shape as ConcavePolygonShape3D).get_faces()
				var sub_xform = trans * cs.transform
				var step = maxi(1, faces.size() / 16)
				for i in range(0, faces.size(), step):
					var v = sub_xform * faces[i]
					min_x = minf(min_x, v.x)
					max_x = maxf(max_x, v.x)
					min_z = minf(min_z, v.z)
					max_z = maxf(max_z, v.z)
					found = true
			elif cs.shape is CylinderShape3D:
				var c = (trans * cs.transform).origin
				var r = (cs.shape as CylinderShape3D).radius
				min_x = minf(min_x, c.x - r)
				max_x = maxf(max_x, c.x + r)
				min_z = minf(min_z, c.z - r)
				max_z = maxf(max_z, c.z + r)
				found = true
	if not found:
		var wp = trans.origin
		return Rect2(wp.x - 5.0, wp.z - 5.0, 10.0, 10.0)
	return Rect2(min_x, min_z, max_x - min_x, max_z - min_z)


func _extract_fairway_boundary_paths(path_pts: Array[Vector3]) -> Array[Array]:
	var result: Array[Array] = []
	if _course_root == null:
		return result

	var candidate_bodies: Array = []
	var fairway_cached = _course_root.get("_cached_fairway_bodies")
	if fairway_cached is Array and not fairway_cached.is_empty():
		for entry in fairway_cached:
			if entry is Dictionary and entry.has("body"):
				var center = entry.get("center_2d", Vector2.ZERO)
				if _dist_to_path_2d(center, path_pts) < 55.0:
					candidate_bodies.append(entry.get("body"))
	else:
		var stack: Array[Node] = [_course_root]
		while not stack.is_empty():
			var n = stack.pop_back()
			if n is StaticBody3D:
				var nl = n.name.to_lower()
				var is_fw = nl.begins_with("fairway_static") or nl.contains("fairway") or (n.has_meta("surface_type") and int(n.get_meta("surface_type")) == 0)
				if is_fw and not nl.contains("green") and not nl.contains("tee"):
					var b = _get_body_bounds_2d(n)
					if _dist_to_path_2d(b.get_center(), path_pts) < 120.0:
						candidate_bodies.append(n)
			for c in n.get_children():
				stack.append(c)

	if not candidate_bodies.is_empty():
		var loops = _extract_bodies_boundary_loops(candidate_bodies)
		for l in loops:
			if l.size() >= 4:
				result.append(l)

	return result


func _extract_green_boundary_paths(pin_pos: Vector3) -> Array[Array]:
	var result: Array[Array] = []
	if _course_root == null or pin_pos.is_zero_approx():
		return result

	if _course_root.has_method("_init_cached_surface_bodies"):
		_course_root.call("_init_cached_surface_bodies")

	var pin_2d = Vector2(pin_pos.x, pin_pos.z)
	var candidate_bodies: Array = []

	var green_cached = _course_root.get("_cached_green_bodies")
	if green_cached is Array and not green_cached.is_empty():
		for entry in green_cached:
			if entry is Dictionary and entry.has("body"):
				var center = entry.get("center_2d", Vector2.ZERO)
				var radius = entry.get("radius", 25.0)
				var d = pin_2d.distance_to(center)
				if d <= 50.0 or (d - radius) <= 25.0:
					candidate_bodies.append(entry.get("body"))
	else:
		var stack: Array[Node] = [_course_root]
		while not stack.is_empty():
			var n = stack.pop_back()
			if n is StaticBody3D:
				var nl = n.name.to_lower()
				var is_grn = nl.begins_with("green_static") or nl.contains("green") or (n.has_meta("surface_type") and int(n.get_meta("surface_type")) == 4)
				if is_grn and not nl.contains("fairway") and not nl.contains("tee"):
					var b = _get_body_bounds_2d(n)
					var center = b.get_center()
					var radius = maxf(b.size.x, b.size.y) * 0.5
					var d = pin_2d.distance_to(center)
					if d <= 50.0 or (d - radius) <= 25.0:
						candidate_bodies.append(n)
			for c in n.get_children():
				stack.append(c)

	if not candidate_bodies.is_empty():
		var loops = _extract_bodies_boundary_loops(candidate_bodies)
		for l in loops:
			if l.size() >= 4:
				result.append(l)

	return result


func _extract_body_boundary_loops(body: StaticBody3D) -> Array[Array]:
	return _extract_bodies_boundary_loops([body])


func _extract_bodies_boundary_loops(bodies: Array) -> Array[Array]:
	var loops: Array[Array] = []
	if bodies.is_empty():
		return loops

	var edge_count := {}
	var edge_pts := {}

	for body in bodies:
		if not (body is StaticBody3D):
			continue
		var trans: Transform3D = body.global_transform if body.is_inside_tree() else body.transform

		for child in body.get_children():
			if not (child is CollisionShape3D):
				continue
			var cs = child as CollisionShape3D
			if cs.shape is ConcavePolygonShape3D:
				var faces: PackedVector3Array = (cs.shape as ConcavePolygonShape3D).get_faces()
				var sub_xform = trans * cs.transform
				var num_faces = faces.size()
				for i in range(0, num_faces - 2, 3):
					var v0 = sub_xform * faces[i]
					var v1 = sub_xform * faces[i + 1]
					var v2 = sub_xform * faces[i + 2]

					var pts = [v0, v1, v2]
					for e in range(3):
						var p_a = pts[e]
						var p_b = pts[(e + 1) % 3]

						var k_a = Vector2i(roundi(p_a.x * 20.0), roundi(p_a.z * 20.0))
						var k_b = Vector2i(roundi(p_b.x * 20.0), roundi(p_b.z * 20.0))
						if k_a == k_b:
							continue

						var u_key = Vector4i(mini(k_a.x, k_b.x), mini(k_a.y, k_b.y), maxi(k_a.x, k_b.x), maxi(k_a.y, k_b.y))
						edge_count[u_key] = edge_count.get(u_key, 0) + 1
						edge_pts[u_key] = [p_a, p_b, k_a, k_b]
			elif cs.shape is CylinderShape3D:
				var cyl_rad: float = (cs.shape as CylinderShape3D).radius
				var center_3d: Vector3 = (trans * cs.transform).origin
				var ring: Array[Vector3] = []
				var steps := 32
				for s in range(steps):
					var ang = float(s) * TAU / float(steps)
					ring.append(center_3d + Vector3(cos(ang) * cyl_rad, 0.0, sin(ang) * cyl_rad))
				ring.append(ring[0])
				loops.append(ring)

	var graph := {}
	var v_map := {}
	for u_key in edge_count:
		if edge_count[u_key] == 1:
			var info = edge_pts[u_key]
			var k_a: Vector2i = info[2]
			var k_b: Vector2i = info[3]
			v_map[k_a] = info[0]
			v_map[k_b] = info[1]
			if not graph.has(k_a):
				graph[k_a] = []
			if not graph.has(k_b):
				graph[k_b] = []
			graph[k_a].append(k_b)
			graph[k_b].append(k_a)

	var visited_edges := {}
	for start_k in graph:
		for next_k in graph[start_k]:
			var e_key = Vector4i(mini(start_k.x, next_k.x), mini(start_k.y, next_k.y), maxi(start_k.x, next_k.x), maxi(start_k.y, next_k.y))
			if visited_edges.has(e_key):
				continue

			var loop: Array[Vector3] = [v_map[start_k]]
			var prev = start_k
			var curr = next_k
			visited_edges[e_key] = true
			var max_steps = graph.size() + 2
			var step_count = 0

			while curr != start_k and step_count < max_steps:
				loop.append(v_map[curr])
				var found_next = false
				for nbr in graph[curr]:
					var n_ekey = Vector4i(mini(curr.x, nbr.x), mini(curr.y, nbr.y), maxi(curr.x, nbr.x), maxi(curr.y, nbr.y))
					if nbr != prev and not visited_edges.has(n_ekey):
						visited_edges[n_ekey] = true
						prev = curr
						curr = nbr
						found_next = true
						break
				if not found_next:
					break
				step_count += 1

			if curr == start_k:
				loop.append(v_map[start_k])

			if loop.size() >= 4:
				loops.append(loop)

	return loops


func _add_quad_to_st(st: SurfaceTool, v0: Vector3, c0: Color, v1: Vector3, c1: Color, v2: Vector3, c2: Color, v3: Vector3, c3: Color) -> void:
	st.set_normal(Vector3.UP)
	st.set_color(c0)
	st.add_vertex(v0)
	st.set_color(c1)
	st.add_vertex(v1)
	st.set_color(c2)
	st.add_vertex(v2)

	st.set_color(c0)
	st.add_vertex(v0)
	st.set_color(c2)
	st.add_vertex(v2)
	st.set_color(c3)
	st.add_vertex(v3)


func _build_fairway_and_green_edge_lights() -> void:
	if _night_lights_root == null or _course_root == null:
		return

	# Clear previous instances if rebuilding
	for child in _night_lights_root.get_children():
		child.queue_free()

	if _night_lights_material == null:
		_night_lights_material = StandardMaterial3D.new()
		_night_lights_material.albedo_color = Color(0.35, 0.90, 1.0)
		_night_lights_material.emission_enabled = true
		_night_lights_material.emission = Color(0.18, 0.85, 1.0)
		_night_lights_material.emission_energy_multiplier = 4.8
		_night_lights_material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		_night_lights_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	if _ground_glow_material == null:
		_ground_glow_material = StandardMaterial3D.new()
		_ground_glow_material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		_ground_glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ground_glow_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_ground_glow_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_ground_glow_material.vertex_color_use_as_albedo = true
		_ground_glow_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var is_dr = false
	if "is_driving_range" in _course_root:
		is_dr = _course_root.is_driving_range

	var boundary_paths: Array[Array] = []

	if is_dr:
		# Driving Range: Boundary neon ribbons along left & right outfield borders
		var left_side: Array[Vector3] = []
		var right_side: Array[Vector3] = []
		var x_step := 5.0
		var cur_x := 10.0
		while cur_x <= 360.0:
			var z_w = lerpf(26.0, 36.0, (cur_x + 10.0) / 370.0)
			left_side.append(Vector3(cur_x, 0.0, -z_w))
			right_side.append(Vector3(cur_x, 0.0, z_w))
			cur_x += x_step
		boundary_paths.append(_densify_path(left_side, 2.5))
		boundary_paths.append(_densify_path(right_side, 2.5))

		# Target flags on driving range
		var target_dists = [50.0, 100.0, 150.0, 200.0, 250.0]
		for td in target_dists:
			var target_x = td * 0.9144
			var ring_pts: Array[Vector3] = []
			var r_rad = 5.5
			for a in range(25):
				var ang = deg_to_rad(float(a) * 15.0)
				ring_pts.append(Vector3(target_x + r_rad * cos(ang), 0.0, r_rad * sin(ang)))
			boundary_paths.append(_densify_path(ring_pts, 2.0))
	else:
		# Course Play: Determine active hole path
		var path_pts: Array[Vector3] = []
		if _course_root.has_method("get_active_hole_config"):
			var active_hole = _course_root.call("get_active_hole_config")
			if active_hole != null and not active_hole.is_empty():
				var path_arr = active_hole.get("Hole Path")
				if path_arr != null and path_arr.size() > 0:
					for pt in path_arr:
						var y_val = _get_terrain_height(pt[0], pt[1])
						path_pts.append(Vector3(pt[0], y_val, pt[1]))

		var spawn_pos = Vector3.ZERO
		if _course_root.has_node("Player/Ball"):
			spawn_pos = _course_root.get_node("Player/Ball").spawn_position
		var hole_pos = Vector3(300.0, 0.0, 0.0)
		if "current_hole_location" in _course_root and not _course_root.current_hole_location.is_zero_approx():
			hole_pos = _course_root.current_hole_location
		elif "aim_target_pos" in _course_root and not _course_root.aim_target_pos.is_zero_approx():
			hole_pos = _course_root.aim_target_pos

		if path_pts.size() < 2:
			path_pts = [spawn_pos, hole_pos]

		# 1. Extract actual Fairway boundaries from course fairway StaticBody3D objects
		var fairway_loops = _extract_fairway_boundary_paths(path_pts)
		for f_loop in fairway_loops:
			boundary_paths.append(_densify_path(f_loop, 2.5))

		# 2. Fallback if no fairway bodies found (synthesize fairway starting 60m ahead of tee)
		if fairway_loops.is_empty():
			var hole_dir = (hole_pos - spawn_pos).normalized()
			var total_dist = spawn_pos.distance_to(hole_pos)
			var fw_start_dist = minf(60.0, total_dist * 0.35)
			var fw_end_dist = maxf(fw_start_dist + 20.0, total_dist - 18.0)
			var fw_half_w = 15.0

			var p_start = spawn_pos + hole_dir * fw_start_dist
			var p_end = spawn_pos + hole_dir * fw_end_dist
			var perp = Vector3(-hole_dir.z, 0.0, hole_dir.x)

			var synth_loop: Array[Vector3] = [
				p_start - perp * fw_half_w,
				p_end - perp * fw_half_w,
				p_end + perp * fw_half_w,
				p_start + perp * fw_half_w,
				p_start - perp * fw_half_w
			]
			boundary_paths.append(_densify_path(synth_loop, 2.5))

		# 3. Putting Green perimeter loop (extracted from green_Static bodies, tracing actual green boundary)
		var pin_pos = hole_pos
		if not pin_pos.is_zero_approx():
			var green_loops = _extract_green_boundary_paths(pin_pos)
			for g_loop in green_loops:
				boundary_paths.append(_densify_path(g_loop, 2.0))

			# Fallback if no green bodies were detected in scene
			if green_loops.is_empty():
				var green_ring: Array[Vector3] = []
				var g_rad = 14.0
				for a in range(25):
					var ang = deg_to_rad(float(a) * 15.0)
					var gx = pin_pos.x + g_rad * cos(ang)
					var gz = pin_pos.z + g_rad * sin(ang)
					green_ring.append(Vector3(gx, 0.0, gz))
				boundary_paths.append(_densify_path(green_ring, 2.0))

	# Build continuous glowing neon core ribbon + wide additive radiant ground glow skirt
	var st_core = SurfaceTool.new()
	st_core.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_core.set_material(_night_lights_material)

	var st_glow = SurfaceTool.new()
	st_glow.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_glow.set_material(_ground_glow_material)

	var core_half_w := 0.07 # 14cm wide core neon ribbon
	var glow_half_w := 0.42 # 84cm wide additive radiant light skirt
	var core_vert_count := 0
	var glow_vert_count := 0

	for b_path in boundary_paths:
		if b_path.size() < 2:
			continue

		for i in range(b_path.size() - 1):
			var p0: Vector3 = b_path[i]
			var p1: Vector3 = b_path[i + 1]

			var seg_len = p0.distance_to(p1)
			if seg_len < 0.05:
				continue

			var seg_dir_2d = Vector2(p1.x - p0.x, p1.z - p0.z).normalized()
			if seg_dir_2d.is_zero_approx():
				continue
			var norm = Vector2(-seg_dir_2d.y, seg_dir_2d.x)

			# Core vertices (height: ground + 0.016m)
			var c_v0_l = Vector3(p0.x - norm.x * core_half_w, p0.y + 0.016, p0.z - norm.y * core_half_w)
			var c_v0_r = Vector3(p0.x + norm.x * core_half_w, p0.y + 0.016, p0.z + norm.y * core_half_w)
			var c_v1_l = Vector3(p1.x - norm.x * core_half_w, p1.y + 0.016, p1.z - norm.y * core_half_w)
			var c_v1_r = Vector3(p1.x + norm.x * core_half_w, p1.y + 0.016, p1.z + norm.y * core_half_w)

			st_core.set_normal(Vector3.UP)
			st_core.set_uv(Vector2(0.0, 0.0))
			st_core.add_vertex(c_v0_l)
			st_core.set_normal(Vector3.UP)
			st_core.set_uv(Vector2(1.0, 0.0))
			st_core.add_vertex(c_v0_r)
			st_core.set_normal(Vector3.UP)
			st_core.set_uv(Vector2(1.0, 1.0))
			st_core.add_vertex(c_v1_r)

			st_core.set_normal(Vector3.UP)
			st_core.set_uv(Vector2(0.0, 0.0))
			st_core.add_vertex(c_v0_l)
			st_core.set_normal(Vector3.UP)
			st_core.set_uv(Vector2(1.0, 1.0))
			st_core.add_vertex(c_v1_r)
			st_core.set_normal(Vector3.UP)
			st_core.set_uv(Vector2(0.0, 1.0))
			st_core.add_vertex(c_v1_l)

			core_vert_count += 6

			# Radiant ground-glow skirt vertices (height: ground + 0.012m)
			var g_v0_ol = Vector3(p0.x - norm.x * glow_half_w, p0.y + 0.012, p0.z - norm.y * glow_half_w)
			var g_v0_ml = Vector3(p0.x - norm.x * core_half_w, p0.y + 0.012, p0.z - norm.y * core_half_w)
			var g_v0_mr = Vector3(p0.x + norm.x * core_half_w, p0.y + 0.012, p0.z + norm.y * core_half_w)
			var g_v0_or = Vector3(p0.x + norm.x * glow_half_w, p0.y + 0.012, p0.z + norm.y * glow_half_w)

			var g_v1_ol = Vector3(p1.x - norm.x * glow_half_w, p1.y + 0.012, p1.z - norm.y * glow_half_w)
			var g_v1_ml = Vector3(p1.x - norm.x * core_half_w, p1.y + 0.012, p1.z - norm.y * core_half_w)
			var g_v1_mr = Vector3(p1.x + norm.x * core_half_w, p1.y + 0.012, p1.z + norm.y * core_half_w)
			var g_v1_or = Vector3(p1.x + norm.x * glow_half_w, p1.y + 0.012, p1.z + norm.y * glow_half_w)

			var c_edge = Color(0.06, 0.45, 1.0, 0.0)
			var c_mid = Color(0.12, 0.75, 1.0, 0.60)

			# Left glow quad: outer-left to mid-left
			_add_quad_to_st(st_glow, g_v0_ol, c_edge, g_v0_ml, c_mid, g_v1_ml, c_mid, g_v1_ol, c_edge)
			# Center glow quad: mid-left to mid-right
			_add_quad_to_st(st_glow, g_v0_ml, c_mid, g_v0_mr, c_mid, g_v1_mr, c_mid, g_v1_ml, c_mid)
			# Right glow quad: mid-right to outer-right
			_add_quad_to_st(st_glow, g_v0_mr, c_mid, g_v0_or, c_edge, g_v1_or, c_edge, g_v1_mr, c_mid)

			glow_vert_count += 18

	if core_vert_count >= 3:
		st_core.generate_tangents()
		var ribbon_mesh = st_core.commit()
		if ribbon_mesh != null:
			var ribbon_inst = MeshInstance3D.new()
			ribbon_inst.name = "FairwayEdgeRibbon"
			ribbon_inst.mesh = ribbon_mesh
			ribbon_inst.material_override = _night_lights_material
			ribbon_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_night_lights_root.add_child(ribbon_inst)

	if glow_vert_count >= 3:
		var glow_mesh = st_glow.commit()
		if glow_mesh != null:
			var glow_inst = MeshInstance3D.new()
			glow_inst.name = "FairwayGroundGlow"
			glow_inst.mesh = glow_mesh
			glow_inst.material_override = _ground_glow_material
			glow_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_night_lights_root.add_child(glow_inst)

	_night_lights_root.visible = (_current_time_ratio < 0.28)


func _build_custom_cup_glow() -> void:
	if _course_root == null:
		return

	# If FlagPin already has a NightCupGlow child, avoid creating duplicate glow nodes
	var flag_pin = _course_root.get_node_or_null("FlagPin")
	if flag_pin != null and flag_pin.has_node("NightCupGlow"):
		return

	if _custom_cup_glow == null:
		_custom_cup_glow = Node3D.new()
		_custom_cup_glow.name = "GlobalNightCupGlow"
		_course_root.add_child(_custom_cup_glow)

		var ring_inst = MeshInstance3D.new()
		ring_inst.name = "CupRing"
		var torus = TorusMesh.new()
		torus.inner_radius = 0.050
		torus.outer_radius = 0.064
		ring_inst.mesh = torus
		ring_inst.material_override = _night_lights_material
		ring_inst.position = Vector3(0.0, 0.004, 0.0)
		_custom_cup_glow.add_child(ring_inst)

		var omni = OmniLight3D.new()
		omni.name = "CupLight"
		omni.light_color = Color(0.15, 0.82, 1.0)
		omni.light_energy = 2.4
		omni.omni_range = 3.5
		omni.omni_attenuation = 1.3
		omni.shadow_enabled = false
		omni.position = Vector3(0.0, 0.16, 0.0)
		_custom_cup_glow.add_child(omni)

	_update_cup_glow_position()
	_custom_cup_glow.visible = (_current_time_ratio < 0.25)


func _update_cup_glow_position() -> void:
	if _custom_cup_glow == null or _course_root == null:
		return
	var hole_pos = Vector3.ZERO
	if "current_hole_location" in _course_root:
		hole_pos = _course_root.current_hole_location
	if hole_pos.is_zero_approx() and "aim_target_pos" in _course_root:
		hole_pos = _course_root.aim_target_pos
	_custom_cup_glow.global_position = hole_pos


func _process(_delta: float) -> void:
	if _course_root == null:
		return

	# Rain particles track camera
	if _is_rain:
		var cam = _get_active_camera()
		if cam != null and is_instance_valid(cam):
			var cam_pos = cam.global_position
			if _rain_particles != null and is_instance_valid(_rain_particles):
				_rain_particles.global_position = cam_pos + Vector3(0.0, 8.5, 0.0)

	# Dynamic cup position sync
	if _custom_cup_glow != null and _custom_cup_glow.visible:
		_update_cup_glow_position()

	# Dynamic hole transition check: rebuild fairway boundary lines & cup glow when hole changes
	if _night_lights_root != null and _current_time_ratio < 0.28:
		_check_hole_transition()


func _check_hole_transition() -> void:
	if _course_root == null:
		return
	var cur_hole_id := ""
	if "current_hole_id" in _course_root:
		cur_hole_id = str(_course_root.current_hole_id)
	var cur_hole_pos := Vector3.ZERO
	if "current_hole_location" in _course_root:
		cur_hole_pos = _course_root.current_hole_location
	elif "aim_target_pos" in _course_root:
		cur_hole_pos = _course_root.aim_target_pos

	if _cached_hole_pos == Vector3.INF:
		_cached_hole_id = cur_hole_id
		_cached_hole_pos = cur_hole_pos
		return

	if cur_hole_id != _cached_hole_id or cur_hole_pos.distance_to(_cached_hole_pos) > 1.0:
		_cached_hole_id = cur_hole_id
		_cached_hole_pos = cur_hole_pos
		_build_fairway_and_green_edge_lights()
		_update_cup_glow_position()


func _get_active_camera() -> Camera3D:
	if _course_root == null or not _course_root.is_inside_tree():
		return null
	var viewport = _course_root.get_viewport()
	if viewport != null:
		var cam = viewport.get_camera_3d()
		if cam != null:
			return cam
	var direct_cam = _course_root.get_node_or_null("Camera3D")
	if direct_cam is Camera3D:
		return direct_cam
	return null


func _on_time_slider_value_changed(val: float) -> void:
	_current_time_ratio = clampf(val, 0.0, 1.0)
	_apply_lighting_time(_current_time_ratio)
	emit_signal("lighting_changed", _current_time_ratio)


func _on_time_slider_gui_input(event: InputEvent) -> void:
	if time_slider == null:
		return
	if event.is_action_pressed("ui_accept"):
		# Pressing controller 'A' / accept on slider shifts focus to weather toggle button
		if weather_toggle_btn != null and is_instance_valid(weather_toggle_btn) and weather_toggle_btn.is_visible_in_tree():
			weather_toggle_btn.grab_focus()
			time_slider.accept_event()
	elif event.is_action_pressed("ui_right") and time_slider.value >= time_slider.max_value - 0.001:
		# Pushing right at the max daylight end advances focus to weather toggle button
		if weather_toggle_btn != null and is_instance_valid(weather_toggle_btn) and weather_toggle_btn.is_visible_in_tree():
			weather_toggle_btn.grab_focus()
			time_slider.accept_event()
	elif event.is_action_pressed("ui_left") and time_slider.value <= time_slider.min_value + 0.001:
		# Pushing left at the min night end moves focus to the left neighbor (e.g. profile option)
		if not time_slider.focus_neighbor_left.is_empty():
			var left_node = time_slider.get_node_or_null(time_slider.focus_neighbor_left)
			if left_node != null and is_instance_valid(left_node) and left_node.is_visible_in_tree():
				left_node.grab_focus()
				time_slider.accept_event()


func _on_weather_toggle_pressed() -> void:
	set_rain_mode(!_is_rain)


func _update_weather_pill_ui() -> void:
	if weather_toggle_btn == null:
		return

	# Explicitly clear icon so Godot never stamps a duplicate large icon over the button
	weather_toggle_btn.icon = null

	if pill_panel == null or pill_indicator == null or pill_sun_icon == null or pill_rain_icon == null:
		return

	var bg_style = pill_panel.get_theme_stylebox("panel") as StyleBoxFlat
	var ind_style = pill_indicator.get_theme_stylebox("panel") as StyleBoxFlat

	if _is_rain:
		# Rain mode active: Highlight Rain on right, Sun on left is faded
		pill_indicator.position = Vector2(24, 2)
		if ind_style != null:
			ind_style.bg_color = Color(0.18, 0.48, 0.85, 0.38)
			ind_style.border_color = Color(0.35, 0.75, 1.0, 0.85)
		if bg_style != null:
			bg_style.border_color = Color(0.25, 0.65, 0.95, 0.6)

		pill_sun_icon.modulate = Color(1.0, 1.0, 1.0, 0.25) # Faded
		pill_rain_icon.modulate = Color(1.0, 1.0, 1.0, 1.0) # Full brightness
		weather_toggle_btn.tooltip_text = "Weather: Rain (Click to toggle)"
	else:
		# Sun mode active: Highlight Sun on left, Rain on right is faded
		pill_indicator.position = Vector2(2, 2)
		if ind_style != null:
			ind_style.bg_color = Color(0.95, 0.75, 0.15, 0.35)
			ind_style.border_color = Color(1.0, 0.85, 0.25, 0.85)
		if bg_style != null:
			bg_style.border_color = Color(0.85, 0.70, 0.20, 0.55)

		pill_sun_icon.modulate = Color(1.0, 1.0, 1.0, 1.0) # Full brightness
		pill_rain_icon.modulate = Color(1.0, 1.0, 1.0, 0.25) # Faded
		weather_toggle_btn.tooltip_text = "Weather: Sun (Click to toggle)"


func set_lighting_time(ratio: float) -> void:
	_current_time_ratio = clampf(ratio, 0.0, 1.0)
	if time_slider != null and not is_equal_approx(time_slider.value, _current_time_ratio):
		time_slider.value = _current_time_ratio
	_apply_lighting_time(_current_time_ratio)
	emit_signal("lighting_changed", _current_time_ratio)


func get_lighting_time() -> float:
	return _current_time_ratio


func update_backdrop_lighting() -> void:
	_apply_backdrop_lighting(_current_time_ratio)


func set_rain_mode(enabled: bool) -> void:
	_is_rain = enabled
	_update_weather_pill_ui()

	# Sync rain state to GlobalSettings and switch ambient sound
	if has_node("/root/GlobalSettings"):
		var gs = get_node("/root/GlobalSettings")
		if gs.has_method("set_rain_mode"):
			gs.call("set_rain_mode", _is_rain)
		elif gs.has_method("set_rain_ambient"):
			gs.call("set_rain_ambient", _is_rain)

	# If course has active ball, immediately update its surface parameters
	if _course_root != null:
		var ball = _course_root.find_child("Ball", true, false)
		if ball != null and is_instance_valid(ball) and ball.has_method("_apply_surface_params"):
			ball.call("_apply_surface_params")

	_apply_weather_state(_is_rain)
	_apply_lighting_time(_current_time_ratio)
	emit_signal("weather_changed", _is_rain)


func is_rain_mode() -> bool:
	return _is_rain


static func is_rain_active() -> bool:
	if _active_controller != null and is_instance_valid(_active_controller):
		return _active_controller._is_rain
	if Engine.has_singleton("GlobalSettings"):
		var gs = Engine.get_singleton("GlobalSettings")
		if gs.has_method("is_rain_mode"):
			return gs.is_rain_mode()
	elif Engine.get_main_loop() is SceneTree:
		var root = (Engine.get_main_loop() as SceneTree).root
		if root != null and root.has_node("GlobalSettings"):
			var gs = root.get_node("GlobalSettings")
			if gs.has_method("is_rain_mode"):
				return gs.call("is_rain_mode")
	return false


func _apply_lighting_time(ratio: float) -> void:
	if _course_root == null:
		return

	# Map ratio (0.0 = Night / Moon, 1.0 = Afternoon Sun)
	var target_hours = lerpf(0.0, 13.25, ratio)

	# 1. Update Sky3D TimeOfDay if present
	var tod = _course_root.get_node_or_null("Sky3D/TimeOfDay")
	if tod != null:
		if tod.has_method("set_total_hours"):
			tod.call("set_total_hours", target_hours)
		elif tod.has_meta("total_hours"):
			tod.set_meta("total_hours", target_hours)
		elif "total_hours" in tod:
			tod.set("total_hours", target_hours)

	# 2. Update Direct Sun & Moon Lights
	var sun = _course_root.get_node_or_null("Sky3D/SunLight") as DirectionalLight3D
	var moon = _course_root.get_node_or_null("Sky3D/MoonLight") as DirectionalLight3D

	var base_sun_energy: float = _cached_light_settings.get("light_energy", 1.1)

	if sun != null:
		if _is_rain:
			sun.light_energy = lerpf(0.0, 0.35, ratio)
			sun.light_color = Color(0.85, 0.88, 0.95)
		else:
			sun.light_energy = lerpf(0.0, base_sun_energy, ratio)
			sun.light_color = _cached_light_settings.get("light_color", Color.WHITE)

		sun.shadow_enabled = (sun.light_energy > 0.05)

	if moon != null:
		var moon_target_energy = 0.40 if not _is_rain else 0.20
		moon.light_energy = lerpf(moon_target_energy, 0.0, ratio)
		moon.light_color = Color(0.65, 0.78, 0.98)
		moon.shadow_enabled = (moon.light_energy > 0.08)

	# 3. Update Environment Ambient Light
	var sky3d = _course_root.get_node_or_null("Sky3D")
	var env: Environment = null
	if sky3d is WorldEnvironment and sky3d.environment != null:
		env = sky3d.environment

	if env != null:
		if _is_rain:
			env.ambient_light_color = Color(0.55, 0.60, 0.68)
			env.ambient_light_energy = lerpf(0.20, 0.42, ratio)
		else:
			var day_amb: Color = _cached_env_settings.get("ambient_light_color", Color(0.5, 0.55, 0.65))
			var night_amb = Color(0.18, 0.22, 0.34)
			env.ambient_light_color = night_amb.lerp(day_amb, ratio)
			env.ambient_light_energy = lerpf(0.25, _cached_env_settings.get("ambient_light_energy", 0.5), ratio)

	# 4. Fallback for standalone DirectionalLight3D without Sky3D
	if sun == null and tod == null:
		var standalone_light = _find_first_directional_light(_course_root)
		if standalone_light != null:
			var pitch = deg_to_rad(lerpf(-15.0, -62.0, ratio))
			var yaw = deg_to_rad(lerpf(-120.0, -35.0, ratio))
			standalone_light.rotation = Vector3(pitch, yaw, 0.0)
			if _is_rain:
				standalone_light.light_energy = lerpf(0.05, 0.35, ratio)
				standalone_light.light_color = Color(0.75, 0.82, 0.92)
			else:
				standalone_light.light_energy = lerpf(0.25, 1.15, ratio)
				standalone_light.light_color = Color(0.60, 0.72, 0.95).lerp(Color.WHITE, ratio)

	# 5. Fix Deep Background / Mountain Backdrop Lighting at Night
	_apply_backdrop_lighting(ratio)

	# 6. Night Golf Visual Features: Glow Ball, Glowing Cup, Blue Fairway/Green Edge Lights
	_apply_night_golf_visuals(ratio)


func _apply_backdrop_lighting(ratio: float) -> void:
	if _course_root == null:
		return

	# Dim the Mountain Backdrop cylinder mesh at night into a natural dark silhouette
	var mountain = _course_root.get_node_or_null("MountainBackdrop/MountainMesh") as MeshInstance3D
	if mountain != null and mountain.material_override is StandardMaterial3D:
		var day_color = Color(1.0, 1.0, 1.0)
		var night_color = Color(0.06, 0.08, 0.14) # Deep moonlit silhouette
		if _is_rain:
			day_color = Color(0.42, 0.45, 0.50)
			night_color = Color(0.04, 0.05, 0.08)
		mountain.material_override.albedo_color = night_color.lerp(day_color, ratio)

	# Check any other unshaded background horizon elements
	var horizon = _course_root.get_node_or_null("HorizonSkirt") as MeshInstance3D
	if horizon != null and horizon.material_override is StandardMaterial3D:
		var day_c = Color.WHITE
		var night_c = Color(0.12, 0.14, 0.20)
		horizon.material_override.albedo_color = night_c.lerp(day_c, ratio)


func _apply_night_golf_visuals(ratio: float) -> void:
	# A. Glow in the dark ball (active when night: ratio < 0.22)
	var is_night_dark = (ratio < 0.22)
	var ball = _find_player_ball()
	if ball != null and ball.has_method("set_glow_mode"):
		ball.call("set_glow_mode", is_night_dark)

	# B. Glowing Cup / Hole (active when dusk/night: ratio < 0.25)
	var is_cup_lit = (ratio < 0.25)
	var flag_pin = _course_root.get_node_or_null("FlagPin") if _course_root != null else null
	if flag_pin != null and flag_pin.has_node("NightCupGlow"):
		flag_pin.get_node("NightCupGlow").visible = is_cup_lit

	if _custom_cup_glow != null:
		_custom_cup_glow.visible = is_cup_lit

	# C. Blue Fairway & Green Edge Lights & Ground Lights (active when night: ratio < 0.28)
	var lights_active = (ratio < 0.28)
	if lights_active:
		_ensure_night_golf_elements()

	if _night_lights_root != null:
		_night_lights_root.visible = lights_active
		if lights_active:
			if _night_lights_material != null:
				var emission_mult = lerpf(4.8, 1.2, ratio / 0.28)
				_night_lights_material.emission_energy_multiplier = emission_mult
			var omni_energy = lerpf(1.6, 0.4, ratio / 0.28)
			for child in _night_lights_root.get_children():
				if child is OmniLight3D and child.name == "EdgeGroundOmniLight":
					child.light_energy = omni_energy


func _find_player_ball() -> Node:
	if _course_root == null:
		return null
	var ball = _course_root.get_node_or_null("Player/Ball")
	if ball == null and _course_root.has_node("Player"):
		var p = _course_root.get_node("Player")
		if "ball" in p and p.ball != null:
			ball = p.ball
	if ball == null:
		ball = _course_root.get_node_or_null("Ball")
	return ball


func _apply_weather_state(rain_active: bool) -> void:
	if _course_root == null:
		return

	# Toggle 3D Particle Precipitation
	if _rain_particles != null:
		_rain_particles.emitting = rain_active
		_rain_particles.visible = rain_active

	# Atmosphere & Clouds in Skydome
	var skydome = _course_root.get_node_or_null("Sky3D/Skydome")
	if skydome != null:
		if rain_active:
			skydome.set("clouds_cumulus_visible", true)
			skydome.set("clouds_cumulus_coverage", 0.94)
			skydome.set("clouds_cumulus_day_color", Color(0.38, 0.40, 0.45, 1.0))
			skydome.set("clouds_cumulus_thickness", 0.045)
		else:
			if _cached_sky_settings.has("clouds_cumulus_coverage"):
				skydome.set("clouds_cumulus_coverage", _cached_sky_settings["clouds_cumulus_coverage"])
			if _cached_sky_settings.has("clouds_cumulus_day_color"):
				skydome.set("clouds_cumulus_day_color", _cached_sky_settings["clouds_cumulus_day_color"])
			if _cached_sky_settings.has("clouds_cumulus_thickness"):
				skydome.set("clouds_cumulus_thickness", _cached_sky_settings["clouds_cumulus_thickness"])
			if _cached_sky_settings.has("clouds_cumulus_visible"):
				skydome.set("clouds_cumulus_visible", _cached_sky_settings["clouds_cumulus_visible"])

	# Fog in WorldEnvironment
	var sky3d = _course_root.get_node_or_null("Sky3D")
	var env: Environment = null
	if sky3d is WorldEnvironment and sky3d.environment != null:
		env = sky3d.environment
	else:
		for child in _course_root.get_children():
			if child is WorldEnvironment and child.environment != null:
				env = child.environment
				break

	if env != null:
		if rain_active:
			env.fog_enabled = true
			env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
			env.fog_light_color = Color(0.48, 0.52, 0.58)
			env.fog_density = 0.0035
			env.fog_sky_affect = 0.6
		else:
			if _cached_env_settings.has("fog_enabled"):
				env.fog_enabled = _cached_env_settings["fog_enabled"]
			if _cached_env_settings.has("fog_mode"):
				env.fog_mode = _cached_env_settings["fog_mode"]
			if _cached_env_settings.has("fog_light_color"):
				env.fog_light_color = _cached_env_settings["fog_light_color"]
			if _cached_env_settings.has("fog_density"):
				env.fog_density = _cached_env_settings["fog_density"]
			if _cached_env_settings.has("fog_sky_affect"):
				env.fog_sky_affect = _cached_env_settings["fog_sky_affect"]


func _find_first_directional_light(node: Node) -> DirectionalLight3D:
	if node is DirectionalLight3D:
		return node
	for child in node.get_children():
		var found = _find_first_directional_light(child)
		if found != null:
			return found
	return null
