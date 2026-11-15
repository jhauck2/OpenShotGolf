extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("=======================================================")
	print("  RUNNING CONDENSED HELPER MENU (IMMERSION & TRAINING) TESTS")
	print("=======================================================")

	var root_node = root

	var gs = root_node.get_node_or_null("/root/GlobalSettings")
	if gs == null:
		var gs_script = load("res://Utils/Settings/global_settings.gd")
		gs = gs_script.new()
		gs.name = "GlobalSettings"
		root_node.add_child(gs)

	# --- Test 1: CoursePlay Helper Menus & Submenus ---
	print("\n--- TEST 1: CoursePlay Immersion & Training Submenus ---")
	var cp_script = load("res://Courses/CoursePlay/course_play.gd")
	var cp = Node3D.new()
	cp.set_script(cp_script)
	root_node.add_child(cp)
	await process_frame

	var cp_hit_btn = cp.find_child("HitDistanceButton", true, false) as Button
	assert(cp_hit_btn != null, "HitDistanceButton node must exist in CoursePlay")
	assert(cp_hit_btn.text == "🎯 Hit Menu", "Hit menu button text must be '🎯 Hit Menu' (not Hit Distance)")

	var cp_imm_btn = cp.find_child("ImmersionMenuButton", true, false) as Button
	assert(cp_imm_btn != null, "ImmersionMenuButton must exist in CoursePlay")
	assert(cp_imm_btn.text == "🎭 Immersion Menu", "Immersion button text must be '🎭 Immersion Menu'")

	var cp_imm_container = cp.find_child("ImmersionMenuContainer", true, false) as VBoxContainer
	assert(cp_imm_container != null, "ImmersionMenuContainer must exist in CoursePlay")
	assert(cp_imm_container.visible == false, "ImmersionMenuContainer must be hidden by default")

	# Immersion contents check
	assert(cp.find_child("SuspenseToggleButton", true, false).get_parent() == cp_imm_container, "SuspenseToggleButton must be in ImmersionMenuContainer")
	assert(cp.find_child("AnnouncerToggleButton", true, false).get_parent() == cp_imm_container, "AnnouncerToggleButton must be in ImmersionMenuContainer")
	assert(cp.find_child("PuttingCamButton", true, false).get_parent() == cp_imm_container, "PuttingCamButton must be in ImmersionMenuContainer")
	assert(cp.find_child("ScreenOffsetControl", true, false).get_parent() == cp_imm_container, "ScreenOffsetControl must be in ImmersionMenuContainer")

	# Training menu check
	var cp_train_btn = cp.find_child("TrainingMenuButton", true, false) as Button
	assert(cp_train_btn != null, "TrainingMenuButton must exist in CoursePlay")
	assert(cp_train_btn.text == "🎯 Training Menu", "Training button text must be '🎯 Training Menu'")

	var cp_train_container = cp.find_child("TrainingMenuContainer", true, false) as VBoxContainer
	assert(cp_train_container != null, "TrainingMenuContainer must exist in CoursePlay")
	assert(cp_train_container.visible == false, "TrainingMenuContainer must be hidden by default")

	# Training contents check
	assert(cp.find_child("GolferCamButton", true, false).get_parent() == cp_train_container, "GolferCamButton must be in TrainingMenuContainer")
	assert(cp.find_child("ShotAnalysisButton", true, false).get_parent() == cp_train_container, "ShotAnalysisButton must be in TrainingMenuContainer")
	assert(cp.find_child("TrackAveragesButton", true, false).get_parent() == cp_train_container, "TrackAveragesButton must be in TrainingMenuContainer")
	assert(cp.find_child("RolloutToggleButton", true, false).get_parent() == cp_train_container, "RolloutToggleButton must be in TrainingMenuContainer")

	# Visuals menu check
	var cp_vis_btn = cp.find_child("VisualsMenuButton", true, false) as Button
	assert(cp_vis_btn != null, "VisualsMenuButton must exist in CoursePlay")
	assert(cp_vis_btn.text == "👁️ Visuals Menu", "Visuals button text must be '👁️ Visuals Menu'")

	var cp_vis_container = cp.find_child("VisualsMenuContainer", true, false) as VBoxContainer
	assert(cp_vis_container != null, "VisualsMenuContainer must exist in CoursePlay")
	assert(cp_vis_container.visible == false, "VisualsMenuContainer must be hidden by default")

	# Visuals contents check
	var cp_free_cam_btn = cp.find_child("FreeCameraButton", true, false) as Button
	assert(cp_free_cam_btn != null, "FreeCameraButton must exist in CoursePlay")
	assert(cp_free_cam_btn.get_parent() == cp_vis_container, "FreeCameraButton must be in VisualsMenuContainer")

	var cp_graphics_btn = cp.find_child("GraphicsToggleButton", true, false) as Button
	assert(cp_graphics_btn != null, "GraphicsToggleButton must exist in CoursePlay")
	assert(cp_graphics_btn.get_parent() == cp_vis_container, "GraphicsToggleButton must be in VisualsMenuContainer")
	assert(cp_graphics_btn.text.begins_with("🎨 Graphics:"), "Graphics toggle button text must start with '🎨 Graphics:'")

	# Root helper menu checks (Stuck Ball Relief)
	var cp_stuck_btn = cp.find_child("StuckBallButton", true, false) as Button
	assert(cp_stuck_btn != null, "StuckBallButton must exist in CoursePlay")
	assert(cp_stuck_btn.get_parent() == cp.toggles_container, "StuckBallButton must remain in toggles_container")

	# Test toggling Immersion Menu
	cp_imm_btn.emit_signal("pressed")
	await process_frame
	assert(cp_imm_container.visible == true, "ImmersionMenuContainer must expand on click")
	assert(cp_imm_btn.text == "🎭 Immersion Menu: OPEN", "Immersion button text must indicate OPEN")
	cp_imm_btn.emit_signal("pressed")
	await process_frame
	assert(cp_imm_container.visible == false, "ImmersionMenuContainer must collapse on click")
	assert(cp_imm_btn.text == "🎭 Immersion Menu", "Immersion button text must restore to default")

	# Test toggling Training Menu
	cp_train_btn.emit_signal("pressed")
	await process_frame
	assert(cp_train_container.visible == true, "TrainingMenuContainer must expand on click")
	assert(cp_train_btn.text == "🎯 Training Menu: OPEN", "Training button text must indicate OPEN")
	cp_train_btn.emit_signal("pressed")
	await process_frame
	assert(cp_train_container.visible == false, "TrainingMenuContainer must collapse on click")
	assert(cp_train_btn.text == "🎯 Training Menu", "Training button text must restore to default")

	# Test toggling Visuals Menu
	cp_vis_btn.emit_signal("pressed")
	await process_frame
	assert(cp_vis_container.visible == true, "VisualsMenuContainer must expand on click")
	assert(cp_vis_btn.text == "👁️ Visuals Menu: OPEN", "Visuals button text must indicate OPEN")
	cp_vis_btn.emit_signal("pressed")
	await process_frame
	assert(cp_vis_container.visible == false, "VisualsMenuContainer must collapse on click")
	assert(cp_vis_btn.text == "👁️ Visuals Menu", "Visuals button text must restore to default")

	print("  PASS: CoursePlay submenus and buttons verified.")

	# --- Test 2: RangeUI Helper Menus & Submenus ---
	print("\n--- TEST 2: RangeUI Immersion & Training Submenus ---")
	var range_scene = load("res://Courses/Range/range.tscn")
	var range_instance = range_scene.instantiate()
	root_node.add_child(range_instance)
	await process_frame
	await process_frame

	var rui = range_instance.get_node_or_null("RangeUI")
	assert(rui != null, "RangeUI must exist in Range scene")

	var rui_hit_btn = rui.find_child("HitDistanceButton", true, false) as Button
	assert(rui_hit_btn != null, "HitDistanceButton must exist in RangeUI")
	assert(rui_hit_btn.text == "🎯 Hit Menu", "RangeUI hit menu button text must be '🎯 Hit Menu'")

	var rui_imm_btn = rui.find_child("ImmersionMenuButton", true, false) as Button
	assert(rui_imm_btn != null, "ImmersionMenuButton must exist in RangeUI")
	var rui_imm_container = rui.find_child("ImmersionMenuContainer", true, false) as VBoxContainer
	assert(rui_imm_container != null, "ImmersionMenuContainer must exist in RangeUI")

	assert(rui.find_child("SuspenseToggleButton", true, false).get_parent() == rui_imm_container, "RangeUI SuspenseToggleButton must be in ImmersionMenuContainer")
	assert(rui.find_child("AnnouncerToggleButton", true, false).get_parent() == rui_imm_container, "RangeUI AnnouncerToggleButton must be in ImmersionMenuContainer")
	assert(rui.find_child("PuttingCamButton", true, false).get_parent() == rui_imm_container, "RangeUI PuttingCamButton must be in ImmersionMenuContainer")
	assert(rui.find_child("ScreenOffsetControl", true, false).get_parent() == rui_imm_container, "RangeUI ScreenOffsetControl must be in ImmersionMenuContainer")

	var rui_train_btn = rui.find_child("TrainingMenuButton", true, false) as Button
	assert(rui_train_btn != null, "TrainingMenuButton must exist in RangeUI")
	var rui_train_container = rui.find_child("TrainingMenuContainer", true, false) as VBoxContainer
	assert(rui_train_container != null, "TrainingMenuContainer must exist in RangeUI")

	assert(rui.find_child("GolferCamButton", true, false).get_parent() == rui_train_container, "RangeUI GolferCamButton must be in TrainingMenuContainer")
	assert(rui.find_child("ShotAnalysisButton", true, false).get_parent() == rui_train_container, "RangeUI ShotAnalysisButton must be in TrainingMenuContainer")
	assert(rui.find_child("TrackAveragesButton", true, false).get_parent() == rui_train_container, "RangeUI TrackAveragesButton must be in TrainingMenuContainer")
	assert(rui.find_child("RolloutToggleButton", true, false).get_parent() == rui_train_container, "RangeUI RolloutToggleButton must be in TrainingMenuContainer")

	var rui_vis_btn = rui.find_child("VisualsMenuButton", true, false) as Button
	assert(rui_vis_btn != null, "VisualsMenuButton must exist in RangeUI")
	var rui_vis_container = rui.find_child("VisualsMenuContainer", true, false) as VBoxContainer
	assert(rui_vis_container != null, "VisualsMenuContainer must exist in RangeUI")

	assert(rui.find_child("FreeCameraButton", true, false).get_parent() == rui_vis_container, "RangeUI FreeCameraButton must be in VisualsMenuContainer")

	var rui_graphics_btn = rui.find_child("GraphicsToggleButton", true, false) as Button
	assert(rui_graphics_btn != null, "GraphicsToggleButton must exist in RangeUI")
	assert(rui_graphics_btn.get_parent() == rui_vis_container, "GraphicsToggleButton must be in VisualsMenuContainer")
	assert(rui_graphics_btn.text.begins_with("🎨 Graphics:"), "RangeUI Graphics toggle button text must start with '🎨 Graphics:'")

	# RangeUI toggle expansion
	rui_imm_btn.emit_signal("pressed")
	await process_frame
	assert(rui_imm_container.visible == true, "RangeUI ImmersionMenuContainer must expand")
	rui_imm_btn.emit_signal("pressed")
	await process_frame
	assert(rui_imm_container.visible == false, "RangeUI ImmersionMenuContainer must collapse")

	rui_train_btn.emit_signal("pressed")
	await process_frame
	assert(rui_train_container.visible == true, "RangeUI TrainingMenuContainer must expand")
	rui_train_btn.emit_signal("pressed")
	await process_frame
	assert(rui_train_container.visible == false, "RangeUI TrainingMenuContainer must collapse")

	rui_vis_btn.emit_signal("pressed")
	await process_frame
	assert(rui_vis_container.visible == true, "RangeUI VisualsMenuContainer must expand")
	rui_vis_btn.emit_signal("pressed")
	await process_frame
	assert(rui_vis_container.visible == false, "RangeUI VisualsMenuContainer must collapse")

	print("  PASS: RangeUI submenus and buttons verified.")

	# Cleanup
	cp.queue_free()
	range_instance.queue_free()
	await process_frame

	print("\n=======================================================")
	print("ALL CONDENSED HELPER MENU TESTS PASSED! 🎉")
	print("=======================================================\n")
	quit(0)
