extends Node
## VisualCaptureHelper — Automated screenshot, video timing, shot replay, and visual testing harness.
##
## Activated via command-line arguments (passed as regular args or after '--'):
##   --screenshot=<path>         Path to save PNG screenshot.
##   --delay=<seconds>           Delay in seconds before capturing screenshot or shooting (default: 2.0).
##   --duration=<seconds>        Total runtime before quitting (useful for fixed-time video recordings).
##   --click=<target>            Button text, name, or node path to click before capturing.
##                               Multiple targets can be separated by semicolons (e.g. "Settings;Audio").
##   --click-delay=<seconds>     Delay between clicks (default: 0.5).
##   --shot=<preset_or_params>   Inject a golf shot on the range/course ("driver", "wedge", "slice", "hook", or "speed=150,vla=12,backspin=5000").
##   --surface=<name>            Override landing surface on range for capture ("green", "fairway", "rough", "bunker").
##   --wait-for-rest             Wait for the golf ball to complete its flight and come to rest before quitting.
##   --resolution=<WxH>          Request specific window resolution (e.g. 1280x720).
##   --no-quit                   Do not quit automatically after capture.
##
## Interactive shortcut:
##   Press F12 anytime to take an instant manual screenshot saved to captures/manual_YYYYMMDD_HHMMSS.png.

const LOG_PREFIX := "[VisualCapture]"

var _is_capture_active: bool = false
var _screenshot_path: String = ""
var _delay_seconds: float = 2.0
var _duration_seconds: float = 0.0
var _click_targets: PackedStringArray = []
var _click_delay: float = 0.5
var _shot_preset: String = ""
var _surface_override: String = ""
var _wait_for_rest: bool = false
var _should_quit: bool = true

func _ready() -> void:
	_parse_arguments()
	if _is_capture_active:
		print(LOG_PREFIX, " Capture mode active. Target: ", _screenshot_path if _screenshot_path != "" else "(video/timed run)", " Delay: ", _delay_seconds, "s Shot: '", _shot_preset, "'")
		_run_capture_sequence()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F12:
			_take_manual_screenshot()

func _parse_arguments() -> void:
	var args := OS.get_cmdline_args()
	var user_args := OS.get_cmdline_user_args()
	var combined_args := []
	combined_args.append_array(args)
	combined_args.append_array(user_args)

	for arg in combined_args:
		var clean_arg: String = arg.strip_edges()
		if clean_arg.begins_with("--screenshot=") or clean_arg.begins_with("--capture-screenshot="):
			_screenshot_path = _get_arg_val(clean_arg)
			_is_capture_active = true
		elif clean_arg.begins_with("--delay=") or clean_arg.begins_with("--capture-delay="):
			_delay_seconds = _get_arg_val(clean_arg).to_float()
			_is_capture_active = true
		elif clean_arg.begins_with("--duration=") or clean_arg.begins_with("--capture-duration="):
			_duration_seconds = _get_arg_val(clean_arg).to_float()
			_is_capture_active = true
		elif clean_arg.begins_with("--shot=") or clean_arg.begins_with("--capture-shot="):
			_shot_preset = _get_arg_val(clean_arg)
			_is_capture_active = true
			_wait_for_rest = true
		elif clean_arg.begins_with("--surface=") or clean_arg.begins_with("--capture-surface="):
			_surface_override = _get_arg_val(clean_arg)
			_is_capture_active = true
		elif clean_arg == "--wait-for-rest" or clean_arg == "--capture-wait-for-rest":
			_wait_for_rest = true
			_is_capture_active = true
		elif clean_arg.begins_with("--click=") or clean_arg.begins_with("--capture-click="):
			var raw_clicks := _get_arg_val(clean_arg)
			if ";" in raw_clicks:
				_click_targets = raw_clicks.split(";")
			elif "," in raw_clicks:
				_click_targets = raw_clicks.split(",")
			else:
				_click_targets = PackedStringArray([raw_clicks])
			_is_capture_active = true
		elif clean_arg.begins_with("--click-delay="):
			_click_delay = _get_arg_val(clean_arg).to_float()
		elif clean_arg == "--no-quit" or clean_arg == "--capture-no-quit":
			_should_quit = false
		elif clean_arg == "--capture":
			_is_capture_active = true

func _get_arg_val(arg_str: String) -> String:
	var eq_idx := arg_str.find("=")
	if eq_idx != -1 and eq_idx < arg_str.length() - 1:
		var val := arg_str.substr(eq_idx + 1).strip_edges()
		if (val.begins_with('"') and val.ends_with('"')) or (val.begins_with("'") and val.ends_with("'")):
			val = val.substr(1, val.length() - 2)
		return val
	return ""

func _resolve_path(path_str: String) -> String:
	var normalized := path_str.replace("\\", "/").strip_edges()
	if normalized.is_absolute_path():
		return normalized
	if normalized.begins_with("res://") or normalized.begins_with("user://"):
		return ProjectSettings.globalize_path(normalized)
	# Relative path: resolve relative to project root
	return ProjectSettings.globalize_path("res://" + normalized)

func _run_capture_sequence() -> void:
	var start_time := Time.get_ticks_msec()
	_arm_safety_watchdog()

	# Wait initial delay before any clicks or screenshot
	if _delay_seconds > 0.0:
		await get_tree().create_timer(_delay_seconds).timeout

	# Perform simulated clicks if requested
	for target in _click_targets:
		var trimmed := target.strip_edges()
		if trimmed.is_empty():
			continue
		_simulate_click(trimmed)
		if _click_delay > 0.0:
			await get_tree().create_timer(_click_delay).timeout

	# Apply landing surface override if requested (e.g. --surface=green)
	if not _surface_override.is_empty():
		_apply_surface_override(_surface_override)

	# Perform shot injection if requested
	if not _shot_preset.is_empty():
		var shot_dict := _build_shot_dict(_shot_preset)
		print(LOG_PREFIX, " Injecting shot preset: '", _shot_preset, "' Speed: ", shot_dict.get("Speed"), "mph VLA: ", shot_dict.get("VLA"), "° Spin: ", shot_dict.get("TotalSpin"))
		_inject_shot(shot_dict)

	# Wait for ball to fly and come to rest
	if _wait_for_rest:
		await _await_ball_rest()
		# Allow landing, rollout, and stats HUD to settle visually before reset timer fires
		await get_tree().create_timer(0.6).timeout

	# Settle frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	# Capture screenshot if requested
	if not _screenshot_path.is_empty():
		var full_path := _resolve_path(_screenshot_path)
		var dir := full_path.get_base_dir()
		if not DirAccess.dir_exists_absolute(dir):
			DirAccess.make_dir_recursive_absolute(dir)

		var image := get_viewport().get_texture().get_image()
		if image != null and not image.is_empty():
			var err := image.save_png(full_path)
			if err == OK:
				print(LOG_PREFIX, " SUCCESS: Screenshot captured: ", full_path)
			else:
				printerr(LOG_PREFIX, " ERROR: Failed to save screenshot: ", err)
		else:
			printerr(LOG_PREFIX, " ERROR: Viewport image was null or empty!")

	# Wait remaining duration if duration was set
	if _duration_seconds > 0.0:
		var elapsed_sec := float(Time.get_ticks_msec() - start_time) / 1000.0
		var remaining := _duration_seconds - elapsed_sec
		if remaining > 0.0:
			await get_tree().create_timer(remaining).timeout

	if _should_quit:
		print(LOG_PREFIX, " Sequence finished. Quitting engine cleanly.")
		get_tree().quit(0)

func _arm_safety_watchdog() -> void:
	if not _should_quit:
		return
	var max_safe_seconds: float = max(35.0, _delay_seconds + _duration_seconds + 25.0)
	var timer := get_tree().create_timer(max_safe_seconds)
	timer.timeout.connect(func():
		if _should_quit:
			printerr(LOG_PREFIX, " CRITICAL TIMEOUT: Safety watchdog fired after ", max_safe_seconds, "s! Force killing engine to prevent runaway process.")
			OS.kill(OS.get_process_id())
	)

func _apply_surface_override(surface_name: String) -> void:
	var surface_map := {
		"fairway": PhysicsEnums.SurfaceType.FAIRWAY,
		"fairway_soft": PhysicsEnums.SurfaceType.FAIRWAY_SOFT,
		"rough": PhysicsEnums.SurfaceType.ROUGH,
		"firm": PhysicsEnums.SurfaceType.FIRM,
		"green": PhysicsEnums.SurfaceType.GREEN,
		"bunker": PhysicsEnums.SurfaceType.BUNKER,
		"cart_path": PhysicsEnums.SurfaceType.CART_PATH
	}
	var key := surface_name.to_lower().strip_edges()
	if not surface_map.has(key):
		printerr(LOG_PREFIX, " Unknown surface override: '", surface_name, "'")
		return
	var target_surface: int = int(surface_map[key])
	var current_scene = get_tree().current_scene
	if current_scene == null:
		return

	var ground = current_scene.find_child("DynamicGround", true, false)
	if ground != null:
		_set_surface_meta_recursive(ground, target_surface)

	var player = current_scene.get_node_or_null("Player")
	if player != null and "ball" in player and player.ball != null:
		player.ball.set_meta("capture_surface_override", target_surface)
		if player.ball.has_method("set_surface"):
			player.ball.set_surface(target_surface)
		if target_surface == PhysicsEnums.SurfaceType.GREEN:
			player.ball.lie_type = "green"
		print(LOG_PREFIX, " Applied surface override '", key, "' (SurfaceType=", target_surface, ") to range ground and ball.")

func _set_surface_meta_recursive(node: Node, surface_val: int) -> void:
	if node is StaticBody3D:
		node.set_meta("surface_type", surface_val)
	for child in node.get_children():
		_set_surface_meta_recursive(child, surface_val)

func _build_shot_dict(preset: String) -> Dictionary:
	var p := preset.to_lower().strip_edges()
	if "=" in p:
		var shot := {
			"Speed": 100.0,
			"SpinAxis": 0.0,
			"BackSpin": 5000.0,
			"SideSpin": 0.0,
			"TotalSpin": 5000.0,
			"HLA": 0.0,
			"VLA": 19.0,
			"ShotType": "iron"
		}
		var has_backspin_key := false
		for part in p.split(","):
			var kv := part.split("=", false, 1)
			if kv.size() != 2:
				continue
			var k := kv[0].strip_edges()
			var v := kv[1].strip_edges()
			match k:
				"speed":
					shot["Speed"] = v.to_float()
				"vla":
					shot["VLA"] = v.to_float()
				"hla":
					shot["HLA"] = v.to_float()
				"backspin":
					shot["BackSpin"] = v.to_float()
					has_backspin_key = true
				"spin", "totalspin":
					var spin_val := v.to_float()
					shot["TotalSpin"] = spin_val
					if not has_backspin_key:
						shot["BackSpin"] = spin_val
				"sidespin":
					shot["SideSpin"] = v.to_float()
				"spinaxis":
					shot["SpinAxis"] = v.to_float()
				"shottype":
					shot["ShotType"] = v
		if has_backspin_key and absf(float(shot["SideSpin"])) < 0.01:
			shot["TotalSpin"] = shot["BackSpin"]
		return shot

	match p:
		"driver", "bomb", "drive":
			return {
				"Speed": 160.0,
				"SpinAxis": 0.5,
				"TotalSpin": 2300.0,
				"HLA": 0.5,
				"VLA": 11.5,
				"ShotType": "drive"
			}
		"wedge", "chip", "iron":
			return {
				"Speed": 85.0,
				"SpinAxis": -1.0,
				"TotalSpin": 7500.0,
				"HLA": -0.5,
				"VLA": 28.0,
				"ShotType": "iron"
			}
		"slice", "fade":
			return {
				"Speed": 140.0,
				"SpinAxis": 18.0,
				"TotalSpin": 3500.0,
				"HLA": 2.5,
				"VLA": 13.5,
				"ShotType": "drive"
			}
		"hook", "draw":
			return {
				"Speed": 140.0,
				"SpinAxis": -18.0,
				"TotalSpin": 3500.0,
				"HLA": -2.5,
				"VLA": 13.5,
				"ShotType": "drive"
			}
		_:
			# Default medium drive
			return {
				"Speed": 145.0,
				"SpinAxis": 0.0,
				"TotalSpin": 2600.0,
				"HLA": 0.0,
				"VLA": 12.5,
				"ShotType": "drive"
			}

func _inject_shot(shot_dict: Dictionary) -> void:
	var lm = get_node_or_null("/root/LaunchMonitorManager")
	if lm != null and lm.has_signal("hit_ball"):
		lm.hit_ball.emit(shot_dict)
		print(LOG_PREFIX, " Emitted shot via LaunchMonitorManager.hit_ball")
		return

	var current_scene = get_tree().current_scene
	if current_scene != null and current_scene.has_method("_on_tcp_client_hit_ball"):
		current_scene._on_tcp_client_hit_ball(shot_dict)
		print(LOG_PREFIX, " Dispatched shot to current scene _on_tcp_client_hit_ball")
		return

	var player = current_scene.get_node_or_null("Player") if current_scene != null else null
	if player != null and player.has_method("_on_tcp_client_hit_ball"):
		player._on_tcp_client_hit_ball(shot_dict)
		print(LOG_PREFIX, " Dispatched shot to Player._on_tcp_client_hit_ball")
		return

	printerr(LOG_PREFIX, " Could not find shot receiver in tree!")

func _await_ball_rest(timeout_sec: float = 18.0) -> void:
	print(LOG_PREFIX, " Tracking ball flight until landing and rest...")
	# Settle initial launch (accumulate simulation time so offline --write-movie renders stay accurate)
	await get_tree().create_timer(0.8).timeout
	var sim_elapsed: float = 0.8

	var current_scene = get_tree().current_scene
	var player = current_scene.get_node_or_null("Player") if current_scene != null else null

	while true:
		await get_tree().create_timer(0.2).timeout
		sim_elapsed += 0.2
		if sim_elapsed >= timeout_sec:
			print(LOG_PREFIX, " Flight tracking reached simulation timeout (", timeout_sec, "s). Finishing.")
			break

		if current_scene != null and "_shot_active" in current_scene:
			if not current_scene._shot_active:
				print(LOG_PREFIX, " Ball reached rest (scene._shot_active == false) after ", sim_elapsed, "s.")
				break
		elif player != null and player.has_method("get_ball_state"):
			if player.get_ball_state() == 0:
				print(LOG_PREFIX, " Ball reached rest (player.get_ball_state() == REST) after ", sim_elapsed, "s.")
				break

func _simulate_click(target: String) -> void:
	var root := get_tree().root
	var btn := _find_button_by_target(root, target)
	if btn != null:
		print(LOG_PREFIX, " Clicking UI button: '", btn.name, "' (Text: '", btn.text if "text" in btn else "", "')")
		if btn is Control:
			(btn as Control).grab_focus()
		if btn.has_signal("pressed"):
			btn.pressed.emit()
	else:
		print(LOG_PREFIX, " Target button not found in tree: '", target, "'")

func _find_button_by_target(node: Node, target: String) -> BaseButton:
	if node is BaseButton:
		var b := node as BaseButton
		if b.is_visible_in_tree():
			if b.name.to_lower() == target.to_lower():
				return b
			if "text" in b and str(b.text).strip_edges().to_lower() == target.strip_edges().to_lower():
				return b
			if target in str(b.get_path()):
				return b
	for child in node.get_children():
		var found := _find_button_by_target(child, target)
		if found != null:
			return found
	return null

func _take_manual_screenshot() -> void:
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := "captures/manual_" + timestamp + ".png"
	var full_path := _resolve_path(path)
	var dir := full_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(full_path)
		print(LOG_PREFIX, " Manual screenshot saved: ", full_path)
