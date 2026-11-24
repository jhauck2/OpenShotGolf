extends RefCounted
class_name CourseGraphicsUpgrader

## CourseGraphicsUpgrader
## Cross-platform (Windows, macOS, iOS, Android) automatic first-launch upgrader for
## downloaded and custom courses stored in `user://courses/`.
## Upgrades existing v1 courses in-place to v2:
## - Converts thousands of individual `Tree_*`, `Bush_*`, and `Rock_*` nodes into spatial
##   `MultiMeshInstance3D` chunks (`MultiMeshFoliageContainer`) + consolidated Jolt physics
## - Builds recessed 3D bunker lip & floor meshes (`HighFidelityBunkers`) and overhanging fescue
## - Builds pond shoreline reeds (`ShorelineReedsMultiMesh`), cart paths (`CartPaths`), and `HorizonSkirt`
## - Optimizes `Sky3D` `Sky.PROCESS_MODE_REALTIME` & gradual clouds (0.005 / 0.003) to eliminate choppiness
## - Stamps `"graphics_version": 2` into `course.json` so subsequent launches have zero overhead.

const CURRENT_COURSE_GRAPHICS_VERSION: int = 23
const ProceduralTreeGeneratorScript = preload("res://HighFidelity/Foliage/procedural_tree_generator.gd")
const CourseDetailEnhancerScript = preload("res://HighFidelity/Terrain/course_detail_enhancer.gd")


static func get_current_graphics_version() -> int:
	return CURRENT_COURSE_GRAPHICS_VERSION


static func is_course_scene_already_upgraded(scene_path: String) -> bool:
	if not FileAccess.file_exists(scene_path):
		return false
	if not scene_path.to_lower().ends_with(".tscn"):
		return false
	var file := FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		return false
	var has_multimesh := false
	var has_terrain := false
	var details_version := 0
	while not file.eof_reached():
		var line := file.get_line()
		if "MultiMeshFoliageContainer" in line:
			has_multimesh = true
		if "UnifiedTerrain" in line:
			has_terrain = true
		if "metadata/course_details_version = " in line:
			var eq_idx := line.find("=")
			if eq_idx >= 0:
				details_version = maxi(details_version, line.substr(eq_idx + 1).strip_edges().to_int())
	file.close()
	if not has_multimesh:
		return false
	if has_terrain:
		return details_version >= CURRENT_COURSE_GRAPHICS_VERSION
	return true


static func get_courses_needing_upgrade(base_dir: String = "user://courses") -> Array[Dictionary]:
	var pending: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(base_dir):
		return pending

	var folders := DirAccess.get_directories_at(base_dir)
	for folder in folders:
		if not folder.begins_with("."):
			var course_dir := base_dir.path_join(folder)
			var config_path := course_dir.path_join("course.json")
			if FileAccess.file_exists(config_path):
				var file := FileAccess.open(config_path, FileAccess.READ)
				if file != null:
					var raw_text := file.get_as_text()
					file.close()
					var json := JSON.new()
					if json.parse(raw_text) == OK and json.data is Dictionary:
						var data: Dictionary = json.data
						var version := int(data.get("graphics_version", 1))
						var rel_scene := str(data.get("scene_path", "course.scn"))
						var scene_path := course_dir.path_join(rel_scene) if not rel_scene.begins_with("user://") and not rel_scene.begins_with("res://") else rel_scene
						if not FileAccess.file_exists(scene_path):
							var scn_path := course_dir.path_join("course.scn")
							var tscn_path := course_dir.path_join("course.tscn")
							if FileAccess.file_exists(scn_path):
								scene_path = scn_path
							elif FileAccess.file_exists(tscn_path):
								scene_path = tscn_path
						var is_corrupt := bool(data.get("corrupted_scene", false))
						if not is_corrupt and version < CURRENT_COURSE_GRAPHICS_VERSION and FileAccess.file_exists(scene_path):
							if is_course_scene_already_upgraded(scene_path):
								data["graphics_version"] = CURRENT_COURSE_GRAPHICS_VERSION
								var wfile := FileAccess.open(config_path, FileAccess.WRITE)
								if wfile != null:
									wfile.store_string(JSON.stringify(data, "\t"))
									wfile.close()
								continue
							pending.append({
								"dir_path": course_dir,
								"config_path": config_path,
								"scene_path": scene_path,
								"title": str(data.get("Title", folder))
							})
	return pending


static func upgrade_single_course(course_entry: Dictionary) -> bool:
	var scene_path := str(course_entry.get("scene_path", ""))
	var config_path := str(course_entry.get("config_path", ""))
	if scene_path == "" or not FileAccess.file_exists(scene_path):
		return false

	var packed := ResourceLoader.load(scene_path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if packed == null:
		push_warning("[CourseGraphicsUpgrader] Failed to load PackedScene: %s" % scene_path)
		_mark_course_corrupted(config_path)
		return false

	var root := packed.instantiate()
	if root == null:
		push_warning("[CourseGraphicsUpgrader] Failed to instantiate scene: %s" % scene_path)
		_mark_course_corrupted(config_path)
		return false

	# 1. Convert individual Tree/Bush/Rock nodes into spatial MultiMesh chunks + consolidated collision
	ProceduralTreeGeneratorScript.convert_scene_foliage_to_multimesh(root, true)

	# 2. Build recessed 3D bunkers, overhanging lip grass, shoreline reeds, cart paths, and horizon skirt
	CourseDetailEnhancerScript.enhance_course_scene(root, true, {"force_rebuild": true})

	# 3. Optimize Sky3D process_mode, radiance_size, clouds speed, and Skydome fog overlay
	var sky3d := root.get_node_or_null("Sky3D") as WorldEnvironment
	if sky3d != null and sky3d.environment != null and sky3d.environment.sky != null:
		sky3d.environment.sky.process_mode = Sky.PROCESS_MODE_REALTIME
		sky3d.environment.sky.radiance_size = Sky.RADIANCE_SIZE_128 if MobilePerformance.is_mobile() else Sky.RADIANCE_SIZE_256
	if sky3d != null:
		if "enable_game_time" in sky3d:
			sky3d.set("enable_game_time", false)
		if "enable_editor_time" in sky3d:
			sky3d.set("enable_editor_time", false)
		var skydome := sky3d.get_node_or_null("Skydome")
		if skydome != null:
			if "fog_visible" in skydome:
				skydome.set("fog_visible", false)
			if "clouds_speed" in skydome:
				skydome.set("clouds_speed", 0.005)
			if "clouds_cumulus_speed" in skydome:
				skydome.set("clouds_cumulus_speed", 0.003)
		var tod := sky3d.get_node_or_null("TimeOfDay")
		if tod != null:
			if "update_in_game" in tod:
				tod.set("update_in_game", false)
			if "update_in_editor" in tod:
				tod.set("update_in_editor", false)
			if "update_interval" in tod:
				tod.set("update_interval", 1.0)

	# 4. Pack and save upgraded course.tscn in-place
	var out_packed := PackedScene.new()
	var pack_err := out_packed.pack(root)
	root.free()
	if pack_err != OK:
		push_warning("[CourseGraphicsUpgrader] Failed to pack upgraded scene: %s (err %d)" % [scene_path, pack_err])
		return false

	var save_err := ResourceSaver.save(out_packed, scene_path)
	if save_err != OK:
		push_warning("[CourseGraphicsUpgrader] Failed to save upgraded scene: %s (err %d)" % [scene_path, save_err])
		return false

	# 5. Stamp graphics_version = 2 in course.json
	if config_path != "" and FileAccess.file_exists(config_path):
		var rfile := FileAccess.open(config_path, FileAccess.READ)
		if rfile != null:
			var raw := rfile.get_as_text()
			rfile.close()
			var json := JSON.new()
			if json.parse(raw) == OK and json.data is Dictionary:
				var data: Dictionary = json.data
				data["graphics_version"] = CURRENT_COURSE_GRAPHICS_VERSION
				var wfile := FileAccess.open(config_path, FileAccess.WRITE)
				if wfile != null:
					wfile.store_string(JSON.stringify(data, "\t"))
					wfile.close()

	return true


static func check_and_upgrade_courses_on_startup(tree: SceneTree, base_dir: String = "user://courses") -> int:
	if tree == null:
		return 0

	var pending := get_courses_needing_upgrade(base_dir)
	if pending.is_empty():
		return 0

	var overlay_info := _create_upgrade_progress_modal(tree, pending.size())
	var modal_layer: CanvasLayer = overlay_info["layer"]
	var status_label: Label = overlay_info["status_label"]
	var progress_bar: ProgressBar = overlay_info["progress_bar"]

	await tree.process_frame
	await tree.process_frame

	var upgraded_count := 0
	var total := pending.size()

	for i in range(total):
		var entry := pending[i]
		var title := str(entry.get("title", "Course %d" % (i + 1)))
		if status_label != null:
			status_label.text = "Upgrading course %d of %d: %s..." % [i + 1, total, title]
		if progress_bar != null:
			progress_bar.value = (float(i) / float(total)) * 100.0

		await tree.process_frame
		await tree.process_frame

		if upgrade_single_course(entry):
			upgraded_count += 1

		if progress_bar != null:
			progress_bar.value = (float(i + 1) / float(total)) * 100.0
		await tree.process_frame

	if status_label != null:
		status_label.text = "Course graphics upgrade complete!"
	await tree.process_frame

	if modal_layer != null and is_instance_valid(modal_layer):
		modal_layer.queue_free()

	return upgraded_count


static func _create_upgrade_progress_modal(tree: SceneTree, total_courses: int) -> Dictionary:
	var layer := CanvasLayer.new()
	layer.name = "CourseGraphicsUpgradeModal"
	layer.layer = 100

	var root_ctrl := Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root_ctrl)

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.10, 0.14, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(580, 250)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.11, 0.16, 0.22, 0.98)
	panel_style.border_color = Color(0.24, 0.56, 0.40, 0.85)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 32
	panel_style.content_margin_right = 32
	panel_style.content_margin_top = 28
	panel_style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "Upgrading Downloaded Courses"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0))
	vbox.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = (
		"Performing a one-time graphics & performance upgrade on your %d downloaded course(s).\n"
		+ "This optimizes 3D trees, bunkers, and terrain so your courses run faster and look better."
	) % total_courses
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 15)
	desc_lbl.add_theme_color_override("font_color", Color(0.76, 0.84, 0.90))
	vbox.add_child(desc_lbl)

	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(480, 28)
	progress.min_value = 0.0
	progress.max_value = 100.0
	progress.value = 0.0
	progress.show_percentage = true

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.22, 0.68, 0.42, 1.0)
	fill_style.set_corner_radius_all(6)
	progress.add_theme_stylebox_override("fill", fill_style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.09, 0.13, 1.0)
	bg_style.set_corner_radius_all(6)
	progress.add_theme_stylebox_override("background", bg_style)
	vbox.add_child(progress)

	var status_lbl := Label.new()
	status_lbl.text = "Preparing course upgrade..."
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 16)
	status_lbl.add_theme_color_override("font_color", Color(0.86, 0.92, 0.96))
	vbox.add_child(status_lbl)

	tree.get_root().add_child(layer)
	return {
		"layer": layer,
		"status_label": status_lbl,
		"progress_bar": progress
	}


static func _mark_course_corrupted(config_path: String) -> void:
	if not FileAccess.file_exists(config_path):
		return
	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		return
	var raw_text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(raw_text) == OK and json.data is Dictionary:
		var data: Dictionary = json.data
		data["graphics_version"] = CURRENT_COURSE_GRAPHICS_VERSION
		data["corrupted_scene"] = true
		var wfile := FileAccess.open(config_path, FileAccess.WRITE)
		if wfile != null:
			wfile.store_string(JSON.stringify(data, "\t"))
			wfile.close()
