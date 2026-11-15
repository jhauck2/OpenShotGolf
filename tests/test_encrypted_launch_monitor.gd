extends SceneTree

var _tested := false


func _initialize() -> void:
	print("=== Running Rainmaker & Encrypted BT Launch Monitor Tests ===")
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	if _tested:
		return
	_tested = true
	_run_tests()


func _run_tests() -> void:
	var lm = root.get_node_or_null("LaunchMonitorManager")
	assert(lm != null, "LaunchMonitorManager autoload must exist in scene tree")

	print("\n--- Test 1: Rainmaker Device Name Detection ---")
	assert(lm.is_rainmaker_device_name("Blue Tees Rainmaker"), "Should identify Blue Tees Rainmaker")
	assert(lm.is_rainmaker_device_name("Rainmaker LM"), "Should identify Rainmaker")
	assert(lm.is_rainmaker_device_name("BlueTees_01"), "Should identify BlueTees")
	assert(not lm.is_rainmaker_device_name("Approach R10"), "Garmin should not be Rainmaker")
	assert(not lm.is_rainmaker_device_name("Square Golf"), "Square should not be Rainmaker")
	assert(not lm.is_rainmaker_device_name(""), "Empty string should not be Rainmaker")
	print("  PASS: Rainmaker device name classification works properly.")

	print("\n--- Test 2: Detect Device Type ---")
	assert(lm.detect_device_type("DEV_RAIN", "Blue Tees Rainmaker") == "rainmaker", "Must detect rainmaker type from name")
	assert(lm.detect_device_type("DEV_SQUARE", "Square Golf") == "square", "Must detect square type from name")
	assert(lm.detect_device_type("DEV_GARMIN", "Approach R10") == "garmin", "Must detect garmin type from name")
	print("  PASS: Device type detection distinguishes rainmaker, square, and garmin.")

	print("\n--- Test 3: Rainmaker Discovery & Code Association ---")
	lm.devices.clear()
	lm._on_rainmaker_device_discovered("RAIN_1234", "Blue Tees Rainmaker", -65)
	assert(lm.devices.has("RAIN_1234"), "Rainmaker device should be added to devices dictionary")
	assert(lm.devices["RAIN_1234"]["type"] == "rainmaker", "Device entry should have type 'rainmaker'")
	print("  PASS: Rainmaker discovery handler populates devices correctly.")

	print("\n--- Test 4: Launch Monitor Modal Instantiation & Encrypted Tab ---")
	var modal_scene = load("res://UI/LaunchMonitorConnectModal/launch_monitor_connect_modal.tscn")
	assert(modal_scene != null, "launch_monitor_connect_modal.tscn must load")
	var modal = modal_scene.instantiate()
	assert(modal != null, "Modal instance must be created")
	root.add_child(modal)

	var tab_container = modal.get_node("%TabContainer")
	assert(tab_container != null, "TabContainer must exist")
	assert(tab_container.get_tab_count() == 3, "TabContainer must have 3 tabs (Bluetooth, Other, Encrypted BT)")
	assert(tab_container.get_tab_title(2).contains("Encrypted"), "Tab 2 must be Encrypted Bluetooth")

	var encrypted_model_option = modal.get_node("%EncryptedModelOption")
	assert(encrypted_model_option != null, "EncryptedModelOption must exist")
	assert(encrypted_model_option.item_count >= 2, "EncryptedModelOption should contain models including Rainmaker")

	var encrypted_code_input = modal.get_node("%EncryptedCodeInput")
	assert(encrypted_code_input != null, "EncryptedCodeInput LineEdit must exist")

	modal.queue_free()
	print("  PASS: Modal loads with 3 tabs and dedicated Encrypted Bluetooth UI.")

	print("\n=== ALL TESTS PASSED SUCCESSFULLY ===")
	quit(0)
