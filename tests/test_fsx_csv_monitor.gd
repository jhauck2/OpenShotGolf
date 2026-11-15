extends SceneTree

const FsxCsvMonitorScript = preload("res://addons/launch_monitors/fsx/fsx_csv_monitor.gd")

func _initialize() -> void:
	print("\n=======================================================")
	print("  Running Bushnell GC3 FSX CSV Monitor Tests")
	print("=======================================================\n")

	for i in range(10):
		await process_frame

	test_csv_row_parsing()
	test_metric_float_parsing()
	test_header_matching_and_shot_parsing()
	test_spin_resolution()
	await test_file_monitoring_and_signals()
	test_launch_monitor_manager_fsx_integration()
	test_launch_monitor_connect_modal_bushnell_tab()

	print("\n=======================================================")
	print("  ALL BUSHNELL GC3 FSX CSV MONITOR TESTS PASSED!       ")
	print("=======================================================\n")
	quit(0)


func test_csv_row_parsing() -> void:
	print("--- Test 1: RFC 4180 CSV Row Parsing ---")
	var line1 = '1,Driver,155.4,11.2,0.8 R,"2,450",-1.2,107.2,1.5 R'
	var tokens1 = FsxCsvMonitorScript.parse_csv_row(line1)
	assert(tokens1.size() == 9, "Expected 9 tokens, got %d" % tokens1.size())
	assert(tokens1[0] == "1", "Token 0 should be '1'")
	assert(tokens1[1] == "Driver", "Token 1 should be 'Driver'")
	assert(tokens1[4] == "0.8 R", "Token 4 should be '0.8 R'")
	assert(tokens1[5] == "2,450", "Token 5 should be '2,450' with quotes stripped")

	var line2 = '"John ""The Pro"" Doe",7-Iron,"115.0 mph"'
	var tokens2 = FsxCsvMonitorScript.parse_csv_row(line2)
	assert(tokens2.size() == 3, "Expected 3 tokens, got %d" % tokens2.size())
	assert(tokens2[0] == 'John "The Pro" Doe', "Escaped quotes should be handled")
	assert(tokens2[2] == "115.0 mph", "Token 2 should preserve unit before parsing")
	print("  PASS: CSV row parsing handles standard and quoted entries.")


func test_metric_float_parsing() -> void:
	print("\n--- Test 2: Metric Float Parsing (Units, Signs, Directions) ---")
	assert(is_equal_approx(FsxCsvMonitorScript.parse_metric_float("155.4"), 155.4), "Plain float failed")
	assert(is_equal_approx(FsxCsvMonitorScript.parse_metric_float("-3.5"), -3.5), "Negative float failed")
	assert(is_equal_approx(FsxCsvMonitorScript.parse_metric_float("2.4 R"), 2.4), "Right direction should be positive")
	assert(is_equal_approx(FsxCsvMonitorScript.parse_metric_float("1.8 L"), -1.8), "Left direction should be negative")
	assert(is_equal_approx(FsxCsvMonitorScript.parse_metric_float("2,450"), 2450.0), "Comma separated number failed")
	assert(is_equal_approx(FsxCsvMonitorScript.parse_metric_float("155.2 mph"), 155.2), "Unit suffix mph failed")
	assert(is_equal_approx(FsxCsvMonitorScript.parse_metric_float("11.5°"), 11.5), "Degree symbol failed")
	assert(is_equal_approx(FsxCsvMonitorScript.parse_metric_float("2.1 In-to-Out"), 2.1), "In-to-out should be positive")
	assert(is_equal_approx(FsxCsvMonitorScript.parse_metric_float("1.5 Out-to-In"), -1.5), "Out-to-in should be negative")
	assert(is_equal_approx(FsxCsvMonitorScript.parse_metric_float("1.0 Open"), 1.0), "Open should be positive")
	assert(is_equal_approx(FsxCsvMonitorScript.parse_metric_float("0.8 Closed"), -0.8), "Closed should be negative")
	assert(is_equal_approx(FsxCsvMonitorScript.parse_metric_float(""), 0.0), "Empty should be 0.0")
	assert(is_equal_approx(FsxCsvMonitorScript.parse_metric_float("N/A"), 0.0), "N/A should be 0.0")
	print("  PASS: Directional and formatted metrics parsed correctly.")


func test_header_matching_and_shot_parsing() -> void:
	print("\n--- Test 3: Header Matching & Full Shot Parsing ---")
	var monitor = FsxCsvMonitorScript.new()
	root.add_child(monitor)

	var header_line = "Shot,Club,Ball Speed (mph),Launch Angle (deg),Launch Direction (deg),Total Spin (rpm),Spin Axis (deg),Club Speed (mph),Club Path (deg),Angle of Attack (deg)"
	var header_tokens = FsxCsvMonitorScript.parse_csv_row(header_line)
	monitor._header_indices = monitor._match_header_tokens(header_tokens)

	assert(monitor._header_indices.has("BallSpeed"), "Header must identify BallSpeed")
	assert(monitor._header_indices.has("VLA"), "Header must identify VLA")
	assert(monitor._header_indices.has("HLA"), "Header must identify HLA")
	assert(monitor._header_indices.has("TotalSpin"), "Header must identify TotalSpin")
	assert(monitor._header_indices.has("SpinAxis"), "Header must identify SpinAxis")
	assert(monitor._header_indices.has("ClubSpeed"), "Header must identify ClubSpeed")

	var row_line = "1,Driver,156.4,11.8,0.5 R,2480,-1.4,108.0,1.8 R,2.0"
	var row_tokens = FsxCsvMonitorScript.parse_csv_row(row_line)
	var shot = monitor.parse_csv_shot_data(row_tokens)

	assert(is_equal_approx(float(shot["BallSpeed"]), 156.4), "BallSpeed mismatch")
	assert(is_equal_approx(float(shot["VLA"]), 11.8), "VLA mismatch")
	assert(is_equal_approx(float(shot["HLA"]), 0.5), "HLA mismatch")
	assert(is_equal_approx(float(shot["TotalSpin"]), 2480.0), "TotalSpin mismatch")
	assert(is_equal_approx(float(shot["SpinAxis"]), -1.4), "SpinAxis mismatch")
	assert(is_equal_approx(float(shot["ClubSpeed"]), 108.0), "ClubSpeed mismatch")
	assert(is_equal_approx(float(shot["ClubPath"]), 1.8), "ClubPath mismatch")
	assert(is_equal_approx(float(shot["AttackAngle"]), 2.0), "AttackAngle mismatch")
	assert(shot["Club"] == "Driver", "Club name mismatch")
	assert(shot.has("SmashFactor") and float(shot["SmashFactor"]) > 1.4, "SmashFactor should be computed")

	monitor.queue_free()
	print("  PASS: Standard FSX Play CSV header and row parsed with high precision.")


func test_spin_resolution() -> void:
	print("\n--- Test 4: Spin Metrics Resolution ---")
	var monitor = FsxCsvMonitorScript.new()
	root.add_child(monitor)

	# Case A: Total spin and spin axis -> computes backspin and sidespin
	monitor._header_indices = {
		"BallSpeed": 0,
		"VLA": 1,
		"TotalSpin": 2,
		"SpinAxis": 3
	}
	var shotA = monitor.parse_csv_shot_data(PackedStringArray(["150.0", "12.0", "2000", "0.0"]))
	assert(is_equal_approx(float(shotA["BackSpin"]), 2000.0), "BackSpin for 0 axis should match total spin")
	assert(is_equal_approx(float(shotA["SideSpin"]), 0.0), "SideSpin for 0 axis should be 0")

	# Case B: Backspin and sidespin -> computes total spin and spin axis
	monitor._header_indices = {
		"BallSpeed": 0,
		"VLA": 1,
		"BackSpin": 2,
		"SideSpin": 3
	}
	var shotB = monitor.parse_csv_shot_data(PackedStringArray(["120.0", "18.0", "6000", "500 R"]))
	assert(float(shotB["TotalSpin"]) > 6000.0, "TotalSpin should be hypotenuse")
	assert(float(shotB["SpinAxis"]) > 0.0, "SpinAxis for right sidespin should be positive")

	monitor.queue_free()
	print("  PASS: Backspin, sidespin, and spin axis cross-calculations verified.")


func test_file_monitoring_and_signals() -> void:
	print("\n--- Test 5: Live File Polling & Signal Emission ---")
	var test_csv_path = "user://test_fsx_shots.csv"

	# Clean up any existing file
	if FileAccess.file_exists(test_csv_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_csv_path))

	# Write initial file with header and 1 shot
	var f = FileAccess.open(test_csv_path, FileAccess.WRITE)
	f.store_line("Shot,Club,Ball Speed,Launch Angle,Launch Direction,Total Spin,Spin Axis")
	f.store_line("1,Driver,150.0,11.0,0.0,2400,0.0")
	f.close()

	var monitor = FsxCsvMonitorScript.new()
	root.add_child(monitor)

	var shots_received: Array[Dictionary] = []
	monitor.shot_received.connect(func(data): shots_received.append(data))

	monitor.start_monitoring(test_csv_path)
	assert(monitor.is_monitoring, "Monitor should be active")
	assert(shots_received.is_empty(), "Baseline shot should NOT be re-emitted upon connect")

	# Append a second shot
	var f2 = FileAccess.open(test_csv_path, FileAccess.READ_WRITE)
	f2.seek_end()
	f2.store_line("2,3-Wood,142.5,13.2,1.2 R,2950,-2.1")
	f2.close()

	# Poll file
	monitor.poll_file()

	assert(shots_received.size() == 1, "Expected 1 new shot received, got %d" % shots_received.size())
	var shot = shots_received[0]
	assert(is_equal_approx(float(shot["BallSpeed"]), 142.5), "BallSpeed should be 142.5")
	assert(is_equal_approx(float(shot["VLA"]), 13.2), "VLA should be 13.2")
	assert(is_equal_approx(float(shot["HLA"]), 1.2), "HLA should be 1.2")
	assert(is_equal_approx(float(shot["TotalSpin"]), 2950.0), "TotalSpin should be 2950")
	assert(is_equal_approx(float(shot["SpinAxis"]), -2.1), "SpinAxis should be -2.1")

	# Clean up test file
	monitor.stop_monitoring()
	monitor.queue_free()
	if FileAccess.file_exists(test_csv_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_csv_path))

	print("  PASS: Live file polling, baseline tracking, and signal delivery verified.")


func test_launch_monitor_manager_fsx_integration() -> void:
	print("\n--- Test 6: LaunchMonitorManager Autoload & Driver Integration ---")
	assert(root.has_node("LaunchMonitorManager"), "Autoload LaunchMonitorManager must be present in tree")
	var lm = root.get_node("LaunchMonitorManager")

	assert(lm.has_method("start_fsx_csv_monitoring"), "LaunchMonitorManager must have start_fsx_csv_monitoring")
	assert(lm.has_method("stop_fsx_csv_monitoring"), "LaunchMonitorManager must have stop_fsx_csv_monitoring")
	assert(lm.has_method("get_fsx_csv_monitor"), "LaunchMonitorManager must have get_fsx_csv_monitor")

	var fsx_monitor = lm.get_fsx_csv_monitor()
	assert(fsx_monitor != null, "FsxCsvMonitor instance must be initialized on LaunchMonitorManager")

	var hits_received: Array[Dictionary] = []
	var hit_callable = func(data): hits_received.append(data)
	lm.hit_ball.connect(hit_callable)

	lm.start_fsx_csv_monitoring("user://test_lm_fsx.csv")
	assert(lm._active_driver == "bushnell_fsx", "_active_driver should be 'bushnell_fsx'")
	assert(lm.is_ready, "Launch monitor manager must become ready")

	# Test simulate shot through fsx monitor
	fsx_monitor.simulate_test_shot("7-Iron", 118.5, 17.5, -0.4, 6500.0, 1.2)
	assert(hits_received.size() == 1, "hit_ball signal must be emitted through LaunchMonitorManager")
	var hit = hits_received[0]
	assert(is_equal_approx(float(hit["BallSpeed"]), 118.5), "Simulated BallSpeed must match")
	assert(hit["Club"] == "7-Iron", "Simulated club must match")

	lm.hit_ball.disconnect(hit_callable)
	lm.stop_fsx_csv_monitoring()
	assert(not lm.is_ready, "Launch monitor manager should not be ready after stop")
	print("  PASS: LaunchMonitorManager start, stop, ready, and hit_ball pipeline verified.")


func test_launch_monitor_connect_modal_bushnell_tab() -> void:
	print("\n--- Test 7: LaunchMonitorConnectModal UI & Bushnell GC3 Tab ---")
	var modal_scene = load("res://UI/LaunchMonitorConnectModal/launch_monitor_connect_modal.tscn")
	assert(modal_scene != null, "Modal scene must exist and load")

	var modal = modal_scene.instantiate()
	root.add_child(modal)

	var tab_container: TabContainer = modal.get_node("%TabContainer")
	assert(tab_container != null, "TabContainer must exist")
	assert(tab_container.get_tab_count() == 4, "Expected 4 tabs in connection menu, got %d" % tab_container.get_tab_count())

	var tab_3_title = tab_container.get_tab_title(3)
	assert(tab_3_title.contains("Bushnell") or tab_3_title.contains("GC3"), "Tab 3 title must mention Bushnell / GC3: '%s'" % tab_3_title)

	var bushnell_tab = modal.get_node("%BushnellTab")
	assert(bushnell_tab != null, "BushnellTab node must exist in modal")

	var path_input: LineEdit = modal.get_node("%BushnellCsvPathInput")
	assert(path_input != null, "BushnellCsvPathInput must exist")

	var browse_btn: Button = modal.get_node("%BushnellBrowseButton")
	assert(browse_btn != null, "BushnellBrowseButton must exist")

	var autodetect_btn: Button = modal.get_node("%BushnellAutoDetectButton")
	assert(autodetect_btn != null, "BushnellAutoDetectButton must exist")

	var connect_btn: Button = modal.get_node("%BushnellConnectButton")
	assert(connect_btn != null, "BushnellConnectButton must exist")

	var disconnect_btn: Button = modal.get_node("%BushnellDisconnectButton")
	assert(disconnect_btn != null, "BushnellDisconnectButton must exist")

	var test_shot_btn: Button = modal.get_node("%BushnellTestShotButton")
	assert(test_shot_btn != null, "BushnellTestShotButton must exist")

	# Test clicking AutoDetect button
	autodetect_btn.emit_signal("pressed")
	assert(path_input.text != "", "Auto-detect must populate CSV path input")

	# Test switching to tab 3
	tab_container.current_tab = 3
	modal._on_tab_changed(3)
	if root.has_node("GlobalSettings"):
		var gs = root.get_node("GlobalSettings")
		assert(int(gs.range_settings.launch_monitor_tab.value) == 3, "GlobalSettings must record tab 3 as saved tab")

	modal.queue_free()
	print("  PASS: Connection menu Bushnell GC3 tab layout, controls, and persistence verified.")

