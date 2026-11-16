extends RefCounted
class_name ProceduralTreeGenerator

## ProceduralTreeGenerator
## 1. Converts thousands of individual Tree_*, Bush_*, and Rock_* StaticBody3D/MeshInstance3D nodes
##    into spatial-chunked MultiMeshInstance3D batches with Lush Summer Parkland INSTANCE_CUSTOM
##    chlorophyll variation and consolidated Jolt compound collision bodies.
## 2. Generates procedural volumetric summer leaf cluster sub-canopies & shoreline reed meshes.

const CHUNK_SIZE_M: float = 160.0

## Lush Summer Parkland species color palette (RGB multiplier + alpha wind seed)
## Matches Warwick Hills summer foliage: emerald oaks, sunlit olive/lime crowns,
## weeping willows near water, silver birches, and deep forest pines.
static func get_lush_summer_instance_color(world_pos: Vector3, near_water: bool = false) -> Color:
	var h1 := fposmod(sin(world_pos.x * 12.9898 + world_pos.z * 78.233) * 43758.5453, 1.0)
	var h2 := fposmod(sin(world_pos.x * 39.346 + world_pos.z * 11.135) * 24634.6345, 1.0)
	var wind_seed := clampf(0.05 + h2 * 0.94, 0.05, 0.99)

	if near_water and h1 < 0.55:
		# Shoreline Weeping Willow / Natural Water-Edge Tone
		var willow := Color(0.94, 1.02, 0.90).lerp(Color(0.98, 1.04, 0.93), h2)
		return Color(willow.r, willow.g, willow.b, wind_seed)

	if h1 < 0.50:
		# Rich Summer Emerald Oak (50%)
		var oak := Color(0.92, 0.98, 0.90).lerp(Color(0.97, 1.02, 0.95), h2)
		return Color(oak.r, oak.g, oak.b, wind_seed)
	elif h1 < 0.75:
		# Sunlit Parkland Deciduous Crown (25%)
		var deciduous := Color(0.96, 1.02, 0.92).lerp(Color(1.02, 1.03, 0.95), h2)
		return Color(deciduous.r, deciduous.g, deciduous.b, wind_seed)
	elif h1 < 0.85:
		# Parkland Maple (10%)
		var maple := Color(0.94, 1.01, 0.93).lerp(Color(0.98, 1.02, 0.96), h2)
		return Color(maple.r, maple.g, maple.b, wind_seed)
	elif h1 < 0.93:
		# Silver Birch Summer Canopy (8%)
		var birch := Color(0.95, 1.03, 0.94).lerp(Color(1.00, 1.04, 0.97), h2)
		return Color(birch.r, birch.g, birch.b, wind_seed)
	else:
		# Deep Forest Pine / Spruce (7%)
		var pine := Color(0.82, 0.92, 0.85).lerp(Color(0.88, 0.96, 0.90), h2)
		return Color(pine.r, pine.g, pine.b, wind_seed)


## Creates a procedural clumped 3D shoreline reed / tall marsh grass mesh with occasional cattails for pond banks.
static func create_shoreline_reed_cluster_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var num_stalks := 30

	for i in range(num_stalks):
		var angle := (float(i) / float(num_stalks)) * TAU + rng.randf_range(-0.22, 0.22)
		var dist := sqrt(rng.randf()) * 0.34
		var base := Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		var stalk_dir := angle + rng.randf_range(-0.48, 0.48)

		# Three natural stature tiers within each clump so blades vary organically in height & arch:
		# - Short outer arching sedge (0.35m - 0.65m)
		# - Medium marsh grass blades (0.70m - 1.15m)
		# - Standout reed stalks (1.20m - 1.55m)
		var tier_roll := i % 5
		var h: float
		var lean: float
		var w: float
		if tier_roll == 0:
			h = rng.randf_range(1.20, 1.55)
			lean = rng.randf_range(0.08, 0.22)
			w = rng.randf_range(0.030, 0.046)
		elif tier_roll == 1 or tier_roll == 2:
			h = rng.randf_range(0.70, 1.15)
			lean = rng.randf_range(0.12, 0.28)
			w = rng.randf_range(0.034, 0.055)
		else:
			h = rng.randf_range(0.35, 0.65)
			lean = rng.randf_range(0.15, 0.32)
			w = rng.randf_range(0.036, 0.058)

		var blade_id := float(i) / float(num_stalks)
		var dry_seed := rng.randf()
		var stature_norm := clampf(h / 1.55, 0.20, 1.0)
		var blade_col := Color(0.0, blade_id, dry_seed, stature_norm)

		var fwd := Vector3(cos(stalk_dir), 0.0, sin(stalk_dir))
		var right := Vector3(-fwd.z, 0.0, fwd.x) * (w * 0.5)

		# Subterranean root vertex: extends 60cm below base into terrain so stalks firmly anchor on slopes
		var p_sub := base - Vector3(0.0, 0.60, 0.0)
		var p0 := base
		var p1 := base + Vector3(0.0, h * 0.50, 0.0) + fwd * (lean * 0.38)
		var p2 := base + Vector3(0.0, h, 0.0) + fwd * lean

		var n := (-fwd + Vector3(0.0, 0.68, 0.0)).normalized()

		# Crossed double-blade planes at slight angle for full 360-degree volumetric density
		for plane_idx in range(2):
			var r_vec := right if plane_idx == 0 else Vector3(fwd.x, 0.0, fwd.z) * (w * 0.42)

			# Subterranean / ground penetration segment
			st.set_color(blade_col)
			st.set_normal(n)
			st.set_uv(Vector2(0.0, 1.0))
			st.add_vertex(p_sub - r_vec)
			st.set_color(blade_col)
			st.set_normal(n)
			st.set_uv(Vector2(1.0, 1.0))
			st.add_vertex(p_sub + r_vec)
			st.set_color(blade_col)
			st.set_normal(n)
			st.set_uv(Vector2(1.0, 1.0))
			st.add_vertex(p0 + r_vec)

			st.set_color(blade_col)
			st.set_normal(n)
			st.set_uv(Vector2(0.0, 1.0))
			st.add_vertex(p_sub - r_vec)
			st.set_color(blade_col)
			st.set_normal(n)
			st.set_uv(Vector2(1.0, 1.0))
			st.add_vertex(p0 + r_vec)
			st.set_color(blade_col)
			st.set_normal(n)
			st.set_uv(Vector2(0.0, 1.0))
			st.add_vertex(p0 - r_vec)

			# Lower above-ground segment
			st.set_color(blade_col)
			st.set_normal(n)
			st.set_uv(Vector2(0.0, 1.0))
			st.add_vertex(p0 - r_vec)
			st.set_color(blade_col)
			st.set_normal(n)
			st.set_uv(Vector2(1.0, 1.0))
			st.add_vertex(p0 + r_vec)
			st.set_color(blade_col)
			st.set_normal(n)
			st.set_uv(Vector2(0.85, 0.5))
			st.add_vertex(p1 + r_vec * 0.72)

			st.set_color(blade_col)
			st.set_normal(n)
			st.set_uv(Vector2(0.0, 1.0))
			st.add_vertex(p0 - r_vec)
			st.set_color(blade_col)
			st.set_normal(n)
			st.set_uv(Vector2(0.85, 0.5))
			st.add_vertex(p1 + r_vec * 0.72)
			st.set_color(blade_col)
			st.set_normal(n)
			st.set_uv(Vector2(0.15, 0.5))
			st.add_vertex(p1 - r_vec * 0.72)

			# Upper segment tapering to blade tip
			st.set_color(blade_col)
			st.set_normal(n)
			st.set_uv(Vector2(0.15, 0.5))
			st.add_vertex(p1 - r_vec * 0.72)
			st.set_color(blade_col)
			st.set_normal(n)
			st.set_uv(Vector2(0.85, 0.5))
			st.add_vertex(p1 + r_vec * 0.72)
			st.set_color(blade_col)
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(0.5, 0.0))
			st.add_vertex(p2)

	# 3 Candidate 3D Cattails (Typha) with cylindrical brown seed heads and narrow top spikes.
	# The vertex shader selectively spawns/culls each candidate per world instance so cattails
	# appear occasionally in natural groupings rather than uniformly in every clump.
	var cattail_heights := [1.18, 1.32, 1.45]
	var cattail_ids := [0.22, 0.52, 0.82]
	for c_idx in range(3):
		var c_angle := (float(c_idx) / 3.0) * TAU + rng.randf_range(0.15, 0.65)
		var c_dist := rng.randf_range(0.05, 0.22)
		var c_base := Vector3(cos(c_angle) * c_dist, 0.0, sin(c_angle) * c_dist)
		var c_sub := c_base - Vector3(0.0, 0.60, 0.0)
		var c_h: float = cattail_heights[c_idx]
		var c_id: float = cattail_ids[c_idx]
		var c_lean := rng.randf_range(0.05, 0.14)
		var c_dir := Vector3(cos(c_angle + 0.2), 0.0, sin(c_angle + 0.2)).normalized()
		var c_perp := Vector3(-c_dir.z, 0.0, c_dir.x)

		var y_head_bot := c_h * 0.66
		var y_head_top := c_h * 0.86
		var p_head_bot := c_base + Vector3(0.0, y_head_bot, 0.0) + c_dir * (c_lean * 0.66)
		var p_head_top := c_base + Vector3(0.0, y_head_top, 0.0) + c_dir * (c_lean * 0.86)
		var p_spike_tip := c_base + Vector3(0.0, c_h, 0.0) + c_dir * c_lean

		# 1. Cattail Stalk Stem (COLOR.r = 0.5, COLOR.b = 0.0)
		var stem_col := Color(0.5, c_id, 0.0, 0.85)
		var stem_w := 0.018
		for sp_idx in range(2):
			var s_r := (c_perp if sp_idx == 0 else c_dir) * (stem_w * 0.5)
			var s_n := (-c_dir + Vector3(0.0, 0.5, 0.0)).normalized()
			# Subterranean stem anchor
			st.set_color(stem_col)
			st.set_normal(s_n)
			st.set_uv(Vector2(0.0, 1.0))
			st.add_vertex(c_sub - s_r)
			st.set_color(stem_col)
			st.set_normal(s_n)
			st.set_uv(Vector2(1.0, 1.0))
			st.add_vertex(c_sub + s_r)
			st.set_color(stem_col)
			st.set_normal(s_n)
			st.set_uv(Vector2(1.0, 1.0))
			st.add_vertex(c_base + s_r)

			st.set_color(stem_col)
			st.set_normal(s_n)
			st.set_uv(Vector2(0.0, 1.0))
			st.add_vertex(c_sub - s_r)
			st.set_color(stem_col)
			st.set_normal(s_n)
			st.set_uv(Vector2(1.0, 1.0))
			st.add_vertex(c_base + s_r)
			st.set_color(stem_col)
			st.set_normal(s_n)
			st.set_uv(Vector2(0.0, 1.0))
			st.add_vertex(c_base - s_r)

			# Above-ground stem up to cattail head base
			st.set_color(stem_col)
			st.set_normal(s_n)
			st.set_uv(Vector2(0.0, 1.0))
			st.add_vertex(c_base - s_r)
			st.set_color(stem_col)
			st.set_normal(s_n)
			st.set_uv(Vector2(1.0, 1.0))
			st.add_vertex(c_base + s_r)
			st.set_color(stem_col)
			st.set_normal(s_n)
			st.set_uv(Vector2(1.0, 0.34))
			st.add_vertex(p_head_bot + s_r * 0.85)

			st.set_color(stem_col)
			st.set_normal(s_n)
			st.set_uv(Vector2(0.0, 1.0))
			st.add_vertex(c_base - s_r)
			st.set_color(stem_col)
			st.set_normal(s_n)
			st.set_uv(Vector2(1.0, 0.34))
			st.add_vertex(p_head_bot + s_r * 0.85)
			st.set_color(stem_col)
			st.set_normal(s_n)
			st.set_uv(Vector2(0.0, 0.34))
			st.add_vertex(p_head_bot - s_r * 0.85)

		# 2. 3D Cylindrical Brown Cattail Seed Head (6-sided hexagonal prism with tapered caps, COLOR.r = 1.0)
		var head_radius := 0.024
		var ring_t := [0.0, 0.12, 0.88, 1.0]
		var ring_r_scale := [0.28, 1.0, 0.96, 0.25]
		var sides := 6
		for r_idx in range(3):
			var t0: float = ring_t[r_idx]
			var t1: float = ring_t[r_idx + 1]
			var center0 := p_head_bot.lerp(p_head_top, t0)
			var center1 := p_head_bot.lerp(p_head_top, t1)
			var rad0: float = head_radius * float(ring_r_scale[r_idx])
			var rad1: float = head_radius * float(ring_r_scale[r_idx + 1])
			var uv_y0 := lerpf(0.34, 0.14, t0)
			var uv_y1 := lerpf(0.34, 0.14, t1)
			var col0 := Color(1.0, c_id, t0, 0.90)
			var col1 := Color(1.0, c_id, t1, 0.90)

			for s_idx in range(sides):
				var a0 := (float(s_idx) / float(sides)) * TAU
				var a1 := (float(s_idx + 1) / float(sides)) * TAU
				var d0 := c_perp * cos(a0) + c_dir * sin(a0)
				var d1 := c_perp * cos(a1) + c_dir * sin(a1)
				var n0 := (d0 + Vector3(0.0, 0.15, 0.0)).normalized()
				var n1 := (d1 + Vector3(0.0, 0.15, 0.0)).normalized()

				var v00 := center0 + d0 * rad0
				var v10 := center0 + d1 * rad0
				var v01 := center1 + d0 * rad1
				var v11 := center1 + d1 * rad1

				st.set_color(col0)
				st.set_normal(n0)
				st.set_uv(Vector2(0.2, uv_y0))
				st.add_vertex(v00)
				st.set_color(col0)
				st.set_normal(n1)
				st.set_uv(Vector2(0.8, uv_y0))
				st.add_vertex(v10)
				st.set_color(col1)
				st.set_normal(n1)
				st.set_uv(Vector2(0.8, uv_y1))
				st.add_vertex(v11)

				st.set_color(col0)
				st.set_normal(n0)
				st.set_uv(Vector2(0.2, uv_y0))
				st.add_vertex(v00)
				st.set_color(col1)
				st.set_normal(n1)
				st.set_uv(Vector2(0.8, uv_y1))
				st.add_vertex(v11)
				st.set_color(col1)
				st.set_normal(n0)
				st.set_uv(Vector2(0.2, uv_y1))
				st.add_vertex(v01)

		# 3. Narrow Top Male Spike above brown cattail head (COLOR.r = 0.5, COLOR.b = 1.0)
		var spike_col := Color(0.5, c_id, 1.0, 0.95)
		var spike_w := 0.011
		for sp_idx in range(2):
			var sp_r := (c_perp if sp_idx == 0 else c_dir) * (spike_w * 0.5)
			st.set_color(spike_col)
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(0.3, 0.14))
			st.add_vertex(p_head_top - sp_r)
			st.set_color(spike_col)
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(0.7, 0.14))
			st.add_vertex(p_head_top + sp_r)
			st.set_color(spike_col)
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(0.5, 0.0))
			st.add_vertex(p_spike_tip)

	# Dense ground-level undergrowth collar (12 leafy blades, 0.35m-0.60m) to form an opaque turf cushion at ground level
	var num_undergrowth := 12
	for j in range(num_undergrowth):
		var u_angle := (float(j) / float(num_undergrowth)) * TAU + rng.randf_range(-0.25, 0.25)
		var u_dist := rng.randf_range(0.04, 0.28)
		var u_base := Vector3(cos(u_angle) * u_dist, 0.0, sin(u_angle) * u_dist)
		var u_sub := u_base - Vector3(0.0, 0.50, 0.0)
		var u_h := rng.randf_range(0.35, 0.60)
		var u_w := rng.randf_range(0.04, 0.07)
		var u_dir := Vector3(cos(u_angle), 0.0, sin(u_angle))
		var u_right := Vector3(-u_dir.z, 0.0, u_dir.x) * (u_w * 0.5)
		var u_tip := u_base + Vector3(0.0, u_h, 0.0) + u_dir * rng.randf_range(0.10, 0.24)
		var u_n := Vector3.UP
		var u_col := Color(0.0, float(j) / float(num_undergrowth), rng.randf() * 0.45, 0.12)

		# Subterranean anchor
		st.set_color(u_col)
		st.set_normal(u_n)
		st.set_uv(Vector2(0.0, 1.0))
		st.add_vertex(u_sub - u_right)
		st.set_color(u_col)
		st.set_normal(u_n)
		st.set_uv(Vector2(1.0, 1.0))
		st.add_vertex(u_sub + u_right)
		st.set_color(u_col)
		st.set_normal(u_n)
		st.set_uv(Vector2(1.0, 1.0))
		st.add_vertex(u_base + u_right)

		st.set_color(u_col)
		st.set_normal(u_n)
		st.set_uv(Vector2(0.0, 1.0))
		st.add_vertex(u_sub - u_right)
		st.set_color(u_col)
		st.set_normal(u_n)
		st.set_uv(Vector2(1.0, 1.0))
		st.add_vertex(u_base + u_right)
		st.set_color(u_col)
		st.set_normal(u_n)
		st.set_uv(Vector2(0.0, 1.0))
		st.add_vertex(u_base - u_right)

		# Above-ground blade to tip
		st.set_color(u_col)
		st.set_normal(u_n)
		st.set_uv(Vector2(0.0, 1.0))
		st.add_vertex(u_base - u_right)
		st.set_color(u_col)
		st.set_normal(u_n)
		st.set_uv(Vector2(1.0, 1.0))
		st.add_vertex(u_base + u_right)
		st.set_color(u_col)
		st.set_normal(u_n)
		st.set_uv(Vector2(0.5, 0.0))
		st.add_vertex(u_tip)

	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	if ResourceLoader.exists("res://Courses/Environments/shaders/grass_blades_high.gdshader"):
		mat.shader = load("res://Courses/Environments/shaders/grass_blades_high.gdshader") as Shader
		mat.set_shader_parameter("root_color", Color(0.14, 0.30, 0.10))
		mat.set_shader_parameter("tip_color", Color(0.32, 0.56, 0.20))
		mat.set_shader_parameter("dry_tip_color", Color(0.64, 0.56, 0.38))
		mat.set_shader_parameter("dry_tip_ratio", 0.42)
		mat.set_shader_parameter("head_ratio", 0.36)
		mat.set_shader_parameter("head_color", Color(0.31, 0.17, 0.09))
		mat.set_shader_parameter("wind_strength", 0.09)
		mat.set_shader_parameter("max_render_distance", 650.0)
		mat.set_shader_parameter("fade_start_distance", 500.0)
	mesh.surface_set_material(0, mat)
	return mesh


## Creates a procedural clumped 3D thick rough / fescue grass mesh for native rough and dunes.
static func create_thick_rough_grass_cluster_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rng := RandomNumberGenerator.new()
	rng.seed = 45812
	var num_blades := 28

	for i in range(num_blades):
		var angle := (float(i) / float(num_blades)) * TAU + rng.randf_range(-0.18, 0.18)
		var dist := rng.randf_range(0.06, 0.88)
		var base := Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		var out_dir := Vector3(cos(angle), 0.0, sin(angle)).normalized()
		var lean := rng.randf_range(0.20, 0.52)
		var h := rng.randf_range(0.85, 1.38)
		var w := rng.randf_range(0.042, 0.072)

		var fwd := (out_dir + Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.25, 0.25))).normalized()
		var right := Vector3(-fwd.z, 0.0, fwd.x) * (w * 0.5)

		var p0 := base
		var p1 := base + Vector3(0.0, h * 0.52, 0.0) + fwd * (lean * 0.38)
		var p2 := base + Vector3(0.0, h, 0.0) + fwd * lean

		var n := (-fwd + Vector3(0.0, 0.70, 0.0)).normalized()

		# Lower segment
		st.set_normal(n)
		st.set_uv(Vector2(0.0, 1.0))
		st.add_vertex(p0 - right)
		st.set_normal(n)
		st.set_uv(Vector2(1.0, 1.0))
		st.add_vertex(p0 + right)
		st.set_normal(n)
		st.set_uv(Vector2(0.85, 0.5))
		st.add_vertex(p1 + right * 0.72)

		st.set_normal(n)
		st.set_uv(Vector2(0.0, 1.0))
		st.add_vertex(p0 - right)
		st.set_normal(n)
		st.set_uv(Vector2(0.85, 0.5))
		st.add_vertex(p1 + right * 0.72)
		st.set_normal(n)
		st.set_uv(Vector2(0.15, 0.5))
		st.add_vertex(p1 - right * 0.72)

		# Upper segment tapering to tip
		st.set_normal(n)
		st.set_uv(Vector2(0.15, 0.5))
		st.add_vertex(p1 - right * 0.72)
		st.set_normal(n)
		st.set_uv(Vector2(0.85, 0.5))
		st.add_vertex(p1 + right * 0.72)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.5, 0.0))
		st.add_vertex(p2)

	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	if ResourceLoader.exists("res://Courses/Environments/shaders/grass_blades_high.gdshader"):
		mat.shader = load("res://Courses/Environments/shaders/grass_blades_high.gdshader") as Shader
		mat.set_shader_parameter("root_color", Color(0.32, 0.30, 0.15))
		mat.set_shader_parameter("tip_color", Color(0.68, 0.60, 0.34))
		mat.set_shader_parameter("dry_tip_color", Color(0.82, 0.74, 0.46))
		mat.set_shader_parameter("dry_tip_ratio", 0.60)
		mat.set_shader_parameter("wind_strength", 0.085)
		mat.set_shader_parameter("wind_speed", 1.25)
		mat.set_shader_parameter("max_render_distance", 260.0)
		mat.set_shader_parameter("fade_start_distance", 170.0)
	mesh.surface_set_material(0, mat)
	return mesh


## Extracts golf hole centerline / line of play corridors from `scene_root` or course metadata.
static func extract_course_hole_corridors(scene_root: Node) -> Array:
	var corridors: Array = []
	if scene_root == null:
		return corridors

	# 1. Check root metadata (set by OsmMapLoader)
	if scene_root.has_meta("hole_paths"):
		var meta_paths = scene_root.get_meta("hole_paths")
		if meta_paths is Array and not meta_paths.is_empty():
			for p in meta_paths:
				if p is PackedVector2Array or p is Array:
					corridors.append(p)
			if not corridors.is_empty():
				return corridors

	# 2. Check for Hole* child containers
	for child in scene_root.get_children():
		if child.name.begins_with("Hole"):
			if child.has_meta("hole_path"):
				var hp = child.get_meta("hole_path")
				if hp is PackedVector2Array or hp is Array:
					corridors.append(hp)
					continue
			var pts: Array[Vector2] = []
			for h_child in child.get_children():
				if h_child is Node3D:
					var p_x: float = h_child.global_position.x if h_child.is_inside_tree() else (h_child.position.x + (child.position.x if child is Node3D else 0.0))
					var p_z: float = h_child.global_position.z if h_child.is_inside_tree() else (h_child.position.z + (child.position.z if child is Node3D else 0.0))
					pts.append(Vector2(p_x, p_z))
			if pts.size() >= 2:
				corridors.append(pts)
	if not corridors.is_empty():
		return corridors

	# 3. Check for course.json in course directory
	var scene_path: String = scene_root.scene_file_path if "scene_file_path" in scene_root else ""
	if not scene_path.is_empty():
		var json_path := scene_path.get_base_dir().path_join("course.json")
		if FileAccess.file_exists(json_path):
			var f := FileAccess.open(json_path, FileAccess.READ)
			if f != null:
				var json_text := f.get_as_text()
				f.close()
				var parsed = JSON.parse_string(json_text)
				if parsed is Dictionary and parsed.has("course_info") and parsed["course_info"].has("holes"):
					var holes: Dictionary = parsed["course_info"]["holes"]
					for h_key in holes.keys():
						var h_data = holes[h_key]
						if h_data is Dictionary and h_data.has("hole_path"):
							var hp_arr = h_data["hole_path"]
							if hp_arr is Array and hp_arr.size() >= 2:
								var p_v2: Array[Vector2] = []
								for pt in hp_arr:
									if pt is Array and pt.size() >= 2:
										p_v2.append(Vector2(float(pt[0]), float(pt[1])))
								if p_v2.size() >= 2:
									corridors.append(p_v2)

	return corridors


## Computes the minimum distance from point `pt` to any segment along `corridor`.
static func get_distance_to_corridor(pt: Vector2, corridor: Variant) -> float:
	var count: int = corridor.size()
	if count == 0:
		return 999999.0
	if count == 1:
		var p0: Vector2 = corridor[0]
		return pt.distance_to(p0)
	var min_d := 999999.0
	for i in range(count - 1):
		var p1: Vector2 = corridor[i]
		var p2: Vector2 = corridor[i + 1]
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(pt, p1, p2)
		var d := pt.distance_to(closest)
		if d < min_d:
			min_d = d
	return min_d


## Classifies tree entries into Low (0), Medium (1), and High (2) graphics tiers.
## Groups trees by their closest golf hole corridor and assigns tiers proportionally within each
## hole group so that the distribution of trees across every single hole is completely even and balanced.
static func classify_trees_into_tiers(tree_entries: Array, corridors: Array) -> void:
	if tree_entries.is_empty():
		return

	# Fallback if no hole corridors are defined (e.g. driving range or minigame scene)
	if corridors.is_empty():
		var min_x := 999999.0
		var max_x := -999999.0
		var min_z := 999999.0
		var max_z := -999999.0
		for entry in tree_entries:
			var p: Vector3 = entry["pos"]
			if p.x < min_x: min_x = p.x
			if p.x > max_x: max_x = p.x
			if p.z < min_z: min_z = p.z
			if p.z > max_z: max_z = p.z
		var grid_cells := 4
		var span_x := maxf(1.0, (max_x - min_x) / float(grid_cells))
		var span_z := maxf(1.0, (max_z - min_z) / float(grid_cells))

		var zone_groups: Dictionary = {}
		for entry in tree_entries:
			var p: Vector3 = entry["pos"]
			var gx := clampi(int((p.x - min_x) / span_x), 0, grid_cells - 1)
			var gz := clampi(int((p.z - min_z) / span_z), 0, grid_cells - 1)
			var z_key := "%d_%d" % [gx, gz]
			if not zone_groups.has(z_key):
				zone_groups[z_key] = []
			entry["dist_to_corridor"] = 0.0
			zone_groups[z_key].append(entry)

		for z_key in zone_groups.keys():
			_assign_tiers_to_group(zone_groups[z_key])
		return

	# Map each tree to closest corridor
	var hole_groups: Array[Array] = []
	for i in range(corridors.size()):
		hole_groups.append([])

	for entry in tree_entries:
		var p: Vector3 = entry["pos"]
		var pt := Vector2(p.x, p.z)
		var best_idx := 0
		var best_dist := 999999.0
		for c_idx in range(corridors.size()):
			var d := get_distance_to_corridor(pt, corridors[c_idx])
			if d < best_dist:
				best_dist = d
				best_idx = c_idx
		entry["dist_to_corridor"] = best_dist
		hole_groups[best_idx].append(entry)

	# Assign tiers per hole group so distribution is even across every hole
	for group in hole_groups:
		_assign_tiers_to_group(group)


static func _assign_tiers_to_group(group: Array) -> void:
	if group.is_empty():
		return
	# Sort group: Authentic OSM trees and willows first, then by distance to corridor ascending (framing first)
	group.sort_custom(func(a, b):
		var a_auth: bool = a.get("is_authentic", false) or a.get("near_water", false)
		var b_auth: bool = b.get("is_authentic", false) or b.get("near_water", false)
		if a_auth != b_auth:
			return a_auth
		return float(a.get("dist_to_corridor", 0.0)) < float(b.get("dist_to_corridor", 0.0))
	)
	var count := group.size()
	# ~35% Low (framing), ~35% Medium (fill rough), ~30% High (deep forest)
	var low_count := maxi(1, int(round(float(count) * 0.35)))
	var med_count := maxi(low_count, int(round(float(count) * 0.70)))

	for i in range(count):
		if i < low_count:
			group[i]["tier"] = 0 # Low
		elif i < med_count:
			group[i]["tier"] = 1 # Medium
		else:
			group[i]["tier"] = 2 # High


## Converts individual Tree_*, Bush_*, and Rock_* nodes in `scene_root` into spatial-chunked
## MultiMeshInstance3D nodes and consolidated Jolt compound collision bodies.
## Safe to run both at runtime and during persistent `.tscn` migration in CourseGraphicsUpgrader.
static func convert_scene_foliage_to_multimesh(scene_root: Node, persist_for_save: bool = false) -> Dictionary:
	var stats := {
		"trees_converted": 0,
		"bushes_converted": 0,
		"rocks_converted": 0,
		"chunks_created": 0
	}
	if scene_root == null:
		return stats

	# If already converted to MultiMeshFoliageContainer, ensure all TreeChunk_* meshes
	# are upgraded from legacy boxy low-poly meshes to the new 16-sided volumetric 3D meshes,
	# classify instances into low/medium/high tiers with even hole distribution,
	# and synchronize ConsolidatedFoliageCollision so trunk colliders tightly align with visuals and tiers.
	var existing_mm := scene_root.get_node_or_null("MultiMeshFoliageContainer")
	if existing_mm != null:
		upgrade_existing_multimesh_trees(existing_mm)
		ensure_multimesh_tiers(scene_root, existing_mm, persist_for_save)
		sync_consolidated_foliage_collision(scene_root, existing_mm, persist_for_save)
		return stats

	var tree_nodes: Array[Node3D] = []
	var bush_nodes: Array[Node3D] = []
	var rock_nodes: Array[Node3D] = []
	var water_positions: Array[Vector2] = []

	# Search scene root plus any Hole* containers (custom multi-hole courses)
	var search_roots: Array[Node] = [scene_root]
	for child in scene_root.get_children():
		if child is Node3D and child.name.begins_with("Hole"):
			search_roots.append(child)
	for search_root in search_roots:
		for child in search_root.get_children():
			if not (child is Node3D):
				continue
			var cname := child.name
			if cname.begins_with("Tree_"):
				tree_nodes.append(child as Node3D)
			elif cname.begins_with("Bush_"):
				bush_nodes.append(child as Node3D)
			elif cname.begins_with("Rock_"):
				rock_nodes.append(child as Node3D)
			elif cname.to_lower().begins_with("water") and child is MeshInstance3D:
				var mi := child as MeshInstance3D
				if mi.mesh != null:
					var aabb := mi.mesh.get_aabb()
					var center := mi.transform * aabb.get_center()
					water_positions.append(Vector2(center.x, center.z))

	if tree_nodes.is_empty() and bush_nodes.is_empty() and rock_nodes.is_empty():
		return stats

	var mm_container := Node3D.new()
	mm_container.name = "MultiMeshFoliageContainer"
	scene_root.add_child(mm_container)
	if persist_for_save:
		mm_container.owner = scene_root

	var static_col_body := StaticBody3D.new()
	static_col_body.name = "ConsolidatedFoliageCollision"
	static_col_body.collision_layer = 1
	static_col_body.collision_mask = 0
	static_col_body.set_meta("is_tree", true)
	static_col_body.set_meta("trunk_collision_version", 2)
	static_col_body.add_to_group("trees", true)
	scene_root.add_child(static_col_body)
	if persist_for_save:
		static_col_body.owner = scene_root

	var canopy_area := Area3D.new()
	canopy_area.name = "ConsolidatedCanopyArea"
	canopy_area.collision_layer = 1
	canopy_area.collision_mask = 0
	canopy_area.monitoring = false
	canopy_area.monitorable = true
	canopy_area.set_meta("is_canopy", true)
	canopy_area.add_to_group("tree_canopy", true)
	scene_root.add_child(canopy_area)
	if persist_for_save:
		canopy_area.owner = scene_root

	var shared_canopy_shape := SphereShape3D.new()
	shared_canopy_shape.radius = 2.4

	var shared_rock_shape := SphereShape3D.new()
	shared_rock_shape.radius = 0.55

	# Compact metadata array of [x, y, z, scale_x, scale_y, scale_z, rot_y, mesh_idx] for CustomCourseBuilder
	var tree_meta_records: PackedFloat32Array = PackedFloat32Array()

	# Group visual instances by (category_mesh_key, chunk_x, chunk_z)
	var chunk_buckets: Dictionary = {}
	var mesh_lookup: Dictionary = {}
	var category_lookup: Dictionary = {}
	var shared_trunk_shape_cache: Dictionary = {}

	# 1. Process Trees: Gather all tree candidates, classify into Low/Medium/High tiers by hole corridor
	var hole_corridors := extract_course_hole_corridors(scene_root)
	var raw_trees: Array = []

	for t_node in tree_nodes:
		var mi := _find_first_mesh_instance(t_node)
		if mi == null or mi.mesh == null:
			continue
		var global_xf := t_node.transform * mi.transform
		var pos := t_node.position

		var m_path := mi.mesh.resource_path
		if m_path.is_empty():
			m_path = mi.mesh.resource_name
		if m_path.is_empty():
			m_path = "tree_mesh_" + str(mi.mesh.get_rid().get_id())
		var key := "Tree__" + m_path
		if not mesh_lookup.has(key):
			mesh_lookup[key] = _duplicate_mesh_with_materials(mi)
			category_lookup[key] = "Tree"

		var near_water := false
		var pos2d := Vector2(pos.x, pos.z)
		for wp in water_positions:
			if pos2d.distance_squared_to(wp) < 2500.0: # Within 50m of pond center
				near_water = true
				break

		var is_auth: bool = t_node.has_meta("is_authentic") or t_node.name.to_lower().contains("authentic") or t_node.name.to_lower().contains("osm") or m_path.to_lower().contains("willow")
		var orig_canopy: Area3D = t_node.get_node_or_null("CanopyArea") as Area3D
		var orig_canopy_shape: Shape3D = null
		var orig_canopy_pos := Vector3.ZERO
		if orig_canopy != null:
			orig_canopy_pos = orig_canopy.position
			for child in orig_canopy.get_children():
				if child is CollisionShape3D and child.shape != null:
					orig_canopy_shape = child.shape
					break
		var trunk_spec := get_visual_trunk_collider_spec(mi.mesh, m_path, t_node)

		raw_trees.append({
			"node": t_node,
			"pos": pos,
			"global_xf": global_xf,
			"color": get_lush_summer_instance_color(pos, near_water),
			"mesh_key": key,
			"mesh_path": m_path,
			"near_water": near_water,
			"is_authentic": is_auth,
			"trunk_spec": trunk_spec,
			"orig_canopy_shape": orig_canopy_shape,
			"orig_canopy_pos": orig_canopy_pos,
			"scale": t_node.scale,
			"rot_y": t_node.rotation.y,
			"tier": 0
		})

	# Classify trees into tiers (0=Low, 1=Medium, 2=High) distributed evenly across all holes
	classify_trees_into_tiers(raw_trees, hole_corridors)

	for entry in raw_trees:
		var pos: Vector3 = entry["pos"]
		var cx := int(floor(pos.x / CHUNK_SIZE_M))
		var cz := int(floor(pos.z / CHUNK_SIZE_M))
		var bucket_key := "%s__%d_%d" % [entry["mesh_key"], cx, cz]
		if not chunk_buckets.has(bucket_key):
			chunk_buckets[bucket_key] = {
				"mesh_key": entry["mesh_key"],
				"category": "Tree",
				"items": []
			}
		chunk_buckets[bucket_key]["items"].append(entry)

		# Record metadata for CustomCourseBuilder hole extraction
		var m_idx := 0
		var m_path: String = entry["mesh_path"]
		if m_path.contains("tree-02"):
			m_idx = 1
		elif m_path.contains("tree-03"):
			m_idx = 2
		var t_scale: Vector3 = entry["scale"]
		tree_meta_records.append(pos.x)
		tree_meta_records.append(pos.y)
		tree_meta_records.append(pos.z)
		tree_meta_records.append(t_scale.x)
		tree_meta_records.append(t_scale.y)
		tree_meta_records.append(t_scale.z)
		tree_meta_records.append(entry["rot_y"])
		tree_meta_records.append(float(m_idx))
		stats["trees_converted"] += 1

	# 2. Process Bushes (Visual MultiMesh only — removing tiny bush physics bodies saves massive CPU/Jolt time)
	for b_node in bush_nodes:
		var mi := _find_first_mesh_instance(b_node)
		if mi == null or mi.mesh == null:
			continue
		var global_xf := b_node.transform * mi.transform
		var pos := b_node.position

		var m_path := mi.mesh.resource_path
		if m_path.is_empty():
			m_path = "bush_mesh_" + str(mi.mesh.get_rid().get_id())
		var key := "Bush__" + m_path
		if not mesh_lookup.has(key):
			mesh_lookup[key] = _duplicate_mesh_with_materials(mi)
			category_lookup[key] = "Bush"

		var cx := int(floor(pos.x / CHUNK_SIZE_M))
		var cz := int(floor(pos.z / CHUNK_SIZE_M))
		var bucket_key := "%s__%d_%d" % [key, cx, cz]
		if not chunk_buckets.has(bucket_key):
			chunk_buckets[bucket_key] = {
				"mesh_key": key,
				"category": "Bush",
				"items": []
			}

		chunk_buckets[bucket_key]["items"].append({
			"global_xf": global_xf,
			"color": get_lush_summer_instance_color(pos, false),
			"tier": 1
		})
		stats["bushes_converted"] += 1

	# 3. Remove legacy Water-Perimeter Rocks (replaced by continuous tall shoreline grass in CourseDetailEnhancer)
	for r_node in rock_nodes:
		r_node.get_parent().remove_child(r_node)
		r_node.free()
		stats["rocks_converted"] += 1

	# 4. Instantiate Spatial MultiMeshInstance3D Chunks
	var chunk_idx := 0
	for bucket_key in chunk_buckets.keys():
		var bucket: Dictionary = chunk_buckets[bucket_key]
		var cat: String = bucket.get("category", category_lookup.get(bucket["mesh_key"], "Tree"))
		var items: Array = bucket["items"]
		var count := items.size()
		if count == 0:
			continue

		# Sort items by tier (Low first: 0, then Medium: 1, then High: 2)
		items.sort_custom(func(a, b):
			return int(a.get("tier", 0)) < int(b.get("tier", 0))
		)

		var c_low := 0
		var c_med := 0
		for item in items:
			var t: int = item.get("tier", 0)
			if t == 0:
				c_low += 1
				c_med += 1
			elif t == 1:
				c_med += 1

		if cat == "Bush":
			# Low graphics = 0 bushes, Medium = 50%, High = 100%
			c_low = 0
			c_med = maxi(1, int(count * 0.5))

		var m_key: String = bucket["mesh_key"]
		var base_mesh: Mesh = mesh_lookup[m_key]

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = base_mesh
		mm.instance_count = count

		var buf := PackedFloat32Array()
		buf.resize(count * 16)
		for i in range(count):
			var item: Dictionary = items[i]
			var xf: Transform3D = item["global_xf"]
			var col: Color = item["color"]
			var b_idx := i * 16
			buf[b_idx + 0] = xf.basis.x.x
			buf[b_idx + 1] = xf.basis.y.x
			buf[b_idx + 2] = xf.basis.z.x
			buf[b_idx + 3] = xf.origin.x
			buf[b_idx + 4] = xf.basis.x.y
			buf[b_idx + 5] = xf.basis.y.y
			buf[b_idx + 6] = xf.basis.z.y
			buf[b_idx + 7] = xf.origin.y
			buf[b_idx + 8] = xf.basis.x.z
			buf[b_idx + 9] = xf.basis.y.z
			buf[b_idx + 10] = xf.basis.z.z
			buf[b_idx + 11] = xf.origin.z
			buf[b_idx + 12] = col.r
			buf[b_idx + 13] = col.g
			buf[b_idx + 14] = col.b
			buf[b_idx + 15] = col.a
			mm.set_instance_transform(i, xf)
			mm.set_instance_custom_data(i, col)

			if cat == "Tree":
				var trunk_spec: Dictionary = item.get("trunk_spec", {})
				if not trunk_spec.is_empty():
					var trunk_col := _create_aligned_trunk_collision_shape(xf, trunk_spec, shared_trunk_shape_cache)
					trunk_col.set_meta("foliage_tier", item.get("tier", 0))
					static_col_body.add_child(trunk_col)
					if persist_for_save:
						trunk_col.owner = scene_root

				var canopy_col := CollisionShape3D.new()
				canopy_col.set_meta("foliage_tier", item.get("tier", 0))
				var pos: Vector3 = item["pos"]
				var i_scale: Vector3 = item.get("scale", Vector3.ONE)
				var c_shape: Shape3D = item.get("orig_canopy_shape", null)
				var c_pos: Vector3 = item.get("orig_canopy_pos", Vector3.ZERO)
				if c_shape != null:
					canopy_col.shape = c_shape
					canopy_col.position = pos + Vector3(
						c_pos.x * i_scale.x,
						c_pos.y * i_scale.y,
						c_pos.z * i_scale.z
					)
				else:
					canopy_col.shape = shared_canopy_shape
					canopy_col.position = pos + Vector3(0.0, 3.8 * i_scale.y, 0.0)

				canopy_col.scale = i_scale
				canopy_area.add_child(canopy_col)
				if persist_for_save:
					canopy_col.owner = scene_root

		mm.buffer = buf

		var mmi := MultiMeshInstance3D.new()
		mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		mmi.name = "%sChunk_%d" % [cat, chunk_idx]
		mmi.multimesh = mm
		mmi.set_meta("tier_low_count", c_low)
		mmi.set_meta("tier_med_count", c_med)
		mmi.set_meta("tier_high_count", count)

		if cat == "Tree":
			mmi.visibility_range_end = 500.0
			mmi.visibility_range_end_margin = 35.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		elif cat == "Bush":
			mmi.visibility_range_end = 220.0
			mmi.visibility_range_end_margin = 25.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			mmi.visibility_range_end = 240.0
			mmi.visibility_range_end_margin = 20.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		mm_container.add_child(mmi)
		if persist_for_save:
			mmi.owner = scene_root
		chunk_idx += 1

	# Safely free original individual tree and bush nodes now that all MultiMeshes and colliders are created
	for t_node in tree_nodes:
		if is_instance_valid(t_node):
			if t_node.get_parent() != null:
				t_node.get_parent().remove_child(t_node)
			t_node.free()
	for b_node in bush_nodes:
		if is_instance_valid(b_node):
			if b_node.get_parent() != null:
				b_node.get_parent().remove_child(b_node)
			b_node.free()

	mm_container.set_meta("tree_records", tree_meta_records)
	stats["chunks_created"] = chunk_idx
	return stats


## Upgrades any existing MultiMeshFoliageContainer so its MultiMesh instances
## are sorted and tagged with tier_low_count, tier_med_count, tier_high_count
## with even distribution across golf holes.
static func ensure_multimesh_tiers(scene_root: Node, mm_container: Node = null, persist_for_save: bool = false) -> void:
	if scene_root == null:
		return
	if mm_container == null:
		mm_container = scene_root.get_node_or_null("MultiMeshFoliageContainer")
	if mm_container == null:
		return

	var tree_chunks: Array[MultiMeshInstance3D] = []
	var needs_upgrade := false
	for child in mm_container.get_children():
		if child is MultiMeshInstance3D:
			var mmi := child as MultiMeshInstance3D
			var cname := mmi.name.to_lower()
			if cname.begins_with("treechunk"):
				tree_chunks.append(mmi)
				if not mmi.has_meta("tier_low_count") or not mmi.has_meta("tier_med_count"):
					needs_upgrade = true
			elif cname.begins_with("bushchunk"):
				if not mmi.has_meta("tier_low_count") or not mmi.has_meta("tier_med_count"):
					var b_cnt := mmi.multimesh.instance_count if mmi.multimesh != null else 0
					mmi.set_meta("tier_low_count", 0)
					mmi.set_meta("tier_med_count", maxi(1, int(b_cnt * 0.5)))
					mmi.set_meta("tier_high_count", b_cnt)

	if not needs_upgrade or tree_chunks.is_empty():
		return

	var hole_corridors := extract_course_hole_corridors(scene_root)

	for mmi in tree_chunks:
		var mm := mmi.multimesh
		if mm == null or mm.instance_count <= 0:
			continue
		var count := mm.instance_count
		var items: Array = []
		for i in range(count):
			var xf := mm.get_instance_transform(i)
			var col := mm.get_instance_custom_data(i)
			items.append({
				"index": i,
				"pos": xf.origin,
				"global_xf": xf,
				"color": col,
				"tier": 0
			})

		classify_trees_into_tiers(items, hole_corridors)

		items.sort_custom(func(a, b):
			return int(a.get("tier", 0)) < int(b.get("tier", 0))
		)

		var c_low := 0
		var c_med := 0
		var buf := PackedFloat32Array()
		buf.resize(count * 16)
		for i in range(count):
			var item: Dictionary = items[i]
			var xf: Transform3D = item["global_xf"]
			var col: Color = item["color"]
			var t: int = item.get("tier", 0)
			if t == 0:
				c_low += 1
				c_med += 1
			elif t == 1:
				c_med += 1

			var b_idx := i * 16
			buf[b_idx + 0] = xf.basis.x.x
			buf[b_idx + 1] = xf.basis.y.x
			buf[b_idx + 2] = xf.basis.z.x
			buf[b_idx + 3] = xf.origin.x
			buf[b_idx + 4] = xf.basis.x.y
			buf[b_idx + 5] = xf.basis.y.y
			buf[b_idx + 6] = xf.basis.z.y
			buf[b_idx + 7] = xf.origin.y
			buf[b_idx + 8] = xf.basis.x.z
			buf[b_idx + 9] = xf.basis.y.z
			buf[b_idx + 10] = xf.basis.z.z
			buf[b_idx + 11] = xf.origin.z
			buf[b_idx + 12] = col.r
			buf[b_idx + 13] = col.g
			buf[b_idx + 14] = col.b
			buf[b_idx + 15] = col.a
			mm.set_instance_transform(i, xf)
			mm.set_instance_custom_data(i, col)

		mm.buffer = buf
		mmi.set_meta("tier_low_count", c_low)
		mmi.set_meta("tier_med_count", c_med)
		mmi.set_meta("tier_high_count", count)

	sync_consolidated_foliage_collision(scene_root, mm_container, persist_for_save)


static func ensure_chunk_tiers(scene_root: Node, mmi: MultiMeshInstance3D) -> void:
	if mmi == null or mmi.multimesh == null or mmi.has_meta("tier_low_count"):
		return
	var mm_container = mmi.get_parent()
	if mm_container != null:
		ensure_multimesh_tiers(scene_root, mm_container, false)


static func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_first_mesh_instance(child)
		if found != null:
			return found
	return null


static func _duplicate_mesh_with_materials(mi: MeshInstance3D) -> Mesh:
	var dup := mi.mesh.duplicate() as Mesh
	for s in range(dup.get_surface_count()):
		var override_m := mi.get_surface_override_material(s)
		if override_m != null:
			dup.surface_set_material(s, override_m)
	return dup


## Upgrades any legacy low-poly TreeChunk_* MultiMeshInstance3D inside `mm_container`
## to use the realistic 16-sided smooth-trunk, multi-lobed 3D tree meshes while preserving materials,
## and strips any legacy RockChunk_* MultiMesh nodes.
static func upgrade_existing_multimesh_trees(mm_container: Node) -> int:
	if mm_container == null:
		return 0
	var upgraded := 0
	var idx := 0
	var rocks_to_remove: Array[Node] = []
	for child in mm_container.get_children():
		if child is MultiMeshInstance3D:
			var cname := child.name.to_lower()
			if cname.begins_with("treechunk"):
				if upgrade_tree_chunk_mesh_in_place(child as MultiMeshInstance3D, idx):
					upgraded += 1
				idx += 1
			elif cname.begins_with("rockchunk"):
				rocks_to_remove.append(child)
	for rc in rocks_to_remove:
		mm_container.remove_child(rc)
		if rc.is_inside_tree():
			rc.queue_free()
		else:
			rc.free()
	return upgraded


static func upgrade_tree_chunk_mesh_in_place(mmi: MultiMeshInstance3D, chunk_idx: int = 0) -> bool:
	if mmi == null or mmi.multimesh == null or mmi.multimesh.mesh == null:
		return false
	var old_mesh := mmi.multimesh.mesh
	# Enhanced photographic 3D tree meshes have resource_name ending in "_v4_photo"
	if old_mesh.resource_name.ends_with("_v4_photo"):
		return false

	var mats: Array[Material] = []
	if mmi.has_meta("orig_surface_mats"):
		var cached: Array = mmi.get_meta("orig_surface_mats")
		for m in cached:
			mats.append(m as Material)
	else:
		for s in range(old_mesh.get_surface_count()):
			mats.append(old_mesh.surface_get_material(s))

	var sig := ""
	for m in mats:
		if m != null:
			sig += " " + m.resource_path.to_lower()
			if m is BaseMaterial3D and (m as BaseMaterial3D).albedo_texture != null:
				sig += " " + (m as BaseMaterial3D).albedo_texture.resource_path.to_lower()
			elif m is ShaderMaterial:
				var tex = (m as ShaderMaterial).get_shader_parameter("texture_albedo")
				if tex is Resource:
					sig += " " + (tex as Resource).resource_path.to_lower()

	var target_scene_path := ""
	if sig.contains("willow"):
		var w_idx := (chunk_idx % 3) + 1
		target_scene_path = "res://addons/shapespark-low-poly-exterior-plants/bodies/tree-willow-%d-staticbody.tscn" % w_idx
	elif sig.contains("pine") or sig.contains("branch-2"):
		var p_idx := (chunk_idx % 4) + 1
		target_scene_path = "res://addons/shapespark-low-poly-exterior-plants/meshes/tree-03-%d-mesh.tscn" % p_idx
	elif sig.contains("birch") or sig.contains("branch-1") or sig.contains("autumn-red"):
		var m_idx := (chunk_idx % 4) + 1
		target_scene_path = "res://addons/shapespark-low-poly-exterior-plants/meshes/tree-02-%d-mesh.tscn" % m_idx
	else:
		var o_idx := (chunk_idx % 4) + 1
		target_scene_path = "res://addons/shapespark-low-poly-exterior-plants/meshes/tree-01-%d-mesh.tscn" % o_idx

	if not ResourceLoader.exists(target_scene_path):
		return false
	var sc := load(target_scene_path) as PackedScene
	if sc == null:
		return false
	var inst := sc.instantiate()
	var mi := _find_first_mesh_instance(inst)
	var new_mesh: Mesh = null
	if mi != null and mi.mesh != null:
		new_mesh = _duplicate_mesh_with_materials(mi)
	inst.free()
	if new_mesh == null:
		return false

	# Re-apply original species materials (if valid BaseMaterial3D) so low/med/high switcher works seamlessly
	if not sig.contains("willow"):
		for s in range(min(new_mesh.get_surface_count(), mats.size())):
			if mats[s] is StandardMaterial3D:
				new_mesh.surface_set_material(s, mats[s])

	var refreshed_orig_mats: Array = []
	for s in range(new_mesh.get_surface_count()):
		refreshed_orig_mats.append(new_mesh.surface_get_material(s))
	mmi.set_meta("orig_surface_mats", refreshed_orig_mats)
	mmi.multimesh.mesh = new_mesh
	return true


## Returns the exact local-space trunk cylinder dimensions (`radius`, `height`, `center_y`)
## matching the visible cylindrical trunk bark geometry (below the upper canopy split) for `mesh`.
static func get_visual_trunk_collider_spec(mesh: Mesh, mesh_hint: String = "", tree_node: Node = null) -> Dictionary:
	var sig := mesh_hint.to_lower()
	if mesh != null:
		sig += " " + mesh.resource_path.to_lower() + " " + mesh.resource_name.to_lower()
		for s in range(mesh.get_surface_count()):
			var mat := mesh.surface_get_material(s)
			if mat != null:
				sig += " " + mat.resource_path.to_lower()
	if tree_node != null:
		if tree_node.has_meta("is_willow"):
			sig += " willow"
		if tree_node.has_meta("is_pine"):
			sig += " pine"
		if tree_node.has_meta("is_birch"):
			sig += " birch"
		if tree_node.has_meta("tree_type"):
			sig += " " + str(tree_node.get_meta("tree_type")).to_lower()

	# Custom primitive CylinderMesh fallback (e.g. unit tests)
	if mesh is CylinderMesh and not sig.contains("tree-"):
		var cm := mesh as CylinderMesh
		var r := clampf((cm.top_radius + cm.bottom_radius) * 0.5, 0.12, 0.40)
		var h := maxf(cm.height * 0.9, 1.5)
		return {
			"radius": r,
			"height": h,
			"center_y": h * 0.5
		}

	# 1. Weeping Willows (tree-willow-1..3): visible trunk r=0.18m from ground to main bough split at y=2.3m
	if sig.contains("willow"):
		return {
			"radius": 0.18,
			"height": 2.3,
			"center_y": 1.15
		}

	# 2. Conifers / Pines / Spruces (tree-03-1..4, tree-pine-1..2): slender central trunk r=0.15m up to y=2.6m
	if sig.contains("tree-03") or sig.contains("pine"):
		return {
			"radius": 0.15,
			"height": 2.6,
			"center_y": 1.3
		}

	# 3. Maples / Birches / Poplars (tree-02-1..4, tree-birch-1..2, tree-autumn-red-1..2):
	#    visible trunk radius at ball impact height (y=0.5..2.35m) is ~0.16m
	if sig.contains("tree-02") or sig.contains("birch") or sig.contains("autumn-red") or sig.contains("branch-1"):
		return {
			"radius": 0.16,
			"height": 2.5,
			"center_y": 1.25
		}

	# 4. Mature Broadleaf Oaks / Sycamores / Autumn Gold / Blossom (tree-01-1..4):
	#    visible trunk radius at ball impact height (y=0.5..2.25m) is ~0.16m
	return {
		"radius": 0.16,
		"height": 2.4,
		"center_y": 1.2
	}


## Creates a world-space aligned `CollisionShape3D` with baked `CylinderShape3D` dimensions
## and `scale = Vector3.ONE` directly from the visual mesh instance's `global_xf`.
static func _create_aligned_trunk_collision_shape(global_xf: Transform3D, trunk_spec: Dictionary, shared_shape_cache: Dictionary = {}) -> CollisionShape3D:
	var scale_vec := global_xf.basis.get_scale()
	var xz_scale := maxf((absf(scale_vec.x) + absf(scale_vec.z)) * 0.5, 0.01)
	var y_scale := maxf(absf(scale_vec.y), 0.01)

	var local_r: float = float(trunk_spec.get("radius", 0.26))
	var local_h: float = float(trunk_spec.get("height", 2.5))
	var local_cy: float = float(trunk_spec.get("center_y", local_h * 0.5))

	# Quantize to 1cm to maximize CylinderShape3D resource sharing across similar-sized trees
	var world_r := snappedf(local_r * xz_scale, 0.01)
	var world_h := snappedf(local_h * y_scale, 0.02)
	var cache_key := "%.2f_%.2f" % [world_r, world_h]

	var cyl: CylinderShape3D = shared_shape_cache.get(cache_key, null) as CylinderShape3D
	if cyl == null:
		cyl = CylinderShape3D.new()
		cyl.radius = maxf(world_r, 0.08)
		cyl.height = maxf(world_h, 0.5)
		shared_shape_cache[cache_key] = cyl

	var trunk_col := CollisionShape3D.new()
	trunk_col.shape = cyl
	# Use global_xf * Vector3(0, local_cy, 0) so the cylinder center is anchored to the exact visual trunk axis
	trunk_col.position = global_xf.origin + Vector3(0.0, local_cy * y_scale, 0.0)
	trunk_col.scale = Vector3.ONE
	trunk_col.rotation = Vector3.ZERO
	return trunk_col


## Synchronizes `ConsolidatedFoliageCollision` trunk colliders in already-converted course scenes
## so that every tree trunk collider matches the exact visual `MultiMeshInstance3D` transform and trunk radius/height.
static func sync_consolidated_foliage_collision(scene_root: Node, mm_container: Node, persist_for_save: bool = false) -> int:
	if scene_root == null or mm_container == null:
		return 0

	var static_col_body := scene_root.get_node_or_null("ConsolidatedFoliageCollision") as StaticBody3D
	if static_col_body == null:
		static_col_body = StaticBody3D.new()
		static_col_body.name = "ConsolidatedFoliageCollision"
		static_col_body.collision_layer = 1
		static_col_body.collision_mask = 0
		static_col_body.set_meta("is_tree", true)
		static_col_body.add_to_group("trees", true)
		scene_root.add_child(static_col_body)
		if persist_for_save:
			static_col_body.owner = scene_root

	# Remove old oversized or double-scaled CylinderShape3D trunk colliders and legacy rock SphereShape3Ds
	var old_trunk_cols: Array[Node] = []
	var old_rock_cols: Array[Node] = []
	for child in static_col_body.get_children():
		if child is CollisionShape3D:
			var cs := child as CollisionShape3D
			if cs.shape is CylinderShape3D:
				old_trunk_cols.append(cs)
			elif cs.shape is SphereShape3D:
				old_rock_cols.append(cs)

	for rc in old_rock_cols:
		static_col_body.remove_child(rc)
		rc.free()

	var canopy_area := scene_root.get_node_or_null("ConsolidatedCanopyArea") as Area3D
	var canopy_needs_sync := false
	if canopy_area != null:
		var canopy_children := canopy_area.get_children()
		if canopy_children.is_empty() or not (canopy_children[0] is CollisionShape3D) or not canopy_children[0].has_meta("foliage_tier"):
			canopy_needs_sync = true

	# Only skip if already at trunk_collision_version 4 AND existing cylinders have foliage_tier and uniform scale
	if not persist_for_save and not canopy_needs_sync and int(static_col_body.get_meta("trunk_collision_version", 0)) >= 4 and not old_trunk_cols.is_empty():
		var first_cs := old_trunk_cols[0] as CollisionShape3D
		if first_cs.scale.is_equal_approx(Vector3.ONE) and first_cs.has_meta("foliage_tier"):
			return 0

	for old_c in old_trunk_cols:
		static_col_body.remove_child(old_c)
		old_c.free()

	var shared_canopy_shape: SphereShape3D = null
	if canopy_area != null and (canopy_needs_sync or persist_for_save or int(static_col_body.get_meta("trunk_collision_version", 0)) < 4):
		canopy_needs_sync = true
		for old_cc in canopy_area.get_children().duplicate():
			canopy_area.remove_child(old_cc)
			old_cc.free()
		shared_canopy_shape = SphereShape3D.new()
		shared_canopy_shape.radius = 2.2

	var shared_shape_cache: Dictionary = {}
	var rebuilt_count := 0

	for child in mm_container.get_children():
		if not (child is MultiMeshInstance3D):
			continue
		var mmi := child as MultiMeshInstance3D
		if not mmi.name.to_lower().begins_with("treechunk"):
			continue
		var mm := mmi.multimesh
		if mm == null or mm.mesh == null or mm.instance_count <= 0:
			continue

		var trunk_spec := get_visual_trunk_collider_spec(mm.mesh, mmi.name)
		var low_cnt: int = mmi.get_meta("tier_low_count", -1)
		var med_cnt: int = mmi.get_meta("tier_med_count", -1)
		for i in range(mm.instance_count):
			var inst_xf := mm.get_instance_transform(i)
			var trunk_col := _create_aligned_trunk_collision_shape(inst_xf, trunk_spec, shared_shape_cache)
			var tier := 0
			if low_cnt >= 0 and med_cnt >= 0:
				if i < low_cnt:
					tier = 0
				elif i < med_cnt:
					tier = 1
				else:
					tier = 2
			else:
				var t_frac := float(i) / float(maxi(1, mm.instance_count))
				tier = 0 if t_frac < 0.35 else (1 if t_frac < 0.70 else 2)
			trunk_col.set_meta("foliage_tier", tier)
			static_col_body.add_child(trunk_col)
			if persist_for_save:
				trunk_col.owner = scene_root
			if canopy_needs_sync and canopy_area != null and shared_canopy_shape != null:
				var i_scale := inst_xf.basis.get_scale()
				var canopy_col := CollisionShape3D.new()
				canopy_col.set_meta("foliage_tier", tier)
				canopy_col.shape = shared_canopy_shape
				canopy_col.position = inst_xf.origin + Vector3(0.0, 3.8 * i_scale.y, 0.0)
				canopy_col.scale = i_scale
				canopy_area.add_child(canopy_col)
				if persist_for_save:
					canopy_col.owner = scene_root
			rebuilt_count += 1

	static_col_body.set_meta("trunk_collision_version", 4)
	return rebuilt_count
