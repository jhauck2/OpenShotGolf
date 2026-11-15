extends Node

## OnlineMatchController — Autoload orchestrating turn sync, sequential event buffering,
## shooter-authoritative state application, remote shot replay, AFK detection, and crash rejoin.
## See docs/multiplayer/09_ONLINE_MATCH_RUNTIME.md.

signal event_applied(event: Dictionary)
signal remote_turn_started(player: Dictionary)
signal waiting_banner_status_changed(is_waiting: bool, player_name: String, is_afk: bool)
signal rejoin_dialog_requested(match_id: String, course_title: String)
signal match_ended(reason: String)

const RemoteShotReplayer = preload("res://Player/remote_shot_replayer.gd")
const RtdbClient = preload("res://Utils/Cloud/rtdb_client.gd")

const ACTIVE_MATCH_FILE := "user://active_online_match.json"
const HEARTBEAT_INTERVAL_SEC := 30.0
const POLL_FALLBACK_INTERVAL_SEC := 2.5
const AFK_HEARTBEAT_THRESHOLD_SEC := 180.0
const AFK_TURN_THRESHOLD_SEC := 240.0

var _last_applied_seq: int = 0
var _event_buffer: Dictionary = {} # seq (int) -> event (Dictionary)
var _is_replaying: bool = false
var _replayer: RemoteShotReplayer = null

var _match_id: String = ""
var _match_meta: Dictionary = {}
var _golfers: Array[Dictionary] = []
var _is_match_running: bool = false

var _heartbeat_timer: Timer = null
var _poll_timer: Timer = null
var _afk_timer: Timer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_replayer = RemoteShotReplayer.new()
	_replayer.name = "RemoteShotReplayer"
	_replayer.replay_started.connect(_on_replay_started)
	_replayer.replay_finished.connect(_on_replay_finished)
	add_child(_replayer)

	var sess := _get_online_session()
	if sess != null:
		if sess.has_signal("match_started") and not sess.match_started.is_connected(start_online_match):
			sess.match_started.connect(start_online_match)
		if sess.has_signal("event_received") and not sess.event_received.is_connected(on_event_received):
			sess.event_received.connect(on_event_received)
		if sess.has_signal("turn_updated") and not sess.turn_updated.is_connected(_on_turn_updated):
			sess.turn_updated.connect(_on_turn_updated)

	var mp := _get_mp_manager()
	if mp != null and mp.has_signal("active_player_changed"):
		mp.active_player_changed.connect(_on_active_player_changed)

	_setup_timers()


func _setup_timers() -> void:
	if _heartbeat_timer == null:
		_heartbeat_timer = Timer.new()
		_heartbeat_timer.name = "MatchHeartbeatTimer"
		_heartbeat_timer.wait_time = HEARTBEAT_INTERVAL_SEC
		_heartbeat_timer.one_shot = false
		_heartbeat_timer.timeout.connect(_on_heartbeat_timeout)
		add_child(_heartbeat_timer)

	if _poll_timer == null:
		_poll_timer = Timer.new()
		_poll_timer.name = "PollFallbackTimer"
		_poll_timer.wait_time = POLL_FALLBACK_INTERVAL_SEC
		_poll_timer.one_shot = false
		_poll_timer.timeout.connect(_on_poll_fallback_timeout)
		add_child(_poll_timer)

	if _afk_timer == null:
		_afk_timer = Timer.new()
		_afk_timer.name = "AfkCheckTimer"
		_afk_timer.wait_time = 3.0
		_afk_timer.one_shot = false
		_afk_timer.timeout.connect(_check_afk_state)
		add_child(_afk_timer)


func _get_online_session() -> Node:
	if has_node("/root/OnlineSession"):
		return get_node("/root/OnlineSession")
	var loop = Engine.get_main_loop()
	if loop is SceneTree and loop.root != null and loop.root.has_node("OnlineSession"):
		return loop.root.get_node("OnlineSession")
	return null


func _get_mp_manager() -> Node:
	if has_node("/root/MultiplayerManager"):
		return get_node("/root/MultiplayerManager")
	var loop = Engine.get_main_loop()
	if loop is SceneTree and loop.root != null and loop.root.has_node("MultiplayerManager"):
		return loop.root.get_node("MultiplayerManager")
	return null


func _get_cloud_auth() -> Node:
	if has_node("/root/CloudAuth"):
		return get_node("/root/CloudAuth")
	var loop = Engine.get_main_loop()
	if loop is SceneTree and loop.root != null and loop.root.has_node("CloudAuth"):
		return loop.root.get_node("CloudAuth")
	return null


func _get_my_uid() -> String:
	var auth := _get_cloud_auth()
	if auth != null and auth.has_method("get_uid"):
		return str(auth.call("get_uid"))
	return ""


func _get_rtdb():
	var sess := _get_online_session()
	if sess != null:
		if sess.has_method("get_rtdb"):
			var client = sess.call("get_rtdb")
			if client != null:
				return client
		if sess.has_method("_resolve_rtdb"):
			var client = sess.call("_resolve_rtdb")
			if client != null:
				return client
		if sess.get("rtdb") != null:
			return sess.rtdb
	var auth := _get_cloud_auth()
	if auth != null and auth.get("rtdb") != null:
		return auth.rtdb
	return null


func is_replaying() -> bool:
	return _is_replaying or (_replayer != null and _replayer.is_replaying())


func get_last_applied_seq() -> int:
	return _last_applied_seq


func get_next_seq() -> int:
	return _last_applied_seq + 1


# ── MATCH START & TRANSITION ──────────────────────────────────────────

func start_online_match(match_id: String, meta: Dictionary, golfers: Array[Dictionary]) -> void:
	if _is_match_running and _match_id == match_id:
		print("[OnlineMatchController] Match %s is already running. Ignoring duplicate start call." % match_id)
		return
	_is_match_running = true

	var sess := _get_online_session()
	if sess != null and bool(sess.get("is_spectator")):
		start_spectating_match(match_id, meta, golfers)
		return

	_match_id = match_id
	_match_meta = meta
	_golfers = golfers
	_last_applied_seq = 0
	_event_buffer.clear()
	_is_replaying = false

	if sess != null:
		sess.is_online_match = true
		sess.match_meta = meta
		if sess.has_method("snapshot_and_apply_match_settings"):
			sess.snapshot_and_apply_match_settings()
		if sess.has_signal("event_received") and not sess.event_received.is_connected(on_event_received):
			sess.event_received.connect(on_event_received)
		if sess.has_signal("turn_updated") and not sess.turn_updated.is_connected(_on_turn_updated):
			sess.turn_updated.connect(_on_turn_updated)

	var course_title: String = str(meta.get("course_title", "Online Course"))
	save_active_match_file(match_id, str(meta.get("course_key", "")), course_title)

	var my_uid := _get_my_uid()
	var player_configs: Array[Dictionary] = []
	for g in golfers:
		var owner_uid: String = str(g.get("owner_uid", ""))
		var is_remote: bool = (not owner_uid.is_empty() and not my_uid.is_empty() and owner_uid != my_uid)
		if g.has("is_remote"):
			is_remote = bool(g["is_remote"])

		var cfg := {
			"name": g.get("name", "Player"),
			"tee": g.get("tee", "Blue"),
			"handicap": g.get("handicap", 0),
			"skill_level": g.get("skill_level", "mid_handicap"),
			"handedness": g.get("handedness", 0),
			"ball_graphic": g.get("ball_graphic", "single_line"),
			"bag": g.get("bag", []),
			"slot_id": g.get("slot_id", ""),
			"owner_uid": owner_uid,
			"cloud_uid": str(g.get("cloud_uid", "")),
			"is_remote": is_remote
		}
		player_configs.append(cfg)

	var scene_path := ""
	var config_path := ""
	if sess != null:
		scene_path = sess.local_scene_path
		config_path = sess.local_config_path

	var course_dict: Dictionary = {}
	if not config_path.is_empty() and FileAccess.file_exists(config_path):
		var f := FileAccess.open(config_path, FileAccess.READ)
		if f != null:
			var txt := f.get_as_text()
			var parser := JSON.new()
			if parser.parse(txt) == OK and parser.data is Dictionary:
				course_dict = parser.data

	var settings: Dictionary = meta.get("settings", {})
	var course_length: String = str(settings.get("course_length", meta.get("course_length", "Full 18")))
	var game_mode: String = str(settings.get("game_mode", meta.get("game_mode", "Standard")))
	var turn_order: String = str(settings.get("turn_order_mode", settings.get("turn_order", meta.get("turn_order_mode", meta.get("turn_order", "Classic")))))
	if turn_order == "furthest_away":
		turn_order = "Classic"
	var teams: Dictionary = {}

	var mp := _get_mp_manager()
	if mp != null:
		mp.setup_game(player_configs, course_dict, scene_path, config_path, course_length, game_mode, teams, turn_order)
		mp.start_hole()

	_heartbeat_timer.start()
	_poll_timer.start()
	_afk_timer.start()

	if has_node("/root/SceneManager") and not scene_path.is_empty():
		get_node("/root/SceneManager").load_course(scene_path, config_path)
	elif not scene_path.is_empty():
		var tree := get_tree()
		if tree != null:
			tree.change_scene_to_file(scene_path)

	_check_afk_state()


func start_spectating_match(match_id: String, meta: Dictionary, golfers: Array[Dictionary], events_dict: Dictionary = {}) -> void:
	if _is_match_running and _match_id == match_id:
		print("[OnlineMatchController] Spectating match %s is already running. Ignoring duplicate start call." % match_id)
		return
	_is_match_running = true

	_match_id = match_id
	_match_meta = meta
	_golfers = golfers
	_last_applied_seq = 0
	_event_buffer.clear()
	_is_replaying = false

	var sess := _get_online_session()
	if sess != null:
		sess.is_online_match = true
		sess.is_spectator = true
		sess.match_meta = meta
		if sess.has_method("snapshot_and_apply_match_settings"):
			sess.snapshot_and_apply_match_settings()

	var player_configs: Array[Dictionary] = []
	for g in golfers:
		var cfg := {
			"name": g.get("name", "Player"),
			"tee": g.get("tee", "Blue"),
			"handicap": g.get("handicap", 0),
			"skill_level": g.get("skill_level", "mid_handicap"),
			"handedness": g.get("handedness", 0),
			"ball_graphic": g.get("ball_graphic", "single_line"),
			"bag": g.get("bag", []),
			"slot_id": g.get("slot_id", ""),
			"owner_uid": str(g.get("owner_uid", "")),
			"cloud_uid": str(g.get("cloud_uid", "")),
			"is_remote": true
		}
		player_configs.append(cfg)

	var scene_path := ""
	var config_path := ""
	if sess != null:
		scene_path = sess.local_scene_path
		config_path = sess.local_config_path

	var course_dict: Dictionary = {}
	if not config_path.is_empty() and FileAccess.file_exists(config_path):
		var f := FileAccess.open(config_path, FileAccess.READ)
		if f != null:
			var txt := f.get_as_text()
			var parser := JSON.new()
			if parser.parse(txt) == OK and parser.data is Dictionary:
				course_dict = parser.data

	var settings: Dictionary = meta.get("settings", {})
	var course_length: String = str(settings.get("course_length", meta.get("course_length", "Full 18")))
	var game_mode: String = str(settings.get("game_mode", meta.get("game_mode", "Standard")))
	var turn_order: String = str(settings.get("turn_order_mode", settings.get("turn_order", meta.get("turn_order_mode", meta.get("turn_order", "Classic")))))
	if turn_order == "furthest_away":
		turn_order = "Classic"
	var teams: Dictionary = {}

	var mp := _get_mp_manager()
	if mp != null:
		mp.setup_game(player_configs, course_dict, scene_path, config_path, course_length, game_mode, teams, turn_order)
		mp.start_hole()

	# Fast-forward existing events instantaneously
	if not events_dict.is_empty():
		var sorted_seqs: Array[int] = []
		var seq_map: Dictionary = {}
		for k in events_dict:
			var evt = events_dict[k]
			if evt is Dictionary:
				var s: int = int(evt.get("seq", str(k).trim_prefix("seq_").to_int()))
				sorted_seqs.append(s)
				seq_map[s] = evt
		sorted_seqs.sort()

		for s in sorted_seqs:
			var evt = seq_map[s]
			_last_applied_seq = s
			if mp != null:
				if evt.has("hole_id"):
					var evt_hole_id := str(evt["hole_id"])
					if not evt_hole_id.is_empty() and evt_hole_id != mp.get_current_hole_id():
						var h_idx: int = int(mp.hole_ids.find(evt_hole_id))
						if h_idx != -1 and h_idx != mp.current_hole_index:
							mp.current_hole_index = h_idx
							mp.start_hole()

				var evt_type := str(evt.get("type", "shot"))
				match evt_type:
					"shot":
						mp.record_remote_shot(_normalize_event_coordinates(evt))
					"leave":
						_apply_leave_event(evt)
					"concede_hole":
						_apply_concede_hole_event(evt)

	_poll_timer.start()
	_afk_timer.start()

	if has_node("/root/SceneManager") and not scene_path.is_empty():
		get_node("/root/SceneManager").load_course(scene_path, config_path)
	elif not scene_path.is_empty():
		var tree := get_tree()
		if tree != null:
			tree.change_scene_to_file(scene_path)

	_check_afk_state()


# ── EVENT RECEIPT & SEQUENTIAL DRAIN ────────────────────────────────────

func on_event_received(seq_key: String, event: Dictionary) -> void:
	if event.is_empty():
		return
	var seq: int = int(event.get("seq", 0))
	if seq <= 0:
		seq = seq_key.trim_prefix("seq_").trim_prefix("event_").to_int()

	if seq <= _last_applied_seq:
		return

	_event_buffer[seq] = event
	_drain_event_queue()


func _drain_event_queue() -> void:
	if _is_replaying:
		return

	var next_seq := _last_applied_seq + 1
	while _event_buffer.has(next_seq):
		var evt: Dictionary = _event_buffer[next_seq]
		_apply_event(evt)
		if _is_replaying:
			break
		next_seq = _last_applied_seq + 1


func _apply_event(evt: Dictionary) -> void:
	var seq: int = int(evt.get("seq", _last_applied_seq + 1))
	_last_applied_seq = seq
	_event_buffer.erase(seq)

	var evt_type := str(evt.get("type", "shot"))
	match evt_type:
		"shot":
			_apply_shot_event(evt)
		"leave":
			_apply_leave_event(evt)
		"concede_hole":
			_apply_concede_hole_event(evt)
		_:
			event_applied.emit(evt)


func _apply_shot_event(evt: Dictionary) -> void:
	var mp := _get_mp_manager()
	var slot_id := str(evt.get("slot_id", ""))
	var shooter_is_remote := false
	var sess := _get_online_session()
	if sess != null and bool(sess.get("is_spectator")):
		shooter_is_remote = true
	elif mp != null:
		for p in mp.players:
			if p.get("slot_id", "") == slot_id:
				shooter_is_remote = bool(p.get("is_remote", false))
				break

	if mp != null and evt.has("hole_id"):
		var evt_hole_id := str(evt["hole_id"])
		if not evt_hole_id.is_empty() and evt_hole_id != mp.get_current_hole_id():
			var h_idx: int = int(mp.hole_ids.find(evt_hole_id))
			if h_idx != -1 and h_idx != mp.current_hole_index:
				mp.current_hole_index = h_idx
				mp.start_hole()
				var tree := get_tree()
				if tree != null and tree.current_scene != null and tree.current_scene.has_method("_on_scorecard_advance"):
					if tree.current_scene.get("hud_scorecard") != null and tree.current_scene.hud_scorecard.visible:
						tree.current_scene.call("_on_scorecard_advance")

	if shooter_is_remote:
		evt = _normalize_event_coordinates(evt)
		var ball_node := _find_ball_node()
		var tracer_node := _find_tracer_node()

		if ball_node != null and _replayer != null:
			_is_replaying = true
			if sess != null:
				sess.set_replaying_remote_turn(true)

			_replayer.play_remote_shot(ball_node, evt, tracer_node)
		else:
			# Headless or scene-less test execution
			if mp != null:
				mp.record_remote_shot(evt)
			event_applied.emit(evt)
			_check_afk_state()
			_drain_event_queue()
	else:
		# Local device already hit and resolved shot
		event_applied.emit(evt)
		_check_afk_state()
		_drain_event_queue()


func _on_replay_started(shot_event: Dictionary) -> void:
	_is_replaying = true
	var sess := _get_online_session()
	if sess != null:
		sess.set_replaying_remote_turn(true)

	var range_node := _find_range_node()
	if range_node != null and range_node.has_method("on_remote_shot_replay_started"):
		range_node.call("on_remote_shot_replay_started", shot_event)

	var shooter_name := "Opponent"
	var mp := _get_mp_manager()
	if mp != null:
		var slot_id := str(shot_event.get("slot_id", ""))
		for p in mp.players:
			if p.get("slot_id", "") == slot_id:
				shooter_name = str(p.get("name", "Opponent"))
				break
	waiting_banner_status_changed.emit(true, shooter_name, false)


func _on_replay_finished(shot_event: Dictionary) -> void:
	_is_replaying = false
	var sess := _get_online_session()
	if sess != null:
		sess.set_replaying_remote_turn(false)

	var range_node := _find_range_node()
	if range_node != null and range_node.has_method("on_remote_shot_replay_finished"):
		range_node.call("on_remote_shot_replay_finished", shot_event)

	var mp := _get_mp_manager()
	if mp != null:
		mp.record_remote_shot(shot_event)

	if _match_meta.has("turn") and _match_meta["turn"] is Dictionary:
		_on_turn_updated(_match_meta["turn"])

	event_applied.emit(shot_event)
	_check_afk_state()
	_drain_event_queue()


func _apply_leave_event(evt: Dictionary) -> void:
	var slot_id := str(evt.get("slot_id", ""))
	var mp := _get_mp_manager()
	if mp != null:
		for idx in range(mp.players.size()):
			var p: Dictionary = mp.players[idx]
			if p.get("slot_id", "") == slot_id or p.get("name", "") == evt.get("name", ""):
				p["active"] = false
				print("[OnlineMatchController] Player %s (%s) left the match." % [p.get("name", "Unknown"), slot_id])
				if mp.active_player_index == idx:
					mp.select_next_player()
				break

	event_applied.emit(evt)
	_check_afk_state()
	_drain_event_queue()


func _apply_concede_hole_event(evt: Dictionary) -> void:
	var slot_id := str(evt.get("slot_id", ""))
	var mp := _get_mp_manager()
	if mp != null:
		var active_p: Dictionary = mp.get_active_player()
		if active_p.get("slot_id", "") == slot_id:
			mp.concede_hole()
		else:
			for p in mp.players:
				if p.get("slot_id", "") == slot_id:
					p["holed_out"] = true
					var h_id := str(evt.get("hole_id", mp.get_current_hole_id()))
					if not h_id.is_empty():
						p["hole_scores"][h_id] = p.get("strokes", 0)
					break

	event_applied.emit(evt)
	_check_afk_state()
	_drain_event_queue()


# ── PUBLISHING LOCAL SHOTS & ACTIONS ────────────────────────────────────

func publish_local_shot(
	start_pos: Vector3,
	end_pos: Vector3,
	club: String,
	lie_end: String,
	penalty: int,
	gimme_strokes: int,
	holed_out: bool,
	target_pin: Vector3
) -> Dictionary:
	var sess_check := _get_online_session()
	if sess_check != null and bool(sess_check.get("is_spectator")):
		return {}

	if _match_id.is_empty() and sess_check != null and not sess_check.current_match_id.is_empty():
		_match_id = sess_check.current_match_id

	var mp := _get_mp_manager()
	if mp == null or _match_id.is_empty():
		push_warning("[OnlineMatchController] publish_local_shot skipped: mp=%s, match_id='%s'" % [str(mp != null), _match_id])
		return {}

	var active_p: Dictionary = mp.get_active_player()
	var slot_id := str(active_p.get("slot_id", "slot_0"))
	var my_uid := _get_my_uid()

	var scores_snapshot: Dictionary = {}
	for p in mp.players:
		scores_snapshot[p.get("slot_id", "")] = {
			"hole_strokes": p.get("strokes", 0),
			"total_strokes": p.get("total_strokes", 0),
			"holed_out": p.get("holed_out", false)
		}

	var next_p: Dictionary = {}
	if mp.has_method("peek_next_player"):
		next_p = mp.peek_next_player()

	var hole_complete: bool = next_p.is_empty() or mp.is_current_hole_completed()
	var next_slot := ""
	var next_owner_uid := ""
	if not hole_complete and not next_p.is_empty():
		next_slot = str(next_p.get("slot_id", ""))
		next_owner_uid = str(next_p.get("owner_uid", ""))

	var seq := _last_applied_seq + 1
	var now := Time.get_unix_time_from_system()

	var shot_stat: Dictionary = {}
	if active_p.has("shot_stats") and active_p["shot_stats"] is Dictionary:
		var cur_hole = mp.get_current_hole_id()
		if active_p["shot_stats"].has(cur_hole) and active_p["shot_stats"][cur_hole] is Array and not active_p["shot_stats"][cur_hole].is_empty():
			var last_stat: Dictionary = active_p["shot_stats"][cur_hole].back()
			shot_stat = last_stat.duplicate(true)
			for pos_key in ["start_pos", "end_pos", "position"]:
				if shot_stat.has(pos_key) and shot_stat[pos_key] is Vector3:
					var v: Vector3 = shot_stat[pos_key]
					shot_stat[pos_key] = [v.x, v.y, v.z]

	var event_data := {
		"seq": seq,
		"by_uid": my_uid,
		"type": "shot",
		"slot_id": slot_id,
		"start": [start_pos.x, start_pos.y, start_pos.z],
		"end": [end_pos.x, end_pos.y, end_pos.z],
		"club": club,
		"lie_end": lie_end,
		"penalty": penalty,
		"gimme_strokes": gimme_strokes,
		"holed_out": holed_out,
		"hole_id": mp.get_current_hole_id(),
		"hole_index": mp.current_hole_index,
		"pin": [target_pin.x, target_pin.y, target_pin.z],
		"scores": scores_snapshot,
		"hole_complete": hole_complete,
		"next_slot": next_slot,
		"created_at": now
	}
	if not shot_stat.is_empty():
		event_data["shot_stat"] = shot_stat

	_last_applied_seq = seq

	var turn_patch := {
		"hole_index": mp.current_hole_index,
		"active_slot": next_slot,
		"active_owner_uid": next_owner_uid,
		"next_seq": seq + 1,
		"updated_at": now
	}

	var rtdb = _get_rtdb()
	if rtdb != null:
		var seq_key := "seq_%06d" % seq
		print("[OnlineMatchController] Publishing shot %s for %s (%s) -> next_slot=%s" % [seq_key, active_p.get("name", "Player"), slot_id, next_slot])
		_write_shot_and_turn_async(rtdb, seq_key, event_data, turn_patch)
	else:
		push_error("[OnlineMatchController] RTDB client unavailable! Cannot publish shot event.")

	_check_afk_state()
	return event_data


func _write_shot_and_turn_async(rtdb, seq_key: String, event_data: Dictionary, turn_patch: Dictionary) -> void:
	var put_res = await rtdb.put_path("matches/%s/events/%s" % [_match_id, seq_key], event_data)
	if not put_res.get("ok", false):
		push_error("[OnlineMatchController] Failed to publish shot event %s: %s" % [seq_key, str(put_res.get("error", "Unknown error"))])
	else:
		print("[OnlineMatchController] Successfully published shot event %s to RTDB." % seq_key)

	var patch_res = await rtdb.patch_path("matches/%s/meta/turn" % _match_id, turn_patch)
	if not patch_res.get("ok", false):
		push_error("[OnlineMatchController] Failed to patch turn to %s: %s" % [turn_patch.get("active_slot", ""), str(patch_res.get("error", "Unknown error"))])
	else:
		print("[OnlineMatchController] Successfully updated turn to %s in RTDB." % turn_patch.get("active_slot", ""))


func concede_active_player() -> void:
	var mp := _get_mp_manager()
	if mp == null or _match_id.is_empty():
		return
	var active_p: Dictionary = mp.get_active_player()
	var slot_id := str(active_p.get("slot_id", ""))
	var seq := _last_applied_seq + 1
	var now := Time.get_unix_time_from_system()
	var my_uid := _get_my_uid()

	var evt := {
		"seq": seq,
		"by_uid": my_uid,
		"type": "concede_hole",
		"slot_id": slot_id,
		"hole_id": mp.get_current_hole_id(),
		"created_at": now
	}
	_last_applied_seq = seq

	var rtdb = _get_rtdb()
	if rtdb != null:
		var seq_key := "seq_%06d" % seq
		rtdb.put_path("matches/%s/events/%s" % [_match_id, seq_key], evt)

	_apply_concede_hole_event(evt)


func remove_active_player() -> void:
	var mp := _get_mp_manager()
	if mp == null or _match_id.is_empty():
		return
	var active_p: Dictionary = mp.get_active_player()
	var slot_id := str(active_p.get("slot_id", ""))
	var seq := _last_applied_seq + 1
	var now := Time.get_unix_time_from_system()
	var my_uid := _get_my_uid()

	var evt := {
		"seq": seq,
		"by_uid": my_uid,
		"type": "leave",
		"slot_id": slot_id,
		"name": active_p.get("name", ""),
		"created_at": now
	}
	_last_applied_seq = seq

	var rtdb = _get_rtdb()
	if rtdb != null:
		var seq_key := "seq_%06d" % seq
		rtdb.put_path("matches/%s/events/%s" % [_match_id, seq_key], evt)

	_apply_leave_event(evt)


func leave_online_match() -> void:
	var sess := _get_online_session()
	if sess != null and bool(sess.get("is_spectator")):
		end_match_and_return_to_menu("Left spectating")
		return

	if not _match_id.is_empty():
		var my_uid := _get_my_uid()
		var mp := _get_mp_manager()
		var my_slot := ""
		if mp != null:
			for p in mp.players:
				if p.get("owner_uid", "") == my_uid:
					my_slot = str(p.get("slot_id", ""))
					break
		var seq := _last_applied_seq + 1
		var now := Time.get_unix_time_from_system()

		var evt := {
			"seq": seq,
			"by_uid": my_uid,
			"type": "leave",
			"slot_id": my_slot,
			"created_at": now
		}
		var rtdb = _get_rtdb()
		if rtdb != null:
			var seq_key := "seq_%06d" % seq
			rtdb.put_path("matches/%s/events/%s" % [_match_id, seq_key], evt)

	end_match_and_return_to_menu("Left online match")


func end_match_and_return_to_menu(reason: String = "") -> void:
	_heartbeat_timer.stop()
	_poll_timer.stop()
	_afk_timer.stop()

	clear_active_match_file()

	var sess := _get_online_session()
	if sess != null and sess.has_method("end_online_match"):
		sess.end_online_match()

	_match_id = ""
	_match_meta = {}
	_golfers = []
	_is_match_running = false
	_last_applied_seq = 0
	_event_buffer.clear()
	_is_replaying = false

	match_ended.emit(reason)

	var sm = get_node_or_null("/root/SceneManager")
	if sm != null and sm.has_method("load_main_menu"):
		sm.load_main_menu()
	else:
		var tree := get_tree()
		if tree != null:
			tree.change_scene_to_file("res://UI/MainMenu/main_menu.tscn")


# ── AFK & HEARTBEAT ─────────────────────────────────────────────────────

func _on_heartbeat_timeout() -> void:
	if _match_id.is_empty():
		return
	var sess := _get_online_session()
	if sess != null and bool(sess.get("is_spectator")):
		return
	var my_uid := _get_my_uid()
	if my_uid.is_empty():
		return
	var rtdb = _get_rtdb()
	if rtdb != null:
		var now := Time.get_unix_time_from_system()
		rtdb.put_path("matches/%s/devices/%s/last_seen" % [_match_id, my_uid], now)


func _on_turn_updated(turn_data: Dictionary) -> void:
	_match_meta["turn"] = turn_data
	var active_slot := str(turn_data.get("active_slot", ""))
	var mp := _get_mp_manager()
	if mp != null and not active_slot.is_empty() and not _is_replaying:
		for idx in range(mp.players.size()):
			if mp.players[idx].get("slot_id", "") == active_slot:
				if mp.active_player_index != idx:
					mp.active_player_index = idx
					mp.emit_signal("active_player_changed", mp.get_active_player())
				break
	_check_afk_state()


func _on_active_player_changed(_player: Dictionary) -> void:
	_check_afk_state()


func _check_afk_state() -> void:
	if _is_replaying:
		return
	var mp := _get_mp_manager()
	if mp == null or _match_id.is_empty():
		waiting_banner_status_changed.emit(false, "", false)
		return

	var active_p: Dictionary = mp.get_active_player()
	if active_p.is_empty():
		waiting_banner_status_changed.emit(false, "", false)
		return

	var sess := _get_online_session()
	var is_spec: bool = sess != null and bool(sess.get("is_spectator"))
	var is_remote: bool = bool(active_p.get("is_remote", false)) or is_spec
	if not is_remote:
		waiting_banner_status_changed.emit(false, "", false)
		return

	var p_name: String = str(active_p.get("name", "Opponent"))
	if is_spec:
		waiting_banner_status_changed.emit(true, p_name, false)
		return

	var owner_uid: String = str(active_p.get("owner_uid", ""))
	var now := Time.get_unix_time_from_system()

	var is_afk := false
	if sess != null:
		var dev: Dictionary = sess.match_devices.get(owner_uid, {})
		var last_seen: float = float(dev.get("last_seen", 0.0))
		if last_seen > 0.0 and (now - last_seen) > AFK_HEARTBEAT_THRESHOLD_SEC:
			is_afk = true

	var turn_data: Dictionary = _match_meta.get("turn", {})
	var turn_updated_at: float = float(turn_data.get("updated_at", 0.0))
	if turn_updated_at > 0.0 and (now - turn_updated_at) > AFK_TURN_THRESHOLD_SEC:
		is_afk = true

	waiting_banner_status_changed.emit(true, p_name, is_afk)


func _on_poll_fallback_timeout() -> void:
	if _match_id.is_empty():
		return
	var rtdb = _get_rtdb()
	if rtdb == null:
		return

	# Fetch missed events
	var res = await rtdb.get_path("matches/%s/events" % _match_id)
	if res.get("ok", false) and res.get("data") is Dictionary:
		var events_dict: Dictionary = res["data"]
		for k in events_dict:
			if events_dict[k] is Dictionary:
				on_event_received(str(k), events_dict[k])


# ── FAST-FORWARD REJOIN ─────────────────────────────────────────────────

func save_active_match_file(match_id: String, course_key: String, course_title: String) -> void:
	var data := {
		"match_id": match_id,
		"course_key": course_key,
		"course_title": course_title,
		"joined_at": Time.get_unix_time_from_system()
	}
	var f := FileAccess.open(ACTIVE_MATCH_FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
		f.close()


func clear_active_match_file() -> void:
	if FileAccess.file_exists(ACTIVE_MATCH_FILE):
		DirAccess.remove_absolute(ACTIVE_MATCH_FILE)


func has_active_match_file() -> bool:
	return FileAccess.file_exists(ACTIVE_MATCH_FILE)


func read_active_match_file() -> Dictionary:
	if not FileAccess.file_exists(ACTIVE_MATCH_FILE):
		return {}
	var f := FileAccess.open(ACTIVE_MATCH_FILE, FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var parser := JSON.new()
	if parser.parse(txt) == OK and parser.data is Dictionary:
		return parser.data
	return {}


func check_and_prompt_rejoin() -> void:
	if not has_active_match_file():
		return
	var active_match := read_active_match_file()
	var m_id: String = str(active_match.get("match_id", ""))
	if m_id.is_empty():
		return

	var rtdb = _get_rtdb()
	if rtdb == null:
		return

	var meta_res = await rtdb.get_path("matches/%s/meta" % m_id)
	if not meta_res.get("ok", false) or not (meta_res.get("data") is Dictionary):
		clear_active_match_file()
		return

	var meta: Dictionary = meta_res["data"]
	if meta.get("status", "") != "active":
		clear_active_match_file()
		return

	var course_title: String = str(meta.get("course_title", active_match.get("course_title", "Course")))
	rejoin_dialog_requested.emit(m_id, course_title)


func rejoin_active_match(match_id: String) -> void:
	var rtdb = _get_rtdb()
	if rtdb == null:
		return

	var snap_res = await rtdb.get_path("matches/%s" % match_id)
	if not snap_res.get("ok", false) or not (snap_res.get("data") is Dictionary):
		clear_active_match_file()
		return

	var match_data: Dictionary = snap_res["data"]
	var meta: Dictionary = match_data.get("meta", {})
	var golfers_dict: Dictionary = match_data.get("golfers", {})
	var events_dict: Dictionary = match_data.get("events", {})

	var sorted_golfers: Array[Dictionary] = []
	for g in golfers_dict.values():
		sorted_golfers.append(g)
	sorted_golfers.sort_custom(func(a, b): return int(a.get("order", 0)) < int(b.get("order", 0)))

	start_online_match(match_id, meta, sorted_golfers)

	# Fast-forward events 1..N-1 without animation
	var sorted_seqs: Array[int] = []
	var seq_map: Dictionary = {}
	for k in events_dict:
		var evt = events_dict[k]
		if evt is Dictionary:
			var s: int = int(evt.get("seq", str(k).trim_prefix("seq_").to_int()))
			sorted_seqs.append(s)
			seq_map[s] = evt
	sorted_seqs.sort()

	var mp := _get_mp_manager()
	for i in range(sorted_seqs.size()):
		var s = sorted_seqs[i]
		var evt = seq_map[s]
		_last_applied_seq = s
		if i < sorted_seqs.size() - 1:
			# Apply instantaneously
			if mp != null and evt.get("type", "shot") == "shot":
				mp.record_remote_shot(_normalize_event_coordinates(evt))
		else:
			# Animate / apply latest event
			_apply_event(evt)


# ── NODE FINDERS ────────────────────────────────────────────────────────

func _find_ball_node() -> Node3D:
	var tree := get_tree()
	if tree == null:
		return null
	var player = tree.root.find_child("Player", true, false)
	if player != null and "ball" in player and player.ball is Node3D:
		return player.ball
	return tree.root.find_child("GolfBall", true, false) as Node3D


func _find_tracer_node() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var player = tree.root.find_child("Player", true, false)
	if player != null:
		if player.has_method("create_new_tracer"):
			return player.create_new_tracer()
		if "current_tracer" in player and player.current_tracer != null:
			return player.current_tracer
		if "ball_tracer" in player and player.ball_tracer != null:
			return player.ball_tracer
	var tracer = tree.root.find_child("ShotTracer", true, false)
	if tracer != null:
		return tracer
	return null


func _find_range_node() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var curr = tree.current_scene
	if curr != null:
		if curr.has_method("on_remote_shot_replay_started") or curr.has_method("get_height"):
			return curr
		if curr.has_node("Range") and (curr.get_node("Range").has_method("on_remote_shot_replay_started") or curr.get_node("Range").has_method("get_height")):
			return curr.get_node("Range")
		if "course_instance" in curr and curr.course_instance != null and (curr.course_instance.has_method("on_remote_shot_replay_started") or curr.course_instance.has_method("get_height")):
			return curr.course_instance
	var r = tree.root.find_child("Range", true, false)
	if r != null and (r.has_method("on_remote_shot_replay_started") or r.has_method("get_height")):
		return r
	return null


# ── COORDINATE NORMALIZATION ──────────────────────────────────────────

func _normalize_event_coordinates(evt: Dictionary) -> Dictionary:
	if not evt.has("start") or not evt.has("end") or not evt.has("pin"):
		return evt

	var shooter_pin := _parse_vector3(evt["pin"])
	if shooter_pin.is_zero_approx():
		return evt

	var mp := _get_mp_manager()
	var hole_id := str(evt.get("hole_id", ""))
	if hole_id.is_empty() and mp != null and not mp.hole_ids.is_empty():
		var h_idx: int = int(evt.get("hole_index", mp.current_hole_index))
		if h_idx >= 0 and h_idx < mp.hole_ids.size():
			hole_id = mp.hole_ids[h_idx]

	var local_pin := Vector3.ZERO
	var range_node := _find_range_node()
	if range_node != null and "current_hole_location" in range_node:
		var cur_loc = range_node.current_hole_location
		if cur_loc is Vector3 and not (cur_loc as Vector3).is_zero_approx():
			if mp == null or hole_id.is_empty() or hole_id == mp.get_current_hole_id():
				local_pin = cur_loc

	if local_pin.is_zero_approx() and mp != null and not hole_id.is_empty():
		var h_info: Dictionary = mp.hole_info.get(hole_id, {})
		var h_loc = h_info.get("Hole Location", [])
		if h_loc is Array and h_loc.size() >= 2:
			if range_node != null and range_node.has_method("get_hole_location_for"):
				local_pin = range_node.get_hole_location_for(h_loc)
			elif range_node != null and range_node.has_method("get_height"):
				local_pin = Vector3(float(h_loc[0]), range_node.get_height(float(h_loc[0]), float(h_loc[1])), float(h_loc[1]))
			else:
				local_pin = Vector3(float(h_loc[0]), 0.0, float(h_loc[1]))

	if local_pin.is_zero_approx() and mp != null and mp.has_method("get_target_pin_position"):
		local_pin = mp.get_target_pin_position()

	if local_pin.is_zero_approx():
		return evt

	var offset_x: float = local_pin.x - shooter_pin.x
	var offset_z: float = local_pin.z - shooter_pin.z
	if absf(offset_x) < 2.0 and absf(offset_z) < 2.0:
		return evt

	print("[OnlineMatchController] Cross-client coordinate offset detected: dX=%.2f, dZ=%.2f. Aligning shot coordinates to local course origin." % [offset_x, offset_z])

	var normalized := evt.duplicate(true)
	var start_raw := _parse_vector3(evt["start"])
	var end_raw := _parse_vector3(evt["end"])
	var norm_start := Vector3(start_raw.x + offset_x, start_raw.y, start_raw.z + offset_z)
	var norm_end := Vector3(end_raw.x + offset_x, end_raw.y, end_raw.z + offset_z)

	var elev_offset_y: float = local_pin.y - shooter_pin.y
	norm_start.y += elev_offset_y
	norm_end.y += elev_offset_y

	if range_node != null and range_node.has_method("get_height"):
		var gh_start: float = range_node.get_height(norm_start.x, norm_start.z)
		var gh_end: float = range_node.get_height(norm_end.x, norm_end.z)
		norm_end.y = gh_end + 0.022335
		var is_teed := (int(evt.get("hole_strokes", 0)) == 0 and str(evt.get("club", "")).to_lower() in ["dr", "driver", "1w"])
		norm_start.y = maxf(norm_start.y, gh_start + (0.059435 if is_teed else 0.022335))

	normalized["start"] = [norm_start.x, norm_start.y, norm_start.z]
	normalized["end"] = [norm_end.x, norm_end.y, norm_end.z]
	if normalized.has("start_pos"):
		normalized["start_pos"] = [norm_start.x, norm_start.y, norm_start.z]
	if normalized.has("end_pos"):
		normalized["end_pos"] = [norm_end.x, norm_end.y, norm_end.z]
	if normalized.has("shot_stat") and normalized["shot_stat"] is Dictionary:
		normalized["shot_stat"]["start_pos"] = [norm_start.x, norm_start.y, norm_start.z]
		normalized["shot_stat"]["end_pos"] = [norm_end.x, norm_end.y, norm_end.z]
	normalized["pin"] = [local_pin.x, local_pin.y, local_pin.z]
	normalized["_normalized"] = true
	return normalized


static func _parse_vector3(val) -> Vector3:
	if val is Vector3:
		return val
	if val is Array or val is PackedFloat32Array or val is PackedFloat64Array:
		if val.size() >= 3:
			return Vector3(float(val[0]), float(val[1]), float(val[2]))
	return Vector3.ZERO
