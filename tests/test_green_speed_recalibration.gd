extends SceneTree

func _initialize() -> void:
	print("==================================================")
	print("Running Green Speed Recalibration Tests")
	print("==================================================")

	var gs = root.get_node_or_null("GlobalSettings")
	if gs == null:
		push_error("GlobalSettings autoload not found")
		quit(1)
		return

	# Test 1: Setting bounds
	print("\n--- Test 1: Green Speed Setting Bounds ---")
	var setting = gs.range_settings.green_speed
	print("Min: %.1f, Max: %.1f, Default: %.1f" % [setting.min_value, setting.max_value, setting.default])
	assert(is_equal_approx(setting.min_value, 5.0), "Min value should be 5.0")
	assert(is_equal_approx(setting.max_value, 16.0), "Max value should be 16.0")
	assert(is_equal_approx(setting.default, 10.0), "Default value should be 10.0")
	print("PASS: Setting bounds correctly configured (5.0 to 16.0, default 10.0).")

	# Test 2: Effective green speed mapping
	print("\n--- Test 2: Effective Green Speed Calculations ---")
	# Value 10 (default) -> effective speed 5.0 (speed of 5 currently)
	setting.set_value(10.0)
	var eff_10 = gs.get_effective_green_speed()
	print("Setting 10.0 -> Effective Speed: %.4f" % eff_10)
	assert(is_equal_approx(eff_10, 5.0), "Setting 10.0 must yield effective speed of 5.0")

	# Value 15 -> effective speed 10.0 (speed that 10 previously was)
	setting.set_value(15.0)
	var eff_15 = gs.get_effective_green_speed()
	print("Setting 15.0 -> Effective Speed: %.4f" % eff_15)
	assert(is_equal_approx(eff_15, 10.0), "Setting 15.0 must yield effective speed of 10.0")

	# Value 5 -> effective speed slower than 10 speed (3.333 < 5.0)
	setting.set_value(5.0)
	var eff_5 = gs.get_effective_green_speed()
	print("Setting 5.0  -> Effective Speed: %.4f" % eff_5)
	assert(eff_5 < eff_10, "Setting 5.0 must be slower than Setting 10.0")
	assert(is_equal_approx(eff_5, 10.0 / 3.0), "Setting 5.0 must yield 10.0 / 3.0 (~3.333)")
	print("PASS: Effective speed mapping correctly shifts 5 -> 10, 10 -> 15, and 5 is slower.")

	# Test 3: Ball friction verification
	print("\n--- Test 3: Physical Green Rolling Friction Verification ---")
	var ball_script = load("res://Player/ball.gd")
	assert(ball_script != null, "ball.gd must load")
	var ball = ball_script.new()
	ball._init_openfairway_instances()
	ball._connect_settings()
	root.add_child(ball)

	# Setting 15.0 -> legacy 10.0 friction (~0.056)
	setting.set_value(15.0)
	ball.set_surface(PhysicsEnums.SurfaceType.GREEN)
	var f_15 = ball._rolling_friction
	print("Green Rolling Friction at 15.0: %.4f" % f_15)
	assert(is_equal_approx(f_15, 0.056), "Friction at 15.0 should be ~0.056")

	# Setting 10.0 -> legacy 5.0 friction (~0.112)
	setting.set_value(10.0)
	ball.set_surface(PhysicsEnums.SurfaceType.GREEN)
	var f_10 = ball._rolling_friction
	print("Green Rolling Friction at 10.0: %.4f" % f_10)
	assert(is_equal_approx(f_10, 0.112), "Friction at 10.0 should be ~0.112")

	# Setting 5.0 -> higher friction (~0.168), slower roll
	setting.set_value(5.0)
	ball.set_surface(PhysicsEnums.SurfaceType.GREEN)
	var f_5 = ball._rolling_friction
	print("Green Rolling Friction at 5.0:  %.4f" % f_5)
	assert(is_equal_approx(f_5, 0.168), "Friction at 5.0 should be ~0.168")
	assert(f_5 > f_10 and f_10 > f_15, "Friction order must be 5.0 > 10.0 > 15.0")
	print("PASS: Physical rolling friction matches speed shifting requirements.")

	# Test 4: TensionManager Deceleration
	print("\n--- Test 4: TensionManager Deceleration ---")
	var tm = root.get_node_or_null("TensionManager")
	if tm != null:
		setting.set_value(15.0)
		var d_15 = tm.get_effective_rolling_deceleration()
		print("Decel at 15.0: %.4f m/s^2" % d_15)
		assert(is_equal_approx(d_15, 0.056 * 9.81), "Decel at 15.0 must match 0.056 * 9.81")

		setting.set_value(10.0)
		var d_10 = tm.get_effective_rolling_deceleration()
		print("Decel at 10.0: %.4f m/s^2" % d_10)
		assert(is_equal_approx(d_10, 0.112 * 9.81), "Decel at 10.0 must match 0.112 * 9.81")

		setting.set_value(5.0)
		var d_5 = tm.get_effective_rolling_deceleration()
		print("Decel at 5.0:  %.4f m/s^2" % d_5)
		assert(is_equal_approx(d_5, 0.168 * 9.81), "Decel at 5.0 must match 0.168 * 9.81")
		print("PASS: TensionManager deceleration matches ball physics.")

	# Reset setting to default 10.0
	setting.set_value(10.0)
	ball.queue_free()

	print("\n==================================================")
	print("ALL GREEN SPEED RECALIBRATION TESTS PASSED! 🎉")
	print("==================================================")
	quit(0)
