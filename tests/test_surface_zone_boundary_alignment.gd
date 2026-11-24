extends SceneTree

func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("--- Running Test: Surface Zone Boundary Alignment (Bunker / Fringe / Rough / Green) ---")
	test_bunker_geometric_detection_at_rim_and_deep_bowl()
	test_fringe_vs_rough_boundary_alignment()
	test_greenside_bunker_beats_fringe()
	test_shader_boundary_alignment()
	print("=======================================================")
	print("  ALL SURFACE ZONE BOUNDARY ALIGNMENT TESTS PASSED!")
	print("=======================================================")
	quit(0)


func _build_mock_course_with_green_and_bunker() -> Dictionary:
	var RangeScript = load("res://Courses/Range/range.gd")
	var BallScript = load("res://Player/ball.gd")

	var course = Node3D.new()
	course.set_script(RangeScript)
	course.set_process(false)
	course.set_physics_process(false)
	root.add_child(course)
	course.is_driving_range = false
	course.shot_count = 1

	# Green square: x in [-5, 5], z in [-5, 5] at y = 0
	var green_body = StaticBody3D.new()
	green_body.name = "green_Static_1"
	green_body.set_meta("surface_type", 4)
	var g_shape = ConcavePolygonShape3D.new()
	g_shape.data = PackedVector3Array([
		Vector3(-5.0, 0.0, -5.0), Vector3(5.0, 0.0, -5.0), Vector3(5.0, 0.0, 5.0),
		Vector3(-5.0, 0.0, -5.0), Vector3(5.0, 0.0, 5.0), Vector3(-5.0, 0.0, 5.0),
	])
	var g_col = CollisionShape3D.new()
	g_col.shape = g_shape
	green_body.add_child(g_col)
	course.add_child(green_body)

	# Bunker rectangle: x in [10, 18], z in [-4, 4]
	# Note: collision sits at y = 0.0 (unsculpted/bridged) while ball will sit at y = -0.9 (deep bowl)
	var bunker_body = StaticBody3D.new()
	bunker_body.name = "bunker_Static_1"
	bunker_body.set_meta("surface_type", 5)
	bunker_body.set_meta("is_sand", true)
	bunker_body.set_meta("boundary_polygon", PackedVector2Array([
		Vector2(10.0, -4.0), Vector2(18.0, -4.0), Vector2(18.0, 4.0), Vector2(10.0, 4.0)
	]))
	var b_shape = ConcavePolygonShape3D.new()
	b_shape.data = PackedVector3Array([
		Vector3(10.0, 0.0, -4.0), Vector3(18.0, 0.0, -4.0), Vector3(18.0, 0.0, 4.0),
		Vector3(10.0, 0.0, -4.0), Vector3(18.0, 0.0, 4.0), Vector3(10.0, 0.0, 4.0),
	])
	var b_col = CollisionShape3D.new()
	b_col.shape = b_shape
	bunker_body.add_child(b_col)
	course.add_child(bunker_body)

	# Greenside bunker right next to green edge: x in [5.4, 8.5], z in [-2, 2]
	# Within 1.5m of green edge (x = 5.0), so bunker MUST take priority over fringe!
	var gs_bunker = StaticBody3D.new()
	gs_bunker.name = "bunker_Static_greenside"
	gs_bunker.set_meta("surface_type", 5)
	gs_bunker.set_meta("is_sand", true)
	gs_bunker.set_meta("boundary_polygon", PackedVector2Array([
		Vector2(5.4, -2.0), Vector2(8.5, -2.0), Vector2(8.5, 2.0), Vector2(5.4, 2.0)
	]))
	course.add_child(gs_bunker)

	var player = Node3D.new()
	player.name = "Player"
	player.set_script(GDScript.new())
	var p_script := GDScript.new()
	p_script.source_code = """extends Node3D
var ball: Node = null
var current_lie_type: String = ""
var current_shot_reduction: float = 0.0
var apex: float = 0.0
var _last_starting_pos: Vector3 = Vector3.ZERO
"""
	p_script.reload()
	player.set_script(p_script)
	course.add_child(player)

	var ball = CharacterBody3D.new()
	ball.set_script(BallScript)
	player.add_child(ball)
	player.ball = ball

	course.current_hole_location = Vector3(0.0, 0.0, 0.0)
	course._init_cached_surface_bodies(true)
	course.clear_surface_distance_caches()

	return {"course": course, "player": player, "ball": ball}


func test_bunker_geometric_detection_at_rim_and_deep_bowl() -> void:
	print("\n--- Test 1: Bunker Detection 1 Foot Inside Rim & In Deep Bowl ---")
	var ctx = _build_mock_course_with_green_and_bunker()
	var course = ctx["course"]
	var ball = ctx["ball"]

	# 1 foot (~0.30m) inside bunker edge at x = 10.30, sitting 0.9m below bridged lip collision
	var pos_one_foot_in = Vector3(10.30, -0.90, 0.0)
	ball.global_position = pos_one_foot_in
	course.clear_surface_distance_caches()

	var d_bunker: float = course.get_distance_to_nearest_bunker(pos_one_foot_in)
	assert(d_bunker <= 0.001, "Ball 1 foot inside bunker must have distance 0.0, got %f" % d_bunker)
	assert(ball._is_position_in_bunker(pos_one_foot_in) == true, "Ball geometric bunker check must be true 1 foot inside sandtrap")
	assert(course.is_ball_in_sand(pos_one_foot_in) == true, "is_ball_in_sand must be true 1 foot inside sandtrap")

	course.update_current_lie_and_reduction()
	assert(ball.lie_type == "sand", "Ball 1 foot inside sandtrap must report lie_type 'sand', got '%s'" % ball.lie_type)
	assert(ball.is_in_sand == true, "Ball 1 foot inside sandtrap must have is_in_sand == true")

	# 1 foot (~0.30m) outside bunker edge at x = 9.70 -> must NOT be in bunker
	var pos_outside = Vector3(9.70, 0.0, 0.0)
	ball.global_position = pos_outside
	ball.is_in_sand = false
	ball.lie_type = "rough"
	course.clear_surface_distance_caches()

	var d_out: float = course.get_distance_to_nearest_bunker(pos_outside)
	assert(absf(d_out - 0.30) < 0.05, "Ball 0.30m outside bunker must report ~0.30m distance, got %f" % d_out)
	assert(ball._is_position_in_bunker(pos_outside) == false, "Ball outside bunker must not report in bunker")

	course.queue_free()
	print("  PASS: Ball 1 foot inside sandtrap is reliably detected as sand even in deep sculpted bowls.")


func test_fringe_vs_rough_boundary_alignment() -> void:
	print("\n--- Test 2: Fringe vs Rough Boundary Alignment (FRINGE_WIDTH_M = 1.5m) ---")
	var ctx = _build_mock_course_with_green_and_bunker()
	var course = ctx["course"]
	var ball = ctx["ball"]

	# Inside green (x = 0, z = 0)
	ball.global_position = Vector3(0.0, 0.0, 0.0)
	course.clear_surface_distance_caches()
	assert(course.is_ball_on_green() == true, "Center of green must be on green")
	assert(course.is_ball_on_fringe() == false, "Center of green must not be on fringe")

	# On fringe (0.75m outside green edge at x = -5.75)
	ball.global_position = Vector3(-5.75, 0.0, 0.0)
	ball.lie_type = "rough"
	course.clear_surface_distance_caches()
	assert(course.is_ball_on_fringe() == true, "0.75m outside green must be on fringe")
	assert(ball._is_position_on_fringe(ball.global_position) == true, "ball._is_position_on_fringe must be true at 0.75m")

	# Just inside 1.5m fringe edge (1.45m outside green edge at x = -6.45)
	ball.global_position = Vector3(-6.45, 0.0, 0.0)
	ball.lie_type = "rough"
	course.clear_surface_distance_caches()
	assert(course.is_ball_on_fringe() == true, "1.45m outside green must still be on fringe")

	# Visually in rough (1.65m and 2.10m outside green edge - previously misreported as fringe!)
	for offset_m in [1.65, 2.10]:
		ball.global_position = Vector3(-5.0 - offset_m, 0.0, 0.0)
		ball.lie_type = "rough"
		course.clear_surface_distance_caches()
		assert(course.is_ball_on_fringe() == false, "%.2fm outside green must NOT be fringe (visually rough)" % offset_m)
		assert(ball._is_position_on_fringe(ball.global_position) == false, "ball._is_position_on_fringe must be false at %.2fm" % offset_m)

	course.queue_free()
	print("  PASS: Fringe strictly matches 1.50m visual collar; >1.50m correctly reports rough.")


func test_greenside_bunker_beats_fringe() -> void:
	print("\n--- Test 3: Greenside Bunker Within 1.5m of Green Takes Priority Over Fringe ---")
	var ctx = _build_mock_course_with_green_and_bunker()
	var course = ctx["course"]
	var ball = ctx["ball"]

	# Ball is at x = 5.80 (0.80m from green edge x=5.0, AND 0.40m inside greenside bunker x in [5.4, 8.5])
	ball.global_position = Vector3(5.80, -0.50, 0.0)
	ball.lie_type = "rough"
	ball.is_in_sand = false
	course.clear_surface_distance_caches()

	assert(ball._is_position_in_bunker(ball.global_position) == true, "Ball in greenside bunker must be detected as in bunker")
	assert(ball._is_position_on_fringe(ball.global_position) == false, "Ball in greenside bunker must NOT be detected as fringe")
	assert(course.is_ball_on_fringe() == false, "course.is_ball_on_fringe() must be false when inside greenside bunker")

	course.update_current_lie_and_reduction()
	assert(ball.lie_type == "sand", "Greenside bunker ball must report 'sand', got '%s'" % ball.lie_type)

	course.queue_free()
	print("  PASS: Greenside bunker overrides fringe/putting cleanly.")


func test_shader_boundary_alignment() -> void:
	print("\n--- Test 4: Terrain & Grass Shaders Load & Use Aligned Cutoffs ---")
	var realistic_shader = load("res://Courses/Environments/shaders/terrain_splat_realistic.gdshader") as Shader
	var standard_shader = load("res://Courses/Environments/shaders/terrain_splat.gdshader") as Shader
	var grass_shader = load("res://Courses/Environments/shaders/grass_blades_high.gdshader") as Shader

	assert(realistic_shader != null and realistic_shader.code.contains("smoothstep(0.44, 0.58"), "terrain_splat_realistic.gdshader must align green/fringe cutoff at 0.44..0.58")
	assert(realistic_shader.code.contains("direct_splat.b"), "terrain_splat_realistic.gdshader must sample bunker channel unblurred")
	assert(standard_shader != null and standard_shader.code.contains("smoothstep(0.44, 0.58"), "terrain_splat.gdshader must align green/fringe cutoff at 0.44..0.58")
	assert(grass_shader != null and grass_shader.code.contains("sp.r > 0.52"), "grass_blades_high.gdshader must align rough blade cutoff with 1.50m fringe edge")
	print("  PASS: All terrain and grass shaders use gameplay-aligned boundary thresholds.")
