extends SceneTree

# test_iron_spin_and_wormburner_physics.gd
# Targeted verification for:
# 1. Low wormburner shots not rolling excessively far on Fairway.
# 2. Iron shots with low-to-mid backspin (< 7500 RPM) rolling forward proportionally
#    more as backspin decreases, with ~5000 RPM rolling out ~8-12 yards forward.
# 3. Approach shots in the 7500-9000 RPM check-and-stop zone doing a slight
#    bounce forward and stopping without spinning backwards.
# 4. High-spin shots (> 9000 RPM) on Greens pulling backwards more as spin increases.

func _sim(adapter, speed: float, vla: float, spin: float, surface: int) -> Dictionary:
	var shot := {
		"BallData": {
			"Speed": speed,
			"VLA": vla,
			"TotalSpin": spin,
			"BackSpin": spin,
			"HLA": 0.0,
			"SideSpin": 0.0
		}
	}
	var res: Dictionary = adapter.SimulateShotFromJson(shot, surface, Vector3.UP)
	var carry := float(res.get("carry_yd", 0.0))
	var total := float(res.get("total_yd", 0.0))
	var land_angle := float(res.get("landing_angle_deg", 0.0))
	return {
		"carry": carry,
		"total": total,
		"roll": total - carry,
		"land_angle": land_angle
	}

func _initialize() -> void:
	print("================================================================================")
	print("Running Iron Spin & Wormburner Physics Verification Tests")
	print("================================================================================")

	var adapter = load("res://addons/openfairway/physics/PhysicsAdapter.cs").new()
	if adapter == null:
		push_error("Could not load PhysicsAdapter.cs")
		quit(1)
		return

	var failures := []

	# -------------------------------------------------------------------------
	# 1. Wormburner shots (low launch angle)
	# -------------------------------------------------------------------------
	print("\n--- 1. Wormburner Shots (Fairway) ---")
	var wb_cases := [
		{"name": "Extreme Wormburner (105 mph, 4° VLA, 2500 rpm)", "speed": 105.0, "vla": 4.0, "spin": 2500.0, "min_roll": 12.0, "max_roll": 30.0},
		{"name": "Fast Wormburner (125 mph, 5° VLA, 2600 rpm)", "speed": 125.0, "vla": 5.0, "spin": 2600.0, "min_roll": 14.0, "max_roll": 32.0},
		{"name": "Low Stinger Runner (110 mph, 10° VLA, 3200 rpm)", "speed": 110.0, "vla": 10.0, "spin": 3200.0, "min_roll": 15.0, "max_roll": 28.0}
	]
	for wb in wb_cases:
		var r := _sim(adapter, float(wb["speed"]), float(wb["vla"]), float(wb["spin"]), PhysicsEnums.SurfaceType.FAIRWAY)
		print("  %-52s | Carry=%5.1f | Land=%4.1f° | Roll=%5.1f yd" % [wb["name"], r["carry"], r["land_angle"], r["roll"]])
		if r["roll"] < float(wb["min_roll"]) or r["roll"] > float(wb["max_roll"]):
			failures.append("%s: FW roll %.1f yd outside [%.1f, %.1f]" % [wb["name"], r["roll"], float(wb["min_roll"]), float(wb["max_roll"])])

	# -------------------------------------------------------------------------
	# 2. Low-to-mid spin iron curve (7-iron ~105 mph, 19° VLA & 8-iron ~95 mph, 22° VLA)
	# -------------------------------------------------------------------------
	print("\n--- 2. Iron Backspin Release Curve (105 mph, 19° VLA) [Tour Green / FW] ---")
	var spin_levels := [3000.0, 5000.0, 6500.0]
	var fw_rolls := {}
	var grn_rolls := {}
	for spin in spin_levels:
		var fw := _sim(adapter, 105.0, 19.0, spin, PhysicsEnums.SurfaceType.FAIRWAY)
		var grn := _sim(adapter, 105.0, 19.0, spin, PhysicsEnums.SurfaceType.GREEN)
		fw_rolls[spin] = fw["roll"]
		grn_rolls[spin] = grn["roll"]
		print("  Spin=%5.0f rpm | Carry=%5.1f | Land=%4.1f° | FW Roll=%5.1f yd | Tour Green Roll=%5.1f yd" % [spin, fw["carry"], fw["land_angle"], fw["roll"], grn["roll"]])

	# Also simulate with in-game Default Green Speed (10.0) multipliers from ball.gd
	var default_grn_adapter = load("res://addons/openfairway/physics/PhysicsAdapter.cs").new()
	var k_mult := pow(2.0, 0.15)
	var r_mult := 2.0
	default_grn_adapter.LoadProfileFromJson('{"KineticFrictionMultiplier": %.4f, "RollingFrictionMultiplier": %.4f}' % [k_mult, r_mult])
	print("\n--- 2b. Iron Backspin on In-Game Default Green (speed=10.0 -> k*%.3f, r*%.3f) ---" % [k_mult, r_mult])
	var def_grn_rolls := {}
	for spin in spin_levels:
		var dg := _sim(default_grn_adapter, 105.0, 19.0, spin, PhysicsEnums.SurfaceType.GREEN)
		var dg8 := _sim(default_grn_adapter, 95.0, 22.0, spin, PhysicsEnums.SurfaceType.GREEN)
		def_grn_rolls[spin] = dg["roll"]
		print("  Spin=%5.0f rpm | 7i(105/19°) DefGreen=%5.1f yd | 8i(95/22°) DefGreen=%5.1f yd" % [spin, dg["roll"], dg8["roll"]])

	if not (fw_rolls[3000.0] > fw_rolls[5000.0] and fw_rolls[5000.0] > fw_rolls[6500.0]):
		failures.append("Fairway iron roll not monotonically decreasing with spin: 3000=%.1f, 5000=%.1f, 6500=%.1f" % [fw_rolls[3000.0], fw_rolls[5000.0], fw_rolls[6500.0]])
	if not (grn_rolls[3000.0] > grn_rolls[5000.0] and grn_rolls[5000.0] > grn_rolls[6500.0]):
		failures.append("Green iron roll not monotonically decreasing with spin: 3000=%.1f, 5000=%.1f, 6500=%.1f" % [grn_rolls[3000.0], grn_rolls[5000.0], grn_rolls[6500.0]])

	if fw_rolls[5000.0] < 7.5 or fw_rolls[5000.0] > 14.0:
		failures.append("5000 RPM iron FW roll %.1f yd outside target ~8-12 yd [7.5, 14.0]" % fw_rolls[5000.0])
	if grn_rolls[5000.0] < 7.5 or grn_rolls[5000.0] > 14.0:
		failures.append("5000 RPM iron Green roll %.1f yd outside target ~8-12 yd [7.5, 14.0]" % grn_rolls[5000.0])

	# -------------------------------------------------------------------------
	# 3. Check-and-stop zone (7500 - 9000 RPM) on Green
	# -------------------------------------------------------------------------
	print("\n--- 3. Check-and-Stop Zone (7500 - 9000 RPM, Green) ---")
	var check_cases := [
		{"name": "8-Iron / PW Check (88 mph, 24° VLA, 8000 rpm)", "speed": 88.0, "vla": 24.0, "spin": 8000.0},
		{"name": "Wedge High Check (85 mph, 28° VLA, 8800 rpm)", "speed": 85.0, "vla": 28.0, "spin": 8800.0}
	]
	for cc in check_cases:
		var grn := _sim(adapter, float(cc["speed"]), float(cc["vla"]), float(cc["spin"]), PhysicsEnums.SurfaceType.GREEN)
		print("  %-52s | Carry=%5.1f | Land=%4.1f° | Green Roll=%5.1f yd" % [cc["name"], grn["carry"], grn["land_angle"], grn["roll"]])
		if grn["roll"] < 0.0 or grn["roll"] > 4.5:
			failures.append("%s: Green roll %.1f yd outside check-and-stop [0.0, 4.5]" % [cc["name"], grn["roll"]])

	# -------------------------------------------------------------------------
	# 4. Spinback zone (> 9000 RPM) on Green
	# -------------------------------------------------------------------------
	print("\n--- 4. Spinback Zone (> 9000 RPM, 87 mph, 29.5° VLA, Green) ---")
	var sb_spins := [9500.0, 10500.0, 11500.0]
	var sb_rolls := {}
	for spin in sb_spins:
		var grn := _sim(adapter, 87.0, 29.5, spin, PhysicsEnums.SurfaceType.GREEN)
		sb_rolls[spin] = grn["roll"]
		print("  Spin=%5.0f rpm | Carry=%5.1f | Land=%4.1f° | Green Roll=%5.1f yd" % [spin, grn["carry"], grn["land_angle"], grn["roll"]])

	if sb_rolls[9500.0] >= 0.0:
		failures.append("9500 RPM steep wedge should spin back (< 0 yd), got %.1f yd" % sb_rolls[9500.0])
	if not (sb_rolls[11500.0] < sb_rolls[10500.0] and sb_rolls[10500.0] < sb_rolls[9500.0]):
		failures.append("Spinback should pull back more as spin increases: 9500=%.1f, 10500=%.1f, 11500=%.1f" % [sb_rolls[9500.0], sb_rolls[10500.0], sb_rolls[11500.0]])

	# -------------------------------------------------------------------------
	# 5. Verify ball.gd default green speed kinetic friction scaling isn't sand-sticky
	# -------------------------------------------------------------------------
	print("\n--- 5. Green Kinetic Friction Scaling in ball.gd ---")
	var ball_script = load("res://Player/ball.gd")
	var ball = ball_script.new()
	ball._init_openfairway_instances()
	ball._connect_settings()
	root.add_child(ball)
	var gs = root.get_node_or_null("GlobalSettings")
	if gs != null:
		gs.range_settings.green_speed.set_value(10.0)
	ball.set_surface(PhysicsEnums.SurfaceType.GREEN)
	print("  Default Green Speed (10.0) -> Green _kinetic_friction=%.3f, _rolling_friction=%.3f" % [ball._kinetic_friction, ball._rolling_friction])
	if ball._kinetic_friction >= 0.90:
		failures.append("Default green _kinetic_friction %.3f is too sticky (>= 0.90)" % ball._kinetic_friction)
	if ball._rolling_friction < 0.105 or ball._rolling_friction > 0.120:
		failures.append("Default green _rolling_friction %.3f drifted outside [0.105, 0.120]" % ball._rolling_friction)
	ball.queue_free()

	print("\n================================================================================")
	if failures.is_empty():
		print("ALL IRON SPIN & WORMBURNER PHYSICS TESTS PASSED!")
		quit(0)
	else:
		for f in failures:
			push_error("FAIL: " + f)
		quit(1)
