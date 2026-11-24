class_name CustomCourseBuilder
extends RefCounted

const CourseGraphicsUpgraderScript = preload("res://Utils/CourseGraphicsUpgrader.gd")

const HOLE_PERIMETER_M: float = 46.0 # 50 yards in meters
const HOLE_SEPARATION_GAP_M: float = 100.0 # Gap between adjacent hole perimeters to prevent overlap

## Builds and saves a custom course by extracting authentic 3D features (fairways, greens, bunkers, water, trees) from selected holes.
## Returns a Dictionary with "title", "config_path", and "scene_path".
static func build_custom_course(
	title: String,
	selected_holes: Array[Dictionary],
	progress_cb: Callable = Callable()
) -> Dictionary:
	if title.strip_edges().is_empty() or selected_holes.is_empty():
		push_error("[CustomCourseBuilder] Invalid title or empty hole list.")
		return {}

	var safe_name = title.strip_edges().to_lower()
	for c in [" ", "/", "\\", ":", "*", "?", "\"", "<", ">", "|", "'"]:
		safe_name = safe_name.replace(c, "_")
	
	var dir_name = "custom_" + safe_name + "_" + str(Time.get_ticks_msec())
	var course_dir = "user://courses/" + dir_name
	
	var err = DirAccess.make_dir_recursive_absolute(course_dir)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_error("[CustomCourseBuilder] Could not create directory: " + course_dir)
		return {}

	var config_path = course_dir.path_join("course.json")
	var scene_path = course_dir.path_join("course.tscn")

	var new_hole_info: Dictionary = {}
	var current_x_offset: float = 0.0

	# 1. Build Hole Info metadata & copy aerial preview images
	for i in range(selected_holes.size()):
		var entry = selected_holes[i]
		var source_config_path: String = entry.get("source_config_path", "")
		var source_hole_key: String = entry.get("hole_key", "Hole 1")
		var source_hole_data: Dictionary = entry.get("hole_data", {})
		var source_dir = source_config_path.get_base_dir()

		var hole_number_str = "Hole " + str(i + 1)
		var par_val = source_hole_data.get("Par", 4)

		# Extract source pin & main tee position to calculate hole length & direction
		var orig_pin = source_hole_data.get("Hole Location", [300.0, 0.0])
		var pin_vec = Vector2(float(orig_pin[0]), float(orig_pin[1]))

		var orig_tees = source_hole_data.get("Tee Boxes", {})
		var default_tee_key = "Blue" if "Blue" in orig_tees else (orig_tees.keys()[0] if not orig_tees.is_empty() else "")
		var tee_vec = Vector2.ZERO
		if not default_tee_key.is_empty():
			var t_arr = orig_tees[default_tee_key]
			tee_vec = Vector2(float(t_arr[0]), float(t_arr[1]))

		var hole_length = max(pin_vec.distance_to(tee_vec), 60.0)
		var hole_dir = (pin_vec - tee_vec).normalized()
		if hole_dir.is_zero_approx():
			hole_dir = Vector2(1, 0)

		# Straight-line positions along X
		var new_pin = Vector2(current_x_offset + hole_length, 0.0)

		var new_tee_boxes: Dictionary = {}
		if typeof(orig_tees) == TYPE_DICTIONARY and not orig_tees.is_empty():
			for tee_color in orig_tees.keys():
				var t_arr = orig_tees[tee_color]
				var t_vec = Vector2(float(t_arr[0]), float(t_arr[1]))
				var rel = t_vec - tee_vec
				var dist_along = rel.dot(hole_dir)
				var dist_perp = rel.cross(hole_dir)
				new_tee_boxes[tee_color] = [current_x_offset + dist_along, dist_perp]
		else:
			new_tee_boxes["Blue"] = [current_x_offset, 0.0]
			new_tee_boxes["White"] = [current_x_offset + 15.0, 0.0]
			new_tee_boxes["Red"] = [current_x_offset + 30.0, 0.0]

		new_hole_info[hole_number_str] = {
			"Par": par_val,
			"Hole Location": [new_pin.x, new_pin.y],
			"Tee Boxes": new_tee_boxes,
			"Source": entry.get("source_title", "Course") + " - " + source_hole_key
		}

		# Preserve original dogleg HolePath if present
		var orig_path = source_hole_data.get("HolePath", source_hole_data.get("Hole Path", []))
		if typeof(orig_path) == TYPE_ARRAY and orig_path.size() >= 2:
			var new_path: Array = []
			for pt in orig_path:
				var p_vec = Vector2(float(pt[0]), float(pt[1]))
				var rel2d = p_vec - tee_vec
				var rel3d = Vector3(rel2d.x, 0.0, rel2d.y)
				var rot3d = rel3d.rotated(Vector3.UP, atan2(hole_dir.y, hole_dir.x))
				new_path.append([current_x_offset + rot3d.x, rot3d.z])
			new_hole_info[hole_number_str]["HolePath"] = new_path

		# Copy aerial preview image if present
		var source_hole_idx = int(str(source_hole_key).replace("Hole", "").strip_edges())
		var src_img_path = source_dir.path_join("aerial_hole_%d.png" % source_hole_idx)
		if FileAccess.file_exists(src_img_path):
			var dest_img_path = course_dir.path_join("aerial_hole_%d.png" % (i + 1))
			DirAccess.copy_absolute(src_img_path, dest_img_path)

		# Next hole starts past the 50-yard perimeter plus separation gap to prevent any mesh overlap
		current_x_offset += hole_length + (HOLE_PERIMETER_M * 2.0) + HOLE_SEPARATION_GAP_M

	# 2. Serialize course.json
	var course_json_dict = {
		"graphics_version": CourseGraphicsUpgraderScript.CURRENT_COURSE_GRAPHICS_VERSION,
		"scene_path": "course.tscn",
		"Title": title.strip_edges(),
		"is_custom": true,
		"Course Info": {
			"Tee Colors": ["Black", "Blue", "White", "Red"],
			"Texture Indices": {
				"Green": [0],
				"Fairway": [1],
				"Rough": [2],
				"Sand": [3],
				"Water": [4],
				"Penalty": [5]
			}
		},
		"Hole Info": new_hole_info
	}

	var json_file = FileAccess.open(config_path, FileAccess.WRITE)
	if json_file != null:
		json_file.store_string(JSON.stringify(course_json_dict, "\t"))
		json_file.close()

	# 3. Create 3D course.tscn scene using Unified Terrain with SplatMap and authentic OSM features
	var build_success = _build_and_save_course_scene(scene_path, new_hole_info, selected_holes, safe_name, progress_cb)
	if not build_success:
		_delete_dir_recursive(course_dir)
		return {}

	return {
		"title": title.strip_edges(),
		"scene_path": scene_path,
		"config_path": config_path,
		"is_custom": true
	}


static func _build_and_save_course_scene(
	scene_path: String,
	new_hole_info: Dictionary,
	selected_holes: Array[Dictionary],
	safe_name: String,
	progress_cb: Callable = Callable()
) -> bool:
	var root = Node3D.new()
	root.name = safe_name
	root.set_script(load("res://Courses/Range/range.gd"))

	# TCPServer (for external launch monitors like GSPro/PiTrac)
	var tcp_script = load("res://addons/launch_monitors/common/tcp_server/TcpServer.cs")
	if tcp_script != null:
		var tcp_server = tcp_script.new()
		tcp_server.name = "TCPServer"
		root.add_child(tcp_server)
		tcp_server.owner = root

	# Player
	var player_scene = load("res://Player/player.tscn")
	if player_scene != null:
		var player_inst = player_scene.instantiate()
		player_inst.name = "Player"
		root.add_child(player_inst)
		player_inst.owner = root

	# RangeUI
	var ui_scene = load("res://UI/range_ui.tscn")
	if ui_scene != null:
		var ui_inst = ui_scene.instantiate()
		ui_inst.name = "RangeUI"
		root.add_child(ui_inst)
		ui_inst.owner = root

	# SessionRecorder
	var session_rec = Node.new()
	session_rec.name = "SessionRecorder"
	var sess_script = load("res://SessionRecorder/session_recorder.gd")
	if sess_script != null:
		session_rec.set_script(sess_script)
	root.add_child(session_rec)
	session_rec.owner = root

	# Sky / Environment
	var sky_env = WorldEnvironment.new()
	sky_env.name = "Sky3D"
	sky_env.set_script(load("res://addons/sky_3d/src/Sky3D.gd"))
	sky_env.set("enable_editor_time", false)
	sky_env.set("enable_game_time", false)
	root.add_child(sky_env)
	sky_env.owner = root

	var sun = DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-45, 45, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.2
	if MobilePerformance.is_mobile():
		sun.directional_shadow_max_distance = 200.0
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_blend_splits = true
		sun.directional_shadow_split_1 = 0.1
	else:
		sun.directional_shadow_max_distance = 600.0
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		sun.directional_shadow_blend_splits = true
		sun.directional_shadow_split_1 = 0.05
		sun.directional_shadow_split_2 = 0.15
		sun.directional_shadow_split_3 = 0.40
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 2.0
	sky_env.add_child(sun)
	sun.owner = root

	var moon = DirectionalLight3D.new()
	moon.name = "MoonLight"
	moon.light_color = Color(0.57, 0.77, 0.95)
	moon.light_energy = 0.0
	sky_env.add_child(moon)
	moon.owner = root

	var skydome = Node.new()
	skydome.name = "Skydome"
	var skydome_script = load("res://addons/sky_3d/src/Skydome.gd")
	if skydome_script != null:
		skydome.set_script(skydome_script)
		skydome.set("fog_visible", false)
		skydome.set("clouds_speed", 0.005)
		skydome.set("clouds_cumulus_speed", 0.003)
	sky_env.add_child(skydome)
	skydome.owner = root

	var time_of_day = Node.new()
	time_of_day.name = "TimeOfDay"
	var tod_script = load("res://addons/sky_3d/src/TimeOfDay.gd")
	if tod_script != null:
		time_of_day.set_script(tod_script)
		time_of_day.set("dome_path", NodePath("../Skydome"))
		time_of_day.set("update_in_game", false)
		time_of_day.set("update_in_editor", false)
		time_of_day.set("update_interval", 1.0)
	sky_env.add_child(time_of_day)
	time_of_day.owner = root

	# PhantomCamera3D & Camera3D
	var pcam = Node3D.new()
	pcam.name = "PhantomCamera3D"
	var pcam_script = load("res://addons/phantom_camera/scripts/phantom_camera/phantom_camera_3d.gd")
	if pcam_script != null:
		pcam.set_script(pcam_script)
	root.add_child(pcam)
	pcam.owner = root

	var cam3d = Camera3D.new()
	cam3d.name = "Camera3D"
	cam3d.fov = 55.0
	cam3d.far = 400.0
	root.add_child(cam3d)
	cam3d.owner = root

	var pcam_host = Node.new()
	pcam_host.name = "PhantomCameraHost"
	var pcam_host_script = load("res://addons/phantom_camera/scripts/phantom_camera_host/phantom_camera_host.gd")
	if pcam_host_script != null:
		pcam_host.set_script(pcam_host_script)
	cam3d.add_child(pcam_host)
	pcam_host.owner = root

	# Aerial Camera
	var aerial_cam = Camera3D.new()
	aerial_cam.name = "AerialCamera"
	aerial_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	aerial_cam.size = 300.0
	aerial_cam.position = Vector3(0, 150, 0)
	aerial_cam.rotation_degrees = Vector3(-90, 0, 0)
	root.add_child(aerial_cam)
	aerial_cam.owner = root

	# Process each selected hole in order
	var hole_keys = new_hole_info.keys()
	var total_holes = selected_holes.size()
	for i in range(total_holes):
		if progress_cb.is_valid():
			progress_cb.call(i + 1, total_holes, "Piecing together hole %d of %d in 3D..." % [i + 1, total_holes])

		var h_key = hole_keys[i]
		var h_data = new_hole_info[h_key]

		var entry = selected_holes[i]
		var source_config_path: String = entry.get("source_config_path", "")
		var source_dir = source_config_path.get_base_dir()
		var source_scene_path = source_dir.path_join("course.tscn")
		if not FileAccess.file_exists(source_scene_path):
			source_scene_path = source_dir.path_join("course.scn")

		var source_hole_key: String = entry.get("hole_key", "Hole 1")
		var source_hole_data: Dictionary = entry.get("hole_data", {})

		# Load all hole data from source course config JSON to allow precise spatial isolation
		var all_source_holes: Dictionary = {}
		if FileAccess.file_exists(source_config_path):
			var src_cfg_file = FileAccess.open(source_config_path, FileAccess.READ)
			if src_cfg_file != null:
				var parsed = JSON.parse_string(src_cfg_file.get_as_text())
				if typeof(parsed) == TYPE_DICTIONARY:
					all_source_holes = parsed.get("Hole Info", {})

		var orig_pin = source_hole_data.get("Hole Location", [300.0, 0.0])
		var src_pin_vec = Vector3(float(orig_pin[0]), 0.0, float(orig_pin[1]))

		var orig_tees = source_hole_data.get("Tee Boxes", {})
		var default_tee_key = "Blue" if "Blue" in orig_tees else (orig_tees.keys()[0] if not orig_tees.is_empty() else "")
		var src_tee_vec = Vector3.ZERO
		if not default_tee_key.is_empty():
			var t_arr = orig_tees[default_tee_key]
			src_tee_vec = Vector3(float(t_arr[0]), 0.0, float(t_arr[1]))

		var src_dir = (src_pin_vec - src_tee_vec)
		src_dir.y = 0
		var src_angle = atan2(src_dir.z, src_dir.x) if not src_dir.is_zero_approx() else 0.0
		var angle_to_x = src_angle

		var target_pin_arr = h_data.get("Hole Location", [300.0, 0.0])
		var target_pin_pos = Vector3(float(target_pin_arr[0]), 0.0, float(target_pin_arr[1]))

		var tees_dict = h_data.get("Tee Boxes", {})
		var blue_arr = tees_dict.get("Blue", [0.0, 0.0])
		var target_tee_pos = Vector3(float(blue_arr[0]), 0.0, float(blue_arr[1]))

		var hole_node = Node3D.new()
		hole_node.name = str(h_key).replace(" ", "")
		root.add_child(hole_node)
		hole_node.owner = root

		# 1. EXTRACT REAL OSM FEATURES (greens, fairways, bunkers, water, tees, trees) & ELEVATION FROM SOURCE SCENE
		var extracted_features = {
			"green": [],    # Array of [Vector2, Vector2, Vector2]
			"fairway": [],
			"bunker": [],
			"tee": [],
			"water": []
		}
		var extracted_3d_faces = {
			"green": PackedVector3Array(),
			"fairway": PackedVector3Array(),
			"bunker": PackedVector3Array(),
			"tee": PackedVector3Array(),
			"water": PackedVector3Array()
		}
		var tree_positions: Array[Vector2] = []
		var tree_nodes: Array[Node3D] = []
		var height_grid: Dictionary = {}

		if ResourceLoader.exists(source_scene_path):
			var scn = load(source_scene_path) as PackedScene
			if scn != null:
				var src_inst = scn.instantiate()
				_extract_hole_geometry(
					src_inst, source_hole_key, source_hole_data, all_source_holes,
					src_tee_vec, angle_to_x, target_tee_pos,
					extracted_features, extracted_3d_faces, tree_positions, tree_nodes,
					height_grid
				)
				src_inst.free()

		# Procedural fallback for fairway/green if source hole had none
		if extracted_features["fairway"].is_empty():
			_generate_fallback_fairway_tris(target_tee_pos, target_pin_pos, h_data, extracted_features["fairway"], extracted_3d_faces["fairway"], height_grid)

		if extracted_features["green"].is_empty():
			_generate_fallback_green_tris(target_pin_pos, extracted_features["green"], extracted_3d_faces["green"], height_grid)

		# 2. CALCULATE FULL 50-YARD (46M) PERIMETER BOUNDS FOR HOLE TERRAIN
		var hole_min_x = min(target_tee_pos.x, target_pin_pos.x)
		var hole_max_x = max(target_tee_pos.x, target_pin_pos.x)
		var hole_min_z = min(target_tee_pos.z, target_pin_pos.z)
		var hole_max_z = max(target_tee_pos.z, target_pin_pos.z)

		for tc in tees_dict.keys():
			var t_arr = tees_dict[tc]
			hole_min_x = min(hole_min_x, float(t_arr[0]))
			hole_max_x = max(hole_max_x, float(t_arr[0]))
			hole_min_z = min(hole_min_z, float(t_arr[1]))
			hole_max_z = max(hole_max_z, float(t_arr[1]))

		var h_path = h_data.get("HolePath", [])
		if typeof(h_path) == TYPE_ARRAY:
			for pt in h_path:
				hole_min_x = min(hole_min_x, float(pt[0]))
				hole_max_x = max(hole_max_x, float(pt[0]))
				hole_min_z = min(hole_min_z, float(pt[1]))
				hole_max_z = max(hole_max_z, float(pt[1]))

		for tag in extracted_3d_faces.keys():
			var faces: PackedVector3Array = extracted_3d_faces[tag]
			for v in faces:
				hole_min_x = min(hole_min_x, v.x)
				hole_max_x = max(hole_max_x, v.x)
				hole_min_z = min(hole_min_z, v.z)
				hole_max_z = max(hole_max_z, v.z)

		var x_min = hole_min_x - HOLE_PERIMETER_M
		var x_max = hole_max_x + HOLE_PERIMETER_M
		var z_min = min(hole_min_z - HOLE_PERIMETER_M, -HOLE_PERIMETER_M)
		var z_max = max(hole_max_z + HOLE_PERIMETER_M, HOLE_PERIMETER_M)

		_build_hole_unified_terrain(
			hole_node, root, x_min, x_max, z_min, z_max,
			extracted_features, extracted_3d_faces, tree_positions,
			height_grid
		)

		# 3. BUILD PERIMETER BOUNDARY WALLS (Prevents balls escaping or falling between hole meshes)
		_build_hole_boundary_walls(hole_node, root, x_min, x_max, z_min, z_max)

		# 4. CREATE COLLISION BODIES FOR GREENS, FAIRWAYS, BUNKERS, TEES, WATER
		_build_surface_collision(hole_node, root, "GreenStatic", 4, false, false, extracted_3d_faces["green"])
		_build_surface_collision(hole_node, root, "FairwayStatic", 0, false, false, extracted_3d_faces["fairway"])
		_build_surface_collision(hole_node, root, "BunkerStatic", 2, true, false, extracted_3d_faces["bunker"])
		_build_surface_collision(hole_node, root, "TeeStatic", 0, false, false, extracted_3d_faces["tee"])
		_build_surface_collision(hole_node, root, "WaterStatic", 2, false, true, extracted_3d_faces["water"])

		# 4. WATER VISUAL MESHES
		if not extracted_3d_faces["water"].is_empty():
			_build_water_visual_mesh(hole_node, root, extracted_3d_faces["water"])

		# 5. SPAWN TRANSFORMED TREES (Firmly grounded on terrain elevation)
		for t_node in tree_nodes:
			var tree_y = _sample_height_from_grid(t_node.position.x, t_node.position.z, height_grid, 4.0, t_node.position.y)
			t_node.position.y = tree_y
			hole_node.add_child(t_node)
			_set_owner_recursive(t_node, root)

		# 6. TEE PADS & MARKERS (Placed on terrain elevation)
		for tee_color in tees_dict.keys():
			var t_arr = tees_dict[tee_color]
			var tee_base_y = _sample_height_from_grid(float(t_arr[0]), float(t_arr[1]), height_grid, 4.0, 0.0)
			var t_pos = Vector3(float(t_arr[0]), tee_base_y + 0.02, float(t_arr[1]))

			var tee_mesh = PlaneMesh.new()
			tee_mesh.size = Vector2(4.0, 4.0)

			var tee_inst = MeshInstance3D.new()
			tee_inst.name = "TeePad_" + tee_color
			tee_inst.mesh = tee_mesh
			var tee_mat = StandardMaterial3D.new()
			tee_mat.albedo_texture = load("res://Courses/Environments/grass-fairway/albedo.png")
			tee_mat.roughness = 0.4
			tee_mat.uv1_scale = Vector3(0.2, 0.2, 0.2)
			tee_inst.material_override = tee_mat
			tee_inst.position = t_pos
			hole_node.add_child(tee_inst)
			tee_inst.owner = root

			var tee_static = StaticBody3D.new()
			tee_static.name = "TeePadStatic_" + tee_color
			tee_static.set_meta("surface_type", 0)
			tee_static.position = t_pos

			var tee_col = CollisionShape3D.new()
			var tee_box = BoxShape3D.new()
			tee_box.size = Vector3(4.0, 0.1, 4.0)
			tee_col.shape = tee_box
			tee_static.add_child(tee_col)
			hole_node.add_child(tee_static)
			tee_static.owner = root
			tee_col.owner = root

		# 7. FLAG PIN & CUP (Placed on terrain elevation)
		var pin_y = _sample_height_from_grid(target_pin_pos.x, target_pin_pos.z, height_grid, 4.0, 0.0)
		var flag_node = Node3D.new()
		flag_node.name = "PinFlag"
		flag_node.position = Vector3(target_pin_pos.x, pin_y, target_pin_pos.z)
		hole_node.add_child(flag_node)
		flag_node.owner = root

		var pole = MeshInstance3D.new()
		pole.name = "Pole"
		var pole_mesh = CylinderMesh.new()
		pole_mesh.top_radius = 0.03
		pole_mesh.bottom_radius = 0.03
		pole_mesh.height = 2.4
		pole.mesh = pole_mesh
		pole.position = Vector3(0, 1.2, 0)
		flag_node.add_child(pole)
		pole.owner = root

		var flag = MeshInstance3D.new()
		flag.name = "Flag"
		var flag_mesh = PrismMesh.new()
		flag_mesh.size = Vector3(0.5, 0.4, 0.02)
		flag.mesh = flag_mesh
		flag.position = Vector3(0.25, 2.1, 0)
		flag.rotation_degrees = Vector3(0, 0, -90)
		var flag_mat = StandardMaterial3D.new()
		flag_mat.albedo_color = Color.RED
		flag_mat.material_override = flag_mat
		flag_node.add_child(flag)
		flag.owner = root

	# Convert foliage into spatial MultiMesh chunks and add recessed 3D bunkers/reeds/horizon/cart paths
	var tree_gen_script = load("res://HighFidelity/Foliage/procedural_tree_generator.gd")
	if tree_gen_script != null:
		tree_gen_script.convert_scene_foliage_to_multimesh(root, true)
	var detail_enhancer_script = load("res://HighFidelity/Terrain/course_detail_enhancer.gd")
	if detail_enhancer_script != null:
		detail_enhancer_script.enhance_course_scene(root, true)

	# Save PackedScene to disk
	if progress_cb.is_valid():
		progress_cb.call(total_holes, total_holes, "Finalizing and saving 3D course scene...")

	var packed = PackedScene.new()
	var pack_err = packed.pack(root)
	if pack_err != OK:
		push_error("[CustomCourseBuilder] Failed to pack custom course scene. Error: " + str(pack_err))
		root.free()
		return false

	var save_err = ResourceSaver.save(packed, scene_path)
	root.free()
	if save_err != OK:
		push_error("[CustomCourseBuilder] Failed to save custom course scene to: " + scene_path + ". Error: " + str(save_err))
		return false

	print("[CustomCourseBuilder] Successfully created custom 3D course scene at: " + scene_path)
	return true


static func _extract_hole_geometry(
	src_inst: Node,
	source_hole_key: String,
	source_hole_data: Dictionary,
	all_source_holes: Dictionary,
	src_tee_vec: Vector3,
	angle: float,
	target_tee_pos: Vector3,
	extracted_features: Dictionary,
	extracted_3d_faces: Dictionary,
	tree_positions: Array[Vector2],
	tree_nodes: Array[Node3D],
	height_grid: Dictionary
) -> void:
	# Extract source terrain mesh vertices to capture authentic USGS/procedural slopes
	var source_terrain_verts = PackedVector3Array()
	_extract_source_terrain_verts(src_inst, source_terrain_verts)

	# Find the base terrain elevation at the source tee so the hole is anchored at Y=0 at tee
	var src_tee_base_y = _find_closest_source_height(source_terrain_verts, Vector2(src_tee_vec.x, src_tee_vec.z))
	var src_tee_3d: Vector3 = Vector3(src_tee_vec.x, src_tee_base_y, src_tee_vec.z)

	# Build spatial height grid for the hole in custom coordinates
	if not source_terrain_verts.is_empty():
		for sv in source_terrain_verts:
			var dist = _get_distance_to_hole_info(sv, source_hole_data)
			if dist <= 90.0:
				var rel_v = sv - src_tee_3d
				var rot_v = rel_v.rotated(Vector3.UP, angle)
				var custom_v = target_tee_pos + rot_v

				var cell_size = 4.0
				var cx = int(floor(custom_v.x / cell_size))
				var cz = int(floor(custom_v.z / cell_size))
				var cell_key = Vector2i(cx, cz)
				if not height_grid.has(cell_key):
					height_grid[cell_key] = []
				height_grid[cell_key].append(custom_v)

	# Also extract trees from MultiMeshFoliageContainer metadata if the source course was upgraded
	var mm_container := src_inst.get_node_or_null("MultiMeshFoliageContainer")
	if mm_container != null and mm_container.has_meta("tree_records"):
		var records: Array = mm_container.get_meta("tree_records", [])
		var mesh_paths: Array = mm_container.get_meta("tree_mesh_paths", [])
		var loaded_scenes: Dictionary = {}
		for rec_idx in range(records.size()):
			var rec = records[rec_idx]
			if not (rec is Array) or rec.size() < 8:
				continue
			var pos := Vector3(float(rec[0]), float(rec[1]), float(rec[2]))
			var dist := _get_distance_to_hole_info(pos, source_hole_data)
			if dist <= 70.0 and _is_closest_to_hole(pos, source_hole_key, all_source_holes, dist):
				var rel_vec: Vector3 = pos - src_tee_3d
				var rot_vec: Vector3 = rel_vec.rotated(Vector3.UP, angle)
				var target_pos: Vector3 = target_tee_pos + rot_vec
				tree_positions.append(Vector2(target_pos.x, target_pos.z))

				var mesh_idx := int(rec[7])
				var mesh_path := "res://Courses/Environments/Tree1.tscn"
				if mesh_idx >= 0 and mesh_idx < mesh_paths.size() and str(mesh_paths[mesh_idx]) != "":
					mesh_path = str(mesh_paths[mesh_idx])
				if not loaded_scenes.has(mesh_path):
					loaded_scenes[mesh_path] = load(mesh_path) if ResourceLoader.exists(mesh_path) else load("res://Courses/Environments/Tree1.tscn")
				var tree_scene := loaded_scenes[mesh_path] as PackedScene
				if tree_scene != null:
					var tree_inst := tree_scene.instantiate() as Node3D
					if tree_inst != null:
						tree_inst.name = "Tree_Extracted_%d" % rec_idx
						tree_inst.position = target_pos
						tree_inst.scale = Vector3(float(rec[3]), float(rec[4]), float(rec[5]))
						tree_inst.rotation.y = float(rec[6]) - angle
						tree_nodes.append(tree_inst)

	var ignored_names: Array[String] = [
		"Player", "RangeUI", "Sky3D", "SunLight", "MoonLight", "Skydome", "TimeOfDay",
		"Camera3D", "PhantomCamera3D", "PhantomCameraHost", "AerialCamera", "SessionRecorder",
		"TCPServer", "YardMarkers", "CenterLine", "RoughMesh_Base", "RoughStatic_Base",
		"PreviewAerialCam", "TerrainStatic", "UnifiedTerrain", "GroundMesh",
		"MultiMeshFoliageContainer", "ConsolidatedFoliageCollision", "ConsolidatedCanopyArea",
		"HighFidelityBunkers", "BunkerLipGrassMultiMesh", "ShorelineReedsMultiMesh",
		"HorizonSkirt", "CartPaths"
	]

	var all_nodes: Array[Node] = []
	_gather_nodes_recursive(src_inst, all_nodes, ignored_names)

	for node in all_nodes:
		var name_lower = node.name.to_lower()

		# Check for Tree & Bush instances
		if node is Node3D and not (node is MultiMeshInstance3D) and (name_lower.contains("tree") or name_lower.contains("bush")):
			var node_3d = node as Node3D
			var rel_t = _get_relative_transform(node_3d, src_inst)
			var pos = rel_t.origin
			var dist = _get_distance_to_hole_info(pos, source_hole_data)
			if dist <= 70.0 and _is_closest_to_hole(pos, source_hole_key, all_source_holes, dist):
				var rel_vec = pos - src_tee_3d
				var rot_vec = rel_vec.rotated(Vector3.UP, angle)
				var target_pos = target_tee_pos + rot_vec

				tree_positions.append(Vector2(target_pos.x, target_pos.z))

				var dup = node_3d.duplicate()
				dup.position = target_pos
				dup.rotation.y = node_3d.rotation.y - angle
				tree_nodes.append(dup)
			continue

		# Check for StaticBody3D golf surfaces
		if node is StaticBody3D:
			var faces = _get_static_body_faces(node as StaticBody3D)
			if faces.is_empty():
				continue

			var centroid = _calculate_centroid(faces)
			var dist = _get_distance_to_hole_info(centroid, source_hole_data)

			if dist <= 75.0 and _is_closest_to_hole(centroid, source_hole_key, all_source_holes, dist):
				var surface_type = node.get_meta("surface_type", -1) if node.has_meta("surface_type") else -1
				var is_sand = node.get_meta("is_sand", false) if node.has_meta("is_sand") else false
				var is_water = node.get_meta("is_water", false) if node.has_meta("is_water") else false

				var type_tag = "fairway"
				if name_lower.contains("green") or surface_type == 4:
					type_tag = "green"
				elif name_lower.contains("bunker") or is_sand or (surface_type == 2 and is_sand):
					type_tag = "bunker"
				elif name_lower.contains("water") or is_water:
					type_tag = "water"
				elif name_lower.contains("tee") or surface_type == 3:
					type_tag = "tee"
				else:
					type_tag = "fairway"

				for i in range(0, faces.size(), 3):
					var v1 = target_tee_pos + (faces[i] - src_tee_3d).rotated(Vector3.UP, angle)
					var v2 = target_tee_pos + (faces[i + 1] - src_tee_3d).rotated(Vector3.UP, angle)
					var v3 = target_tee_pos + (faces[i + 2] - src_tee_3d).rotated(Vector3.UP, angle)

					extracted_3d_faces[type_tag].append_array([v1, v2, v3])
					extracted_features[type_tag].append([Vector2(v1.x, v1.z), Vector2(v2.x, v2.z), Vector2(v3.x, v3.z)])

		# Check for MeshInstance3D water surfaces
		elif node is MeshInstance3D and name_lower.contains("water"):
			var faces = _get_mesh_faces(node as MeshInstance3D)
			if not faces.is_empty():
				var centroid = _calculate_centroid(faces)
				var dist = _get_distance_to_hole_info(centroid, source_hole_data)
				if dist <= 75.0 and _is_closest_to_hole(centroid, source_hole_key, all_source_holes, dist):
					for i in range(0, faces.size(), 3):
						var v1 = target_tee_pos + (faces[i] - src_tee_3d).rotated(Vector3.UP, angle)
						var v2 = target_tee_pos + (faces[i + 1] - src_tee_3d).rotated(Vector3.UP, angle)
						var v3 = target_tee_pos + (faces[i + 2] - src_tee_3d).rotated(Vector3.UP, angle)

						extracted_3d_faces["water"].append_array([v1, v2, v3])
						extracted_features["water"].append([Vector2(v1.x, v1.z), Vector2(v2.x, v2.z), Vector2(v3.x, v3.z)])


static func _generate_fallback_fairway_tris(
	target_tee_pos: Vector3,
	target_pin_pos: Vector3,
	h_data: Dictionary,
	out_features: Array,
	out_3d: PackedVector3Array,
	height_grid: Dictionary = {}
) -> void:
	var path_arr = h_data.get("HolePath", h_data.get("Hole Path", []))
	var center_pts: Array[Vector2] = []
	if typeof(path_arr) == TYPE_ARRAY and path_arr.size() >= 2:
		for pt in path_arr:
			center_pts.append(Vector2(float(pt[0]), float(pt[1])))
	else:
		center_pts.append(Vector2(target_tee_pos.x, target_tee_pos.z))
		center_pts.append(Vector2(target_pin_pos.x, target_pin_pos.z))

	# Resample / subdivide center points so fallback fairway conforms smoothly to rolling terrain
	var resampled_pts: Array[Vector2] = []
	for j in range(center_pts.size() - 1):
		var cp1 = center_pts[j]
		var cp2 = center_pts[j + 1]
		var seg_len = cp1.distance_to(cp2)
		var steps = maxi(1, int(ceil(seg_len / 16.0)))
		for s in range(steps):
			var t = float(s) / float(steps)
			resampled_pts.append(cp1.lerp(cp2, t))
	resampled_pts.append(center_pts.back())

	var half_w = 14.0 # 28m fairway width
	for j in range(resampled_pts.size() - 1):
		var p1 = resampled_pts[j]
		var p2 = resampled_pts[j + 1]
		var fwd = (p2 - p1).normalized()
		var side = Vector2(-fwd.y, fwd.x) * half_w

		var a_y = _sample_height_from_grid(p1.x - side.x, p1.y - side.y, height_grid, 4.0, 0.0)
		var b_y = _sample_height_from_grid(p1.x + side.x, p1.y + side.y, height_grid, 4.0, 0.0)
		var c_y = _sample_height_from_grid(p2.x + side.x, p2.y + side.y, height_grid, 4.0, 0.0)
		var d_y = _sample_height_from_grid(p2.x - side.x, p2.y - side.y, height_grid, 4.0, 0.0)

		var a = Vector3(p1.x - side.x, a_y, p1.y - side.y)
		var b = Vector3(p1.x + side.x, b_y, p1.y + side.y)
		var c = Vector3(p2.x + side.x, c_y, p2.y + side.y)
		var d = Vector3(p2.x - side.x, d_y, p2.y - side.y)

		out_3d.append_array([a, b, c, a, c, d])
		out_features.append([Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z)])
		out_features.append([Vector2(a.x, a.z), Vector2(c.x, c.z), Vector2(d.x, d.z)])


static func _generate_fallback_green_tris(
	target_pin_pos: Vector3,
	out_features: Array,
	out_3d: PackedVector3Array,
	height_grid: Dictionary = {}
) -> void:
	var radius = 13.0
	var segs = 24
	var rings = 3
	var center_y = _sample_height_from_grid(target_pin_pos.x, target_pin_pos.z, height_grid, 4.0, 0.0)
	var center = Vector3(target_pin_pos.x, center_y, target_pin_pos.z)
	var center2d = Vector2(center.x, center.z)

	var ring_radii = [radius * 0.35, radius * 0.70, radius * 1.0]
	var prev_pts_2d: Array[Vector2] = []
	var prev_pts_3d: PackedVector3Array = PackedVector3Array()

	# Center fan to ring 0
	for i in range(segs):
		var a = (float(i) / float(segs)) * TAU
		var p_xz = center2d + Vector2(cos(a), sin(a)) * ring_radii[0]
		var py = _sample_height_from_grid(p_xz.x, p_xz.y, height_grid, 4.0, center_y)
		prev_pts_2d.append(p_xz)
		prev_pts_3d.append(Vector3(p_xz.x, py, p_xz.y))

	for i in range(segs):
		var i_next = (i + 1) % segs
		out_3d.append_array([center, prev_pts_3d[i], prev_pts_3d[i_next]])
		out_features.append([center2d, prev_pts_2d[i], prev_pts_2d[i_next]])

	# Concentric quads for outer rings
	for r in range(1, rings):
		var curr_r = ring_radii[r]
		var curr_pts_2d: Array[Vector2] = []
		var curr_pts_3d: PackedVector3Array = PackedVector3Array()

		for i in range(segs):
			var a = (float(i) / float(segs)) * TAU
			var p_xz = center2d + Vector2(cos(a), sin(a)) * curr_r
			var py = _sample_height_from_grid(p_xz.x, p_xz.y, height_grid, 4.0, center_y)
			curr_pts_2d.append(p_xz)
			curr_pts_3d.append(Vector3(p_xz.x, py, p_xz.y))

		for i in range(segs):
			var i_next = (i + 1) % segs
			var p_in_a = prev_pts_3d[i]
			var p_in_b = prev_pts_3d[i_next]
			var p_out_a = curr_pts_3d[i]
			var p_out_b = curr_pts_3d[i_next]

			out_3d.append_array([p_in_a, p_out_a, p_in_b, p_in_b, p_out_a, p_out_b])
			out_features.append([prev_pts_2d[i], curr_pts_2d[i], prev_pts_2d[i_next]])
			out_features.append([prev_pts_2d[i_next], curr_pts_2d[i], curr_pts_2d[i_next]])

		prev_pts_2d = curr_pts_2d
		prev_pts_3d = curr_pts_3d


static func _build_hole_unified_terrain(
	hole_node: Node3D,
	root: Node3D,
	min_x: float,
	max_x: float,
	min_z: float,
	max_z: float,
	features: Dictionary,
	faces_3d: Dictionary,
	tree_positions: Array[Vector2],
	height_grid: Dictionary = {}
) -> void:
	var width = max_x - min_x
	var depth = max_z - min_z
	if width <= 0 or depth <= 0:
		return

	# 1. Rasterize 256x256 splat map (optimal resolution and performance)
	var tex_size = 256
	var image = Image.create_empty(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	var blend_radius = 3.0

	var green_tris = features.get("green", [])
	var fairway_tris = features.get("fairway", [])
	var bunker_tris = features.get("bunker", [])
	var tee_tris = features.get("tee", [])

	for py in range(tex_size):
		var world_z = min_z + (float(py) / float(tex_size - 1)) * depth
		for px in range(tex_size):
			var world_x = min_x + (float(px) / float(tex_size - 1)) * width
			var pt = Vector2(world_x, world_z)

			var green_w = _calculate_weight_for_tris(pt, green_tris, blend_radius)
			var fairway_w = _calculate_weight_for_tris(pt, fairway_tris, blend_radius)
			var tee_w = _calculate_weight_for_tris(pt, tee_tris, blend_radius)
			var bunker_w = _calculate_weight_for_tris(pt, bunker_tris, blend_radius)

			green_w = max(green_w, tee_w)

			# Mulch weight around trees (radius 2.2m)
			var mulch_w = 0.0
			for t_pos in tree_positions:
				var d = pt.distance_to(t_pos)
				if d < 2.2:
					var w = 1.0 - (d / 2.2)
					mulch_w = max(mulch_w, _quintic_smooth(w))

			# Priority override: bunker > green/tee > mulch > fairway
			if bunker_w >= 1.0:
				green_w = 0.0
				fairway_w = 0.0
				mulch_w = 0.0
			elif green_w >= 1.0:
				fairway_w = 0.0
				mulch_w = 0.0
				bunker_w = min(bunker_w, 1.0 - green_w)
			elif mulch_w >= 1.0:
				fairway_w = 0.0
				green_w = min(green_w, 1.0 - mulch_w)
				bunker_w = min(bunker_w, 1.0 - mulch_w)
			else:
				var base_sum = green_w + bunker_w + mulch_w
				if base_sum > 0.0:
					fairway_w = min(fairway_w, 1.0 - base_sum)

			image.set_pixel(px, py, Color(green_w, fairway_w, bunker_w, mulch_w))

	var splat_tex = ImageTexture.create_from_image(image)

	# 2. Build UnifiedTerrain ArrayMesh grid with authentic elevation and normals
	var subdiv_x = clampi(int(width / 3.0), 30, 250)
	var subdiv_z = clampi(int(depth / 3.0), 25, 75)
	var cell_w = width / float(subdiv_x)
	var cell_d = depth / float(subdiv_z)

	var num_verts = (subdiv_x + 1) * (subdiv_z + 1)
	var verts = PackedVector3Array()
	verts.resize(num_verts)
	var normals = PackedVector3Array()
	normals.resize(num_verts)
	var uvs = PackedVector2Array()
	uvs.resize(num_verts)
	var uv2s = PackedVector2Array()
	uv2s.resize(num_verts)

	# Precalculate boundary segments for smooth organic curvature around hazards
	var bunker_boundary = _get_boundary_segments(bunker_tris)
	var water_boundary = _get_boundary_segments(features.get("water", []))

	var sample_h = func(sx: float, sz: float) -> float:
		var base_y = 0.0
		if not height_grid.is_empty():
			base_y = _sample_height_from_grid(sx, sz, height_grid, 4.0, 0.0)
		else:
			base_y = sin(sx * 0.022 + sz * 0.012) * cos(sz * 0.025 - sx * 0.015) * 5.5 + sin(sx * 0.045 - sz * 0.035) * 2.2 + cos(sx * 0.085 + sz * 0.065) * 1.0

		var sp2d = Vector2(sx, sz)
		var bunker_dep = 0.0
		if not bunker_boundary.is_empty():
			var min_edge_d = 999999.0
			for edge in bunker_boundary:
				var d = _dist_to_segment_2d(sp2d, edge[0], edge[1])
				if d < min_edge_d:
					min_edge_d = d

			if _is_point_in_tri_list(sp2d, bunker_tris):
				var bowl_radius = 7.0
				var max_depth = 1.0
				if min_edge_d < bowl_radius:
					var t = min_edge_d / bowl_radius
					bunker_dep = _quintic_smooth(t) * max_depth
				else:
					bunker_dep = max_depth
			elif min_edge_d < 4.0:
				var t = 1.0 - (min_edge_d / 4.0)
				bunker_dep = -_quintic_smooth(t) * 0.12 # gentle raised lip outside bunker

		var water_dep = 0.0
		if not water_boundary.is_empty() and _is_point_in_tri_list(sp2d, features.get("water", [])):
			var min_water_d = 999999.0
			for edge in water_boundary:
				var d = _dist_to_segment_2d(sp2d, edge[0], edge[1])
				if d < min_water_d:
					min_water_d = d
			if min_water_d < 15.0:
				var t = min_water_d / 15.0
				water_dep = _quintic_smooth(t) * 2.0
			else:
				water_dep = 2.0

		return base_y - maxf(bunker_dep, water_dep)

	var idx = 0
	for z in range(subdiv_z + 1):
		for x in range(subdiv_x + 1):
			var vx = min_x + float(x) * cell_w
			var vz = min_z + float(z) * cell_d
			var vy = sample_h.call(vx, vz)
			verts[idx] = Vector3(vx, vy, vz)

			# Compute normal from height differences for proper slope shading
			var hL = sample_h.call(vx - 1.0, vz)
			var hR = sample_h.call(vx + 1.0, vz)
			var hD = sample_h.call(vx, vz - 1.0)
			var hU = sample_h.call(vx, vz + 1.0)
			normals[idx] = Vector3(hL - hR, 2.0, hD - hU).normalized()

			uvs[idx] = Vector2(vx, vz) * 0.1 # UV1 world-space tiling
			uv2s[idx] = Vector2((vx - min_x) / width, (vz - min_z) / depth) # UV2 normalized for splat map
			idx += 1

	# Indices for grid quads (2 triangles each)
	var indices = PackedInt32Array()
	for z in range(subdiv_z):
		for x in range(subdiv_x):
			var r1 = z * (subdiv_x + 1)
			var r2 = (z + 1) * (subdiv_x + 1)

			indices.append(r1 + x)
			indices.append(r1 + x + 1)
			indices.append(r2 + x)

			indices.append(r1 + x + 1)
			indices.append(r2 + x + 1)
			indices.append(r2 + x)

	# Add vertical skirt around all 4 perimeter borders extending down to -80m to seal the underside of the hole
	var skirt_bottom_y = -80.0

	# 1. North skirt (z = 0, along X)
	for x in range(subdiv_x):
		var i_top_a = x
		var i_top_b = x + 1
		var v_top_a = verts[i_top_a]
		var v_top_b = verts[i_top_b]

		var i_bot_a = verts.size()
		verts.append(Vector3(v_top_a.x, skirt_bottom_y, v_top_a.z))
		normals.append(Vector3(0, 0, -1))
		uvs.append(Vector2(v_top_a.x, skirt_bottom_y) * 0.1)
		uv2s.append(uv2s[i_top_a])

		var i_bot_b = verts.size()
		verts.append(Vector3(v_top_b.x, skirt_bottom_y, v_top_b.z))
		normals.append(Vector3(0, 0, -1))
		uvs.append(Vector2(v_top_b.x, skirt_bottom_y) * 0.1)
		uv2s.append(uv2s[i_top_b])

		indices.append(i_top_a)
		indices.append(i_bot_b)
		indices.append(i_top_b)

		indices.append(i_top_a)
		indices.append(i_bot_a)
		indices.append(i_bot_b)

	# 2. South skirt (z = subdiv_z, along X)
	for x in range(subdiv_x):
		var i_top_a = subdiv_z * (subdiv_x + 1) + x
		var i_top_b = subdiv_z * (subdiv_x + 1) + x + 1
		var v_top_a = verts[i_top_a]
		var v_top_b = verts[i_top_b]

		var i_bot_a = verts.size()
		verts.append(Vector3(v_top_a.x, skirt_bottom_y, v_top_a.z))
		normals.append(Vector3(0, 0, 1))
		uvs.append(Vector2(v_top_a.x, skirt_bottom_y) * 0.1)
		uv2s.append(uv2s[i_top_a])

		var i_bot_b = verts.size()
		verts.append(Vector3(v_top_b.x, skirt_bottom_y, v_top_b.z))
		normals.append(Vector3(0, 0, 1))
		uvs.append(Vector2(v_top_b.x, skirt_bottom_y) * 0.1)
		uv2s.append(uv2s[i_top_b])

		indices.append(i_top_a)
		indices.append(i_top_b)
		indices.append(i_bot_b)

		indices.append(i_top_a)
		indices.append(i_bot_b)
		indices.append(i_bot_a)

	# 3. West skirt (x = 0, along Z)
	for z in range(subdiv_z):
		var i_top_a = z * (subdiv_x + 1)
		var i_top_b = (z + 1) * (subdiv_x + 1)
		var v_top_a = verts[i_top_a]
		var v_top_b = verts[i_top_b]

		var i_bot_a = verts.size()
		verts.append(Vector3(v_top_a.x, skirt_bottom_y, v_top_a.z))
		normals.append(Vector3(-1, 0, 0))
		uvs.append(Vector2(v_top_a.z, skirt_bottom_y) * 0.1)
		uv2s.append(uv2s[i_top_a])

		var i_bot_b = verts.size()
		verts.append(Vector3(v_top_b.x, skirt_bottom_y, v_top_b.z))
		normals.append(Vector3(-1, 0, 0))
		uvs.append(Vector2(v_top_b.z, skirt_bottom_y) * 0.1)
		uv2s.append(uv2s[i_top_b])

		indices.append(i_top_a)
		indices.append(i_top_b)
		indices.append(i_bot_b)

		indices.append(i_top_a)
		indices.append(i_bot_b)
		indices.append(i_bot_a)

	# 4. East skirt (x = subdiv_x, along Z)
	for z in range(subdiv_z):
		var i_top_a = z * (subdiv_x + 1) + subdiv_x
		var i_top_b = (z + 1) * (subdiv_x + 1) + subdiv_x
		var v_top_a = verts[i_top_a]
		var v_top_b = verts[i_top_b]

		var i_bot_a = verts.size()
		verts.append(Vector3(v_top_a.x, skirt_bottom_y, v_top_a.z))
		normals.append(Vector3(1, 0, 0))
		uvs.append(Vector2(v_top_a.z, skirt_bottom_y) * 0.1)
		uv2s.append(uv2s[i_top_a])

		var i_bot_b = verts.size()
		verts.append(Vector3(v_top_b.x, skirt_bottom_y, v_top_b.z))
		normals.append(Vector3(1, 0, 0))
		uvs.append(Vector2(v_top_b.z, skirt_bottom_y) * 0.1)
		uv2s.append(uv2s[i_top_b])

		indices.append(i_top_a)
		indices.append(i_bot_b)
		indices.append(i_top_b)

		indices.append(i_top_a)
		indices.append(i_bot_a)
		indices.append(i_bot_b)

	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_TEX_UV2] = uv2s
	arr[Mesh.ARRAY_INDEX] = indices

	var arr_mesh = ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)

	# Assign terrain_splat.gdshader
	var shader = load("res://Courses/Environments/shaders/terrain_splat.gdshader")
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("splat_map", splat_tex)
	mat.set_shader_parameter("tex_rough", load("res://Courses/Environments/grass-rough/albedo.png"))
	mat.set_shader_parameter("tex_green", load("res://Courses/Environments/grass-green/albedo.png"))
	mat.set_shader_parameter("tex_fairway", load("res://Courses/Environments/grass-fairway/albedo.png"))
	mat.set_shader_parameter("tex_bunker", load("res://Courses/Environments/sand-bunker/albedo.png"))
	mat.set_shader_parameter("tex_mulch", load("res://Courses/Environments/tree-bark/albedo.png"))
	
	# Normal Maps
	mat.set_shader_parameter("normal_rough", load("res://Courses/Environments/grass-rough/normal.png"))
	mat.set_shader_parameter("normal_green", load("res://Courses/Environments/grass-green/normal.png"))
	mat.set_shader_parameter("normal_fairway", load("res://Courses/Environments/grass-fairway/normal.png"))
	mat.set_shader_parameter("normal_bunker", load("res://Courses/Environments/sand-bunker/normal.png"))
	mat.set_shader_parameter("normal_mulch", load("res://Courses/Environments/tree-bark/normal.png"))

	# Ambient Occlusion Maps
	mat.set_shader_parameter("ao_rough", load("res://Courses/Environments/grass-rough/ao.png"))
	mat.set_shader_parameter("ao_green", load("res://Courses/Environments/grass-green/ao.png"))
	mat.set_shader_parameter("ao_fairway", load("res://Courses/Environments/grass-fairway/ao.png"))
	mat.set_shader_parameter("ao_bunker", load("res://Courses/Environments/sand-bunker/ao.png"))
	if ResourceLoader.exists("res://Courses/Environments/tree-bark/ao.png"):
		mat.set_shader_parameter("ao_mulch", load("res://Courses/Environments/tree-bark/ao.png"))

	# Roughness Maps
	mat.set_shader_parameter("roughness_tex_rough", load("res://Courses/Environments/grass-rough/roughness.png"))
	mat.set_shader_parameter("roughness_tex_green", load("res://Courses/Environments/grass-green/roughness.png"))
	mat.set_shader_parameter("roughness_tex_fairway", load("res://Courses/Environments/grass-fairway/roughness.png"))
	mat.set_shader_parameter("roughness_tex_bunker", load("res://Courses/Environments/sand-bunker/roughness.png"))
	if ResourceLoader.exists("res://Courses/Environments/tree-bark/roughness.png"):
		mat.set_shader_parameter("roughness_tex_mulch", load("res://Courses/Environments/tree-bark/roughness.png"))

	# Height Maps
	mat.set_shader_parameter("height_rough", load("res://Courses/Environments/grass-rough/height.png"))
	mat.set_shader_parameter("height_green", load("res://Courses/Environments/grass-green/height.png"))
	mat.set_shader_parameter("height_fairway", load("res://Courses/Environments/grass-fairway/height.png"))
	mat.set_shader_parameter("height_bunker", load("res://Courses/Environments/sand-bunker/height.png"))
	if ResourceLoader.exists("res://Courses/Environments/tree-bark/height.png"):
		mat.set_shader_parameter("height_mulch", load("res://Courses/Environments/tree-bark/height.png"))

	mat.set_shader_parameter("sun_direction", Vector3(-0.45, -0.65, -0.60).normalized())

	arr_mesh.surface_set_material(0, mat)

	var ground_mesh = MeshInstance3D.new()
	ground_mesh.name = "UnifiedTerrain"
	ground_mesh.mesh = arr_mesh
	var q = GlobalSettings.get_graphics_quality() if GlobalSettings != null else "High"
	MobilePerformance.apply_graphics_quality(ground_mesh, q)
	hole_node.add_child(ground_mesh)
	ground_mesh.owner = root

	# TerrainStatic (Rough collision)
	var terrain_static = StaticBody3D.new()
	terrain_static.name = "TerrainStatic"
	terrain_static.set_meta("surface_type", 2) # Rough

	var col_shape = CollisionShape3D.new()
	var concave_shape = ConcavePolygonShape3D.new()
	var col_verts = PackedVector3Array()
	col_verts.resize(indices.size())
	for k in range(indices.size()):
		col_verts[k] = verts[indices[k]]
	concave_shape.data = col_verts
	col_shape.shape = concave_shape

	terrain_static.add_child(col_shape)
	hole_node.add_child(terrain_static)
	terrain_static.owner = root
	col_shape.owner = root


static func _calculate_weight_for_tris(p: Vector2, tris: Array, blend_radius: float) -> float:
	if tris.is_empty():
		return 0.0

	var min_dist = 999999.0
	var has_nearby = false

	for tri in tris:
		var a: Vector2 = tri[0]
		var b: Vector2 = tri[1]
		var c: Vector2 = tri[2]
		var min_x = min(a.x, min(b.x, c.x)) - blend_radius
		var max_x = max(a.x, max(b.x, c.x)) + blend_radius
		var min_y = min(a.y, min(b.y, c.y)) - blend_radius
		var max_y = max(a.y, max(b.y, c.y)) + blend_radius
		if p.x < min_x or p.x > max_x or p.y < min_y or p.y > max_y:
			continue

		if _point_in_tri_2d(p, a, b, c):
			return 1.0

		var d = _dist_to_tri_2d(p, a, b, c)
		if d < min_dist:
			min_dist = d
			has_nearby = true

	if has_nearby and min_dist < blend_radius:
		var t = 1.0 - (min_dist / blend_radius)
		return _quintic_smooth(t)

	return 0.0


static func _quintic_smooth(t: float) -> float:
	var c = clampf(t, 0.0, 1.0)
	return c * c * c * (c * (c * 6.0 - 15.0) + 10.0)


static func _get_boundary_segments(tris: Array) -> Array:
	if tris.is_empty():
		return []
	var edge_counts = {}
	for tri in tris:
		for i in range(3):
			var a: Vector2 = tri[i]
			var b: Vector2 = tri[(i + 1) % 3]
			var key = "%0.2f,%0.2f_%0.2f,%0.2f" % [a.x, a.y, b.x, b.y] if (a.x < b.x or (a.x == b.x and a.y < b.y)) else "%0.2f,%0.2f_%0.2f,%0.2f" % [b.x, b.y, a.x, a.y]
			if edge_counts.has(key):
				edge_counts[key]["count"] += 1
			else:
				edge_counts[key] = {"count": 1, "a": a, "b": b}
	var boundary = []
	for key in edge_counts:
		if edge_counts[key]["count"] == 1:
			boundary.append([edge_counts[key]["a"], edge_counts[key]["b"]])
	return boundary


static func _is_point_in_tri_list(p: Vector2, tris: Array) -> bool:
	for tri in tris:
		if _point_in_tri_2d(p, tri[0], tri[1], tri[2]):
			return true
	return false


static func _point_in_tri_2d(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 = (p.x - b.x) * (a.y - b.y) - (a.x - b.x) * (p.y - b.y)
	var d2 = (p.x - c.x) * (b.y - c.y) - (b.x - c.x) * (p.y - c.y)
	var d3 = (p.x - a.x) * (c.y - a.y) - (c.x - a.x) * (p.y - a.y)
	var has_neg = (d1 < 0) or (d2 < 0) or (d3 < 0)
	var has_pos = (d1 > 0) or (d2 > 0) or (d3 > 0)
	return not (has_neg and has_pos)


static func _dist_to_tri_2d(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> float:
	var d_ab = _dist_to_segment_2d(p, a, b)
	var d_bc = _dist_to_segment_2d(p, b, c)
	var d_ca = _dist_to_segment_2d(p, c, a)
	return min(d_ab, min(d_bc, d_ca))


static func _build_surface_collision(
	hole_node: Node3D,
	root: Node3D,
	name_tag: String,
	surface_type_val: int,
	is_sand: bool,
	is_water: bool,
	faces: PackedVector3Array
) -> void:
	if faces.is_empty():
		return

	var static_body = StaticBody3D.new()
	static_body.name = name_tag
	static_body.set_meta("surface_type", surface_type_val)
	if is_sand:
		static_body.set_meta("is_sand", true)
	if is_water:
		static_body.set_meta("is_water", true)
	else:
		# Place invisible surface-zone overlay colliders on Layer 4 (bitmask 8) so TerrainStatic
		# (1:1 visual UnifiedTerrain mesh) is the sole authoritative Layer 1 ground surface.
		static_body.collision_layer = 8
		static_body.collision_mask = 0

	var col_shape = CollisionShape3D.new()
	var concave_shape = ConcavePolygonShape3D.new()
	concave_shape.data = faces
	col_shape.shape = concave_shape
	static_body.add_child(col_shape)
	hole_node.add_child(static_body)
	static_body.owner = root
	col_shape.owner = root


static func _build_water_visual_mesh(hole_node: Node3D, root: Node3D, faces: PackedVector3Array) -> void:
	var vis_faces = PackedVector3Array()
	vis_faces.resize(faces.size())
	var normals = PackedVector3Array()
	normals.resize(faces.size())
	var uvs = PackedVector2Array()
	uvs.resize(faces.size())

	for i in range(faces.size()):
		var v = faces[i]
		vis_faces[i] = Vector3(v.x, v.y - 0.05, v.z)
		normals[i] = Vector3.UP
		uvs[i] = Vector2(v.x, v.z) * 0.1

	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vis_faces
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_TEX_UV] = uvs

	var arr_mesh = ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)

	var water_mat = StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.12, 0.38, 0.72, 0.85)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.roughness = 0.1
	water_mat.metallic = 0.2
	arr_mesh.surface_set_material(0, water_mat)

	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "WaterMesh"
	mesh_inst.mesh = arr_mesh
	hole_node.add_child(mesh_inst)
	mesh_inst.owner = root


static func _extract_source_terrain_verts(src_inst: Node, out_verts: PackedVector3Array) -> void:
	var terrain_node = src_inst.find_child("UnifiedTerrain", true, false)
	if terrain_node is MeshInstance3D and (terrain_node as MeshInstance3D).mesh != null:
		var m = (terrain_node as MeshInstance3D).mesh
		var rel_t = _get_relative_transform(terrain_node as Node3D, src_inst)
		var arrays = m.surface_get_arrays(0)
		if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] != null:
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for v in verts:
				out_verts.append(rel_t * v)
			return
		var faces = m.get_faces()
		if not faces.is_empty():
			for f in faces:
				out_verts.append(rel_t * f)
			return

	var static_node = src_inst.find_child("TerrainStatic", true, false)
	if static_node is StaticBody3D:
		var faces = _get_static_body_faces(static_node as StaticBody3D)
		if not faces.is_empty():
			var rel_t = _get_relative_transform(static_node as Node3D, src_inst)
			for f in faces:
				out_verts.append(rel_t * f)
			return


static func _find_closest_source_height(source_verts: PackedVector3Array, p2d: Vector2) -> float:
	if source_verts.is_empty():
		return 0.0
	var min_d2 = 999999.0
	var closest_y = 0.0
	for v in source_verts:
		var d2 = p2d.distance_squared_to(Vector2(v.x, v.z))
		if d2 < min_d2:
			min_d2 = d2
			closest_y = v.y
			if d2 < 0.25: # within 0.5 meters
				break
	return closest_y


static func _sample_height_from_grid(
	x: float, z: float,
	height_grid: Dictionary,
	cell_size: float = 4.0,
	fallback_y: float = 0.0
) -> float:
	if height_grid.is_empty():
		return fallback_y

	var cx = int(floor(x / cell_size))
	var cz = int(floor(z / cell_size))
	var p2 = Vector2(x, z)

	var total_weight: float = 0.0
	var weighted_height: float = 0.0
	var min_dist_sq: float = 999999.0
	var closest_y: float = fallback_y

	var support_radius: float = 14.0
	var support_radius_sq: float = support_radius * support_radius

	for dx in range(-3, 4):
		for dz in range(-3, 4):
			var cell_key = Vector2i(cx + dx, cz + dz)
			if not height_grid.has(cell_key):
				continue
			var cell_verts: Array = height_grid[cell_key]
			for v in cell_verts:
				var d2 = p2.distance_squared_to(Vector2(v.x, v.z))
				if d2 < 0.0001:
					return v.y
				if d2 < min_dist_sq:
					min_dist_sq = d2
					closest_y = v.y
				if d2 < support_radius_sq:
					var dist = sqrt(d2)
					var q = dist / support_radius
					# Wendland C2 compact polynomial: (1 - q)^4 * (4q + 1)
					# Guarantees smooth first and second derivatives with zero tangent at boundary
					var omq = 1.0 - q
					var w = omq * omq * omq * omq * (4.0 * q + 1.0)
					weighted_height += v.y * w
					total_weight += w

	if total_weight > 0.0:
		return weighted_height / total_weight
	if min_dist_sq < 1600.0: # within 40 meters
		var d = sqrt(min_dist_sq)
		var t = clampf((d - support_radius) / (40.0 - support_radius), 0.0, 1.0)
		return lerpf(closest_y, fallback_y, _quintic_smooth(t))
	return fallback_y


static func _get_static_body_faces(static_body: StaticBody3D) -> PackedVector3Array:
	var faces = PackedVector3Array()
	for child in static_body.get_children():
		if child is CollisionShape3D and child.shape is ConcavePolygonShape3D:
			var data = (child.shape as ConcavePolygonShape3D).data
			if not data.is_empty():
				faces.append_array(data)
	return faces


static func _get_mesh_faces(mesh_inst: MeshInstance3D) -> PackedVector3Array:
	if mesh_inst.mesh != null:
		return mesh_inst.mesh.get_faces()
	return PackedVector3Array()


static func _calculate_centroid(faces: PackedVector3Array) -> Vector3:
	if faces.is_empty():
		return Vector3.ZERO
	var sum = Vector3.ZERO
	var count = faces.size()
	for v in faces:
		sum += v
	return sum / float(count)


static func _build_hole_boundary_walls(
	hole_node: Node3D,
	root: Node3D,
	min_x: float,
	max_x: float,
	min_z: float,
	max_z: float
) -> void:
	var wall_height = 80.0
	var wall_center_y = 20.0
	var wall_thickness = 4.0
	var width = max_x - min_x
	var depth = max_z - min_z
	var center_x = (min_x + max_x) * 0.5
	var center_z = (min_z + max_z) * 0.5

	var wall_configs = [
		{"name": "BoundaryWall_West", "pos": Vector3(min_x - wall_thickness * 0.5, wall_center_y, center_z), "size": Vector3(wall_thickness, wall_height, depth + wall_thickness * 2.0)},
		{"name": "BoundaryWall_East", "pos": Vector3(max_x + wall_thickness * 0.5, wall_center_y, center_z), "size": Vector3(wall_thickness, wall_height, depth + wall_thickness * 2.0)},
		{"name": "BoundaryWall_North", "pos": Vector3(center_x, wall_center_y, min_z - wall_thickness * 0.5), "size": Vector3(width + wall_thickness * 2.0, wall_height, wall_thickness)},
		{"name": "BoundaryWall_South", "pos": Vector3(center_x, wall_center_y, max_z + wall_thickness * 0.5), "size": Vector3(width + wall_thickness * 2.0, wall_height, wall_thickness)}
	]

	for cfg in wall_configs:
		var wall_body = StaticBody3D.new()
		wall_body.name = cfg["name"]
		wall_body.position = cfg["pos"]
		wall_body.set_meta("surface_type", 2) # Rough physics so ball bounces/stops if it strikes wall

		var col_shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = cfg["size"]
		col_shape.shape = box

		wall_body.add_child(col_shape)
		hole_node.add_child(wall_body)
		wall_body.owner = root
		col_shape.owner = root


static func _is_closest_to_hole(point: Vector3, target_hole_key: String, all_source_holes: Dictionary, target_dist: float) -> bool:
	# If point is within the core 50-yard envelope (46m), always keep it
	if target_dist <= 46.0:
		return true
	for other_key in all_source_holes.keys():
		if other_key == target_hole_key:
			continue
		var other_data = all_source_holes[other_key]
		var dist_other = _get_distance_to_hole_info(point, other_data)
		if dist_other < target_dist - 15.0:
			return false
	return true


static func _gather_nodes_recursive(node: Node, out_list: Array[Node], ignored_names: Array[String]) -> void:
	if ignored_names.has(node.name):
		return
	out_list.append(node)
	for child in node.get_children():
		_gather_nodes_recursive(child, out_list, ignored_names)


static func _get_distance_to_hole_info(node_pos: Vector3, h_data: Dictionary) -> float:
	var p2d = Vector2(node_pos.x, node_pos.z)
	var path_arr = h_data.get("HolePath", h_data.get("Hole Path", []))
	if typeof(path_arr) == TYPE_ARRAY and path_arr.size() >= 2:
		var min_dist = 999999.0
		for i in range(path_arr.size() - 1):
			var a = Vector2(float(path_arr[i][0]), float(path_arr[i][1]))
			var b = Vector2(float(path_arr[i + 1][0]), float(path_arr[i + 1][1]))
			var d = _dist_to_segment_2d(p2d, a, b)
			if d < min_dist:
				min_dist = d
		return min_dist

	var orig_pin = h_data.get("Hole Location", [300.0, 0.0])
	var pin_vec = Vector2(float(orig_pin[0]), float(orig_pin[1]))

	var orig_tees = h_data.get("Tee Boxes", {})
	var tee_vec = Vector2.ZERO
	if typeof(orig_tees) == TYPE_DICTIONARY and not orig_tees.is_empty():
		var default_key = "Blue" if "Blue" in orig_tees else orig_tees.keys()[0]
		var t_arr = orig_tees[default_key]
		tee_vec = Vector2(float(t_arr[0]), float(t_arr[1]))

	return _dist_to_segment_2d(p2d, tee_vec, pin_vec)


static func _dist_to_segment_2d(pt: Vector2, a: Vector2, b: Vector2) -> float:
	var ab = b - a
	if ab.is_zero_approx():
		return pt.distance_to(a)
	var t = clamp((pt - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var proj = a + ab * t
	return pt.distance_to(proj)


static func _set_owner_recursive(node: Node, new_owner: Node) -> void:
	if node != new_owner and node.get_parent() != null:
		node.owner = new_owner
	for child in node.get_children():
		_set_owner_recursive(child, new_owner)


static func _delete_dir_recursive(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir = DirAccess.open(path)
	if dir != null:
		var files_to_delete: Array[String] = []
		var subdirs_to_delete: Array[String] = []
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not file_name.begins_with("."):
				if dir.current_is_dir():
					subdirs_to_delete.append(path.path_join(file_name))
				else:
					files_to_delete.append(path.path_join(file_name))
			file_name = dir.get_next()
		dir.list_dir_end()
		dir = null

		for f in files_to_delete:
			DirAccess.remove_absolute(f)
		for d in subdirs_to_delete:
			_delete_dir_recursive(d)

		DirAccess.remove_absolute(path)


static func _get_relative_transform(node: Node3D, root_node: Node) -> Transform3D:
	var t = Transform3D.IDENTITY
	var curr: Node = node
	while curr != null and is_instance_valid(curr) and curr != root_node:
		if curr is Node3D:
			t = (curr as Node3D).transform * t
		if not curr.is_inside_tree():
			break
		curr = curr.get_parent()
	return t
