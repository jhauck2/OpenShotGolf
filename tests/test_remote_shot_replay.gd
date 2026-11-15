extends SceneTree

# Targeted Unit Tests for RemoteShotReplayer (Work Package 08)
# Covers all 3 test cases in §5 of docs/multiplayer/08_REMOTE_SHOT_REPLAY.md:
# 1. Direct A -> B Endpoint & Zero Rollout Guarantee (Driver, 7i, SW, Pt)
# 2. Putter Straight-Line Roll (interpolates along A.lerp(B, w) with peak_height_m == 0.0)
# 3. Zero rest Signal Emission (Hole H19) - ball.rest fires 0 times, replay_finished fires once

const RemoteShotReplayer = preload("res://Player/remote_shot_replayer.gd")

var _tested := false

func _initialize() -> void:
	print("=== Running Work Package 08 RemoteShotReplayer Tests ===")
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	if _tested:
		return
	_tested = true
	test_direct_endpoint_and_zero_rollout()
	test_putter_straight_line_roll()
	test_zero_rest_signal_emission()
	test_stepped_process_replay_and_tracer()
	test_shot_replay_follow_setting()
	print("\n=======================================================")
	print("ALL WORK PACKAGE 08 TESTS PASSED! 🎉")
	print("=======================================================")
	quit(0)


func test_direct_endpoint_and_zero_rollout() -> void:
	print("\n--- Test 1: Direct A -> B Endpoint & Zero Rollout Guarantee ---")
	var start_pos := Vector3(10.0, 1.5, 20.0)
	var end_pos := Vector3(160.0, 4.0, 210.0)
	var clubs := ["Dr", "7i", "SW", "Pt"]

	for club in clubs:
		var profile := RemoteShotReplayer.build_trajectory_profile(start_pos, end_pos, club)
		assert(profile.has("duration_s"), "Profile must have duration_s for club %s" % club)
		var duration_s: float = profile["duration_s"]
		assert(duration_s > 0.0, "duration_s must be positive for club %s" % club)

		# Non-putter and putter shots both have zero rollout phase in remote replay
		assert(profile.has("roll_s"), "Profile must have roll_s field")
		assert(profile["roll_s"] == 0.0, "roll_s must be exactly 0.0 for club %s" % club)

		# Sample at t = 0.0 -> must be identically start_pos
		var pos_start := RemoteShotReplayer.sample_trajectory_at_time(profile, 0.0)
		assert(pos_start.is_equal_approx(start_pos), "t=0.0 must be start_pos for %s, got %s vs %s" % [club, pos_start, start_pos])

		# Sample at t = duration_s -> must be identically end_pos
		var pos_end := RemoteShotReplayer.sample_trajectory_at_time(profile, duration_s)
		assert(pos_end.is_equal_approx(end_pos), "t=duration_s must be end_pos for %s, got %s vs %s" % [club, pos_end, end_pos])

		# Sample past duration -> must clamp cleanly to end_pos
		var pos_past := RemoteShotReplayer.sample_trajectory_at_time(profile, duration_s + 2.0)
		assert(pos_past.is_equal_approx(end_pos), "t>duration_s must clamp to end_pos for %s" % club)

		if club != "Pt":
			# Verify arc height at mid-flight
			assert(profile["peak_height_m"] > 0.0, "Non-putter peak_height_m must be > 0")
			var mid_t := duration_s * 0.5
			var pos_mid := RemoteShotReplayer.sample_trajectory_at_time(profile, mid_t)
			var base_mid := start_pos.lerp(end_pos, 0.5)
			var expected_y: float = base_mid.y + float(profile["peak_height_m"])
			assert(absf(pos_mid.y - expected_y) < 0.001, "Mid-arc peak height mismatch for %s: got %f expected %f" % [club, pos_mid.y, expected_y])

		print("  PASS: Trajectory profile and endpoints verified for club '%s'" % club)


func test_putter_straight_line_roll() -> void:
	print("\n--- Test 2: Putter Straight-Line Roll ---")
	var start_pos := Vector3(5.0, 1.0, 10.0)
	var end_pos := Vector3(15.0, 1.8, 30.0)

	var profile := RemoteShotReplayer.build_trajectory_profile(start_pos, end_pos, "Pt")
	assert(profile["is_putt"] == true, "Profile must identify 'Pt' as putt")
	assert(profile["peak_height_m"] == 0.0, "Putter peak_height_m must be exactly 0.0 (zero vertical arc)")
	assert(profile["roll_s"] == 0.0, "Putter roll_s must be 0.0")

	var duration_s: float = profile["duration_s"]
	var sample_steps := [0.1, 0.25, 0.5, 0.75, 0.9]

	for u in sample_steps:
		var elapsed_s: float = duration_s * u
		var w: float = 1.0 - (1.0 - u) * (1.0 - u)
		var expected_pos := start_pos.lerp(end_pos, w)
		var sampled_pos := RemoteShotReplayer.sample_trajectory_at_time(profile, elapsed_s)
		assert(sampled_pos.is_equal_approx(expected_pos), "Putter pos at u=%.2f must match A.lerp(B, w). Got %s, expected %s" % [u, sampled_pos, expected_pos])
		# Verify straight-line vertical interpolation (zero arc lift)
		assert(absf(sampled_pos.y - expected_pos.y) < 0.0001, "Putter vertical position must have zero arc offset")

	print("  PASS: Putter straight-line roll along A.lerp(B, w) verified with peak_height_m == 0.0")


func test_zero_rest_signal_emission() -> void:
	print("\n--- Test 3: Zero rest Signal Emission (Hole H19 Guardrail) ---")
	var BallScript = load("res://Player/ball.gd")
	assert(BallScript != null, "Player/ball.gd must load")

	var ball = CharacterBody3D.new()
	ball.set_script(BallScript)
	root.add_child(ball)

	var replayer := RemoteShotReplayer.new()
	root.add_child(replayer)

	var ball_rest_counter := [0]
	ball.rest.connect(func(): ball_rest_counter[0] += 1)

	var replay_started_counter := [0]
	replayer.replay_started.connect(func(_ev): replay_started_counter[0] += 1)

	var replay_finished_counter := [0]
	replayer.replay_finished.connect(func(_ev): replay_finished_counter[0] += 1)

	var start_pos := Vector3(0.0, 0.5, 0.0)
	var end_pos := Vector3(180.0, 2.0, 120.0)
	var shot_event := {
		"start": start_pos,
		"end": end_pos,
		"club": "Dr"
	}

	replayer.play_remote_shot(ball, shot_event)

	assert(replayer.is_replaying() == true, "Replayer should be replaying")
	assert(ball.is_replaying_remote_shot == true, "ball.is_replaying_remote_shot must be true")
	assert(ball.global_position.is_equal_approx(start_pos), "Ball must start at start_pos")
	assert(replay_started_counter[0] == 1, "replay_started must emit once")

	# Simulate multiple physics frames while replaying
	for _i in range(10):
		ball._physics_process(0.016)

	# Explicitly test calling _enter_rest_state() while replaying
	ball._enter_rest_state()

	assert(ball_rest_counter[0] == 0, "ball.rest MUST NOT emit during replay! Emitted %d times" % ball_rest_counter[0])

	# Skip to end
	replayer.skip_to_end()

	assert(replayer.is_replaying() == false, "Replayer should no longer be replaying")
	assert(ball.is_replaying_remote_shot == false, "ball.is_replaying_remote_shot must be false after finish")
	assert(ball.global_position.is_equal_approx(end_pos), "Ball must stop exactly at end_pos")
	assert(ball.state == PhysicsEnums.BallState.REST, "Ball state must be set to REST")
	assert(replay_finished_counter[0] == 1, "replay_finished must emit exactly once")
	assert(ball_rest_counter[0] == 0, "ball.rest MUST STILL BE 0 after replay finished! Emitted %d times" % ball_rest_counter[0])

	ball.queue_free()
	replayer.queue_free()
	print("  PASS: Zero ball.rest emission verified (replay_finished=1, ball.rest=0)")


func test_stepped_process_replay_and_tracer() -> void:
	print("\n--- Test 4: Stepped _process replay and tracer updates ---")
	var BallScript = load("res://Player/ball.gd")
	var ball = CharacterBody3D.new()
	ball.set_script(BallScript)
	root.add_child(ball)

	var replayer := RemoteShotReplayer.new()
	root.add_child(replayer)

	# Mock tracer node
	var mock_tracer = Node.new()
	var points: Array[Vector3] = []
	mock_tracer.set_meta("points", points)
	# Add update_trail and finalize_trail methods dynamically via script
	var tracer_script = GDScript.new()
	tracer_script.source_code = """
extends Node
var points: Array = []
var finalized: bool = false
func start_trail(p: Vector3) -> void:
	points.clear()
	points.append(p)
func update_trail(p: Vector3) -> void:
	points.append(p)
func finalize_trail() -> void:
	finalized = true
"""
	tracer_script.reload()
	mock_tracer.set_script(tracer_script)
	root.add_child(mock_tracer)

	var progress_points: Array[Vector3] = []
	replayer.replay_progress.connect(func(pos): progress_points.append(pos))

	var finished_events: Array[Dictionary] = []
	replayer.replay_finished.connect(func(ev): finished_events.append(ev))

	var start_pos := Vector3(0.0, 0.0, 0.0)
	var end_pos := Vector3(10.0, 0.0, 0.0)
	var shot_event := {
		"start": [0.0, 0.0, 0.0],
		"end": [10.0, 0.0, 0.0],
		"club": "Pt"
	}

	replayer.play_remote_shot(ball, shot_event, mock_tracer)
	assert(mock_tracer.points.size() >= 1, "Tracer should have start point")

	# Step through _process until replay completes
	var max_steps := 500
	var step := 0
	while replayer.is_replaying() and step < max_steps:
		replayer._process(0.05)
		step += 1
		if step == 5:
			# Verify ball.get_interpolated_position() follows ball.global_position dynamically
			assert(ball.is_replaying_remote_shot, "Ball should have is_replaying_remote_shot set to true")
			assert(ball.get_interpolated_position().is_equal_approx(ball.global_position), "Interpolated position must follow ball.global_position during replay")

	assert(replayer.is_replaying() == false, "Replayer should finish after stepping duration")
	assert(finished_events.size() == 1, "replay_finished should emit exactly once")
	assert(finished_events[0] == shot_event, "replay_finished event must match original shot_event")
	assert(ball.global_position.is_equal_approx(end_pos), "Ball must finish at end_pos")
	assert(ball.spawn_position.is_equal_approx(end_pos), "Ball spawn_position must be updated to end_pos")
	assert(mock_tracer.finalized == true, "Tracer should be finalized")
	assert(progress_points.size() > 1, "replay_progress should emit during steps")

	# Verify reset_ball preserves position at end_pos
	ball.reset()
	assert(ball.global_position.is_equal_approx(end_pos), "ball.reset() must maintain position at end_pos, not revert to start_pos")

	ball.queue_free()
	replayer.queue_free()
	mock_tracer.queue_free()
	print("  PASS: Stepped replay with tracer updates and array coordinates verified")


func test_shot_replay_follow_setting() -> void:
	print("\n--- Test 5: Shot Replay Follow Setting Default & Toggle Behavior ---")
	var rs = RangeSettings.new()
	assert(rs.settings.has("shot_replay_follow"), "RangeSettings must include shot_replay_follow setting")
	assert(rs.shot_replay_follow.value == false, "shot_replay_follow must default to false (current view)")

	# Verify toggle on / off
	rs.shot_replay_follow.set_value(true)
	assert(rs.shot_replay_follow.value == true, "shot_replay_follow should be toggled to true")
	rs.shot_replay_follow.set_value(false)
	assert(rs.shot_replay_follow.value == false, "shot_replay_follow should be toggled to false")

	# Test Range script replay follow logic with mock range node
	var range_script = load("res://Courses/Range/range.gd")
	var range_node = Node3D.new()
	range_node.set_script(range_script)

	var pcam = Node3D.new()
	pcam.name = "PhantomCamera3D"
	pcam.set("follow_mode", 0)
	pcam.set("look_at_mode", 0)
	range_node.add_child(pcam)

	var cam3d = Camera3D.new()
	cam3d.name = "Camera3D"
	range_node.add_child(cam3d)

	var player = Node3D.new()
	player.name = "Player"
	var ball = GolfBall.new()
	ball.name = "GolfBall"
	player.add_child(ball)
	player.set("ball", ball)
	range_node.add_child(player)

	# When shot_replay_follow is false (default)
	if GlobalSettings.range_settings != null and GlobalSettings.range_settings.settings.has("shot_replay_follow"):
		GlobalSettings.range_settings.shot_replay_follow.set_value(false)

	var shot_evt = {
		"start": Vector3(0, 0, 0),
		"end": Vector3(100, 5, 50),
		"club": "7i"
	}

	range_node.on_remote_shot_replay_started(shot_evt)
	assert(pcam.get("follow_mode") == 0, "When shot_replay_follow is false, follow_mode must remain NONE (0)")

	range_node.on_remote_shot_replay_finished(shot_evt)
	assert(pcam.get("follow_mode") == 0, "After finish, follow_mode must remain NONE (0)")

	# When shot_replay_follow is true
	if GlobalSettings.range_settings != null and GlobalSettings.range_settings.settings.has("shot_replay_follow"):
		GlobalSettings.range_settings.shot_replay_follow.set_value(true)

	range_node.on_remote_shot_replay_started(shot_evt)
	assert(pcam.get("follow_mode") == 2, "When shot_replay_follow is true, follow_mode must be SIMPLE (2)")

	range_node.on_remote_shot_replay_finished(shot_evt)
	assert(pcam.get("follow_mode") == 0, "After finish, follow_mode must reset to NONE (0)")

	# Cleanup
	if GlobalSettings.range_settings != null and GlobalSettings.range_settings.settings.has("shot_replay_follow"):
		GlobalSettings.range_settings.shot_replay_follow.set_value(false)

	range_node.queue_free()
	print("  PASS: Shot Replay Follow setting default and camera follow toggle verified")
