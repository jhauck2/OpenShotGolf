extends SceneTree

const FlagBuilder = preload("res://Courses/Range/flag_builder.gd")

var _started := false


func _process(_delta: float) -> bool:
	if _started:
		return false
	_started = true
	call_deferred("_run_tests")
	return false


func _run_tests() -> void:
	print("\n=======================================================")
	print("STARTING TEST: Hole & Ball Ground Alignment")
	print("=======================================================")

	_test_cup_slope_alignment()
	await _test_layer4_surface_zone_separation()

	print("ALL HOLE & BALL GROUND ALIGNMENT TESTS PASSED!")
	quit(0)


func _test_cup_slope_alignment() -> void:
	var pin := Node3D.new()
	pin.name = "TestFlagPin"
	root.add_child(pin)

	FlagBuilder.build_flag_pin(pin, 2.5, Color(0.95, 0.12, 0.12), 0.054, "Medium")
	var sloped_normal := Vector3(0.15, 0.985, -0.08).normalized()
	FlagBuilder.align_cup_to_normal(pin, sloped_normal)

	var cup_interior := pin.get_node_or_null("CupInterior") as Node3D
	var cup_white := pin.get_node_or_null("CupWhite") as Node3D
	var cup_dark := pin.get_node_or_null("Cup") as Node3D
	var pole := pin.get_node_or_null("Pole") as Node3D

	assert(cup_interior != null, "CupInterior must exist")
	assert(cup_white != null, "CupWhite must exist")
	assert(cup_dark != null, "Cup bottom must exist")
	assert(pole != null, "Pole must exist")

	assert(cup_interior.basis.y.distance_to(sloped_normal) < 0.001,
		"CupInterior +Y must align with sloped green normal")
	assert(cup_white.basis.y.distance_to(sloped_normal) < 0.001,
		"CupWhite +Y must align with sloped green normal")
	assert(cup_dark.basis.y.distance_to(sloped_normal) < 0.001,
		"Cup bottom +Y must align with sloped green normal")
	assert(pole.basis.y.distance_to(Vector3.UP) < 0.001,
		"Flagstick pole must remain strictly vertical in world gravity")

	var expected_white_pos := sloped_normal * (-FlagBuilder.CUP_SOIL_DEPTH - FlagBuilder.CUP_LINER_HEIGHT * 0.5)
	assert(cup_white.position.distance_to(expected_white_pos) < 0.0005,
		"CupWhite must be recessed along -surface_normal")

	# Guard: steep / invalid normal falls back safely to flat identity
	assert(FlagBuilder.basis_from_surface_normal(Vector3(1.0, 0.1, 0.0)) == Basis.IDENTITY,
		"Overly steep normal must fall back to Basis.IDENTITY")
	assert(FlagBuilder.basis_from_surface_normal(Vector3.ZERO) == Basis.IDENTITY,
		"Zero normal must fall back to Basis.IDENTITY")

	pin.queue_free()
	print("  [PASS] Cup slope alignment (rim flush to green, pole vertical)")


func _test_layer4_surface_zone_separation() -> void:
	var holder := Node3D.new()
	holder.name = "TestCourse"
	root.add_child(holder)

	# Authoritative 1:1 visual terrain collider on Layer 1 at y = 2.0
	var terrain_static := StaticBody3D.new()
	terrain_static.name = "TerrainStatic"
	terrain_static.collision_layer = 1
	terrain_static.collision_mask = 0
	terrain_static.set_meta("surface_type", 2)
	var t_shape := CollisionShape3D.new()
	var t_box := BoxShape3D.new()
	t_box.size = Vector3(20.0, 0.2, 20.0)
	t_shape.shape = t_box
	t_shape.position = Vector3(0.0, 1.9, 0.0) # Top face at y = 2.0
	terrain_static.add_child(t_shape)
	holder.add_child(terrain_static)

	# Floating invisible green overlay collider on Layer 4 (bitmask 8) at y = 2.08 (+8cm mismatch)
	var green_overlay := StaticBody3D.new()
	green_overlay.name = "green_Static_999"
	green_overlay.collision_layer = 8
	green_overlay.collision_mask = 0
	green_overlay.set_meta("surface_type", 4)
	var g_shape := CollisionShape3D.new()
	var g_box := BoxShape3D.new()
	g_box.size = Vector3(10.0, 0.02, 10.0)
	g_shape.shape = g_box
	g_shape.position = Vector3(0.0, 2.07, 0.0) # Top face at y = 2.08
	green_overlay.add_child(g_shape)
	holder.add_child(green_overlay)

	await physics_frame
	await physics_frame

	var space := holder.get_world_3d().direct_space_state

	# 1. Layer 1 ground query must hit TerrainStatic at y = 2.0 (NOT the +8cm floating overlay!)
	var ground_q := PhysicsRayQueryParameters3D.create(Vector3(0.0, 10.0, 0.0), Vector3(0.0, -10.0, 0.0), 1)
	ground_q.collide_with_areas = false
	ground_q.collide_with_bodies = true
	var ground_hit := space.intersect_ray(ground_q)
	assert(not ground_hit.is_empty(), "Layer 1 ground raycast must hit TerrainStatic")
	assert(ground_hit["collider"] == terrain_static, "Layer 1 must hit TerrainStatic, not Layer 4 overlay")
	assert(absf(float(ground_hit["position"].y) - 2.0) < 0.002,
		"Ground height must match TerrainStatic y=2.0 (got %.4f)" % float(ground_hit["position"].y))

	# 2. Layer 1|8 surface query (excluding TerrainStatic) must still detect green_Static_999
	var surf_q := PhysicsRayQueryParameters3D.create(Vector3(0.0, 4.0, 0.0), Vector3(0.0, 0.0, 0.0), 1 | 8)
	surf_q.collide_with_areas = false
	surf_q.collide_with_bodies = true
	surf_q.exclude = [terrain_static.get_rid()]
	var surf_hit := space.intersect_ray(surf_q)
	assert(not surf_hit.is_empty(), "Layer 1|8 surface query must detect Layer 4 green overlay")
	assert(surf_hit["collider"] == green_overlay, "Surface query must return green_Static_999")
	assert(int(surf_hit["collider"].get_meta("surface_type")) == 4, "Surface type must remain GREEN (4)")

	holder.queue_free()
	print("  [PASS] Layer 4 surface-zone separation (Layer 1 ground exact, Layer 4 surface detection intact)")
