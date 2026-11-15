extends SceneTree

func _initialize() -> void:
	print("==================================================")
	print("Running Ball Rolling Physics Verification Tests")
	print("==================================================")

	var ball_script = load("res://Player/ball.gd")
	if ball_script == null:
		push_error("Could not load ball.gd")
		quit(1)
		return

	var ball = ball_script.new()
	root.add_child(ball)

	# Verify surface parameters under recalibrated green speeds
	print("\n--- Test 1: Verifying Surface Rolling Friction Parameters ---")
	# At Tour speed (15.0), green speed is calibrated to legacy standard 10.0 speed
	GlobalSettings.range_settings.green_speed.set_value(15.0)
	ball.set_surface(PhysicsEnums.SurfaceType.FAIRWAY)
	print("Fairway rolling friction (Tour 15.0): %.4f" % ball._rolling_friction)
	assert(ball._rolling_friction >= 0.080 and ball._rolling_friction <= 0.090, "Fairway friction at speed 15 should be ~0.085")

	ball.set_surface(PhysicsEnums.SurfaceType.GREEN)
	print("Green rolling friction (Tour 15.0): %.4f" % ball._rolling_friction)
	assert(ball._rolling_friction >= 0.050 and ball._rolling_friction <= 0.060, "Green friction at speed 15 should be ~0.056")

	# At default speed (10.0), green speed is shifted to legacy 5.0 speed
	GlobalSettings.range_settings.green_speed.set_value(10.0)
	ball.set_surface(PhysicsEnums.SurfaceType.GREEN)
	print("Green rolling friction (Default 10.0): %.4f" % ball._rolling_friction)
	assert(ball._rolling_friction >= 0.105 and ball._rolling_friction <= 0.120, "Green friction at default speed 10 should be ~0.112 (legacy 5.0 speed)")

	ball.set_surface(PhysicsEnums.SurfaceType.ROUGH)
	print("Rough rolling friction: %.4f" % ball._rolling_friction)
	assert(ball._rolling_friction >= 0.160 and ball._rolling_friction <= 0.210, "Rough friction should be ~0.175-0.200")

	# Verify Rough friction is greater than Green friction
	ball.set_surface(PhysicsEnums.SurfaceType.GREEN)
	var gr_fric = ball._rolling_friction
	ball.set_surface(PhysicsEnums.SurfaceType.ROUGH)
	var rough_fric = ball._rolling_friction
	assert(rough_fric > gr_fric, "Rough rolling friction must be greater than Green rolling friction")
	print("PASS: Surface parameters correctly calibrated.")

	# Test BallPhysics calculate_forces with slope
	print("\n--- Test 2: Verifying BallPhysics Forces on Downhill Slope ---")
	var physics_class = load("res://addons/openfairway/physics/BallPhysics.cs")
	var params_class = load("res://addons/openfairway/physics/PhysicsParams.cs")
	if physics_class != null and params_class != null:
		var bp = physics_class.new()
		var p = params_class.new()
		p.RollingFriction = 0.085
		p.KineticFriction = 0.44
		p.SlopeForceScale = 0.5
		p.FloorNormal = Vector3(0.087, 0.996, 0.0).normalized() # ~5 degree slope

		# At 5 m/s rolling down slope
		var vel_high = Vector3(5.0, 0.0, 0.0)
		var forces_high = bp.CalculateForces(vel_high, Vector3.ZERO, true, p)
		print("At 5.0 m/s: force = %s, net ax = %.3f m/s^2" % [forces_high, forces_high.x / bp.BallMass])
		# Force should be opposing velocity (negative X) to decelerate
		assert(forces_high.x < 0.0, "Ball at 5.0 m/s on mild slope must still experience braking force")

		# At near rest (0.2 m/s), slope force scale hold should prevent indefinite creeping
		var vel_low = Vector3(0.2, 0.0, 0.0)
		var forces_low = bp.CalculateForces(vel_low, Vector3.ZERO, true, p)
		print("At 0.2 m/s: force = %s, net ax = %.3f m/s^2" % [forces_low, forces_low.x / bp.BallMass])
		assert(forces_low.x < 0.0, "Ball at 0.2 m/s must experience braking force to reach rest")
		print("PASS: Downhill slope force properly bounded without endless creep.")

	# Test 3: Verify Ball Visual Mesh Scaling and Rolling Surface Height
	print("\n--- Test 3: Verifying Ball Visual Mesh Scaling & Rolling Surface Elevation ---")
	var expected_scale = ball._ball_radius / 1.007168
	assert(is_equal_approx(ball._ball_mesh.scale.x, expected_scale), "Ball mesh scale must match physical radius")
	print("PASS: Ball mesh scale correctly matched to physical radius: %.5f (radius: %.5f)" % [ball._ball_mesh.scale.x, ball._ball_radius])

	# While rolling in rough, ball must NOT sink underground (target_y = 0.0)
	ball.state = PhysicsEnums.BallState.ROLLOUT
	ball.lie_type = "rough"
	ball.set_surface(PhysicsEnums.SurfaceType.ROUGH)
	ball._process(0.016)
	assert(is_equal_approx(ball._ball_mesh.position.y, 0.0), "Rolling ball in rough must stay at Y=0 on surface, not sink")
	print("PASS: Ball rolling in rough stays on surface without sinking.")

	# When ball comes to rest in rough, ball settles into grass
	ball.state = PhysicsEnums.BallState.REST
	for i in range(30):
		ball._process(0.016)
	assert(ball._ball_mesh.position.y < -0.010, "Ball resting in rough must settle into grass")
	print("PASS: Ball resting in rough settles into grass (mesh Y: %.4f)." % ball._ball_mesh.position.y)

	ball.queue_free()
	print("\n==================================================")
	print("All Ball Rolling Physics Tests PASSED!")
	print("==================================================")
	quit(0)
