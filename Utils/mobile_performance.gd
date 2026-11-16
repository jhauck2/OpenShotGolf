class_name MobilePerformance

## Returns physical RAM in gigabytes, or -1.0 if unavailable
static func get_system_ram_gb() -> float:
	var mem = OS.get_memory_info()
	if mem.has("physical") and mem["physical"] > 0:
		return float(mem["physical"]) / (1024.0 * 1024.0 * 1024.0)
	return -1.0

## Returns the hardware-recommended default graphics quality ("Low", "Medium", or "High")
## Systems with < 8GB RAM or running mobile OS default to "Low", 8-15GB defaults to "Medium", >= 15GB defaults to "High".
static func get_default_graphics_quality() -> String:
	if is_mobile():
		return "Low"
	var ram_gb = get_system_ram_gb()
	if ram_gb > 0.0 and ram_gb < 7.5: # 8GB systems often report ~7.7-7.9 GB
		return "Low"
	elif ram_gb > 0.0 and ram_gb < 15.0:
		return "Medium"
	return "High"

## Returns true if running on mobile operating systems (Android or iOS) or mobile feature profile
static func is_mobile() -> bool:
	var os_name = OS.get_name()
	return os_name == "Android" or os_name == "iOS" or OS.has_feature("mobile")

## Call this after Sky3D / WorldEnvironment is set up and in the scene tree
static func optimize_sky3d(sky3d: Node) -> void:
	if not is_mobile() or sky3d == null:
		return
	
	# Disable expensive cloud layers
	if "clouds_enabled" in sky3d:
		sky3d.clouds_enabled = false
	
	# Disable atmospheric fog post-process
	if "fog_enabled" in sky3d:
		sky3d.fog_enabled = false
	
	# Set sky to only re-render when parameters change (prevents per-frame radiance recomputation)
	if "environment" in sky3d and sky3d.environment != null:
		sky3d.environment.ssao_enabled = false
		if sky3d.environment.sky != null:
			sky3d.environment.sky.process_mode = Sky.PROCESS_MODE_REALTIME
			sky3d.environment.sky.radiance_size = Sky.RADIANCE_SIZE_128

	# Reduce shadow quality on SunLight
	var sun: DirectionalLight3D = null
	if "sun" in sky3d and sky3d.sun != null:
		sun = sky3d.sun
	elif sky3d.has_node("SunLight"):
		sun = sky3d.get_node("SunLight") as DirectionalLight3D

	if sun != null:
		optimize_sun_light(sun)

## Optimize DirectionalLight3D shadows for mobile
static func optimize_sun_light(sun: DirectionalLight3D) -> void:
	if not is_mobile() or sun == null:
		return
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 200.0
	sun.directional_shadow_blend_splits = false

## Optimizes any 3D scene (DirectionalLights, Sky, WorldEnvironment) for mobile
static func optimize_scene(scene_root: Node) -> void:
	if not is_mobile() or scene_root == null:
		return
	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is DirectionalLight3D:
			optimize_sun_light(n)
		elif n is WorldEnvironment and n.environment != null:
			optimize_environment(n.environment)
		elif n is MeshInstance3D:
			var n_lower = n.name.to_lower()
			if n_lower.contains("ground") or n_lower.contains("terrain") or n_lower.contains("fairway") or n_lower.contains("green") or n_lower.contains("fringe") or n_lower.contains("rough"):
				n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for child in n.get_children():
			stack.append(child)

## Optimize generic Environment for mobile
static func optimize_environment(env: Environment) -> void:
	if not is_mobile() or env == null:
		return
	env.ssao_enabled = false
	if env.sky != null:
		env.sky.process_mode = Sky.PROCESS_MODE_REALTIME
		env.sky.radiance_size = Sky.RADIANCE_SIZE_128


## Call this once at game startup (e.g., in SceneManager)
static func apply_global_render_settings(tree: SceneTree = null) -> void:
	if not is_mobile():
		return
	
	# Allow mobile displays to render at their native refresh rate (60/90/120Hz)
	# Physics interpolation smoothly bridges 60Hz physics across arbitrary display refresh rates.
	
	# Reduce soft shadow quality project-wide
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_LOW
	)
	
	# Reduce 3D render resolution if root viewport is accessible
	if tree != null and tree.root != null:
		tree.root.scaling_3d_scale = 0.8
		tree.root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR

## Helpers for Parallax Turf shaders
static func get_parallax_layers() -> int:
	return 1 if is_mobile() else 16

static func get_parallax_depth_scale() -> float:
	return 0.0 if is_mobile() else 0.12

static func is_driving_range_node(node: Node) -> bool:
	if node == null:
		return false
	if "is_driving_range" in node and bool(node.get("is_driving_range")):
		return true
	if node.has_meta("is_driving_range") and bool(node.get_meta("is_driving_range")):
		return true
	var n_name := node.name.to_lower()
	var f_path := str(node.scene_file_path).to_lower() if "scene_file_path" in node else ""
	if n_name == "range" or f_path.ends_with("range/range.tscn") or f_path.ends_with("range.tscn") or f_path.ends_with("range.scn"):
		if not node.has_node("CoursePlay"):
			return true

	# Check children or active scene tree if node is /root or Window
	if node is Window or n_name == "root":
		var tree := node.get_tree() if node.is_inside_tree() else null
		if tree != null and tree.current_scene != null and tree.current_scene != node:
			if is_driving_range_node(tree.current_scene):
				return true
		var range_child := node.find_child("Range", true, false)
		if range_child != null and is_driving_range_node(range_child):
			return true

	var ml = Engine.get_main_loop()
	if ml is SceneTree:
		var gs = ml.root.get_node_or_null("GlobalSettings")
		if gs != null and gs.has_method("is_driving_range_scene") and gs.is_driving_range_scene():
			return true

	return false

## Applies chosen graphics quality ("Low", "Medium", or "High") dynamically to any loaded 3D scene.
## - Low: Fast stylized stippled turf, cartoon foliage, orthogonal low shadows.
## - Medium: Balanced full PBR terrain splatting, standard foliage, and 4-split cascaded shadows (the previous High).
## - High: Photorealistic terrain splatting (macro color variegation, micro blade detail, organic bunker lips, anisotropic mowing stripes), 3D translucent swaying trees, high-resolution soft shadows, and atmospheric lighting.
static func apply_graphics_quality(scene_root: Node, quality: String) -> void:
	if scene_root == null:
		return
	
	if quality != "Low" and quality != "Medium" and quality != "High":
		quality = "High"

	if is_mobile() and (quality == "High" or quality == "Ultra"):
		quality = "Medium"

	var is_low = quality == "Low"
	var is_med = quality == "Medium"
	var is_high = quality == "High"

	_apply_surrounding_features_visibility(scene_root, quality)
	_apply_cart_paths_visibility(scene_root, quality)

	# Convert any unbatched course Tree_*, Bush_*, and Rock_* nodes into MultiMesh chunks
	if ResourceLoader.exists("res://HighFidelity/Foliage/procedural_tree_generator.gd"):
		var ptg = load("res://HighFidelity/Foliage/procedural_tree_generator.gd")
		if ptg != null:
			ptg.convert_scene_foliage_to_multimesh(scene_root, false)

	var stack: Array[Node] = [scene_root]

	var stipple_shader: Shader = null
	var water_low_shader: Shader = null

	if is_low:
		if ResourceLoader.exists("res://Courses/Environments/shaders/terrain_stipple.gdshader"):
			stipple_shader = load("res://Courses/Environments/shaders/terrain_stipple.gdshader") as Shader
		if ResourceLoader.exists("res://Courses/Environments/shaders/water_low.gdshader"):
			water_low_shader = load("res://Courses/Environments/shaders/water_low.gdshader") as Shader

	while not stack.is_empty():
		var n = stack.pop_back()
		if n is MeshInstance3D:
			var n_lower = n.name.to_lower()

			# 1. Terrain Mesh (e.g. UnifiedTerrain on golf courses)
			var is_terrain = n.name == "UnifiedTerrain" or n_lower.contains("terrain")
			if not is_terrain:
				if n.material_override is ShaderMaterial and (n.material_override as ShaderMaterial).shader != null:
					var s_path = (n.material_override as ShaderMaterial).shader.resource_path
					if s_path.contains("terrain_splat") or s_path.contains("terrain_stipple"):
						is_terrain = true
				if not is_terrain and n.mesh != null and n.mesh.get_surface_count() > 0:
					var sm = n.mesh.surface_get_material(0)
					if sm is ShaderMaterial and sm.shader != null:
						var s_path = sm.shader.resource_path
						if s_path.contains("terrain_splat") or s_path.contains("terrain_stipple"):
							is_terrain = true

			if is_terrain:
				# Cache original parameters into metadata so they are never lost across repeated toggles
				if not n.has_meta("orig_splat_map"):
					var orig_splat = null
					var orig_ao = null
					var orig_sun = null
					var base_m = n.get_surface_override_material(0)
					if base_m == null and n.mesh != null and n.mesh.get_surface_count() > 0:
						base_m = n.mesh.surface_get_material(0)
					if base_m == null and n.material_override is ShaderMaterial:
						base_m = n.material_override
					if base_m is ShaderMaterial:
						orig_splat = base_m.get_shader_parameter("splat_map")
						orig_ao = base_m.get_shader_parameter("terrain_ao_map")
						orig_sun = base_m.get_shader_parameter("sun_direction")
					if orig_splat != null:
						n.set_meta("orig_splat_map", orig_splat)
					if orig_ao != null:
						n.set_meta("orig_ao_map", orig_ao)
					if orig_sun != null:
						n.set_meta("orig_sun_direction", orig_sun)

				var base_m: Material = null
				if n.mesh != null and n.mesh.get_surface_count() > 0:
					base_m = n.mesh.surface_get_material(0)
				if base_m == null:
					base_m = n.get_surface_override_material(0)
				if base_m == null and n.material_override is ShaderMaterial:
					base_m = n.material_override

				if is_low and stipple_shader != null:
					var splat_map = n.get_meta("orig_splat_map") if n.has_meta("orig_splat_map") else null
					var ao_map = n.get_meta("orig_ao_map") if n.has_meta("orig_ao_map") else null
					var sun_dir = n.get_meta("orig_sun_direction") if n.has_meta("orig_sun_direction") else null

					if splat_map == null and base_m is ShaderMaterial:
						splat_map = (base_m as ShaderMaterial).get_shader_parameter("splat_map")
						ao_map = (base_m as ShaderMaterial).get_shader_parameter("terrain_ao_map")
						sun_dir = (base_m as ShaderMaterial).get_shader_parameter("sun_direction")

					if splat_map != null:
						var stipple_mat = ShaderMaterial.new()
						stipple_mat.shader = stipple_shader
						stipple_mat.set_shader_parameter("splat_map", splat_map)
						if ao_map != null:
							stipple_mat.set_shader_parameter("terrain_ao_map", ao_map)
						if sun_dir != null:
							stipple_mat.set_shader_parameter("sun_direction", sun_dir)
						if n.has_meta("active_hole_pos"):
							stipple_mat.set_shader_parameter("active_hole_pos", n.get_meta("active_hole_pos"))
						if n.has_meta("active_hole_radius"):
							stipple_mat.set_shader_parameter("active_hole_radius", n.get_meta("active_hole_radius"))
						n.material_override = stipple_mat
					_set_terrain_has_deep_rough_map(n, false)
				elif is_med:
					n.material_override = null
					# Thick rough texture only exists and renders in High graphic setting
					_set_terrain_has_deep_rough_map(n, false)
				else:
					var realistic_terrain = _create_realistic_terrain_material(base_m as ShaderMaterial, n)
					if realistic_terrain != null:
						n.material_override = realistic_terrain
					else:
						n.material_override = null
					var deep_map: Texture2D = null
					if ResourceLoader.exists("res://HighFidelity/Terrain/course_detail_enhancer.gd"):
						var cde = load("res://HighFidelity/Terrain/course_detail_enhancer.gd")
						if cde != null and cde.has_method("ensure_deep_rough_map"):
							deep_map = cde.ensure_deep_rough_map(scene_root, n)
					_set_terrain_has_deep_rough_map(n, true, deep_map)

			# 2. Driving Range Ground Mesh
			elif n.name == "DynamicGround" or (n_lower == "ground" and not is_terrain):
				if is_low:
					var low_turf := StandardMaterial3D.new()
					low_turf.albedo_color = Color(0.24, 0.54, 0.20)
					low_turf.roughness = 0.95
					low_turf.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
					n.material_override = low_turf
				elif is_med or is_mobile():
					var base_m = n.mesh.surface_get_material(0) if (n.mesh != null and n.mesh.get_surface_count() > 0) else null
					if base_m is ShaderMaterial:
						n.material_override = null
					else:
						n.material_override = _create_high_quality_range_turf()
				else:
					n.material_override = _create_realistic_range_turf()

			# 3. Water Meshes
			elif n_lower.contains("water"):
				if is_low and water_low_shader != null:
					var w_mat = ShaderMaterial.new()
					w_mat.shader = water_low_shader
					n.material_override = w_mat
				else:
					n.material_override = null

			# 4. Individual Foliage / Tree Meshes (e.g. Driving Range trees)
			var is_foliage = false
			var parent_name = n.get_parent().name.to_lower() if n.get_parent() != null else ""
			var is_bush = n_lower.contains("bush") or parent_name.contains("bush") or n_lower.contains("shrub") or n_lower.contains("hedge")
			if n_lower.contains("tree") or parent_name.contains("tree") or is_bush or n_lower.contains("plant"):
				is_foliage = true
			elif n.mesh != null and n.mesh.get_surface_count() > 0:
				for s in range(n.mesh.get_surface_count()):
					var sm = n.mesh.surface_get_material(s)
					if sm != null and sm.resource_path.contains("shapespark-low-poly-exterior-plants"):
						is_foliage = true
						break

			if is_foliage and n.mesh != null:
				if is_bush:
					if is_low:
						n.visible = false
					elif is_med:
						n.visible = (n.get_index() % 2 == 0)
					else:
						n.visible = true
				else:
					var tier := 0
					if n.has_meta("foliage_tier"):
						tier = int(n.get_meta("foliage_tier"))
					else:
						tier = n.get_index() % 3
						n.set_meta("foliage_tier", tier)
					if is_low:
						n.visible = (tier == 0)
					elif is_med:
						n.visible = (tier <= 1)
					else:
						n.visible = true

				var p_node: Node = n.get_parent()
				if p_node is CollisionObject3D:
					for p_col in p_node.get_children():
						if p_col is CollisionShape3D:
							p_col.disabled = not n.visible
						elif p_col is Area3D:
							for area_col in p_col.get_children():
								if area_col is CollisionShape3D:
									area_col.disabled = not n.visible

				if n.material_override != null:
					n.material_override = null
				n.visibility_range_end = (140.0 if is_bush else 200.0) if is_low else ((200.0 if is_bush else 340.0) if is_med else (280.0 if is_bush else 550.0))
				n.visibility_range_end_margin = 20.0
				n.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				if is_bush:
					n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if not n.has_meta("orig_surface_mats"):
					var orig_mats: Array = []
					for s in range(n.mesh.get_surface_count()):
						var over_m = n.get_surface_override_material(s)
						orig_mats.append(over_m if over_m != null else n.mesh.surface_get_material(s))
					n.set_meta("orig_surface_mats", orig_mats)
				var cached_n_mats: Array = n.get_meta("orig_surface_mats")
				for s in range(n.mesh.get_surface_count()):
					var orig_m: Material = cached_n_mats[s] if s < cached_n_mats.size() else n.mesh.surface_get_material(s)
					var s_name = ""
					if n.mesh is ArrayMesh:
						s_name = (n.mesh as ArrayMesh).surface_get_name(s)
					if is_low:
						var low_m = _get_low_tree_material(orig_m, s_name, s)
						if low_m != null:
							n.set_surface_override_material(s, low_m)
					elif is_med:
						n.set_surface_override_material(s, orig_m)
					else:
						var high_m = _get_realistic_tree_material(orig_m, s_name, s)
						if high_m != null:
							n.set_surface_override_material(s, high_m)
						else:
							n.set_surface_override_material(s, orig_m)

		# 5. Spatial MultiMesh Foliage Chunks (TreeChunk_*, BushChunk_*, RockChunk_*, ShorelineReedsMultiMesh)
		elif n is MultiMeshInstance3D:
			var mmi := n as MultiMeshInstance3D
			var m_name := mmi.name.to_lower()
			if m_name.begins_with("shorelinereeds"):
				mmi.visible = is_water_grass_enabled_for_quality(scene_root, quality)
				if mmi.visible and mmi.multimesh != null and mmi.multimesh.mesh is ArrayMesh:
					if not mmi.has_meta("reeds_version") or int(mmi.get_meta("reeds_version")) < 3:
						if ResourceLoader.exists("res://HighFidelity/Foliage/procedural_tree_generator.gd"):
							var ptg = load("res://HighFidelity/Foliage/procedural_tree_generator.gd")
							if ptg != null and ptg.has_method("create_shoreline_reed_cluster_mesh"):
								mmi.multimesh.mesh = ptg.create_shoreline_reed_cluster_mesh()
								mmi.set_meta("reeds_version", 3)
			var is_tree_chunk := m_name.begins_with("treechunk")
			var is_bush_chunk := m_name.begins_with("bushchunk")
			var is_rock_chunk := m_name.begins_with("rockchunk")
			if (is_tree_chunk or is_bush_chunk or is_rock_chunk) and mmi.multimesh != null and mmi.multimesh.mesh != null:
				if is_tree_chunk:
					if ResourceLoader.exists("res://HighFidelity/Foliage/procedural_tree_generator.gd"):
						var ptg = load("res://HighFidelity/Foliage/procedural_tree_generator.gd")
						if ptg != null and ptg.has_method("upgrade_tree_chunk_mesh_in_place"):
							ptg.upgrade_tree_chunk_mesh_in_place(mmi, mmi.get_index())
						if ptg != null and ptg.has_method("ensure_chunk_tiers"):
							ptg.ensure_chunk_tiers(scene_root, mmi)

					var low_cnt: int = mmi.get_meta("tier_low_count") if mmi.has_meta("tier_low_count") else maxi(1, int(mmi.multimesh.instance_count * 0.35))
					var med_cnt: int = mmi.get_meta("tier_med_count") if mmi.has_meta("tier_med_count") else maxi(low_cnt, int(mmi.multimesh.instance_count * 0.70))

					if is_low:
						mmi.multimesh.visible_instance_count = mini(low_cnt, mmi.multimesh.instance_count)
					elif is_med:
						mmi.multimesh.visible_instance_count = mini(med_cnt, mmi.multimesh.instance_count)
					else:
						mmi.multimesh.visible_instance_count = -1

					mmi.visibility_range_end = 190.0 if is_low else (330.0 if is_med else 560.0)
					mmi.visibility_range_end_margin = 30.0
					mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				elif is_bush_chunk:
					var show_bushes := is_bushes_enabled_for_quality(scene_root, quality)
					if not show_bushes:
						mmi.visible = false
						if mmi.multimesh != null and mmi.multimesh.instance_count > 0:
							mmi.multimesh.visible_instance_count = 0
					elif is_low:
						mmi.visible = true
						var low_bush_cnt: int = mmi.get_meta("tier_low_count") if mmi.has_meta("tier_low_count") else maxi(1, int(mmi.multimesh.instance_count * 0.25))
						mmi.multimesh.visible_instance_count = mini(low_bush_cnt, mmi.multimesh.instance_count)
						mmi.visibility_range_end = 150.0
						mmi.visibility_range_end_margin = 15.0
						mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					elif is_med:
						mmi.visible = true
						var med_bush_cnt: int = mmi.get_meta("tier_med_count") if mmi.has_meta("tier_med_count") else maxi(1, int(mmi.multimesh.instance_count * 0.5))
						mmi.multimesh.visible_instance_count = mini(med_bush_cnt, mmi.multimesh.instance_count)
						mmi.visibility_range_end = 190.0
						mmi.visibility_range_end_margin = 20.0
						mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					else:
						mmi.visible = true
						mmi.multimesh.visible_instance_count = -1
						mmi.visibility_range_end = 270.0
						mmi.visibility_range_end_margin = 20.0
						mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				else:
					mmi.visibility_range_end = 130.0 if is_low else (200.0 if is_med else 290.0)
					mmi.visibility_range_end_margin = 20.0
					mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

				if is_tree_chunk or is_bush_chunk:
					var mesh := mmi.multimesh.mesh
					if not mmi.has_meta("orig_surface_mats"):
						var orig_mats: Array = []
						for s in range(mesh.get_surface_count()):
							orig_mats.append(mesh.surface_get_material(s))
						mmi.set_meta("orig_surface_mats", orig_mats)
					var cached_mats: Array = mmi.get_meta("orig_surface_mats")
					for s in range(mesh.get_surface_count()):
						var orig_m: Material = cached_mats[s] if s < cached_mats.size() else mesh.surface_get_material(s)
						var s_name := ""
						if mesh is ArrayMesh:
							s_name = (mesh as ArrayMesh).surface_get_name(s)
						if is_low:
							var low_m = _get_low_tree_material(orig_m, s_name, s)
							if low_m != null:
								mesh.surface_set_material(s, low_m)
						elif is_med:
							mesh.surface_set_material(s, orig_m)
						else:
							var high_m = _get_realistic_tree_material(orig_m, s_name, s)
							if high_m != null:
								mesh.surface_set_material(s, high_m)
							else:
								mesh.surface_set_material(s, orig_m)

		elif n is DirectionalLight3D:
			if is_low:
				n.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
				n.directional_shadow_max_distance = 180.0
				n.directional_shadow_blend_splits = false
				n.directional_shadow_split_1 = 0.15
				n.shadow_bias = 0.04
				n.shadow_normal_bias = 2.0
				RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			elif is_med:
				n.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if is_mobile() else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
				n.directional_shadow_max_distance = 240.0 if is_mobile() else 420.0
				n.directional_shadow_blend_splits = true
				n.directional_shadow_split_1 = 0.045
				n.directional_shadow_split_2 = 0.14
				n.directional_shadow_split_3 = 0.38
				n.shadow_bias = 0.03
				n.shadow_normal_bias = 2.0
				RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
			else:
				n.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
				n.directional_shadow_max_distance = 550.0
				n.directional_shadow_blend_splits = true
				n.directional_shadow_split_1 = 0.025
				n.directional_shadow_split_2 = 0.10
				n.directional_shadow_split_3 = 0.32
				n.shadow_bias = 0.018
				n.shadow_normal_bias = 1.6
				RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)

		elif n is WorldEnvironment and n.environment != null:
			if n.environment.sky != null:
				n.environment.sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL if is_high else Sky.PROCESS_MODE_REALTIME
				n.environment.sky.radiance_size = Sky.RADIANCE_SIZE_256
			if is_low:
				n.environment.ssao_enabled = false
				n.environment.ssr_enabled = false
				n.environment.glow_enabled = false
				n.environment.fog_enabled = false
			elif is_med:
				n.environment.ssao_enabled = not is_mobile()
				n.environment.ssao_radius = 1.8
				n.environment.ssao_intensity = 1.0
				n.environment.ssr_enabled = false
				n.environment.glow_enabled = true
				n.environment.fog_enabled = false
			else:
				n.environment.ssao_enabled = true
				n.environment.ssao_radius = 1.35
				n.environment.ssao_intensity = 1.15
				n.environment.ssao_power = 1.45
				n.environment.ssao_detail = 0.55
				n.environment.ssao_horizon = 0.06
				n.environment.glow_enabled = true
				n.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
				n.environment.ambient_light_sky_contribution = 0.52
				n.environment.ambient_light_energy = 0.46
				n.environment.ambient_light_color = Color(0.68, 0.80, 0.94)
				n.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
				n.environment.tonemap_white = 6.0
				n.environment.tonemap_exposure = 1.02

		elif n.name == "ConsolidatedFoliageCollision" or n.name == "ConsolidatedCanopyArea":
			_apply_tier_collision_shapes(n, is_low, is_med)

		for child in n.get_children():
			stack.append(child)

	if is_high and not is_mobile():
		if ResourceLoader.exists("res://HighFidelity/Core/high_fidelity_builder.gd"):
			var builder_script = load("res://HighFidelity/Core/high_fidelity_builder.gd")
			if builder_script != null:
				builder_script.apply_high_fidelity(scene_root)
	else:
		if ResourceLoader.exists("res://HighFidelity/Core/high_fidelity_builder.gd"):
			var builder_script = load("res://HighFidelity/Core/high_fidelity_builder.gd")
			if builder_script != null:
				builder_script.remove_high_fidelity(scene_root)
		# Ensure thick rough bushes and meshes are hidden on Low and Medium
		_hide_thick_rough_nodes(scene_root)

	_apply_deep_rough_blades(scene_root, is_med)

	# Update teebox markers vibrancy if present in scene
	if ResourceLoader.exists("res://Courses/Range/teebox_marker_builder.gd"):
		var tmb = load("res://Courses/Range/teebox_marker_builder.gd")
		if tmb != null and tmb.has_method("apply_graphics_quality_to_markers"):
			tmb.apply_graphics_quality_to_markers(scene_root, is_low)

	# Update 3D golf flags realism and wind waving if present in scene
	if ResourceLoader.exists("res://Courses/Range/flag_builder.gd"):
		var fb = load("res://Courses/Range/flag_builder.gd")
		if fb != null and fb.has_method("apply_graphics_quality_to_flags"):
			fb.apply_graphics_quality_to_flags(scene_root, quality)

	# Ensure grass/reeds around water hazards are hidden on Low quality
	_apply_shoreline_reeds_visibility(scene_root, not is_low)



static var _low_tree_materials: Dictionary = {}

static func _apply_tier_collision_shapes(container: Node, is_low: bool, is_med: bool) -> void:
	for col in container.get_children():
		if col is CollisionShape3D and col.has_meta("foliage_tier"):
			var tier: int = col.get_meta("foliage_tier")
			if is_low:
				col.disabled = (tier > 0)
			elif is_med:
				col.disabled = (tier > 1)
			else:
				col.disabled = false

static func _apply_shoreline_reeds_visibility(scene_root: Node, visible: bool) -> void:
	if scene_root == null:
		return
	var root_reeds := scene_root.get_node_or_null("ShorelineReedsMultiMesh") as Node3D
	if root_reeds != null:
		root_reeds.visible = visible
	for child in scene_root.find_children("*ShorelineReeds*", "Node3D", true, false):
		(child as Node3D).visible = visible

## Thick rough real 3D grass blades only exist in High graphic setting (via HighFidelityBuilder).
## On Medium, Low, or mobile, thick rough blade nodes must not exist.
static func _apply_deep_rough_blades(scene_root: Node, _is_med: bool) -> void:
	const NODE_NAME := "DeepRoughGrassMedium"
	var existing := scene_root.get_node_or_null(NODE_NAME)
	if existing != null:
		scene_root.remove_child(existing)
		existing.queue_free()


static func _hide_thick_rough_nodes(scene_root: Node) -> void:
	if scene_root == null:
		return
	var thick_bushes := scene_root.get_node_or_null("ThickRoughBushes") as Node3D
	if thick_bushes != null:
		thick_bushes.visible = false
	for child in scene_root.get_children():
		if child is Node3D and (child.name.begins_with("ThickRough_") or child.name.begins_with("ThickRoughBush")):
			child.visible = false


static func _set_terrain_has_deep_rough_map(n: MeshInstance3D, enabled: bool, deep_tex: Texture2D = null) -> void:
	if n == null:
		return
	var mats: Array[ShaderMaterial] = []
	if n.material_override is ShaderMaterial:
		mats.append(n.material_override as ShaderMaterial)
	if n.mesh != null:
		for s in range(n.mesh.get_surface_count()):
			var som = n.get_surface_override_material(s)
			if som is ShaderMaterial and not mats.has(som):
				mats.append(som as ShaderMaterial)
			var sm = n.mesh.surface_get_material(s)
			if sm is ShaderMaterial and not mats.has(sm):
				mats.append(sm as ShaderMaterial)
	for m in mats:
		if deep_tex != null:
			m.set_shader_parameter("deep_rough_map", deep_tex)
		elif n.has_meta("deep_rough_map"):
			m.set_shader_parameter("deep_rough_map", n.get_meta("deep_rough_map"))
		m.set_shader_parameter("has_deep_rough_map", enabled)

static var _low_tree_textures: Dictionary = {}
static var _foliage_low_shader: Shader = null
static var _trunk_low_shader: Shader = null

static func _get_low_tree_material(orig_mat: Material, surface_name: String, surface_idx: int = 0) -> Material:
	var s_lower = surface_name.to_lower()
	var orig_path = ""
	var albedo_tex: Texture2D = null

	if orig_mat != null:
		orig_path = orig_mat.resource_path.to_lower()
		if orig_mat is BaseMaterial3D:
			albedo_tex = (orig_mat as BaseMaterial3D).albedo_texture
		elif orig_mat is ShaderMaterial:
			var tex = (orig_mat as ShaderMaterial).get_shader_parameter("texture_albedo")
			if tex is Texture2D:
				albedo_tex = tex

	var tex_path = albedo_tex.resource_path.to_lower() if albedo_tex != null else ""
	var is_trunk = (surface_idx == 0) or s_lower.contains("trunk") or s_lower.contains("bark") or tex_path.contains("bark")
	if tex_path.contains("branch") or tex_path.contains("leaf") or tex_path.contains("clover") or tex_path.contains("shrub") or tex_path.contains("hedge"):
		is_trunk = false

	var cache_key = "%d_%s_%s_%s" % [surface_idx, s_lower, orig_path, tex_path]
	if _low_tree_materials.has(cache_key):
		return _low_tree_materials[cache_key]

	if _foliage_low_shader == null and ResourceLoader.exists("res://Courses/Environments/shaders/foliage_low.gdshader"):
		_foliage_low_shader = load("res://Courses/Environments/shaders/foliage_low.gdshader") as Shader
	if _trunk_low_shader == null and ResourceLoader.exists("res://Courses/Environments/shaders/trunk_low.gdshader"):
		_trunk_low_shader = load("res://Courses/Environments/shaders/trunk_low.gdshader") as Shader

	var combined_sig = (s_lower + " " + orig_path + " " + tex_path).to_lower()

	if is_trunk:
		# Trunk: clean stylized wood tone with 2-step cel shading, zero photographic noise
		var wood_color := Color(0.36, 0.24, 0.15)
		var wood_shadow := Color(0.23, 0.14, 0.09)

		if combined_sig.contains("birch"):
			wood_color = Color(0.86, 0.84, 0.80)
			wood_shadow = Color(0.66, 0.63, 0.58)
		elif combined_sig.contains("pine"):
			wood_color = Color(0.44, 0.27, 0.16)
			wood_shadow = Color(0.28, 0.16, 0.10)
		elif combined_sig.contains("willow"):
			wood_color = Color(0.40, 0.32, 0.22)
			wood_shadow = Color(0.26, 0.20, 0.13)

		if _trunk_low_shader != null:
			var sm = ShaderMaterial.new()
			sm.shader = _trunk_low_shader
			sm.set_shader_parameter("wood_color", wood_color)
			sm.set_shader_parameter("wood_shadow_color", wood_shadow)
			_low_tree_materials[cache_key] = sm
			return sm
		else:
			var low_m = StandardMaterial3D.new()
			low_m.albedo_color = wood_color
			low_m.roughness = 1.0
			low_m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			low_m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			_low_tree_materials[cache_key] = low_m
			return low_m
	else:
		# Foliage / Leaves: stylized cartoon leaf cutout with 3-tone cel posterization
		var foliage_color := Color(0.28, 0.62, 0.24) # Rich parkland summer green

		if combined_sig.contains("autumn-gold") or combined_sig.contains("gold"):
			foliage_color = Color(0.95, 0.72, 0.16)
		elif combined_sig.contains("autumn-red") or combined_sig.contains("red"):
			foliage_color = Color(0.85, 0.22, 0.14)
		elif combined_sig.contains("blossom"):
			foliage_color = Color(0.98, 0.78, 0.85)
		elif combined_sig.contains("pine") or combined_sig.contains("branch-2"):
			foliage_color = Color(0.18, 0.38, 0.20)
		elif combined_sig.contains("birch") or combined_sig.contains("branch-1"):
			foliage_color = Color(0.40, 0.72, 0.25)
		elif combined_sig.contains("willow"):
			foliage_color = Color(0.48, 0.68, 0.22)

		if albedo_tex == null:
			if ResourceLoader.exists("res://addons/shapespark-low-poly-exterior-plants/textures/branch-01.png"):
				albedo_tex = load("res://addons/shapespark-low-poly-exterior-plants/textures/branch-01.png") as Texture2D

		if _foliage_low_shader != null:
			var sm = ShaderMaterial.new()
			sm.shader = _foliage_low_shader
			sm.set_shader_parameter("albedo_color", foliage_color)
			if albedo_tex != null:
				sm.set_shader_parameter("texture_albedo", albedo_tex)
			_low_tree_materials[cache_key] = sm
			return sm
		else:
			var low_m = StandardMaterial3D.new()
			if albedo_tex != null:
				low_m.albedo_texture = albedo_tex
			low_m.albedo_color = foliage_color
			low_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			low_m.alpha_scissor_threshold = 0.45
			low_m.cull_mode = BaseMaterial3D.CULL_DISABLED
			low_m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			low_m.roughness = 1.0
			low_m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			_low_tree_materials[cache_key] = low_m
			return low_m


static func _create_high_quality_range_turf() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	if ResourceLoader.exists("res://Courses/Environments/shaders/driving_range_turf.gdshader"):
		mat.shader = load("res://Courses/Environments/shaders/driving_range_turf.gdshader") as Shader
		if ResourceLoader.exists("res://Courses/Environments/grass-fairway/albedo.png"):
			mat.set_shader_parameter("tex_fairway", load("res://Courses/Environments/grass-fairway/albedo.png"))
		if ResourceLoader.exists("res://Courses/Environments/grass-fairway/normal.png"):
			mat.set_shader_parameter("normal_fairway", load("res://Courses/Environments/grass-fairway/normal.png"))
		if ResourceLoader.exists("res://Courses/Environments/grass-fairway/ao.png"):
			mat.set_shader_parameter("ao_fairway", load("res://Courses/Environments/grass-fairway/ao.png"))
		if ResourceLoader.exists("res://Courses/Environments/grass-fairway/roughness.png"):
			mat.set_shader_parameter("roughness_fairway", load("res://Courses/Environments/grass-fairway/roughness.png"))

		if ResourceLoader.exists("res://Courses/Environments/grass-rough/albedo.png"):
			mat.set_shader_parameter("tex_rough", load("res://Courses/Environments/grass-rough/albedo.png"))
		if ResourceLoader.exists("res://Courses/Environments/grass-rough/normal.png"):
			mat.set_shader_parameter("normal_rough", load("res://Courses/Environments/grass-rough/normal.png"))
		if ResourceLoader.exists("res://Courses/Environments/grass-rough/ao.png"):
			mat.set_shader_parameter("ao_rough", load("res://Courses/Environments/grass-rough/ao.png"))
		if ResourceLoader.exists("res://Courses/Environments/grass-rough/roughness.png"):
			mat.set_shader_parameter("roughness_rough", load("res://Courses/Environments/grass-rough/roughness.png"))

		mat.set_shader_parameter("corridor_half_width", 26.0)
		mat.set_shader_parameter("blend_margin", 0.85)
		mat.set_shader_parameter("tee_start_x", -12.0)
		mat.set_shader_parameter("tee_blend_x", 4.0)
		mat.set_shader_parameter("max_range_dist", 320.04)
		mat.set_shader_parameter("uv_scale_fairway", 0.12)
		mat.set_shader_parameter("uv_scale_rough", 0.08)
		mat.set_shader_parameter("normal_depth", 0.65)
		mat.set_shader_parameter("stripe_strength", 0.70)
	return mat


static func _create_realistic_range_turf() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	if ResourceLoader.exists("res://Courses/Environments/shaders/driving_range_turf_realistic.gdshader"):
		mat.shader = load("res://Courses/Environments/shaders/driving_range_turf_realistic.gdshader") as Shader
		if ResourceLoader.exists("res://Courses/Environments/grass-fairway/albedo.png"):
			mat.set_shader_parameter("tex_fairway", load("res://Courses/Environments/grass-fairway/albedo.png"))
		if ResourceLoader.exists("res://Courses/Environments/grass-fairway/normal.png"):
			mat.set_shader_parameter("normal_fairway", load("res://Courses/Environments/grass-fairway/normal.png"))
		if ResourceLoader.exists("res://Courses/Environments/grass-fairway/ao.png"):
			mat.set_shader_parameter("ao_fairway", load("res://Courses/Environments/grass-fairway/ao.png"))
		if ResourceLoader.exists("res://Courses/Environments/grass-fairway/roughness.png"):
			mat.set_shader_parameter("roughness_fairway", load("res://Courses/Environments/grass-fairway/roughness.png"))

		if ResourceLoader.exists("res://Courses/Environments/grass-rough/albedo.png"):
			mat.set_shader_parameter("tex_rough", load("res://Courses/Environments/grass-rough/albedo.png"))
		if ResourceLoader.exists("res://Courses/Environments/grass-rough/normal.png"):
			mat.set_shader_parameter("normal_rough", load("res://Courses/Environments/grass-rough/normal.png"))
		if ResourceLoader.exists("res://Courses/Environments/grass-rough/ao.png"):
			mat.set_shader_parameter("ao_rough", load("res://Courses/Environments/grass-rough/ao.png"))
		if ResourceLoader.exists("res://Courses/Environments/grass-rough/roughness.png"):
			mat.set_shader_parameter("roughness_rough", load("res://Courses/Environments/grass-rough/roughness.png"))

		mat.set_shader_parameter("corridor_half_width", 26.0)
		mat.set_shader_parameter("blend_margin", 0.85)
		mat.set_shader_parameter("tee_start_x", -12.0)
		mat.set_shader_parameter("tee_blend_x", 4.0)
		mat.set_shader_parameter("max_range_dist", 320.04)
		mat.set_shader_parameter("uv_scale_fairway", 0.12)
		mat.set_shader_parameter("uv_scale_rough", 0.08)
		mat.set_shader_parameter("normal_depth", 0.95)
		mat.set_shader_parameter("stripe_strength", 0.70)
	elif ResourceLoader.exists("res://Courses/Environments/shaders/driving_range_turf.gdshader"):
		return _create_high_quality_range_turf()
	return mat


static var _realistic_terrain_shader: Shader = null

static func _create_realistic_terrain_material(base_m: ShaderMaterial, n: MeshInstance3D = null) -> ShaderMaterial:
	if _realistic_terrain_shader == null:
		if ResourceLoader.exists("res://Courses/Environments/shaders/terrain_splat_realistic.gdshader"):
			_realistic_terrain_shader = load("res://Courses/Environments/shaders/terrain_splat_realistic.gdshader") as Shader
	
	if _realistic_terrain_shader == null:
		return null
		
	var mat = ShaderMaterial.new()
	mat.shader = _realistic_terrain_shader
	
	# Transfer parameters from base_m
	if base_m != null:
		var params = [
			"splat_map", "terrain_ao_map", "deep_rough_map", "has_deep_rough_map",
			"tex_rough", "tex_green", "tex_fairway", "tex_bunker", "tex_mulch",
			"normal_rough", "normal_green", "normal_fairway", "normal_bunker", "normal_mulch",
			"ao_rough", "ao_green", "ao_fairway", "ao_bunker", "ao_mulch",
			"roughness_tex_rough", "roughness_tex_green", "roughness_tex_fairway", "roughness_tex_bunker", "roughness_tex_mulch",
			"height_rough", "height_green", "height_fairway", "height_bunker", "height_mulch",
			"uv_scale_rough", "uv_scale_green", "uv_scale_fairway", "uv_scale_bunker", "uv_scale_mulch",
			"roughness_rough", "roughness_green", "roughness_fairway", "roughness_bunker", "roughness_mulch",
			"normal_depth", "sun_direction", "slope_shading_strength", "height_blend_contrast",
			"active_hole_pos", "active_hole_radius"
		]
		for p in params:
			var val = base_m.get_shader_parameter(p)
			if val != null:
				mat.set_shader_parameter(p, val)
	
	# Fallback for splat_map from metadata if base_m didn't have it
	if n != null and mat.get_shader_parameter("splat_map") == null:
		if n.has_meta("orig_splat_map"):
			mat.set_shader_parameter("splat_map", n.get_meta("orig_splat_map"))
		if n.has_meta("orig_ao_map"):
			mat.set_shader_parameter("terrain_ao_map", n.get_meta("orig_ao_map"))
		if n.has_meta("orig_sun_direction"):
			mat.set_shader_parameter("sun_direction", n.get_meta("orig_sun_direction"))
	if n != null and n.has_meta("deep_rough_map"):
		mat.set_shader_parameter("deep_rough_map", n.get_meta("deep_rough_map"))
		mat.set_shader_parameter("has_deep_rough_map", true)
	if n != null and n.has_meta("active_hole_pos"):
		mat.set_shader_parameter("active_hole_pos", n.get_meta("active_hole_pos"))
	if n != null and n.has_meta("active_hole_radius"):
		mat.set_shader_parameter("active_hole_radius", n.get_meta("active_hole_radius"))
			
	# Fallback texture defaults if not set
	if mat.get_shader_parameter("tex_rough") == null and ResourceLoader.exists("res://Courses/Environments/grass-rough/albedo.png"):
		mat.set_shader_parameter("tex_rough", load("res://Courses/Environments/grass-rough/albedo.png"))
	if mat.get_shader_parameter("tex_green") == null and ResourceLoader.exists("res://Courses/Environments/grass-green/albedo.png"):
		mat.set_shader_parameter("tex_green", load("res://Courses/Environments/grass-green/albedo.png"))
	if mat.get_shader_parameter("tex_fairway") == null and ResourceLoader.exists("res://Courses/Environments/grass-fairway/albedo.png"):
		mat.set_shader_parameter("tex_fairway", load("res://Courses/Environments/grass-fairway/albedo.png"))
	if mat.get_shader_parameter("tex_bunker") == null and ResourceLoader.exists("res://Courses/Environments/sand-bunker/albedo.png"):
		mat.set_shader_parameter("tex_bunker", load("res://Courses/Environments/sand-bunker/albedo.png"))
	if mat.get_shader_parameter("tex_mulch") == null and ResourceLoader.exists("res://Courses/Environments/tree-bark/albedo.png"):
		mat.set_shader_parameter("tex_mulch", load("res://Courses/Environments/tree-bark/albedo.png"))

	if mat.get_shader_parameter("normal_rough") == null and ResourceLoader.exists("res://Courses/Environments/grass-rough/normal.png"):
		mat.set_shader_parameter("normal_rough", load("res://Courses/Environments/grass-rough/normal.png"))
	if mat.get_shader_parameter("normal_green") == null and ResourceLoader.exists("res://Courses/Environments/grass-green/normal.png"):
		mat.set_shader_parameter("normal_green", load("res://Courses/Environments/grass-green/normal.png"))
	if mat.get_shader_parameter("normal_fairway") == null and ResourceLoader.exists("res://Courses/Environments/grass-fairway/normal.png"):
		mat.set_shader_parameter("normal_fairway", load("res://Courses/Environments/grass-fairway/normal.png"))
	if mat.get_shader_parameter("normal_bunker") == null and ResourceLoader.exists("res://Courses/Environments/sand-bunker/normal.png"):
		mat.set_shader_parameter("normal_bunker", load("res://Courses/Environments/sand-bunker/normal.png"))

	if mat.get_shader_parameter("height_rough") == null and ResourceLoader.exists("res://Courses/Environments/grass-rough/height.png"):
		mat.set_shader_parameter("height_rough", load("res://Courses/Environments/grass-rough/height.png"))
	if mat.get_shader_parameter("height_green") == null and ResourceLoader.exists("res://Courses/Environments/grass-green/height.png"):
		mat.set_shader_parameter("height_green", load("res://Courses/Environments/grass-green/height.png"))
	if mat.get_shader_parameter("height_fairway") == null and ResourceLoader.exists("res://Courses/Environments/grass-fairway/height.png"):
		mat.set_shader_parameter("height_fairway", load("res://Courses/Environments/grass-fairway/height.png"))
	if mat.get_shader_parameter("height_bunker") == null and ResourceLoader.exists("res://Courses/Environments/sand-bunker/height.png"):
		mat.set_shader_parameter("height_bunker", load("res://Courses/Environments/sand-bunker/height.png"))

	# High-graphics 2048px procedural grass textures override the original low-res images
	var high_dir := "res://Courses/Environments/high/"
	for kind in ["rough", "green", "fairway"]:
		var a_path: String = high_dir + "grass_%s_albedo.png" % kind
		var n_path: String = high_dir + "grass_%s_normal.png" % kind
		var r_path: String = high_dir + "grass_%s_roughness.png" % kind
		if ResourceLoader.exists(a_path):
			mat.set_shader_parameter("tex_" + kind, load(a_path))
		if ResourceLoader.exists(n_path):
			mat.set_shader_parameter("normal_" + kind, load(n_path))
		if ResourceLoader.exists(r_path):
			mat.set_shader_parameter("roughness_tex_" + kind, load(r_path))

	return mat


static var _realistic_tree_materials: Dictionary = {}
static var _realistic_bark_materials: Dictionary = {}

static func _get_realistic_tree_material(orig_mat: Material, surface_name: String, surface_idx: int = 0) -> Material:
	var s_lower = surface_name.to_lower()
	var is_trunk = (surface_idx == 0) or s_lower.contains("trunk") or s_lower.contains("bark")
	if orig_mat != null and (orig_mat is BaseMaterial3D or orig_mat is StandardMaterial3D):
		var base_m = orig_mat as BaseMaterial3D
		if base_m.albedo_texture != null:
			var path_lower = base_m.albedo_texture.resource_path.to_lower()
			if path_lower.contains("bark"):
				is_trunk = true
			elif path_lower.contains("branch") or path_lower.contains("leaf") or path_lower.contains("clover") or path_lower.contains("shrub") or path_lower.contains("hedge"):
				is_trunk = false
				
	if is_trunk:
		return _get_realistic_bark_material(orig_mat)
	else:
		return _get_realistic_foliage_material(orig_mat, surface_name, surface_idx)


static func _get_realistic_bark_material(orig_mat: Material) -> Material:
	var cache_key = "bark"
	if orig_mat != null and not orig_mat.resource_path.is_empty():
		cache_key += "_" + orig_mat.resource_path
	if _realistic_bark_materials.has(cache_key):
		return _realistic_bark_materials[cache_key]

	var mat = StandardMaterial3D.new()
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mat.metallic_specular = 0.04
	mat.roughness = 0.94
	
	# Albedo texture
	var is_species_bark: bool = false
	if orig_mat is BaseMaterial3D and (orig_mat as BaseMaterial3D).albedo_texture != null:
		mat.albedo_texture = (orig_mat as BaseMaterial3D).albedo_texture
		var tex_path_l: String = str(mat.albedo_texture.resource_path).to_lower()
		if tex_path_l.contains("birch") or tex_path_l.contains("pine") or tex_path_l.contains("willow"):
			is_species_bark = true
	elif ResourceLoader.exists("res://addons/shapespark-low-poly-exterior-plants/textures/bark.jpg"):
		mat.albedo_texture = load("res://addons/shapespark-low-poly-exterior-plants/textures/bark.jpg") as Texture2D
	
	# High-detail Bark Normal & Roughness maps
	if ResourceLoader.exists("res://Courses/Environments/tree-bark/normal.png"):
		mat.normal_enabled = true
		mat.normal_texture = load("res://Courses/Environments/tree-bark/normal.png") as Texture2D
		mat.normal_scale = 1.15
	if ResourceLoader.exists("res://Courses/Environments/tree-bark/roughness.png"):
		mat.roughness_texture = load("res://Courses/Environments/tree-bark/roughness.png") as Texture2D
	
	mat.uv1_scale = Vector3(1.0, 1.0, 1.0)

	# Keep the authentic photographic bark albedo (bark.jpg / willow-bark.jpg / pine-bark.jpg / birch-bark.jpg)
	# and pair it with high-resolution normal & roughness maps for crisp 3D bark micro-relief.
	var bark_dir := "res://Courses/Environments/high/"
	if ResourceLoader.exists(bark_dir + "bark_normal.png"):
		mat.normal_enabled = true
		mat.normal_texture = load(bark_dir + "bark_normal.png") as Texture2D
		mat.normal_scale = 0.70 if is_species_bark else 0.90
	if ResourceLoader.exists(bark_dir + "bark_roughness.png"):
		mat.roughness_texture = load(bark_dir + "bark_roughness.png") as Texture2D
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_realistic_bark_materials[cache_key] = mat
	return mat


static var _wind_listener_connected: bool = false

static func get_foliage_wind_params(speed_mph: float) -> Dictionary:
	var strength := 0.035
	var speed := 0.75
	var flutter := 0.003
	var flutter_spd := 3.0

	if speed_mph <= 6.0:
		# ~6 MPH or less: Gentle subtle breeze (exact current sway user liked)
		var t = clampf(speed_mph / 6.0, 0.2, 1.0)
		strength = lerpf(0.022, 0.035, t)
		speed = lerpf(0.55, 0.75, t)
		flutter = lerpf(0.002, 0.003, t)
		flutter_spd = 2.8
	elif speed_mph <= 12.0:
		# 6-12 MPH: Sway a bit more than <=6
		var t = clampf((speed_mph - 6.0) / 6.0, 0.0, 1.0)
		strength = lerpf(0.040, 0.068, t)
		speed = lerpf(0.85, 1.18, t)
		flutter = lerpf(0.0035, 0.0065, t)
		flutter_spd = 3.6
	else:
		# 13+ MPH: Sway more than 6-12
		var t = clampf((speed_mph - 12.0) / 13.0, 0.0, 1.0)
		strength = lerpf(0.075, 0.115, t)
		speed = lerpf(1.25, 1.65, t)
		flutter = lerpf(0.007, 0.012, t)
		flutter_spd = 4.8

	return {
		"strength": strength,
		"speed": speed,
		"flutter": flutter,
		"flutter_spd": flutter_spd
	}

static func update_wind_on_foliage(speed_mph: float, direction_rad: float = 0.0) -> void:
	var params = get_foliage_wind_params(speed_mph)
	var dir_2d = Vector2(cos(direction_rad), sin(direction_rad))
	if dir_2d.length_squared() < 0.01:
		dir_2d = Vector2(0.85, 0.52).normalized()
	for mat in _realistic_tree_materials.values():
		if mat is ShaderMaterial:
			mat.set_shader_parameter("wind_strength", params["strength"])
			mat.set_shader_parameter("wind_speed", params["speed"])
			mat.set_shader_parameter("leaf_flutter_strength", params["flutter"])
			mat.set_shader_parameter("leaf_flutter_speed", params["flutter_spd"])
			mat.set_shader_parameter("wind_direction", dir_2d)

static func _ensure_wind_listener() -> void:
	if _wind_listener_connected:
		return
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree and (main_loop as SceneTree).root != null:
		var gs = (main_loop as SceneTree).root.get_node_or_null("GlobalSettings")
		if gs != null and gs.has_signal("wind_changed"):
			gs.wind_changed.connect(func(speed_mph, dir_rad):
				update_wind_on_foliage(speed_mph, dir_rad)
			)
			_wind_listener_connected = true


static func _get_realistic_foliage_material(orig_mat: Material, surface_name: String, surface_idx: int) -> Material:
	var cache_key = "%d_%s" % [surface_idx, surface_name]
	if orig_mat != null and not orig_mat.resource_path.is_empty():
		cache_key += "_" + orig_mat.resource_path
	if _realistic_tree_materials.has(cache_key):
		return _realistic_tree_materials[cache_key]

	var mat = ShaderMaterial.new()
	if ResourceLoader.exists("res://Courses/Environments/shaders/foliage_realistic.gdshader"):
		mat.shader = load("res://Courses/Environments/shaders/foliage_realistic.gdshader") as Shader

	# Extract albedo texture from original material
	var albedo_tex: Texture2D = null
	if orig_mat is BaseMaterial3D and (orig_mat as BaseMaterial3D).albedo_texture != null:
		albedo_tex = (orig_mat as BaseMaterial3D).albedo_texture
	elif orig_mat is ShaderMaterial:
		albedo_tex = (orig_mat as ShaderMaterial).get_shader_parameter("texture_albedo")
	
	if albedo_tex != null:
		mat.set_shader_parameter("texture_albedo", albedo_tex)
	
	# Normal & roughness maps for realistic foliage depth
	if ResourceLoader.exists("res://Courses/Environments/tree-foliage/normal.png"):
		mat.set_shader_parameter("texture_normal", load("res://Courses/Environments/tree-foliage/normal.png"))
	if ResourceLoader.exists("res://Courses/Environments/tree-foliage/roughness.png"):
		mat.set_shader_parameter("texture_roughness", load("res://Courses/Environments/tree-foliage/roughness.png"))

	# Keep native branch textures crisp without blurry 85% detail overlay
	if ResourceLoader.exists("res://Courses/Environments/high/leaf_albedo.png"):
		mat.set_shader_parameter("leaf_detail_albedo", load("res://Courses/Environments/high/leaf_albedo.png"))
		mat.set_shader_parameter("use_leaf_detail", false)
		if ResourceLoader.exists("res://Courses/Environments/high/leaf_normal.png"):
			mat.set_shader_parameter("leaf_detail_normal", load("res://Courses/Environments/high/leaf_normal.png"))
			mat.set_shader_parameter("use_leaf_detail_normal", false)

	mat.set_shader_parameter("backlight_color", Color(0.20, 0.32, 0.08))
	mat.set_shader_parameter("backlight_strength", 0.30)
	mat.set_shader_parameter("canopy_depth_ao", 0.45)
	mat.set_shader_parameter("spherical_normal_blend", 0.82)
	mat.set_shader_parameter("alpha_scissor_threshold", 0.42)
	mat.set_shader_parameter("roughness", 0.85)
	mat.set_shader_parameter("specular", 0.08)

	_ensure_wind_listener()

	var cur_mph := 6.0
	var cur_rad := 0.0
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree and (main_loop as SceneTree).root != null:
		var gs = (main_loop as SceneTree).root.get_node_or_null("GlobalSettings")
		if gs != null:
			if "current_wind_speed_mph" in gs:
				cur_mph = float(gs.current_wind_speed_mph)
			if "current_wind_direction_rad" in gs:
				cur_rad = float(gs.current_wind_direction_rad)

	var wind_params = get_foliage_wind_params(cur_mph)
	var dir_2d = Vector2(cos(cur_rad), sin(cur_rad))
	if dir_2d.length_squared() < 0.01:
		dir_2d = Vector2(0.85, 0.52).normalized()

	mat.set_shader_parameter("wind_speed", wind_params["speed"])
	mat.set_shader_parameter("wind_strength", wind_params["strength"])
	mat.set_shader_parameter("leaf_flutter_speed", wind_params["flutter_spd"])
	mat.set_shader_parameter("leaf_flutter_strength", 0.0)
	mat.set_shader_parameter("wind_direction", dir_2d)

	_realistic_tree_materials[cache_key] = mat
	return mat


static var _is_reloading_graphics: bool = false

## Displays an animated loading spinner wheel overlay and applies graphics quality cleanly across the scene tree.
## Guarantees visual feedback: menu closes first, popup shows that graphics are changing, then reload is triggered.
static func apply_graphics_quality_with_spinner(tree: SceneTree, quality: String) -> void:
	if tree == null or tree.root == null:
		return
	if _is_reloading_graphics:
		return
	_is_reloading_graphics = true
	
	# Step 1: Wait 1 frame so Godot draws the closed settings menu off-screen first
	await tree.process_frame
	
	# Step 2: Show popup indicator that graphics are changing
	var overlay = CanvasLayer.new()
	overlay.layer = 150
	overlay.name = "GraphicsReloadOverlay"
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.04, 0.06, 0.75)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	
	var panel = PanelContainer.new()
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.08, 0.12, 0.16, 0.95)
	p_style.border_color = Color(0.28, 0.75, 0.50, 0.8)
	p_style.border_width_left = 2
	p_style.border_width_right = 2
	p_style.border_width_top = 2
	p_style.border_width_bottom = 2
	p_style.corner_radius_top_left = 16
	p_style.corner_radius_top_right = 16
	p_style.corner_radius_bottom_left = 16
	p_style.corner_radius_bottom_right = 16
	p_style.content_margin_left = 36
	p_style.content_margin_right = 36
	p_style.content_margin_top = 26
	p_style.content_margin_bottom = 26
	panel.add_theme_stylebox_override("panel", p_style)
	center.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	
	var spinner_script = load("res://UI/LoadingSpinner.gd")
	if spinner_script != null:
		var spinner = spinner_script.new()
		spinner.custom_minimum_size = Vector2(72, 72)
		spinner.radius = 26.0
		spinner.thickness = 5.0
		spinner.color = Color(0.28, 0.82, 0.52, 1.0)
		spinner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(spinner)
	
	var title_lbl = Label.new()
	title_lbl.text = "Applying Graphics Settings..."
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)
	
	var desc_lbl = Label.new()
	var mode_name = "Low (Fast Stylized)"
	if quality == "Medium":
		mode_name = "Medium (Balanced PBR)"
	elif quality == "High":
		mode_name = "High (Photorealistic)"
	desc_lbl.text = "Switching to %s mode" % mode_name
	desc_lbl.add_theme_font_size_override("font_size", 16)
	desc_lbl.add_theme_color_override("font_color", Color(0.72, 0.86, 0.80))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc_lbl)
	
	tree.root.add_child(overlay)
	
	# Yield 2 frames so Godot renders the spinner overlay on screen before shader recompilation
	await tree.process_frame
	await tree.process_frame
	
	# Step 3: Trigger the graphics reload while the user sees the popup indicator
	apply_graphics_quality(tree.root, quality)
	
	# Hold for a moment so the reload feels intentional and visually finished
	await tree.create_timer(0.35).timeout
	
	if is_instance_valid(overlay):
		var tween = tree.create_tween()
		if tween != null:
			tween.tween_property(bg, "modulate:a", 0.0, 0.2)
			tween.parallel().tween_property(panel, "modulate:a", 0.0, 0.2)
			await tween.finished
		if is_instance_valid(overlay):
			overlay.queue_free()
	
	_is_reloading_graphics = false


## Retrieves the saved or embedded course graphic settings from scene metadata or course.json.
static func get_course_graphic_settings(scene_root: Node) -> Dictionary:
	if scene_root == null:
		return {}
	if scene_root.has_meta("graphic_settings"):
		var m = scene_root.get_meta("graphic_settings")
		if m is Dictionary:
			return m
	if scene_root.owner != null and scene_root.owner.has_meta("graphic_settings"):
		var m = scene_root.owner.get_meta("graphic_settings")
		if m is Dictionary:
			return m
	var p = scene_root.get_parent()
	while p != null:
		if p.has_meta("graphic_settings"):
			var m = p.get_meta("graphic_settings")
			if m is Dictionary:
				return m
		p = p.get_parent()
	for ch in scene_root.get_children():
		if ch != null and ch.has_meta("graphic_settings"):
			var m = ch.get_meta("graphic_settings")
			if m is Dictionary:
				return m
	var scene_path := scene_root.scene_file_path
	if scene_path == "" and scene_root.owner != null:
		scene_path = scene_root.owner.scene_file_path
	if scene_path != "":
		var json_path := scene_path.get_base_dir().path_join("course.json")
		if FileAccess.file_exists(json_path):
			var fa := FileAccess.open(json_path, FileAccess.READ)
			if fa != null:
				var parsed = JSON.parse_string(fa.get_as_text())
				if parsed is Dictionary and parsed.has("graphic_settings") and parsed["graphic_settings"] is Dictionary:
					return parsed["graphic_settings"]
	return {}


## Checks whether surrounding features (highways and buildings) are enabled for the specified quality.
static func is_surrounding_features_enabled_for_quality(scene_root: Node, quality: String) -> bool:
	var q_key := quality.to_lower()
	var g_settings := get_course_graphic_settings(scene_root)
	if g_settings.has(q_key) and g_settings[q_key] is Dictionary:
		var q_dict: Dictionary = g_settings[q_key]
		if q_dict.has("generate_roads_buildings"):
			return bool(q_dict["generate_roads_buildings"])
		if q_dict.has("roads_buildings"):
			return bool(q_dict["roads_buildings"])
	var cfg_path := "user://course_search_settings.cfg"
	if FileAccess.file_exists(cfg_path):
		var cfg := ConfigFile.new()
		if cfg.load(cfg_path) == OK:
			var sec := "course_generation_" + q_key
			if cfg.has_section(sec) and cfg.has_section_key(sec, "generate_roads_buildings"):
				return bool(cfg.get_value(sec, "generate_roads_buildings"))
			elif q_key == "medium" and cfg.has_section("course_generation") and cfg.has_section_key("course_generation", "generate_roads_buildings"):
				return bool(cfg.get_value("course_generation", "generate_roads_buildings"))
	# Defaults: Low is false; Medium and High are true (matching default download presets)
	return q_key != "low"


## Checks whether cart paths are enabled for the specified quality.
static func is_cart_paths_enabled_for_quality(scene_root: Node, quality: String) -> bool:
	var q_key := quality.to_lower()
	var g_settings := get_course_graphic_settings(scene_root)
	if g_settings.has(q_key) and g_settings[q_key] is Dictionary:
		var q_dict: Dictionary = g_settings[q_key]
		if q_dict.has("generate_cart_paths"):
			return bool(q_dict["generate_cart_paths"])
	var cfg_path := "user://course_search_settings.cfg"
	if FileAccess.file_exists(cfg_path):
		var cfg := ConfigFile.new()
		if cfg.load(cfg_path) == OK:
			var sec := "course_generation_" + q_key
			if cfg.has_section(sec) and cfg.has_section_key(sec, "generate_cart_paths"):
				return bool(cfg.get_value(sec, "generate_cart_paths"))
	return q_key != "low"


## Checks whether shoreline reeds / water grass are enabled for the specified quality.
static func is_water_grass_enabled_for_quality(scene_root: Node, quality: String) -> bool:
	var q_key := quality.to_lower()
	var g_settings := get_course_graphic_settings(scene_root)
	if g_settings.has(q_key) and g_settings[q_key] is Dictionary:
		var q_dict: Dictionary = g_settings[q_key]
		if q_dict.has("generate_water_long_grass"):
			return bool(q_dict["generate_water_long_grass"])
	var cfg_path := "user://course_search_settings.cfg"
	if FileAccess.file_exists(cfg_path):
		var cfg := ConfigFile.new()
		if cfg.load(cfg_path) == OK:
			var sec := "course_generation_" + q_key
			if cfg.has_section(sec) and cfg.has_section_key(sec, "generate_water_long_grass"):
				return bool(cfg.get_value(sec, "generate_water_long_grass"))
	return q_key != "low"


## Checks whether bushes are enabled for the specified quality.
static func is_bushes_enabled_for_quality(scene_root: Node, quality: String) -> bool:
	var q_key := quality.to_lower()
	var g_settings := get_course_graphic_settings(scene_root)
	if g_settings.has(q_key) and g_settings[q_key] is Dictionary:
		var q_dict: Dictionary = g_settings[q_key]
		if q_dict.has("generate_bushes"):
			return bool(q_dict["generate_bushes"])
	var cfg_path := "user://course_search_settings.cfg"
	if FileAccess.file_exists(cfg_path):
		var cfg := ConfigFile.new()
		if cfg.load(cfg_path) == OK:
			var sec := "course_generation_" + q_key
			if cfg.has_section(sec) and cfg.has_section_key(sec, "generate_bushes"):
				return bool(cfg.get_value(sec, "generate_bushes"))
	return q_key != "low"


## Shows or hides cart paths (and their collision) based on quality setting.
static func _apply_cart_paths_visibility(scene_root: Node, quality_arg: Variant = "High") -> void:
	if scene_root == null:
		return
	var quality_str := "High"
	if typeof(quality_arg) == TYPE_STRING:
		quality_str = str(quality_arg)
	elif typeof(quality_arg) == TYPE_BOOL:
		quality_str = "High" if bool(quality_arg) else "Low"

	var show_cart_paths := is_cart_paths_enabled_for_quality(scene_root, quality_str)
	var nodes_to_toggle: Array[Node] = []
	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var curr: Node = stack.pop_back()
		if curr != null and curr != scene_root:
			var cname: String = String(curr.name).to_lower()
			if curr.is_in_group("cart_paths") or bool(curr.get_meta("is_cart_path", false)) or cname.begins_with("cartpath_"):
				if not nodes_to_toggle.has(curr):
					nodes_to_toggle.append(curr)
		for ch in curr.get_children():
			stack.append(ch)

	for node in nodes_to_toggle:
		if node is Node3D:
			(node as Node3D).visible = show_cart_paths
		if node is CollisionShape3D:
			var cs := node as CollisionShape3D
			cs.disabled = not show_cart_paths
			cs.set_deferred("disabled", not show_cart_paths)
		for sub in node.find_children("*", "Node", true, false):
			if sub is Node3D:
				(sub as Node3D).visible = show_cart_paths
			if sub is CollisionShape3D:
				var sub_cs := sub as CollisionShape3D
				sub_cs.disabled = not show_cart_paths
				sub_cs.set_deferred("disabled", not show_cart_paths)


## Shows or hides generated roads, clubhouses, houses and other buildings (and their collision).
## They appear on any graphics quality setting where enabled in download settings.
static func _apply_surrounding_features_visibility(scene_root: Node, quality_arg: Variant = "High") -> void:
	if scene_root == null:
		return
	var quality_str := "High"
	if typeof(quality_arg) == TYPE_STRING:
		quality_str = str(quality_arg)
	elif typeof(quality_arg) == TYPE_BOOL:
		quality_str = "High" if bool(quality_arg) else "Low"

	var show_features := is_surrounding_features_enabled_for_quality(scene_root, quality_str)

	var nodes_to_toggle: Array[Node] = []

	var tree := scene_root.get_tree() if scene_root.is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree != null:
		for g_name in ["roads", "buildings", "clubhouses", "houses", "business_buildings"]:
			for node in tree.get_nodes_in_group(g_name):
				if node != null and (node == scene_root or scene_root.is_ancestor_of(node) or node.is_ancestor_of(scene_root) or scene_root == tree.root):
					if not nodes_to_toggle.has(node):
						nodes_to_toggle.append(node)

	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var curr: Node = stack.pop_back()
		if curr != null and curr != scene_root:
			var cname: String = String(curr.name).to_lower()
			var is_target: bool = false
			if curr.is_in_group("roads") or curr.is_in_group("buildings") or curr.is_in_group("clubhouses") or curr.is_in_group("houses") or curr.is_in_group("business_buildings"):
				is_target = true
			elif bool(curr.get_meta("is_road", false)) or bool(curr.get_meta("is_building", false)):
				is_target = true
			elif cname.begins_with("road_") or cname.begins_with("house_") or cname.begins_with("clubhouse_") or cname.begins_with("building_") or cname.begins_with("business_") or cname.begins_with("commercial_"):
				is_target = true

			if is_target:
				if not nodes_to_toggle.has(curr):
					nodes_to_toggle.append(curr)

		for ch in curr.get_children():
			stack.append(ch)

	for node in nodes_to_toggle:
		if node is Node3D:
			(node as Node3D).visible = show_features
		if node is CollisionShape3D:
			var cs := node as CollisionShape3D
			cs.disabled = not show_features
			cs.set_deferred("disabled", not show_features)
		for sub in node.find_children("*", "Node", true, false):
			if sub is Node3D:
				(sub as Node3D).visible = show_features
			if sub is CollisionShape3D:
				var sub_cs := sub as CollisionShape3D
				sub_cs.disabled = not show_features
				sub_cs.set_deferred("disabled", not show_features)
