extends Node

## OnlineSession — Autoload managing online multiplayer lobbies, join codes, public browser,
## presence heartbeats, course identity verification, and match start transitions.
## See docs/multiplayer/07_ONLINE_LOBBY_HOST_JOIN.md.

signal lobby_updated(meta: Dictionary, devices: Dictionary, golfers: Dictionary)
signal public_lobbies_loaded(lobbies: Array[Dictionary])
signal lobby_error(code: String, message: String)
signal course_install_required(course_info: Dictionary, reason: String) # "missing" | "fingerprint_mismatch"
signal match_started(match_id: String, meta: Dictionary, golfers: Array[Dictionary])
signal lobby_closed(reason: String)
signal match_spectated(match_id: String, meta: Dictionary, golfers: Array[Dictionary], events: Dictionary)
signal event_received(seq_key: String, event_data: Dictionary)
signal turn_updated(turn_data: Dictionary)
signal device_updated(uid: String, device_data: Dictionary)

const CourseFingerprint = preload("res://Utils/Cloud/course_fingerprint.gd")
const RtdbClient = preload("res://Utils/Cloud/rtdb_client.gd")
const RtdbStream = preload("res://Utils/Cloud/rtdb_stream.gd")

const ONLINE_PROTOCOL_VERSION := 1
const MAX_GOLFERS := 4
const CODE_ALPHABET := "ABCDEFGHJKMNPQRSTUVWXYZ23456789" # No 0/O/1/I/L
const HEARTBEAT_INTERVAL_SEC := 20.0
const STALE_HEARTBEAT_THRESHOLD_SEC := 45.0
const SNAPSHOT_SETTINGS_KEYS := [
	"wind_enabled", "wind_speed", "green_speed", "random_pin_enabled",
	"ball_rollout_enabled", "turn_order_mode"
]
const GIMME_SETTINGS_KEYS := [
	"gimme_range_1_enabled", "gimme_range_1_distance",
	"gimme_range_2_enabled", "gimme_range_2_distance",
	"gimme_range_3_enabled", "gimme_range_3_distance"
]

var is_online_match: bool = false
var is_spectator: bool = false
var current_match_id: String = ""
var is_host: bool = false
var current_join_code: String = ""
var match_meta: Dictionary = {}
var match_devices: Dictionary = {}
var match_golfers: Dictionary = {}

var local_scene_path: String = ""
var local_config_path: String = ""
var is_local_course_ready: bool = false
var is_local_course_downloading: bool = false
var is_local_device_ready: bool = false

var _saved_local_settings: Dictionary = {}
var _is_replaying_remote: bool = false
var _match_started_emitted: bool = false

var rtdb: RtdbClient = null
var _stream: RtdbStream = null
var _heartbeat_timer: Timer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resolve_rtdb()

	# Listen to auth state changes to auto-cleanup lobbies on sign-out
	var auth_node := _get_cloud_auth()
	if auth_node != null and auth_node.has_signal("auth_state_changed"):
		auth_node.auth_state_changed.connect(_on_auth_state_changed)

	_setup_heartbeat_timer()


func _setup_heartbeat_timer() -> void:
	if _heartbeat_timer == null:
		_heartbeat_timer = Timer.new()
		_heartbeat_timer.name = "LobbyHeartbeatTimer"
		_heartbeat_timer.wait_time = HEARTBEAT_INTERVAL_SEC
		_heartbeat_timer.one_shot = false
		_heartbeat_timer.timeout.connect(_on_heartbeat_timeout)
		add_child(_heartbeat_timer)


func _notification(what: int) -> void:
	# Clean up immediately on window close or mobile backgrounding while hosting un-started lobby (H14)
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_host and is_online_match and match_meta.get("status", "") == "lobby":
			leave_lobby()


func _on_auth_state_changed(is_signed_in: bool, _user: Dictionary) -> void:
	var auth_node := _get_cloud_auth()
	var has_auth: bool = is_signed_in or (auth_node != null and auth_node.is_authenticated_any())
	if not has_auth and is_host and is_online_match and match_meta.get("status", "") == "lobby":
		leave_lobby()


# ── CLIENT RESOLUTION ───────────────────────────────────────────────────

func _get_cloud_auth() -> Node:
	if has_node("/root/CloudAuth"):
		return get_node("/root/CloudAuth")
	var loop = Engine.get_main_loop()
	if loop is SceneTree and loop.root != null and loop.root.has_node("CloudAuth"):
		return loop.root.get_node("CloudAuth")
	return null


func _resolve_rtdb() -> RtdbClient:
	if rtdb != null:
		return rtdb
	var auth_node := _get_cloud_auth()
	if auth_node != null and auth_node.rtdb != null:
		rtdb = auth_node.rtdb
		return rtdb
	rtdb = RtdbClient.new(auth_node)
	return rtdb


func get_rtdb() -> RtdbClient:
	return _resolve_rtdb()


func _get_my_uid() -> String:
	var auth_node := _get_cloud_auth()
	if auth_node != null and auth_node.has_method("get_uid"):
		var uid: String = auth_node.get_uid()
		if not uid.is_empty():
			return uid
	return "local_dev_uid"


func _get_my_display_name() -> String:
	var auth_node := _get_cloud_auth()
	if auth_node != null and auth_node.has_method("get_display_name"):
		var name_str: String = auth_node.get_display_name()
		if not name_str.is_empty():
			return name_str
	return "Player"


func _ensure_auth() -> Dictionary:
	if rtdb != null and rtdb.get_script() != RtdbClient:
		return {"ok": true}
	var auth_node := _get_cloud_auth()
	if auth_node != null:
		if not auth_node.is_authenticated_any():
			var res = await auth_node.ensure_anonymous_session()
			if not res.get("ok", false):
				return {"ok": false, "error": res.get("error", "Authentication failed")}
		if auth_node.is_cloud_service_paused():
			return {
				"ok": false,
				"error": auth_node.get_cloud_pause_message(),
				"budget_paused": true
			}
	return {"ok": true}


func _generate_join_code() -> String:
	var code := ""
	var max_idx := CODE_ALPHABET.length()
	for i in range(6):
		var rand_idx := randi() % max_idx
		code += CODE_ALPHABET[rand_idx]
	return code


# ── HOST ACTIONS ────────────────────────────────────────────────────────

func create_lobby(course_config_path: String, settings: Dictionary, visibility: String, local_golfers: Array) -> Dictionary:
	var auth_check = await _ensure_auth()
	if not auth_check.get("ok", false):
		lobby_error.emit("AUTH_ERROR", auth_check.get("error", ""))
		return auth_check

	var course_info := CourseFingerprint.inspect_course_config(course_config_path)
	if not course_info.get("ok", false):
		var err: String = course_info.get("error", "Invalid course configuration.")
		lobby_error.emit("COURSE_ERROR", err)
		return {"ok": false, "error": err}

	if course_info.get("is_custom", false):
		var err := "Custom local courses cannot be hosted online yet because remote players cannot download them from the course catalog."
		lobby_error.emit("CUSTOM_COURSE_NOT_SUPPORTED", err)
		return {"ok": false, "error": err}

	if local_golfers.is_empty():
		var err := "At least one local golfer is required to host a lobby."
		lobby_error.emit("NO_GOLFERS", err)
		return {"ok": false, "error": err}

	var client := _resolve_rtdb()
	var my_uid := _get_my_uid()
	var my_name := _get_my_display_name()
	var now := Time.get_unix_time_from_system()

	var normalized_visibility := "public" if visibility.to_lower() == "public" else "private"

	var initial_match := {
		"meta": {
			"protocol_version": ONLINE_PROTOCOL_VERSION,
			"host_uid": my_uid,
			"status": "lobby",
			"visibility": normalized_visibility,
			"created_at": now,
			"updated_at": now,
			"course": {
				"key": course_info.key,
				"title": course_info.title,
				"lat": course_info.lat,
				"lon": course_info.lon,
				"location": course_info.location,
				"fingerprint": course_info.fingerprint,
				"is_cached": course_info.is_cached
			},
			"settings": {
				"course_length": settings.get("course_length", "Full 18"),
				"game_mode": settings.get("game_mode", "Standard"),
				"turn_order_mode": settings.get("turn_order_mode", "Stay Up"),
				"wind_speed_mph": float(settings.get("wind_speed_mph", 0.0)),
				"wind_dir_rad": float(settings.get("wind_dir_rad", 0.0)),
				"pin_seed": int(settings.get("pin_seed", randi())),
				"green_speed": settings.get("green_speed", "Normal"),
				"force_gimmes": bool(settings.get("force_gimmes", false)),
				"gimme_range_1_enabled": bool(settings.get("gimme_range_1_enabled", true)),
				"gimme_range_1_distance": float(settings.get("gimme_range_1_distance", 4.0)),
				"gimme_range_2_enabled": bool(settings.get("gimme_range_2_enabled", false)),
				"gimme_range_2_distance": float(settings.get("gimme_range_2_distance", 10.0)),
				"gimme_range_3_enabled": bool(settings.get("gimme_range_3_enabled", false)),
				"gimme_range_3_distance": float(settings.get("gimme_range_3_distance", 30.0)),
				"random_pin_enabled": bool(settings.get("random_pin_enabled", false)),
				"ball_rollout_enabled": bool(settings.get("ball_rollout_enabled", true))
			}
		},
		"devices": {
			my_uid: {
				"device_name": my_name,
				"joined_at": now,
				"last_seen": now,
				"course_ready": true,
				"course_downloading": false,
				"ready": true
			}
		},
		"golfers": {}
	}

	for i in range(mini(local_golfers.size(), MAX_GOLFERS)):
		var g = local_golfers[i]
		var slot_id := "slot_%d" % i
		initial_match["golfers"][slot_id] = {
			"slot_id": slot_id,
			"owner_uid": my_uid,
			"name": g.get("name", "Player %d" % (i + 1)),
			"tee": g.get("tee", "Blue"),
			"avatar": g.get("avatar", ""),
			"order": i,
			"hand": int(g.get("handedness", 0)),
			"ball_graphic": g.get("ball_graphic", "single_line")
		}

	# 1. Create match in RTDB
	var post_res = await client.post_path("matches", initial_match)
	if not post_res.get("ok", false):
		lobby_error.emit("MATCH_CREATE_FAILED", post_res.get("error", "Failed to create match."))
		return post_res

	var match_id: String = ""
	if post_res.data is Dictionary:
		match_id = str(post_res.data.get("name", ""))
	if match_id.is_empty():
		return {"ok": false, "error": "Invalid match ID returned by database."}

	# 2. Collision-safe Join Code Reservation with null_etag (Hole H15)
	var reserved_code := ""
	var code_claimed := false
	var last_code_error := ""
	var is_collision := false
	for attempt in range(5):
		var cand_code := _generate_join_code()
		var code_payload := {
			"match_id": match_id,
			"host_uid": my_uid,
			"created_at": now
		}
		var code_res = await client.put_path("codes/" + cand_code, code_payload, "null_etag")
		if code_res.get("ok", false):
			reserved_code = cand_code
			code_claimed = true
			break
		elif code_res.get("status", 0) == 412 or str(code_res.get("error", "")).contains("412") or str(code_res.get("error", "")).contains("Precondition"):
			is_collision = true
			last_code_error = "Join code collision (412 Precondition Failed)"
			continue
		else:
			# Non-collision error (e.g. permission or network error)
			is_collision = false
			last_code_error = str(code_res.get("error", "Database error %s" % str(code_res.get("status", ""))))
			break

	if not code_claimed:
		await client.delete_path("matches/" + match_id)
		var err := ""
		if is_collision:
			err = "Failed to reserve a unique join code after multiple attempts."
		elif not last_code_error.is_empty():
			err = "Failed to reserve join code: %s" % last_code_error
		else:
			err = "Failed to reserve a unique join code after multiple attempts."
		lobby_error.emit("JOIN_CODE_COLLISION", err)
		return {"ok": false, "error": err}

	# 3. If public, publish to /lobbies/{matchId}
	if normalized_visibility == "public":
		var lobby_payload := {
			"match_id": match_id,
			"host_uid": my_uid,
			"host_name": my_name,
			"course_title": course_info.title,
			"course_length": initial_match["meta"]["settings"]["course_length"],
			"game_mode": initial_match["meta"]["settings"]["game_mode"],
			"player_count": initial_match["golfers"].size(),
			"max_players": MAX_GOLFERS,
			"status": "lobby",
			"created_at": now,
			"last_seen": now
		}
		await client.put_path("lobbies/" + match_id, lobby_payload)

	# 4. Set state
	is_online_match = true
	current_match_id = match_id
	is_host = true
	current_join_code = reserved_code
	match_meta = initial_match["meta"]
	match_devices = initial_match["devices"]
	match_golfers = initial_match["golfers"]
	local_scene_path = course_info.scene_path
	local_config_path = course_info.config_path
	is_local_course_ready = true
	is_local_course_downloading = false
	is_local_device_ready = true
	_match_started_emitted = false

	_start_stream(match_id)
	_start_heartbeat()

	lobby_updated.emit(match_meta, match_devices, match_golfers)
	return {
		"ok": true,
		"match_id": match_id,
		"code": reserved_code
	}


func update_lobby_settings(settings: Dictionary) -> Dictionary:
	if not is_host or current_match_id.is_empty():
		return {"ok": false, "error": "Only the host can modify lobby settings."}

	var client := _resolve_rtdb()
	var cur_settings: Dictionary = match_meta.get("settings", {})
	for k in settings:
		cur_settings[k] = settings[k]

	match_meta["settings"] = cur_settings
	var patch_res = await client.patch_path("matches/" + current_match_id + "/meta/settings", settings)

	if match_meta.get("visibility", "") == "public":
		var lobby_patch := {}
		if settings.has("course_length"):
			lobby_patch["course_length"] = settings["course_length"]
		if settings.has("game_mode"):
			lobby_patch["game_mode"] = settings["game_mode"]
		if not lobby_patch.is_empty():
			await client.patch_path("lobbies/" + current_match_id, lobby_patch)

	lobby_updated.emit(match_meta, match_devices, match_golfers)
	return patch_res


func kick_device(target_uid: String) -> Dictionary:
	if not is_host or current_match_id.is_empty():
		return {"ok": false, "error": "Only the host can kick players."}
	if target_uid == _get_my_uid():
		return {"ok": false, "error": "Host cannot kick themselves."}

	var client := _resolve_rtdb()

	# Delete target golfers
	for slot_id in match_golfers.keys():
		var g = match_golfers[slot_id]
		if g.get("owner_uid", "") == target_uid:
			await client.delete_path("matches/" + current_match_id + "/golfers/" + slot_id)
			match_golfers.erase(slot_id)

	# Delete target device
	var dev_res = await client.delete_path("matches/" + current_match_id + "/devices/" + target_uid)
	match_devices.erase(target_uid)

	# Update public lobby player count if host
	if match_meta.get("visibility", "") == "public":
		await client.patch_path("lobbies/" + current_match_id, {"player_count": match_golfers.size()})

	lobby_updated.emit(match_meta, match_devices, match_golfers)
	return dev_res


func start_online_match() -> Dictionary:
	if not is_host or current_match_id.is_empty():
		return {"ok": false, "error": "Only the host can start the match."}

	if match_meta.get("status", "") != "lobby":
		return {"ok": false, "error": "Match has already been started."}

	if match_golfers.size() < 2:
		return {"ok": false, "error": "At least 2 golfers are required to start an online match."}
	if match_golfers.size() > MAX_GOLFERS:
		return {"ok": false, "error": "Maximum 4 golfers allowed."}

	var now := Time.get_unix_time_from_system()

	# Check devices: all active devices must have course_ready == true and ready == true
	for dev_uid in match_devices.keys():
		var dev = match_devices[dev_uid]
		var last_seen := float(dev.get("last_seen", 0.0))
		if (now - last_seen) < 120.0:
			if not bool(dev.get("course_ready", false)):
				if bool(dev.get("course_downloading", false)):
					var dev_name = str(dev.get("device_name", "A player"))
					return {"ok": false, "error": "%s is currently downloading the course." % dev_name}
				return {"ok": false, "error": "Not all players have the required course installed."}
			if not bool(dev.get("ready", false)):
				return {"ok": false, "error": "Not all players are ready."}

	var sorted_golfers: Array[Dictionary] = []
	for g in match_golfers.values():
		sorted_golfers.append(g)
	sorted_golfers.sort_custom(func(a, b): return int(a.get("order", 0)) < int(b.get("order", 0)))
	var first_slot: Dictionary = sorted_golfers[0]

	var meta_patch := {
		"status": "active",
		"started_at": now,
		"updated_at": now,
		"turn": {
			"hole_index": 0,
			"active_slot": first_slot.get("slot_id", "slot_0"),
			"active_owner_uid": first_slot.get("owner_uid", _get_my_uid()),
			"next_seq": 1,
			"updated_at": now
		}
	}

	var client := _resolve_rtdb()
	var patch_res = await client.patch_path("matches/" + current_match_id + "/meta", meta_patch)
	if not patch_res.get("ok", false):
		return patch_res

	# Atomically delete join code so nobody else can join as player (G8 + H15)
	if not current_join_code.is_empty():
		await client.delete_path("codes/" + current_join_code)
	if match_meta.get("visibility", "") == "public":
		# Update lobby entry to in_progress so spectators can discover and watch
		await client.patch_path("lobbies/" + current_match_id, {
			"status": "in_progress",
			"last_seen": now
		})

	match_meta["status"] = "active"
	match_meta["started_at"] = now
	match_meta["turn"] = meta_patch["turn"]

	_match_started_emitted = true
	match_started.emit(current_match_id, match_meta, sorted_golfers)
	return {"ok": true}


# ── JOINER / BROWSER ACTIONS ────────────────────────────────────────────

func fetch_public_lobbies() -> Array[Dictionary]:
	var auth_check = await _ensure_auth()
	if not auth_check.get("ok", false):
		lobby_error.emit("AUTH_ERROR", auth_check.get("error", ""))
		return []

	var client := _resolve_rtdb()
	var res = await client.get_path("lobbies")
	if not res.get("ok", false):
		lobby_error.emit("FETCH_LOBBIES_FAILED", res.get("error", "Failed to load public matches."))
		return []

	var now := Time.get_unix_time_from_system()
	var active_lobbies: Array[Dictionary] = []

	if res.data is Dictionary:
		for m_id in res.data.keys():
			var l_data = res.data[m_id]
			if not (l_data is Dictionary):
				continue
			var last_seen := float(l_data.get("last_seen", 0.0))
			# Stale lobby auto-purge (> 45s without host heartbeat)
			if (now - last_seen) > STALE_HEARTBEAT_THRESHOLD_SEC:
				client.delete_path("lobbies/" + str(m_id))
			else:
				var lobby_item: Dictionary = l_data.duplicate()
				lobby_item["match_id"] = str(m_id)
				active_lobbies.append(lobby_item)

	public_lobbies_loaded.emit(active_lobbies)
	return active_lobbies


func join_by_code(code: String, local_golfers: Array) -> Dictionary:
	var clean_code := code.strip_edges().to_upper()
	if clean_code.length() != 6:
		var err := "Join code must be 6 characters."
		lobby_error.emit("INVALID_CODE", err)
		return {"ok": false, "error": err}

	var auth_check = await _ensure_auth()
	if not auth_check.get("ok", false):
		lobby_error.emit("AUTH_ERROR", auth_check.get("error", ""))
		return auth_check

	var client := _resolve_rtdb()
	var code_res = await client.get_path("codes/" + clean_code)
	if not code_res.get("ok", false) or not (code_res.data is Dictionary):
		var err := "Invalid or expired join code."
		lobby_error.emit("CODE_NOT_FOUND", err)
		return {"ok": false, "error": err}

	var match_id: String = str(code_res.data.get("match_id", ""))
	if match_id.is_empty():
		return {"ok": false, "error": "Invalid join code record."}

	current_join_code = clean_code
	return await _join_match_internal(match_id, local_golfers)


func join_by_match_id(match_id: String, local_golfers: Array) -> Dictionary:
	var auth_check = await _ensure_auth()
	if not auth_check.get("ok", false):
		lobby_error.emit("AUTH_ERROR", auth_check.get("error", ""))
		return auth_check

	return await _join_match_internal(match_id, local_golfers)


func spectate_match(match_id: String) -> Dictionary:
	var auth_check = await _ensure_auth()
	if not auth_check.get("ok", false):
		lobby_error.emit("AUTH_ERROR", auth_check.get("error", ""))
		return auth_check

	var client := _resolve_rtdb()
	var m_res = await client.get_path("matches/" + match_id)
	if not m_res.get("ok", false) or not (m_res.data is Dictionary):
		var err := "Match not found or no longer active."
		lobby_error.emit("MATCH_NOT_FOUND", err)
		return {"ok": false, "error": err}

	var m_data: Dictionary = m_res.data
	var meta: Dictionary = m_data.get("meta", {})
	var host_uid: String = meta.get("host_uid", "")
	var devices: Dictionary = m_data.get("devices", {})
	var host_device: Dictionary = devices.get(host_uid, {})
	var host_last_seen := float(host_device.get("last_seen", 0.0))
	var now := Time.get_unix_time_from_system()

	if host_last_seen > 0.0 and (now - host_last_seen) > 180.0:
		var err := "The match host appears to be disconnected."
		lobby_error.emit("HOST_DISCONNECTED", err)
		return {"ok": false, "error": err}

	# Verify course installation and fingerprint
	var course: Dictionary = meta.get("course", {})
	var course_key: String = str(course.get("key", ""))
	var lat: float = float(course.get("lat", 0.0))
	var lon: float = float(course.get("lon", 0.0))
	var title: String = str(course.get("title", ""))

	var found: Dictionary = CourseFingerprint.find_installed_course(course_key, lat, lon, title)
	if found.is_empty():
		course_install_required.emit(course, "missing")
		return {"ok": false, "error": "Course not installed.", "need_course": true, "course": course}

	var expected_fingerprint: String = str(course.get("fingerprint", ""))
	if not expected_fingerprint.is_empty() and str(found.get("fingerprint", "")) != expected_fingerprint:
		push_warning("[OnlineSession] Spectating course '%s' with geometry fingerprint difference." % title)

	local_scene_path = str(found.get("scene_path", ""))
	local_config_path = str(found.get("config_path", ""))
	is_local_course_ready = true

	# Set spectator state
	is_online_match = true
	is_spectator = true
	is_host = false
	current_match_id = match_id
	match_meta = meta
	match_devices = devices
	var golfers: Dictionary = m_data.get("golfers", {})
	match_golfers = golfers
	var events: Dictionary = m_data.get("events", {})

	_start_stream(match_id)

	var sorted_golfers: Array[Dictionary] = []
	for g in golfers.values():
		if g is Dictionary:
			sorted_golfers.append(g)
	sorted_golfers.sort_custom(func(a, b): return int(a.get("order", 0)) < int(b.get("order", 0)))

	var loop = Engine.get_main_loop()
	var omc: Node = null
	if has_node("/root/OnlineMatchController"):
		omc = get_node("/root/OnlineMatchController")
	elif loop is SceneTree and loop.root != null and loop.root.has_node("OnlineMatchController"):
		omc = loop.root.get_node("OnlineMatchController")

	if omc != null and omc.has_method("start_spectating_match"):
		omc.start_spectating_match(match_id, meta, sorted_golfers, events)

	match_spectated.emit(match_id, meta, sorted_golfers, events)
	return {"ok": true, "match_id": match_id}


func _join_match_internal(match_id: String, local_golfers: Array) -> Dictionary:
	var client := _resolve_rtdb()
	var m_res = await client.get_path("matches/" + match_id)
	if not m_res.get("ok", false) or not (m_res.data is Dictionary):
		var err := "Lobby not found."
		lobby_error.emit("LOBBY_NOT_FOUND", err)
		return {"ok": false, "error": err}

	var m_data: Dictionary = m_res.data
	var meta: Dictionary = m_data.get("meta", {})
	if meta.get("status", "") != "lobby":
		var err := "Match has already started or completed."
		lobby_error.emit("MATCH_ALREADY_STARTED", err)
		return {"ok": false, "error": err}

	var host_uid: String = meta.get("host_uid", "")
	var devices: Dictionary = m_data.get("devices", {})
	var host_device: Dictionary = devices.get(host_uid, {})
	var host_last_seen := float(host_device.get("last_seen", 0.0))
	var now := Time.get_unix_time_from_system()

	# Pre-join Host Liveness Check (§4.4 #3)
	if (now - host_last_seen) > STALE_HEARTBEAT_THRESHOLD_SEC:
		await client.delete_path("lobbies/" + match_id)
		var err := "That lobby is no longer active (the host disconnected)."
		lobby_error.emit("HOST_DISCONNECTED", err)
		return {"ok": false, "error": err}

	var golfers: Dictionary = m_data.get("golfers", {})
	if golfers.size() + local_golfers.size() > MAX_GOLFERS:
		var err := "Lobby is full (maximum %d golfers)." % MAX_GOLFERS
		lobby_error.emit("LOBBY_FULL", err)
		return {"ok": false, "error": err}

	var my_uid := _get_my_uid()
	var my_name := _get_my_display_name()

	var course: Dictionary = meta.get("course", {})
	var course_key: String = course.get("key", "")
	var lat: float = float(course.get("lat", 0.0))
	var lon: float = float(course.get("lon", 0.0))
	var title: String = course.get("title", "")
	var found := CourseFingerprint.find_installed_course(course_key, lat, lon, title)
	var initial_course_ready := not found.is_empty()
	if initial_course_ready:
		local_scene_path = str(found.get("scene_path", ""))
		local_config_path = str(found.get("config_path", ""))

	var dev_payload := {
		"device_name": my_name,
		"joined_at": now,
		"last_seen": now,
		"course_ready": initial_course_ready,
		"course_downloading": false,
		"ready": false
	}
	await client.put_path("matches/" + match_id + "/devices/" + my_uid, dev_payload)
	devices[my_uid] = dev_payload

	# Add local golfers to open slots
	for g in local_golfers:
		var slot_id := ""
		for s in range(MAX_GOLFERS):
			var cand_slot := "slot_%d" % s
			if not golfers.has(cand_slot):
				slot_id = cand_slot
				break
		if slot_id.is_empty():
			break
		var order_idx := int(slot_id.replace("slot_", ""))
		var g_payload := {
			"slot_id": slot_id,
			"owner_uid": my_uid,
			"name": g.get("name", "Player"),
			"tee": g.get("tee", "Blue"),
			"avatar": g.get("avatar", ""),
			"order": order_idx,
			"hand": int(g.get("handedness", 0)),
			"ball_graphic": g.get("ball_graphic", "single_line")
		}
		await client.put_path("matches/" + match_id + "/golfers/" + slot_id, g_payload)
		golfers[slot_id] = g_payload

	# Set state
	is_online_match = true
	current_match_id = match_id
	is_host = false
	match_meta = meta
	match_devices = devices
	match_golfers = golfers
	is_local_course_ready = initial_course_ready
	is_local_course_downloading = false
	is_local_device_ready = false
	restore_local_settings()
	_match_started_emitted = false

	_start_stream(match_id)
	_start_heartbeat()

	# Course Verification (§4.5)
	_verify_local_course(course)

	lobby_updated.emit(match_meta, match_devices, match_golfers)
	return {"ok": true, "match_id": match_id}


func _verify_local_course(course: Dictionary) -> void:
	var course_key: String = course.get("key", "")
	var lat: float = float(course.get("lat", 0.0))
	var lon: float = float(course.get("lon", 0.0))
	var title: String = course.get("title", "")
	var expected_fp: String = course.get("fingerprint", "")

	var found := CourseFingerprint.find_installed_course(course_key, lat, lon, title)
	if not found.is_empty():
		var found_fp: String = str(found.get("fingerprint", ""))
		if expected_fp.is_empty() or found_fp == expected_fp:
			set_local_course_ready(true, found.get("scene_path", ""), found.get("config_path", ""))
		else:
			push_warning("[OnlineSession] Course '%s' installed with geometry fingerprint difference (local: %s, host: %s). Allowing match play." % [title, found_fp, expected_fp])
			set_local_course_ready(true, found.get("scene_path", ""), found.get("config_path", ""))
	else:
		set_local_course_ready(false, "", "")
		course_install_required.emit(course, "missing")


func set_local_course_ready(ready: bool, scene_path: String = "", config_path: String = "") -> void:
	is_local_course_ready = ready
	local_scene_path = scene_path
	local_config_path = config_path
	if ready:
		is_local_course_downloading = false

	if is_online_match and not current_match_id.is_empty():
		var my_uid := _get_my_uid()
		var client := _resolve_rtdb()
		var patch_data: Dictionary = {"course_ready": ready}
		if ready:
			patch_data["course_downloading"] = false
		client.patch_path("matches/" + current_match_id + "/devices/" + my_uid, patch_data)
		if match_devices.has(my_uid):
			match_devices[my_uid]["course_ready"] = ready
			if ready:
				match_devices[my_uid]["course_downloading"] = false
			lobby_updated.emit(match_meta, match_devices, match_golfers)


func set_local_course_downloading(downloading: bool) -> void:
	is_local_course_downloading = downloading
	if is_online_match and not is_spectator and not current_match_id.is_empty():
		var my_uid := _get_my_uid()
		var client := _resolve_rtdb()
		client.patch_path("matches/" + current_match_id + "/devices/" + my_uid, {"course_downloading": downloading})
		if match_devices.has(my_uid):
			match_devices[my_uid]["course_downloading"] = downloading
			lobby_updated.emit(match_meta, match_devices, match_golfers)


func set_local_device_ready(ready: bool) -> void:
	is_local_device_ready = ready
	if is_online_match and not current_match_id.is_empty():
		var my_uid := _get_my_uid()
		var client := _resolve_rtdb()
		client.patch_path("matches/" + current_match_id + "/devices/" + my_uid, {"ready": ready})
		if match_devices.has(my_uid):
			match_devices[my_uid]["ready"] = ready
			lobby_updated.emit(match_meta, match_devices, match_golfers)


func add_local_golfer_to_lobby(golfer_config: Dictionary) -> Dictionary:
	if not is_online_match or current_match_id.is_empty():
		return {"ok": false, "error": "Not currently in a lobby."}

	if match_golfers.size() >= MAX_GOLFERS:
		return {"ok": false, "error": "Lobby is full."}

	var slot_id := ""
	for s in range(MAX_GOLFERS):
		var cand_slot := "slot_%d" % s
		if not match_golfers.has(cand_slot):
			slot_id = cand_slot
			break
	if slot_id.is_empty():
		return {"ok": false, "error": "No open golfer slots."}

	var my_uid := _get_my_uid()
	var order_idx := int(slot_id.replace("slot_", ""))
	var g_payload := {
		"slot_id": slot_id,
		"owner_uid": my_uid,
		"name": golfer_config.get("name", "Player"),
		"tee": golfer_config.get("tee", "Blue"),
		"avatar": golfer_config.get("avatar", ""),
		"order": order_idx,
		"hand": int(golfer_config.get("handedness", 0)),
		"ball_graphic": golfer_config.get("ball_graphic", "single_line")
	}

	var client := _resolve_rtdb()
	var res = await client.put_path("matches/" + current_match_id + "/golfers/" + slot_id, g_payload)
	if res.get("ok", false):
		match_golfers[slot_id] = g_payload
		if is_host and match_meta.get("visibility", "") == "public":
			client.patch_path("lobbies/" + current_match_id, {"player_count": match_golfers.size()})
		lobby_updated.emit(match_meta, match_devices, match_golfers)
	return res


func remove_local_golfer_from_lobby(slot_id: String) -> Dictionary:
	if not is_online_match or current_match_id.is_empty():
		return {"ok": false, "error": "Not currently in a lobby."}

	if not match_golfers.has(slot_id):
		return {"ok": false, "error": "Golfer slot not found."}

	var g = match_golfers[slot_id]
	var my_uid := _get_my_uid()
	if not is_host and g.get("owner_uid", "") != my_uid:
		return {"ok": false, "error": "Cannot remove another player's golfer."}

	var client := _resolve_rtdb()
	var res = await client.delete_path("matches/" + current_match_id + "/golfers/" + slot_id)
	match_golfers.erase(slot_id)

	if is_host and match_meta.get("visibility", "") == "public":
		client.patch_path("lobbies/" + current_match_id, {"player_count": match_golfers.size()})

	lobby_updated.emit(match_meta, match_devices, match_golfers)
	return res


func leave_lobby() -> void:
	if not is_online_match and current_match_id.is_empty():
		return

	var client := _resolve_rtdb()
	var m_id := current_match_id
	var code := current_join_code
	var was_host := is_host
	var was_spec := is_spectator
	var is_still_in_lobby: bool = (match_meta.get("status", "") == "lobby")

	_stop_heartbeat()
	_close_stream()

	is_online_match = false
	is_spectator = false
	current_match_id = ""
	is_host = false
	current_join_code = ""
	_match_started_emitted = false
	match_meta.clear()
	match_devices.clear()
	match_golfers.clear()
	is_local_course_ready = false
	is_local_course_downloading = false
	is_local_device_ready = false
	restore_local_settings()

	if was_spec:
		lobby_closed.emit("left")
		return

	# If host of un-started lobby or active match, clean up
	if was_host:
		if not code.is_empty():
			client.delete_path("codes/" + code)
		if not m_id.is_empty():
			client.delete_path("lobbies/" + m_id)
			if is_still_in_lobby:
				client.delete_path("matches/" + m_id)
	elif not was_host and not m_id.is_empty():
		# Remove own golfers and device
		var my_uid := _get_my_uid()
		for slot_id in match_golfers.keys():
			var g = match_golfers[slot_id]
			if g.get("owner_uid", "") == my_uid:
				client.delete_path("matches/" + m_id + "/golfers/" + slot_id)
		client.delete_path("matches/" + m_id + "/devices/" + my_uid)

	lobby_closed.emit("left")


# ── HEARTBEAT & SSE STREAM ──────────────────────────────────────────────

func _start_heartbeat() -> void:
	if _heartbeat_timer != null:
		_heartbeat_timer.start(HEARTBEAT_INTERVAL_SEC)


func _stop_heartbeat() -> void:
	if _heartbeat_timer != null:
		_heartbeat_timer.stop()


func _on_heartbeat_timeout() -> void:
	if not is_online_match or current_match_id.is_empty():
		_stop_heartbeat()
		return

	var client := _resolve_rtdb()
	var now := Time.get_unix_time_from_system()
	var my_uid := _get_my_uid()

	client.patch_path("matches/" + current_match_id + "/devices/" + my_uid, {"last_seen": now})
	if is_host and match_meta.get("visibility", "") == "public":
		client.patch_path("lobbies/" + current_match_id, {
			"last_seen": now,
			"player_count": match_golfers.size()
		})


func _start_stream(match_id: String) -> void:
	_close_stream()
	var client := _resolve_rtdb()
	if client == null or client.database_url.is_empty():
		return
	_stream = client.open_stream("matches/" + match_id)
	_stream.put.connect(_on_stream_put, CONNECT_DEFERRED)
	_stream.patch.connect(_on_stream_patch, CONNECT_DEFERRED)


func _close_stream() -> void:
	if _stream != null:
		_stream.close()
		_stream = null


func _preserve_local_device_state() -> void:
	var my_uid := _get_my_uid()
	if is_online_match and not my_uid.is_empty() and match_devices.has(my_uid):
		if is_local_course_ready:
			match_devices[my_uid]["course_ready"] = true
		if is_local_course_downloading:
			match_devices[my_uid]["course_downloading"] = true
		if is_local_device_ready:
			match_devices[my_uid]["ready"] = true


func _on_stream_put(path: String, data: Variant) -> void:
	var clean_path := path.strip_edges().trim_prefix("/")
	if clean_path.is_empty():
		if data is Dictionary:
			match_meta = data.get("meta", {})
			match_devices = data.get("devices", {})
			_preserve_local_device_state()
			match_golfers = data.get("golfers", {})
			if data.has("events") and data["events"] is Dictionary:
				for k in data["events"]:
					if data["events"][k] is Dictionary:
						event_received.emit(str(k), data["events"][k])
			if match_meta.has("turn") and match_meta["turn"] is Dictionary:
				turn_updated.emit(match_meta["turn"])
	elif clean_path == "meta" and data is Dictionary:
		match_meta = data
		if match_meta.has("turn") and match_meta["turn"] is Dictionary:
			turn_updated.emit(match_meta["turn"])
	elif clean_path.begins_with("meta/"):
		var sub := clean_path.trim_prefix("meta/")
		match_meta[sub] = data
		if sub == "turn" and data is Dictionary:
			turn_updated.emit(data)
	elif clean_path == "devices" and data is Dictionary:
		match_devices = data
		_preserve_local_device_state()
		for dev_uid in match_devices:
			if match_devices[dev_uid] is Dictionary:
				device_updated.emit(str(dev_uid), match_devices[dev_uid])
	elif clean_path.begins_with("devices/"):
		var sub := clean_path.trim_prefix("devices/")
		var parts := sub.split("/")
		var dev_uid := parts[0]
		if parts.size() == 1:
			if data == null:
				match_devices.erase(dev_uid)
			elif data is Dictionary:
				match_devices[dev_uid] = data
				if dev_uid == _get_my_uid():
					_preserve_local_device_state()
				device_updated.emit(dev_uid, match_devices[dev_uid])
		elif parts.size() == 2:
			var prop := parts[1]
			if not match_devices.has(dev_uid):
				match_devices[dev_uid] = {}
			if data == null:
				match_devices[dev_uid].erase(prop)
			else:
				match_devices[dev_uid][prop] = data
			if dev_uid == _get_my_uid():
				_preserve_local_device_state()
			device_updated.emit(dev_uid, match_devices[dev_uid])
	elif clean_path == "golfers" and data is Dictionary:
		match_golfers = data
	elif clean_path.begins_with("golfers/"):
		var slot_id := clean_path.trim_prefix("golfers/")
		if data == null:
			match_golfers.erase(slot_id)
		elif data is Dictionary:
			match_golfers[slot_id] = data
	elif clean_path == "events" and data is Dictionary:
		for k in data:
			if data[k] is Dictionary:
				event_received.emit(str(k), data[k])
	elif clean_path.begins_with("events/"):
		var seq_key := clean_path.trim_prefix("events/")
		if data is Dictionary:
			event_received.emit(seq_key, data)

	_check_stream_state_transition()


func _on_stream_patch(path: String, data: Variant) -> void:
	var clean_path := path.strip_edges().trim_prefix("/")
	if not (data is Dictionary):
		return

	if clean_path.is_empty():
		for k in data:
			if k == "meta" and data[k] is Dictionary:
				_merge_dict(match_meta, data[k])
				if match_meta.has("turn") and match_meta["turn"] is Dictionary:
					turn_updated.emit(match_meta["turn"])
			elif k == "devices" and data[k] is Dictionary:
				_merge_dict(match_devices, data[k])
				_preserve_local_device_state()
			elif k == "golfers" and data[k] is Dictionary:
				_merge_dict(match_golfers, data[k])
			elif k == "events" and data[k] is Dictionary:
				for ek in data[k]:
					if data[k][ek] is Dictionary:
						event_received.emit(str(ek), data[k][ek])
	elif clean_path == "meta":
		_merge_dict(match_meta, data)
		if match_meta.has("turn") and match_meta["turn"] is Dictionary:
			turn_updated.emit(match_meta["turn"])
	elif clean_path.begins_with("meta/"):
		var sub := clean_path.trim_prefix("meta/")
		match_meta[sub] = data
		if sub == "turn" and data is Dictionary:
			turn_updated.emit(data)
	elif clean_path == "devices":
		_merge_dict(match_devices, data)
		_preserve_local_device_state()
	elif clean_path.begins_with("devices/"):
		var sub := clean_path.trim_prefix("devices/")
		var parts := sub.split("/")
		var dev_uid := parts[0]
		if not match_devices.has(dev_uid):
			match_devices[dev_uid] = {}
		if parts.size() == 1:
			_merge_dict(match_devices[dev_uid], data)
		elif parts.size() == 2:
			var prop := parts[1]
			if not match_devices[dev_uid].has(prop) or not (match_devices[dev_uid][prop] is Dictionary):
				match_devices[dev_uid][prop] = {}
			_merge_dict(match_devices[dev_uid][prop], data)
		if dev_uid == _get_my_uid():
			_preserve_local_device_state()
		device_updated.emit(dev_uid, match_devices[dev_uid])
	elif clean_path == "golfers":
		_merge_dict(match_golfers, data)
	elif clean_path.begins_with("golfers/"):
		var slot_id := clean_path.trim_prefix("golfers/")
		if not match_golfers.has(slot_id):
			match_golfers[slot_id] = {}
		_merge_dict(match_golfers[slot_id], data)
	elif clean_path == "events":
		for k in data:
			if data[k] is Dictionary:
				event_received.emit(str(k), data[k])
	elif clean_path.begins_with("events/"):
		var seq_key := clean_path.trim_prefix("events/")
		event_received.emit(seq_key, data)

	_check_stream_state_transition()


func is_replaying_remote_turn() -> bool:
	if _is_replaying_remote:
		return true
	if has_node("/root/OnlineMatchController"):
		var omc = get_node("/root/OnlineMatchController")
		if omc != null and omc.has_method("is_replaying"):
			return bool(omc.call("is_replaying"))
	return false


func set_replaying_remote_turn(replaying: bool) -> void:
	_is_replaying_remote = replaying


func snapshot_and_apply_match_settings() -> void:
	_saved_local_settings.clear()
	var gs = _get_global_settings()
	if gs != null and gs.range_settings != null:
		var s: Dictionary = match_meta.get("settings", {})

		# 1. Standard match settings
		for k in SNAPSHOT_SETTINGS_KEYS:
			if gs.range_settings.settings.has(k):
				_saved_local_settings[k] = gs.range_settings.settings[k].value

		for k in SNAPSHOT_SETTINGS_KEYS:
			if s.has(k) and gs.range_settings.settings.has(k):
				gs.range_settings.settings[k].set_value(s[k])

		# 2. Gimme settings: only force if host specified force_gimmes == true
		var force_gimmes: bool = bool(s.get("force_gimmes", false))
		if force_gimmes:
			if "suppress_save" in gs:
				gs.suppress_save = true

			for k in GIMME_SETTINGS_KEYS:
				if gs.range_settings.settings.has(k):
					_saved_local_settings[k] = gs.range_settings.settings[k].value
					if s.has(k):
						gs.range_settings.settings[k].set_value(s[k])
			print("[OnlineSession] Applied forced host gimme settings for online match.")
		else:
			print("[OnlineSession] Using players' personal local gimme settings.")

		if s.has("wind_speed_mph"):
			gs.current_wind_speed_mph = float(s["wind_speed_mph"])
		if s.has("wind_dir_rad"):
			gs.current_wind_direction_rad = float(s["wind_dir_rad"])


func restore_local_settings() -> void:
	var gs = _get_global_settings()
	if gs != null and gs.range_settings != null:
		for k in _saved_local_settings:
			if gs.range_settings.settings.has(k):
				gs.range_settings.settings[k].set_value(_saved_local_settings[k])
		if "suppress_save" in gs:
			gs.suppress_save = false
		if gs.has_method("save_settings"):
			gs.save_settings()
	_saved_local_settings.clear()

	if has_node("/root/CloudSync"):
		var cs = get_node("/root/CloudSync")
		if cs != null and cs.has_method("sync_all_profiles"):
			cs.call("sync_all_profiles")


func _get_global_settings() -> Node:
	if has_node("/root/GlobalSettings"):
		return get_node("/root/GlobalSettings")
	var loop = Engine.get_main_loop()
	if loop is SceneTree and loop.root != null and loop.root.has_node("GlobalSettings"):
		return loop.root.get_node("GlobalSettings")
	return null


func end_online_match() -> void:
	if is_host and not current_match_id.is_empty() and match_meta.get("visibility", "") == "public":
		var client := _resolve_rtdb()
		client.delete_path("lobbies/" + current_match_id)
	is_online_match = false
	is_spectator = false
	current_match_id = ""
	is_host = false
	current_join_code = ""
	match_meta = {}
	match_devices = {}
	match_golfers = {}
	is_local_course_ready = false
	is_local_course_downloading = false
	is_local_device_ready = false
	restore_local_settings()
	_match_started_emitted = false
	_close_stream()
	restore_local_settings()
	if FileAccess.file_exists("user://active_online_match.json"):
		DirAccess.remove_absolute("user://active_online_match.json")


func _merge_dict(target: Dictionary, patch: Dictionary) -> void:
	for k in patch:
		target[k] = patch[k]


func _check_stream_state_transition() -> void:
	# If remote host kicked this device
	var my_uid := _get_my_uid()
	if not is_host and not is_spectator and is_online_match and not my_uid.is_empty() and not match_devices.has(my_uid):
		leave_lobby()
		lobby_closed.emit("You were removed from the lobby by the host.")
		return

	if match_meta.get("status", "") == "active":
		if not _match_started_emitted:
			_match_started_emitted = true
			var sorted_golfers: Array[Dictionary] = []
			for g in match_golfers.values():
				sorted_golfers.append(g)
			sorted_golfers.sort_custom(func(a, b): return int(a.get("order", 0)) < int(b.get("order", 0)))
			match_started.emit(current_match_id, match_meta, sorted_golfers)
	else:
		_match_started_emitted = false
		lobby_updated.emit(match_meta, match_devices, match_golfers)
