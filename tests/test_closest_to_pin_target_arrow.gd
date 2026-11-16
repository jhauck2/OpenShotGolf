extends SceneTree

var _tested := false


func _initialize() -> void:
	print("--- Running test_closest_to_pin_target_arrow.gd ---")
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	if _tested:
		return
	_tested = true
	_run_tests()


func _run_tests() -> void:
	var packed: PackedScene = load("res://Courses/Minigames/ClosestToPin/closest_to_pin.tscn")
	assert(packed != null, "closest_to_pin.tscn must load")

	var scene: Node = packed.instantiate()
	assert(scene != null, "closest_to_pin.tscn must instantiate")
	root.add_child(scene)

	var target_rings := scene.get_node_or_null("TargetRings") as Node3D
	assert(target_rings != null, "ClosestToPin must build TargetRings")

	var arrow := target_rings.get_node_or_null("TargetArrow") as Node3D
	assert(arrow != null, "TargetRings must have TargetArrow pointing at bullseye center")
	assert(is_equal_approx(arrow.position.x, 0.0) and is_equal_approx(arrow.position.z, 0.0),
		"TargetArrow must be centered over bullseye (x=0, z=0)")
	assert(arrow.position.y > 3.25, "TargetArrow must sit above TargetDistLabel")

	var head := arrow.get_node_or_null("ArrowHead") as MeshInstance3D
	assert(head != null and head.mesh is CylinderMesh, "TargetArrow must have ArrowHead CylinderMesh")
	var head_mesh := head.mesh as CylinderMesh
	assert(head_mesh.bottom_radius == 0.0 and head_mesh.top_radius > 0.0,
		"ArrowHead must taper downward to a point at the bottom")

	var shaft := arrow.get_node_or_null("ArrowShaft") as MeshInstance3D
	assert(shaft != null and shaft.mesh is CylinderMesh, "TargetArrow must have ArrowShaft CylinderMesh")

	for child in arrow.get_children():
		assert(not (child is StaticBody3D), "TargetArrow must not have physics colliders")

	scene.queue_free()
	print("PASS: ClosestToPin TargetArrow points down at bullseye center!")
	quit(0)
