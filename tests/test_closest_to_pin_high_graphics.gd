extends SceneTree

var _tested := false


func _initialize() -> void:
	print("--- Running test_closest_to_pin_high_graphics.gd ---")
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

	# Verify driving range flag & metadata
	assert(bool(scene.get("is_driving_range")) == true, "ClosestToPin must have is_driving_range = true")
	assert(MobilePerformance.is_driving_range_node(scene), "MobilePerformance.is_driving_range_node must return true for ClosestToPin")

	# Verify Sky3D environment matches Driving Range
	var sky3d := scene.get_node_or_null("Sky3D")
	assert(sky3d != null, "ClosestToPin must have Sky3D node")
	assert(sky3d.get_node_or_null("SunLight") != null, "Sky3D must have SunLight")
	assert(sky3d.get_node_or_null("Skydome") != null, "Sky3D must have Skydome")
	assert(sky3d.get_node_or_null("TimeOfDay") != null, "Sky3D must have TimeOfDay")
	assert(scene.get_node_or_null("WorldEnvironment") == null, "Fallback WorldEnvironment must not be duplicated when Sky3D exists")

	# Verify Driving Range hitting bays replace the old TeeBox
	assert(scene.get_node_or_null("DrivingRangeBaySetup") != null, "ClosestToPin must spawn DrivingRangeBaySetup")
	assert(scene.get_node_or_null("TeeBox") == null, "Legacy TeeBox must not be spawned when DrivingRangeBaySetup exists")

	# Verify High graphics quality applies realistic range turf shader & HighFidelityBuilder
	MobilePerformance.apply_graphics_quality(scene, "High")
	var ground := scene.get_node_or_null("DynamicGround") as MeshInstance3D
	assert(ground != null, "ClosestToPin must have DynamicGround")
	if not MobilePerformance.is_mobile():
		assert(ground.material_override is ShaderMaterial, "DynamicGround must have ShaderMaterial on High")
		var sm := ground.material_override as ShaderMaterial
		assert(sm.shader != null and sm.shader.resource_path.ends_with("driving_range_turf_realistic.gdshader"),
			"DynamicGround on High must use driving_range_turf_realistic.gdshader")
		var hf_builder := scene.get_node_or_null("HighFidelityBuilder")
		assert(hf_builder != null, "HighFidelityBuilder must be applied on High desktop")
		assert(hf_builder.get_node_or_null("HighFidelityGrass") == null,
			"HighFidelityGrass must not spawn on driving range turf")

	scene.queue_free()
	print("PASS: ClosestToPin uses Driving Range High graphics!")
	quit(0)
