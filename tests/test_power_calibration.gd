extends SceneTree

var _tested := false

func _initialize() -> void:
	print("=== Running Power Calibration Unit Tests ===")
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	if _tested:
		return
	_tested = true
	await _run_tests()

func _run_tests() -> void:
	var gs = root.get_node_or_null("GlobalSettings")
	assert(gs != null, "GlobalSettings autoload must exist")
	var orig_value = gs.range_settings.power_calibration_percent.value
	var orig_suppress = gs.suppress_save
	gs.suppress_save = true

	# Test 1: Default value and bounds
	print("\n--- Test 1: Setting Default & Bounds ---")
	var setting: Setting = gs.range_settings.power_calibration_percent
	assert(setting != null, "power_calibration_percent setting must exist")
	assert(is_equal_approx(float(orig_value), 0.0) or (float(setting.min_value) == -10.0 and float(setting.max_value) == 10.0), "Bounds must be -10 to 10")
	assert(float(setting.min_value) == -10.0, "min_value must be -10.0")
	assert(float(setting.max_value) == 10.0, "max_value must be 10.0")
	var fresh_rs := RangeSettings.new()
	assert(is_equal_approx(float(fresh_rs.power_calibration_percent.value), 0.0), "Default power_calibration_percent must be 0.0")
	print("  PASS: Default is 0.0%, range is [-10.0%, +10.0%].")

	# Test 2: Multiplier calculation & clamping
	print("\n--- Test 2: Multiplier Calculation ---")
	assert(is_equal_approx(PowerCalibration.calculate_multiplier(0.0), 1.0), "0% -> 1.0")
	assert(is_equal_approx(PowerCalibration.calculate_multiplier(10.0), 1.1), "+10% -> 1.1")
	assert(is_equal_approx(PowerCalibration.calculate_multiplier(-10.0), 0.9), "-10% -> 0.9")
	assert(is_equal_approx(PowerCalibration.calculate_multiplier(25.0), 1.1), "+25% clamped -> 1.1")
	assert(is_equal_approx(PowerCalibration.calculate_multiplier(-25.0), 0.9), "-25% clamped -> 0.9")
	print("  PASS: Multipliers and clamping verified.")

	# Test 3: 0% leaves shot data unchanged
	print("\n--- Test 3: 0% Default Leaves Shot Unchanged ---")
	setting.value = 0.0
	var shot_zero := {"Speed": 120.0, "BallSpeed": 120.0, "ClubSpeed": 80.0, "SmashFactor": 1.5}
	PowerCalibration.apply_calibration(shot_zero)
	assert(is_equal_approx(float(shot_zero["Speed"]), 120.0), "Speed unchanged at 0%")
	assert(is_equal_approx(float(shot_zero["BallSpeed"]), 120.0), "BallSpeed unchanged at 0%")
	assert(is_equal_approx(float(shot_zero["SmashFactor"]), 1.5), "SmashFactor unchanged at 0%")
	print("  PASS: 0% leaves shot data untouched.")

	# Test 4: +10% boost and SmashFactor update + idempotency
	print("\n--- Test 4: +10% Power Calibration & Idempotency ---")
	setting.value = 10.0
	var shot_up := {"Speed": 100.0, "BallSpeed": 100.0, "ClubSpeed": 70.0, "SmashFactor": 100.0 / 70.0}
	PowerCalibration.apply_calibration(shot_up)
	assert(is_equal_approx(float(shot_up["Speed"]), 110.0), "Speed must be 110.0 at +10%")
	assert(is_equal_approx(float(shot_up["BallSpeed"]), 110.0), "BallSpeed must be 110.0 at +10%")
	assert(is_equal_approx(float(shot_up["SmashFactor"]), 110.0 / 70.0), "SmashFactor must match 110/70")
	# Second call must be a no-op
	PowerCalibration.apply_calibration(shot_up)
	assert(is_equal_approx(float(shot_up["Speed"]), 110.0), "Second call must not double-scale")
	print("  PASS: +10% applied accurately and idempotently.")

	# Test 5: -10% reduction (without ClubSpeed)
	print("\n--- Test 5: -10% Power Calibration ---")
	setting.value = -10.0
	var shot_down := {"Speed": 100.0, "BallSpeed": 100.0, "SmashFactor": 1.40}
	PowerCalibration.apply_calibration(shot_down)
	assert(is_equal_approx(float(shot_down["Speed"]), 90.0), "Speed must be 90.0 at -10%")
	assert(is_equal_approx(float(shot_down["BallSpeed"]), 90.0), "BallSpeed must be 90.0 at -10%")
	assert(is_equal_approx(float(shot_down["SmashFactor"]), 1.26), "SmashFactor must scale to 1.26")
	print("  PASS: -10% applied accurately.")

	# Test 6: Settings UI controls in Gameplay tab
	print("\n--- Test 6: Settings UI Controls ---")
	setting.value = 0.0
	var settings_scene = load("res://UI/Settings/RangeSettings/range_settings.tscn")
	assert(settings_scene != null, "range_settings.tscn must load")
	var settings_ui = settings_scene.instantiate()
	root.add_child(settings_ui)
	await process_frame
	await process_frame

	var slider = settings_ui.find_child("PowerCalibrationSlider", true, false) as HSlider
	var lbl = settings_ui.find_child("PowerCalibrationLabel", true, false) as Label
	var minus_btn = settings_ui.find_child("PowerCalibrationMinusBtn", true, false) as Button
	var plus_btn = settings_ui.find_child("PowerCalibrationPlusBtn", true, false) as Button
	assert(slider != null, "PowerCalibrationSlider must exist")
	assert(lbl != null, "PowerCalibrationLabel must exist")
	assert(minus_btn != null, "PowerCalibrationMinusBtn must exist")
	assert(plus_btn != null, "PowerCalibrationPlusBtn must exist")
	assert(is_equal_approx(slider.min_value, -10.0), "Slider min must be -10")
	assert(is_equal_approx(slider.max_value, 10.0), "Slider max must be 10")
	assert(is_equal_approx(slider.value, 0.0), "Slider default must be 0")
	assert(lbl.text == "Power Adjust: 0%", "Default label must be 'Power Adjust: 0%', got: " + lbl.text)

	plus_btn.emit_signal("pressed")
	await process_frame
	assert(is_equal_approx(float(setting.value), 1.0), "Plus button must increment setting to 1.0")
	assert(lbl.text == "Power Adjust: +1%", "Label must update to 'Power Adjust: +1%', got: " + lbl.text)

	minus_btn.emit_signal("pressed")
	minus_btn.emit_signal("pressed")
	await process_frame
	assert(is_equal_approx(float(setting.value), -1.0), "Minus button twice must decrement setting to -1.0")
	assert(lbl.text == "Power Adjust: -1%", "Label must update to 'Power Adjust: -1%', got: " + lbl.text)
	print("  PASS: Settings UI controls and interactions verified.")

	settings_ui.queue_free()
	setting.value = orig_value
	gs.suppress_save = orig_suppress
	print("\n=== ALL POWER CALIBRATION TESTS PASSED ===")
	quit(0)
