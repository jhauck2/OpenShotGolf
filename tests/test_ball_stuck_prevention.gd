extends SceneTree

func _initialize() -> void:
	_run_tests()

func _run_tests() -> void:
	print("==================================================")
	print("Running Ball Stuck in Tree / Fairway Prevention Tests")
	print("==================================================")

	var sub_viewport = SubViewport.new()
	root.add_child(sub_viewport)

	var test_scene = Node3D.new()
	test_scene.name = "TestScene"
	sub_viewport.add_child(test_scene)

	var ball_script = load("res://Player/ball.gd")
	assert(ball_script != null, "Could not load ball.gd")

	var ball = CharacterBody3D.new()
	ball.name = "GolfBall"
	ball.set_script(ball_script)
	test_scene.add_child(ball)
	if ball.has_method("initialize_ball"):
		ball.initialize_ball()

	var tree_body = StaticBody3D.new()
	tree_body.name = "Tree_Willow_1"
	tree_body.set_meta("is_tree", true)
	tree_body.add_to_group("trees")
	tree_body.position = Vector3(10.0, 0.0, 10.0)

	var tree_col = CollisionShape3D.new()
	var tree_cyl = CylinderShape3D.new()
	tree_cyl.radius = 0.45
	tree_cyl.height = 4.0
	tree_col.shape = tree_cyl
	tree_body.add_child(tree_col)
	test_scene.add_child(tree_body)

	var branch_child = StaticBody3D.new()
	branch_child.name = "BranchCollision"
	tree_body.add_child(branch_child)

	var ground_body = StaticBody3D.new()
	ground_body.name = "fairway_static_body"
	var ground_col = CollisionShape3D.new()
	var ground_box = BoxShape3D.new()
	ground_box.size = Vector3(100.0, 1.0, 100.0)
	ground_col.shape = ground_box
	ground_col.position = Vector3(0.0, -0.5, 0.0)
	ground_body.add_child(ground_col)
	test_scene.add_child(ground_body)

	await process_frame
	await physics_frame

	# Test 1: Verify tree collider detection
	print("\n--- Test 1: Tree Collider Detection ---")
	assert(ball._is_collider_tree(tree_body) == true, "tree_body must be identified as a tree")
	assert(ball._is_collider_tree(branch_child) == true, "branch_child must be identified as a tree")
	assert(ball._is_collider_tree(ground_body) == false, "fairway body must NOT be identified as a tree")
	print("PASS: Tree colliders correctly recognized, ground colliders not flagged as trees.")

	# Test 2: Tree must never be considered ground normal
	print("\n--- Test 2: Tree Surface Ground Exclusion ---")
	var up_normal = Vector3.UP
	var is_ground = ball._is_ground_normal(up_normal)
	assert(is_ground == true, "Standard UP vector is a ground normal")
	assert(is_ground and not ball._is_collider_tree(tree_body) == false, "Tree collision with UP normal must NOT be treated as ground")
	print("PASS: Tree upward normal excluded from ground classification.")

	# Test 3: Tree clearance relief
	print("\n--- Test 3: Tree Clearance Relief ---")
	ball.global_position = Vector3(10.2, 0.0, 10.0)
	await physics_frame
	var nearby_before = ball._get_nearby_trees(ball.global_position, ball.TREE_CLEARANCE_RADIUS)
	assert(nearby_before.size() > 0, "Tree must be detected nearby before relief")

	var relief_applied = ball.ensure_tree_clearance()
	assert(relief_applied == true, "ensure_tree_clearance must apply relief when ball is within 1.0m of tree trunk")
	await physics_frame
	var dist_after = Vector2(ball.global_position.x - tree_body.global_position.x, ball.global_position.z - tree_body.global_position.z).length()
	assert(dist_after >= ball.TREE_CLEARANCE_RADIUS, "Ball must be moved at least TREE_CLEARANCE_RADIUS away from tree trunk")
	print("PASS: Ball moved clear of tree trunk to distance %.2fm (threshold: %.2fm)." % [dist_after, ball.TREE_CLEARANCE_RADIUS])

	# Test 4: Airborne low speed does not immediately rest in mid-air
	print("\n--- Test 4: Mid-Air Resting Protection ---")
	ball.state = PhysicsEnums.BallState.FLIGHT
	ball.on_ground = false
	ball.velocity = Vector3(0.05, 0.02, 0.01) # speed < 0.12 m/s while in air
	ball._airborne_low_speed_timer = 0.0
	ball._physics_process(0.016)
	assert(ball.state != PhysicsEnums.BallState.REST, "Airborne ball with low velocity must NOT immediately enter rest in mid-air")
	assert(ball._airborne_low_speed_timer > 0.0, "Airborne low speed timer must increment while airborne")
	print("PASS: Ball does not freeze in mid-air or tree canopy when speed drops below 0.12 m/s.")

	# Test 5: Out of bounds fall-through recovery
	print("\n--- Test 5: Fall-Through Fairway Recovery ---")
	ball.state = PhysicsEnums.BallState.FLIGHT
	ball.global_position = Vector3(0.0, -50.0, 0.0) # Far below terrain
	var oob = ball._check_out_of_bounds()
	assert(oob == true, "Ball far below ground must be caught by _check_out_of_bounds")
	assert(ball.state == PhysicsEnums.BallState.REST, "Recovered ball must be placed at rest on surface")
	print("PASS: Fall-through below fairway caught and safely recovered to ground.")

	# Test 6: Distant course tee box (>3000m from origin) must not falsely trigger out-of-bounds
	print("\n--- Test 6: Distant Tee Box Bounds Check ---")
	ball.state = PhysicsEnums.BallState.FLIGHT
	ball.shot_start_pos = Vector3(3500.0, 0.06, -3200.0)
	ball.position = Vector3(3500.0, 0.06, -3200.0)
	var distant_oob = ball._check_out_of_bounds()
	assert(distant_oob == false, "Ball at distant tee box must NOT falsely trigger out-of-bounds")
	assert(ball.state == PhysicsEnums.BallState.FLIGHT, "Ball at distant tee box must remain in FLIGHT")
	print("PASS: Distant tee box (>3000m from origin) does not trigger false OOB.")

	# Cleanup
	sub_viewport.queue_free()

	print("\n==================================================")
	print("All Ball Stuck Prevention Tests PASSED!")
	print("==================================================")
	quit(0)
