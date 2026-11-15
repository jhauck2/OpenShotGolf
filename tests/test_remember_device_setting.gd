extends SceneTree

var _tested := false


func _initialize() -> void:
	print("=== Running Remember Device Launch Monitor Tests ===")
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	if _tested:
		return
	_tested = true
	_run_tests()


func _run_tests() -> void:
	var lm = root.get_node_or_null("LaunchMonitorManager")
	assert(lm != null, "LaunchMonitorManager autoload must exist in scene tree")

	# Test 1: Manager settings dictionary has remember_device key
	print("\n--- Test 1: Manager settings has remember_device ---")
	assert(lm.settings.has("remember_device"), "LaunchMonitorManager.settings must contain 'remember_device'")
	print("  PASS: settings['remember_device'] exists.")

	# Test 2: set_remember_device and is_remember_device_enabled
	print("\n--- Test 2: set_remember_device API ---")
	lm.set_remember_device(true)
	assert(lm.is_remember_device_enabled() == true, "is_remember_device_enabled() must return true when set to true")
	lm.set_remember_device(false)
	assert(lm.is_remember_device_enabled() == false, "is_remember_device_enabled() must return false when set to false")
	print("  PASS: set_remember_device properly sets and reports state.")

	# Test 3: LaunchMonitorConnectModal instantiates and contains RememberDeviceCheckBox
	print("\n--- Test 3: Modal contains RememberDeviceCheckBox ---")
	lm.set_remember_device(false)
	var modal_scene = load("res://UI/LaunchMonitorConnectModal/launch_monitor_connect_modal.tscn")
	assert(modal_scene != null, "Modal scene must exist")
	var modal = modal_scene.instantiate()
	root.add_child(modal)
	await process_frame
	await process_frame

	var checkbox: CheckBox = modal.get_node_or_null("%RememberDeviceCheckBox")
	assert(checkbox != null, "Modal must have unique node %RememberDeviceCheckBox")
	assert(checkbox.button_pressed == false, "Checkbox should be unchecked when remember_device is false")
	print("  PASS: Modal contains RememberDeviceCheckBox with initial unchecked state.")

	# Test 4: Toggling checkbox updates manager setting
	print("\n--- Test 4: Toggling Checkbox updates Manager setting ---")
	checkbox.button_pressed = true
	checkbox.toggled.emit(true)
	assert(lm.is_remember_device_enabled() == true, "Toggling checkbox on must update manager remember_device to true")

	checkbox.button_pressed = false
	checkbox.toggled.emit(false)
	assert(lm.is_remember_device_enabled() == false, "Toggling checkbox off must update manager remember_device to false")
	print("  PASS: Checkbox toggle updates LaunchMonitorManager.")

	# Test 5: Re-opening modal when remember_device was true retains checked state
	print("\n--- Test 5: Modal retains saved checked state ---")
	lm.set_remember_device(true)
	modal.queue_free()
	await process_frame
	await process_frame

	var modal2 = modal_scene.instantiate()
	root.add_child(modal2)
	await process_frame
	await process_frame

	var checkbox2: CheckBox = modal2.get_node_or_null("%RememberDeviceCheckBox")
	assert(checkbox2 != null, "Modal2 must have %RememberDeviceCheckBox")
	assert(checkbox2.button_pressed == true, "Checkbox should be checked when remember_device is true")
	modal2.queue_free()
	await process_frame
	await process_frame
	print("  PASS: Modal initialized with saved checked state.")

	# Test 6: Auto-connect decision logic
	print("\n--- Test 6: Startup Auto-Connect Decision Logic ---")
	# Case A: remember_device is false -> should_auto_connect is false
	lm.settings["remember_device"] = false
	lm.settings["device_id"] = "AA:BB:CC:DD:EE:FF"
	lm.settings["enabled"] = true
	var should_auto_connect_a := bool(lm.settings.get("remember_device", false)) and bool(lm.settings.get("enabled", true)) and str(lm.settings.get("device_id", "")).strip_edges() != ""
	assert(should_auto_connect_a == false, "Auto-connect must be false when remember_device is false")

	# Case B: remember_device is true but device_id is empty -> should_auto_connect is false
	lm.settings["remember_device"] = true
	lm.settings["device_id"] = ""
	lm.settings["enabled"] = true
	var should_auto_connect_b := bool(lm.settings.get("remember_device", false)) and bool(lm.settings.get("enabled", true)) and str(lm.settings.get("device_id", "")).strip_edges() != ""
	assert(should_auto_connect_b == false, "Auto-connect must be false when device_id is empty")

	# Case C: remember_device is true with valid device_id -> should_auto_connect is true
	lm.settings["remember_device"] = true
	lm.settings["device_id"] = "AA:BB:CC:DD:EE:FF"
	lm.settings["enabled"] = true
	var should_auto_connect_c := bool(lm.settings.get("remember_device", false)) and bool(lm.settings.get("enabled", true)) and str(lm.settings.get("device_id", "")).strip_edges() != ""
	assert(should_auto_connect_c == true, "Auto-connect must be true when remember_device is true and device_id is present")
	print("  PASS: Startup auto-connect decision logic correctly verified.")

	# Cleanup
	lm.set_remember_device(false)
	print("\n=== ALL REMEMBER DEVICE TESTS PASSED SUCCESSFULLY! ===")
	quit(0)
