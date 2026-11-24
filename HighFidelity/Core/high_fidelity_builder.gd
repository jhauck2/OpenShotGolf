extends Node3D
class_name HighFidelityBuilder

## HighFidelityBuilder
## Master coordinator for High-fidelity desktop graphics.
## Dynamically instantiates and configures Forward+ lighting, SSAO, SSR,
## GPU-instanced 3D grass, recessed 3D bunker lips, shoreline reeds, and performance telemetry.

const HighFidelityLightingScript = preload("res://HighFidelity/Lighting/high_fidelity_lighting.gd")
const HighFidelityOverlayScript = preload("res://HighFidelity/Core/high_fidelity_overlay.gd")
const HighFidelityGrassScript = preload("res://HighFidelity/Foliage/high_fidelity_grass.gd")
const CourseDetailEnhancerScript = preload("res://HighFidelity/Terrain/course_detail_enhancer.gd")

var overlay_node: CanvasLayer = null
var grass_node: Node3D = null


static func is_supported() -> bool:
	return not MobilePerformance.is_mobile()


static func apply_high_fidelity(scene_root: Node) -> Node3D:
	if scene_root == null or not is_supported():
		return null

	var existing = scene_root.get_node_or_null("HighFidelityBuilder")
	if existing != null:
		if existing.has_method("refresh"):
			existing.refresh(scene_root)
		return existing

	var script = load("res://HighFidelity/Core/high_fidelity_builder.gd") as GDScript
	var builder = script.new() as Node3D
	builder.name = "HighFidelityBuilder"
	scene_root.add_child(builder)
	builder.call("setup", scene_root)
	return builder


static func remove_high_fidelity(scene_root: Node) -> void:
	if scene_root == null:
		return

	var existing = scene_root.get_node_or_null("HighFidelityBuilder")
	if existing != null:
		if existing.has_method("teardown"):
			existing.call("teardown", scene_root)
		scene_root.remove_child(existing)
		existing.queue_free()
	else:
		HighFidelityLightingScript.remove(scene_root)
	_set_detail_nodes_visible(scene_root, false)


func setup(scene_root: Node) -> void:
	# 1. Apply Forward+ Desktop Lighting, SSAO, SSR, Crisp 4-Split Shadows & Calibrated AgX Tonemapper
	HighFidelityLightingScript.apply(scene_root)

	# 2. Ensure course 3D recessed bunkers, shoreline reeds, & horizon skirt exist and are visible
	var reeds := scene_root.get_node_or_null("ShorelineReedsMultiMesh")
	var bunkers := scene_root.get_node_or_null("HighFidelityBunkers")
	var details_baked := bool(scene_root.get_meta("course_details_baked", false))
	if not details_baked and (reeds == null or bunkers == null):
		CourseDetailEnhancerScript.enhance_course_scene(scene_root, false)
	_set_detail_nodes_visible(scene_root, true)

	# 3. Spawn GPU MultiMesh 3D Grass System (Golfer Address Turf + Clumped Rough/Fescue)
	# On the driving range, no 3D grass blade meshes are spawned; range turf is manicured via shader
	var is_range := MobilePerformance.is_driving_range_node(scene_root)
	if not is_range:
		if grass_node == null:
			grass_node = HighFidelityGrassScript.new()
			grass_node.name = "HighFidelityGrass"
			add_child(grass_node)
			grass_node.setup(scene_root)
	else:
		if grass_node != null:
			grass_node.queue_free()
			grass_node = null

	# 4. Add Diagnostic Telemetry HUD (toggleable with F3)
	if overlay_node == null:
		overlay_node = HighFidelityOverlayScript.new()
		add_child(overlay_node)


func refresh(scene_root: Node) -> void:
	HighFidelityLightingScript.apply(scene_root)
	if not bool(scene_root.get_meta("course_details_baked", false)) and scene_root.get_node_or_null("HighFidelityBunkers") == null and scene_root.get_node_or_null("ShorelineReedsMultiMesh") == null:
		CourseDetailEnhancerScript.enhance_course_scene(scene_root, false)
	_set_detail_nodes_visible(scene_root, true)
	var is_range := MobilePerformance.is_driving_range_node(scene_root)
	if is_range:
		if grass_node != null:
			grass_node.queue_free()
			grass_node = null
	elif grass_node != null and grass_node.has_method("_refresh_anchor"):
		grass_node.call("_refresh_anchor", true)


func teardown(scene_root: Node) -> void:
	HighFidelityLightingScript.remove(scene_root)
	_set_detail_nodes_visible(scene_root, false)
	if grass_node != null:
		grass_node.queue_free()
		grass_node = null
	if overlay_node != null:
		overlay_node.queue_free()
		overlay_node = null


static func _set_detail_nodes_visible(scene_root: Node, vis: bool) -> void:
	if scene_root == null:
		return
	var bunkers := scene_root.get_node_or_null("HighFidelityBunkers") as Node3D
	if bunkers != null:
		bunkers.visible = vis
	var reeds := scene_root.get_node_or_null("ShorelineReedsMultiMesh") as Node3D
	if reeds != null:
		var is_low := false
		var main_loop = Engine.get_main_loop()
		if main_loop is SceneTree and (main_loop as SceneTree).root != null:
			var gs = (main_loop as SceneTree).root.get_node_or_null("GlobalSettings")
			if gs != null and gs.has_method("get_graphics_quality"):
				is_low = (gs.get_graphics_quality() == "Low")
		reeds.visible = not is_low
	var thick_grass := scene_root.get_node_or_null("ThickRoughGrassMultiMesh") as Node3D
	if thick_grass != null:
		thick_grass.visible = false
	var thick_bushes := scene_root.get_node_or_null("ThickRoughBushes") as Node3D
	if thick_bushes != null:
		thick_bushes.visible = vis
	for child in scene_root.get_children():
		if child is Node3D and child.name.begins_with("ThickRoughGrass"):
			child.visible = false
		elif child is Node3D and (child.name.begins_with("ThickRough_") or child.name.begins_with("ThickRoughBush")):
			child.visible = vis

	# Update terrain shader parameter so thick rough elevated textures only render on High graphics
	for tname in ["UnifiedTerrain", "DynamicGround", "RoughGround", "Terrain", "TerrainMesh"]:
		var terrain := scene_root.find_child(tname, true, false) as MeshInstance3D
		if terrain != null:
			var mats: Array[ShaderMaterial] = []
			if terrain.material_override is ShaderMaterial:
				mats.append(terrain.material_override as ShaderMaterial)
			if terrain.get_surface_override_material(0) is ShaderMaterial:
				mats.append(terrain.get_surface_override_material(0) as ShaderMaterial)
			if terrain.mesh != null and terrain.mesh.get_surface_count() > 0 and terrain.mesh.surface_get_material(0) is ShaderMaterial:
				mats.append(terrain.mesh.surface_get_material(0) as ShaderMaterial)
			for m in mats:
				m.set_shader_parameter("has_deep_rough_map", vis)

