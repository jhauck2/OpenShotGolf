extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("=======================================================")
	print("  RUNNING GRAPHICS TOGGLE HELPER MENU TESTS            ")
	print("=======================================================")

	var root_node = root

	var gs = root_node.get_node_or_null("/root/GlobalSettings")
	if gs == null:
		var gs_script = load("res://Utils/Settings/global_settings.gd")
		gs = gs_script.new()
		gs.name = "GlobalSettings"
		root_node.add_child(gs)

	# --- TEST 1: CoursePlay Graphics Toggle Button ---
	print("\n--- TEST 1: CoursePlay Graphics Toggle Button ---")
	var cp_script = load("res://Courses/CoursePlay/course_play.gd")
	var cp = Node3D.new()
	cp.set_script(cp_script)
	root_node.add_child(cp)
	await process_frame

	var cp_vis_container = cp.find_child("VisualsMenuContainer", true, false) as VBoxContainer
	assert(cp_vis_container != null, "VisualsMenuContainer must exist in CoursePlay")

	var cp_graphics_btn = cp.find_child("GraphicsToggleButton", true, false) as Button
	assert(cp_graphics_btn != null, "GraphicsToggleButton must exist in CoursePlay")
	assert(cp_graphics_btn.get_parent() == cp_vis_container, "GraphicsToggleButton must be inside VisualsMenuContainer")

	# Test initial quality setting
	cp.set_graphics_quality("Low")
	await process_frame
	assert(cp_graphics_btn.text == "🎨 Graphics: Low", "Button text should be '🎨 Graphics: Low'")
	assert(gs.get_graphics_quality() == "Low", "GlobalSettings quality should be Low")

	# Cycle forward: Low -> Medium
	cp.cycle_graphics_quality(false)
	await process_frame
	assert(cp_graphics_btn.text == "🎨 Graphics: Medium", "Button text should be '🎨 Graphics: Medium'")
	assert(gs.get_graphics_quality() == "Medium", "GlobalSettings quality should be Medium")

	# Cycle forward: Medium -> High (on desktop)
	if not MobilePerformance.is_mobile():
		cp.cycle_graphics_quality(false)
		await process_frame
		assert(cp_graphics_btn.text == "🎨 Graphics: High", "Button text should be '🎨 Graphics: High'")
		assert(gs.get_graphics_quality() == "High", "GlobalSettings quality should be High")

		# Cycle forward: High -> Low
		cp.cycle_graphics_quality(false)
		await process_frame
		assert(cp_graphics_btn.text == "🎨 Graphics: Low", "Button text should wrap back to '🎨 Graphics: Low'")
		assert(gs.get_graphics_quality() == "Low", "GlobalSettings quality should be Low")

		# Cycle backwards: Low -> High
		cp.cycle_graphics_quality(true)
		await process_frame
		assert(cp_graphics_btn.text == "🎨 Graphics: High", "Reverse cycle should go from Low to High")
		assert(gs.get_graphics_quality() == "High", "GlobalSettings quality should be High")

	print("  PASS: CoursePlay graphics toggle cycling and synchronization verified.")

	# --- TEST 2: RangeUI Graphics Toggle Button ---
	print("\n--- TEST 2: RangeUI Graphics Toggle Button ---")
	var range_scene = load("res://Courses/Range/range.tscn")
	var range_instance = range_scene.instantiate()
	root_node.add_child(range_instance)
	await process_frame
	await process_frame

	var rui = range_instance.get_node_or_null("RangeUI")
	assert(rui != null, "RangeUI must exist in Range scene")

	var rui_vis_container = rui.find_child("VisualsMenuContainer", true, false) as VBoxContainer
	assert(rui_vis_container != null, "VisualsMenuContainer must exist in RangeUI")

	var rui_graphics_btn = rui.find_child("GraphicsToggleButton", true, false) as Button
	assert(rui_graphics_btn != null, "GraphicsToggleButton must exist in RangeUI")
	assert(rui_graphics_btn.get_parent() == rui_vis_container, "GraphicsToggleButton must be inside VisualsMenuContainer")

	# Setting quality via RangeUI
	rui.set_graphics_quality("Medium")
	await process_frame
	assert(rui_graphics_btn.text == "🎨 Graphics: Medium", "RangeUI button text should be '🎨 Graphics: Medium'")
	assert(gs.get_graphics_quality() == "Medium", "GlobalSettings quality should be Medium")

	# Cycle forward via RangeUI
	if not MobilePerformance.is_mobile():
		rui.cycle_graphics_quality(false)
		await process_frame
		assert(rui_graphics_btn.text == "🎨 Graphics: High", "RangeUI button text should cycle to High")
		assert(gs.get_graphics_quality() == "High", "GlobalSettings quality should be High")

	print("  PASS: RangeUI graphics toggle verified.")

	# Cleanup
	cp.queue_free()
	range_instance.queue_free()
	await process_frame

	print("\n=======================================================")
	print("ALL GRAPHICS TOGGLE HELPER TESTS PASSED! 🎉")
	print("=======================================================\n")
	quit(0)
