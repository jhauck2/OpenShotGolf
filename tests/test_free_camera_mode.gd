extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("=======================================================")
	print("  RUNNING FREE CAMERA MODE TESTS")
	print("=======================================================")

	var root_node = root

	var gs = root_node.get_node_or_null("/root/GlobalSettings")
	if gs == null:
		var gs_script = load("res://Utils/Settings/global_settings.gd")
		gs = gs_script.new()
		gs.name = "GlobalSettings"
		root_node.add_child(gs)

	# --- TEST 1: FreeCamera Activation & Deactivation ---
	print("\n--- TEST 1: FreeCamera Activation & Deactivation ---")
	var free_cam_script = load("res://Utils/free_camera.gd")
	assert(free_cam_script != null, "free_camera.gd must load successfully")

	var dummy_cam = Camera3D.new()
	dummy_cam.name = "DummyCamera3D"
	dummy_cam.global_position = Vector3(0, 25, -10)
	dummy_cam.fov = 75.0
	dummy_cam.near = 0.1
	dummy_cam.far = 1000.0
	root_node.add_child(dummy_cam)
	dummy_cam.make_current()
	await process_frame

	var dummy_course = MockCourse.new()
	dummy_course.name = "DummyCourse"
	root_node.add_child(dummy_course)

	var free_cam = free_cam_script.new()
	free_cam.name = "TestFreeCamera"
	root_node.add_child(free_cam)
	await process_frame

	assert(free_cam.is_active == false, "FreeCamera must start inactive")

	# Activate
	free_cam.activate(dummy_cam, dummy_course)
	await process_frame

	assert(free_cam.is_active == true, "FreeCamera must be active after activate()")
	assert(free_cam.current == true, "FreeCamera must be the current camera")
	assert(free_cam.global_position.is_equal_approx(dummy_cam.global_position), "FreeCamera should copy initial position")
	assert(free_cam.fov > 50.0 and free_cam.fov < 100.0, "FreeCamera fov should be in standard perspective range")

	# Deactivate
	free_cam.deactivate()
	await process_frame

	assert(free_cam.is_active == false, "FreeCamera must be inactive after deactivate()")
	assert(dummy_cam.current == true, "DummyCamera should be restored as current camera")
	print("  PASS: FreeCamera activation & deactivation verified.")

	# --- TEST 2: Terrain Height Clamping ---
	print("\n--- TEST 2: Terrain Height Clamping ---")
	free_cam.activate(dummy_cam, dummy_course)
	# Force position below dummy course height (dummy course returns 12.0)
	free_cam.global_position = Vector3(10, -5, 10)
	free_cam._clamp_to_terrain()

	var expected_min_y = 12.0 + free_cam.min_height_above_ground
	assert(free_cam.global_position.y >= expected_min_y - 0.01, "Camera Y must not dip below terrain height + clearance")
	print("  PASS: Terrain height clamping verified.")

	# --- TEST 3: Click-to-Move Autopilot ---
	print("\n--- TEST 3: Click-to-Move Autopilot ---")
	var click_screen_pos = Vector2(400, 300)
	free_cam.perform_click_to_move(click_screen_pos)
	await process_frame

	assert(free_cam._is_flying_to_target == true, "Click to move should initiate target flight")
	assert(free_cam._waypoint_marker != null, "Waypoint marker must be created")
	assert(free_cam._waypoint_marker.visible == true, "Waypoint marker must be visible during flight")

	# Advance frames to simulate flight
	var initial_dist = free_cam.global_position.distance_to(free_cam._target_destination)
	free_cam._process(0.2)
	var new_dist = free_cam.global_position.distance_to(free_cam._target_destination)
	assert(new_dist < initial_dist, "Camera should move closer to target during autopilot flight")

	# Deactivate free_cam
	free_cam.deactivate()
	print("  PASS: Click-to-move autopilot verified.")

	# --- TEST 4: CoursePlay Visuals Submenu & FreeCamera Mode ---
	print("\n--- TEST 4: CoursePlay Visuals Submenu & FreeCamera Mode ---")
	var cp_script = load("res://Courses/CoursePlay/course_play.gd")
	var cp = Node3D.new()
	cp.set_script(cp_script)
	root_node.add_child(cp)
	await process_frame

	var cp_vis_btn = cp.find_child("VisualsMenuButton", true, false) as Button
	assert(cp_vis_btn != null, "VisualsMenuButton must exist in CoursePlay")
	assert(cp_vis_btn.text == "👁️ Visuals Menu", "VisualsMenuButton text should be '👁️ Visuals Menu'")

	var cp_vis_container = cp.find_child("VisualsMenuContainer", true, false) as VBoxContainer
	assert(cp_vis_container != null, "VisualsMenuContainer must exist in CoursePlay")
	assert(cp_vis_container.visible == false, "VisualsMenuContainer must be hidden by default")

	var cp_free_btn = cp.find_child("FreeCameraButton", true, false) as Button
	assert(cp_free_btn != null, "FreeCameraButton must exist in CoursePlay")
	assert(cp_free_btn.get_parent() == cp_vis_container, "FreeCameraButton must be in VisualsMenuContainer")
	assert(cp_free_btn.text == "🎥 Free Camera: OFF", "Initial FreeCamera text should be OFF")

	# Expand visuals menu
	cp_vis_btn.emit_signal("pressed")
	await process_frame
	assert(cp_vis_container.visible == true, "VisualsMenuContainer should expand on click")
	assert(cp_vis_btn.text == "👁️ Visuals Menu: OPEN", "VisualsMenuButton should show OPEN")

	# Toggle Free Camera ON
	cp_free_btn.emit_signal("pressed")
	await process_frame
	assert(cp.is_free_camera_active() == true, "Free camera must be active after pressing toggle")
	assert(cp_free_btn.text == "🎥 Free Camera: ON", "FreeCamera button text must indicate ON")

	# Toggle Free Camera OFF
	cp_free_btn.emit_signal("pressed")
	await process_frame
	assert(cp.is_free_camera_active() == false, "Free camera must be inactive after toggling off")
	assert(cp_free_btn.text == "🎥 Free Camera: OFF", "FreeCamera button text must indicate OFF")
	print("  PASS: CoursePlay Visuals Submenu & FreeCamera toggle verified.")

	# --- TEST 5: FreeCamera Elevation Up/Down & On-Screen HUD ---
	print("\n--- TEST 5: FreeCamera Elevation Up/Down & On-Screen HUD ---")
	free_cam = free_cam_script.new()
	free_cam.name = "TestFreeCameraElev"
	root_node.add_child(free_cam)
	await process_frame

	free_cam.activate(dummy_cam, dummy_course)
	await process_frame

	assert(free_cam._hud_canvas != null, "HUD CanvasLayer should exist when FreeCamera is active")
	var hud_up_btn = free_cam._hud_canvas.find_child("ElevateUpButton", true, false) as Button
	var hud_down_btn = free_cam._hud_canvas.find_child("ElevateDownButton", true, false) as Button
	var hud_ball_view_btn = free_cam._hud_canvas.find_child("ReturnBallViewButton", true, false) as Button
	assert(hud_up_btn != null, "HUD ElevateUpButton must exist")
	assert(hud_down_btn != null, "HUD ElevateDownButton must exist")
	assert(hud_ball_view_btn != null, "HUD ReturnBallViewButton must exist")

	var initial_y = free_cam.global_position.y
	# Test HUD Up button
	hud_up_btn.emit_signal("button_down")
	assert(free_cam._ui_elev_up_pressed == true, "_ui_elev_up_pressed should be true on button_down")
	free_cam._process(0.1)
	assert(free_cam.global_position.y > initial_y, "Camera should have ascended with Up button pressed")
	hud_up_btn.emit_signal("button_up")
	assert(free_cam._ui_elev_up_pressed == false, "_ui_elev_up_pressed should be false on button_up")

	# Test HUD Down button
	var elevated_y = free_cam.global_position.y
	hud_down_btn.emit_signal("button_down")
	assert(free_cam._ui_elev_down_pressed == true, "_ui_elev_down_pressed should be true on button_down")
	free_cam._process(0.1)
	assert(free_cam.global_position.y < elevated_y, "Camera should have descended with Down button pressed")
	hud_down_btn.emit_signal("button_up")
	assert(free_cam._ui_elev_down_pressed == false, "_ui_elev_down_pressed should be false on button_up")

	# Test Mouse Wheel Up & Down
	var pre_wheel_y = free_cam.global_position.y
	var wheel_up_event = InputEventMouseButton.new()
	wheel_up_event.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up_event.pressed = true
	free_cam._unhandled_input(wheel_up_event)
	assert(free_cam.global_position.y > pre_wheel_y, "Mouse wheel up should elevate camera up")

	var post_wheel_up_y = free_cam.global_position.y
	var wheel_down_event = InputEventMouseButton.new()
	wheel_down_event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_down_event.pressed = true
	free_cam._unhandled_input(wheel_down_event)
	assert(free_cam.global_position.y < post_wheel_up_y, "Mouse wheel down should elevate camera down")

	# Test Middle Mouse Drag
	var pre_drag_y = free_cam.global_position.y
	var mmb_down = InputEventMouseButton.new()
	mmb_down.button_index = MOUSE_BUTTON_MIDDLE
	mmb_down.pressed = true
	free_cam._unhandled_input(mmb_down)
	assert(free_cam._is_mouse_middle_down == true, "Middle mouse button should be tracked down")

	var drag_up = InputEventMouseMotion.new()
	drag_up.relative = Vector2(0, -30) # Dragging mouse up
	free_cam._unhandled_input(drag_up)
	assert(free_cam.global_position.y > pre_drag_y, "Dragging mouse up with middle button should elevate camera")

	var mmb_up = InputEventMouseButton.new()
	mmb_up.button_index = MOUSE_BUTTON_MIDDLE
	mmb_up.pressed = false
	free_cam._unhandled_input(mmb_up)
	assert(free_cam._is_mouse_middle_down == false, "Middle mouse button should be released")

	print("  PASS: Elevation up/down (HUD, Mouse Wheel, Middle Drag) verified.")

	# --- TEST 6: FreeCamera Return to Standard Ball View on Deactivation ---
	print("\n--- TEST 6: FreeCamera Return to Standard Ball View on Deactivation ---")
	var ball_view_called = [false]
	dummy_course.ball_view_reset_cb = func():
		ball_view_called[0] = true

	# Test HUD Return to Ball View button
	hud_ball_view_btn.emit_signal("pressed")
	await process_frame
	assert(free_cam.is_active == false, "FreeCamera should deactivate on Ball View button press")
	assert(free_cam._hud_canvas == null, "HUD CanvasLayer should be cleared on deactivation")
	assert(ball_view_called[0] == true, "reset_to_standard_ball_view should be called on deactivation")
	print("  PASS: FreeCamera deactivation resets camera to standard ball view.")

	# Cleanup
	free_cam.queue_free()
	dummy_cam.queue_free()
	dummy_course.queue_free()
	cp.queue_free()
	await process_frame

	print("\n=======================================================")
	print("ALL FREE CAMERA MODE TESTS PASSED! 🎉")
	print("=======================================================\n")
	quit(0)

class MockCourse extends Node3D:
	var ball_view_reset_cb: Callable = Callable()

	func get_height(_x: float, _z: float) -> float:
		return 12.0

	func reset_to_standard_ball_view() -> void:
		if ball_view_reset_cb.is_valid():
			ball_view_reset_cb.call()
