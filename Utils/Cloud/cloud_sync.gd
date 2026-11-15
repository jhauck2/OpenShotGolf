extends Node

## Cloud Sync Engine for OpenFairway.
## Handles non-destructive startup pull, match-end push with idempotent transforms,
## 30-minute foreground sync timer, and dirty tracking in user://cloud_sync_state.json.

const FirestoreClient = preload("res://Utils/Cloud/firestore_client.gd")
const StatsMerger = preload("res://Utils/Cloud/stats_merger.gd")
const LinkServiceClass = preload("res://Utils/Cloud/link_service.gd")

signal sync_started()
signal sync_completed(success: bool, synced_profiles: Array[String])
signal primary_profile_changed(player_name: String)
signal sync_throttled(cooldown_remaining: float)

const SYNC_STATE_PATH := "user://cloud_sync_state.json"
const PERIODIC_SYNC_INTERVAL := 1800.0 # 30 minutes in seconds
const DEFAULT_MANUAL_SYNC_COOLDOWN := 60.0 # 60 seconds rate limit on manual button clicks

var manual_sync_cooldown_seconds: float = DEFAULT_MANUAL_SYNC_COOLDOWN
var last_manual_sync_timestamp: float = 0.0

var dirty_profiles: Array[String] = []
var pending_matches: Array[Dictionary] = []
var last_pushed_leaderboard: Dictionary = {}

var _active_foreground_seconds: float = 0.0
var _is_app_focused: bool = true
var _is_syncing: bool = false
var firestore: FirestoreClient = null
var auth_node: Node = null


func _init() -> void:
	name = "CloudSync"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_load_sync_state()

	# Listen to CloudAuth auth changes
	if has_node("/root/CloudAuth"):
		var auth = get_node("/root/CloudAuth")
		if auth.has_signal("auth_state_changed"):
			auth.auth_state_changed.connect(_on_auth_state_changed)

	# Listen to MultiplayerManager game over
	if has_node("/root/MultiplayerManager"):
		var mp = get_node("/root/MultiplayerManager")
		if mp.has_signal("game_over"):
			mp.game_over.connect(_on_multiplayer_game_over)

	# If already signed in on startup, trigger startup pull
	call_deferred("_check_startup_sync")


func _process(delta: float) -> void:
	if not _is_app_focused:
		return

	_active_foreground_seconds += delta
	if _active_foreground_seconds >= PERIODIC_SYNC_INTERVAL:
		_active_foreground_seconds = 0.0
		# Only sync if there are dirty profiles or pending matches
		if not dirty_profiles.is_empty() or not pending_matches.is_empty():
			print("[CloudSync] 30 minutes of active usage elapsed with dirty changes. Triggering periodic sync.")
			sync_all_eligible_profiles("periodic_30m")
		else:
			print("[CloudSync] 30 minutes of active usage elapsed with NO dirty changes. Skipping sync pass (0 writes).")


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_is_app_focused = true
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_is_app_focused = false
			_save_sync_state()
		NOTIFICATION_APPLICATION_PAUSED:
			# Mobile OS pause (Android / iOS)
			_is_app_focused = false
			_save_sync_state()
		NOTIFICATION_APPLICATION_RESUMED:
			# Mobile OS resume
			_is_app_focused = true
		NOTIFICATION_WM_CLOSE_REQUEST:
			_save_sync_state()


func set_auth_node(p_auth: Node) -> void:
	auth_node = p_auth


func _get_auth() -> Node:
	if auth_node != null and is_instance_valid(auth_node):
		return auth_node
	return get_node_or_null("/root/CloudAuth")


func set_firestore_client(p_client: FirestoreClient) -> void:
	firestore = p_client


func _get_firestore() -> FirestoreClient:
	if firestore == null:
		var auth := _get_auth()
		firestore = FirestoreClient.new(auth)
	return firestore


# ── STATE PERSISTENCE ────────────────────────────────────────────────────

func _load_sync_state() -> void:
	if not FileAccess.file_exists(SYNC_STATE_PATH):
		return
	var f = FileAccess.open(SYNC_STATE_PATH, FileAccess.READ)
	if f == null:
		return
	var txt = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if parsed is Dictionary:
		dirty_profiles.clear()
		for p in parsed.get("dirty_profiles", []):
			dirty_profiles.append(str(p))
		pending_matches.clear()
		for m in parsed.get("pending_matches", []):
			if m is Dictionary:
				pending_matches.append(m)
		last_pushed_leaderboard = parsed.get("last_pushed_leaderboard", {})
		last_manual_sync_timestamp = float(parsed.get("last_manual_sync_timestamp", 0.0))


func _save_sync_state() -> void:
	var state = {
		"dirty_profiles": dirty_profiles,
		"pending_matches": pending_matches,
		"last_pushed_leaderboard": last_pushed_leaderboard,
		"last_manual_sync_timestamp": last_manual_sync_timestamp
	}
	var f = FileAccess.open(SYNC_STATE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(state, "\t"))
		f.close()


func get_manual_sync_cooldown_remaining() -> float:
	var now := Time.get_unix_time_from_system()
	var elapsed := now - last_manual_sync_timestamp
	if elapsed < 0.0:
		return 0.0
	return maxf(0.0, manual_sync_cooldown_seconds - elapsed)


func can_manual_sync() -> bool:
	if _is_syncing:
		return false
	return get_manual_sync_cooldown_remaining() <= 0.0


func reset_manual_sync_cooldown() -> void:
	last_manual_sync_timestamp = 0.0
	_save_sync_state()


# ── DIRTY & MATCH TRACKING ───────────────────────────────────────────────

func mark_profile_dirty(player_name: String) -> void:
	var clean_name = player_name.strip_edges()
	if clean_name.is_empty():
		return

	var is_synced := false
	if has_node("/root/MultiplayerManager"):
		var reg = get_node("/root/MultiplayerManager").call("get_registered_players")
		for p in reg:
			if str(p.get("name", "")).to_lower() == clean_name.to_lower():
				var role = str(p.get("link_role", "none"))
				if role in ["primary", "linked"]:
					is_synced = true
					clean_name = str(p.get("name", clean_name))
				break
	else:
		is_synced = true

	if is_synced:
		var already_dirty := false
		for dp in dirty_profiles:
			if str(dp).strip_edges().to_lower() == clean_name.to_lower():
				already_dirty = true
				break
		if not already_dirty:
			dirty_profiles.append(clean_name)
		_save_sync_state()


func queue_completed_match(match_json: Dictionary) -> void:
	var is_practice = bool(match_json.get("practice_mode_active", false))
	if is_practice:
		return
	var is_finished = bool(match_json.get("is_finished", true))

	var players_list = match_json.get("players", [])
	if players_list.is_empty():
		return

	var mp = get_node_or_null("/root/MultiplayerManager")
	var registered: Array = []
	if mp != null and mp.has_method("get_registered_players"):
		registered = mp.get_registered_players()

	var hole_ids: Array = match_json.get("hole_ids", [])
	var holes_count = hole_ids.size()
	var game_mode = str(match_json.get("game_mode", "Standard"))

	# Determine winners
	var winners: Array = match_json.get("winners", [])
	var is_single_player = (players_list.size() == 1)

	for p in players_list:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var p_name = str(p.get("name", ""))
		# Find in registered players
		var reg_p = null
		for rp in registered:
			if str(rp.get("name", "")).to_lower() == p_name.to_lower():
				reg_p = rp
				break

		if reg_p == null:
			continue
		var link_role = str(reg_p.get("link_role", "none"))
		var cloud_uid = str(reg_p.get("cloud_uid", ""))
		if not (link_role in ["primary", "linked"]) or cloud_uid.is_empty():
			continue

		var raw_strokes = int(p.get("total_strokes", 0))
		var par = 0
		var hole_pars = match_json.get("hole_pars", {})
		if hole_pars is Dictionary:
			for hid in hole_pars:
				par += int(hole_pars[hid])

		var to_par = raw_strokes - par if par > 0 else 0
		var is_winner = winners.has(p_name)
		var is_loss = (not is_winner and not is_single_player and winners.size() > 0)
		var is_tie = (is_winner and winners.size() > 1)

		var longest_dr := 0.0
		var longest_pt := 0.0
		var p_shot_stats = p.get("shot_stats", {})
		if p_shot_stats is Dictionary:
			for hid in p_shot_stats:
				if p_shot_stats[hid] is Array:
					for s in p_shot_stats[hid]:
						if s is Dictionary:
							var clb = str(s.get("club", "")).to_lower()
							var tot_y = float(s.get("total_yds", 0.0))
							if (clb in ["dr", "driver", "1w"] or clb.begins_with("dr")) and tot_y > longest_dr:
								longest_dr = tot_y

		var m_id = str(match_json.get("match_id", ""))
		if m_id.is_empty():
			if mp != null and mp.has_method("generate_uuid_v4"):
				m_id = str(mp.call("generate_uuid_v4"))
			else:
				m_id = "match_%d" % int(Time.get_unix_time_from_system())

		var holes_arr: Array = []
		var hole_scores = p.get("hole_scores", {})
		if hole_scores is Dictionary and hole_ids is Array:
			for i in range(hole_ids.size()):
				var hid = hole_ids[i]
				var h_par = int(hole_pars.get(hid, 4)) if hole_pars is Dictionary else 4
				var h_score = int(hole_scores.get(hid, 0))
				if h_score > 0:
					holes_arr.append({
						"hole_number": i + 1,
						"par": h_par,
						"score": h_score
					})

		# Do not upload empty 0-shot unplayed stub matches
		if raw_strokes <= 0 and holes_arr.is_empty() and longest_dr <= 0.0:
			continue
		var strokes = maxi(1, raw_strokes)

		var played_time = int(match_json.get("unix_time", match_json.get("timestamp", Time.get_unix_time_from_system())))

		var summary = {
			"schema_version": 1,
			"match_id": m_id,
			"cloud_uid": cloud_uid,
			"player_name": p_name,
			"course_name": str(match_json.get("course_title", match_json.get("course_name", "Unknown Course"))),
			"holes_count": clampi(holes_count, 1, 36),
			"strokes": strokes,
			"par": par,
			"to_par": to_par,
			"is_finished": is_finished,
			"is_winner": is_winner,
			"is_loss": is_loss,
			"is_tie": is_tie,
			"is_single_player": is_single_player,
			"match_type": "single_player" if is_single_player else "multiplayer",
			"mulligans_used": int(p.get("mulligans_used", 0)),
			"game_mode": game_mode,
			"longest_drive_yds": longest_dr,
			"longest_putt_ft": longest_pt,
			"played_at": played_time,
			"created_at": played_time
		}
		if not holes_arr.is_empty():
			summary["holes"] = holes_arr

		# Prevent duplicate pending match
		var already_queued := false
		for m in pending_matches:
			if m.get("match_id") == summary["match_id"] and m.get("cloud_uid") == summary["cloud_uid"]:
				already_queued = true
				break
		if not already_queued:
			pending_matches.append(summary)

		mark_profile_dirty(p_name)

	_save_sync_state()
	sync_all_eligible_profiles.call_deferred("match_finished")


func enqueue_historical_local_matches_for_profile(player_name: String, cloud_uid: String) -> void:
	if player_name.strip_edges().is_empty() or cloud_uid.strip_edges().is_empty():
		return
	var hist_dir := "user://match_history"
	if not DirAccess.dir_exists_absolute(hist_dir):
		return
	var dir := DirAccess.open(hist_dir)
	if dir == null:
		return

	var clean_target := player_name.strip_edges().to_lower()
	var added_any := false
	dir.list_dir_begin()
	var fname := dir.get_next()
	while not fname.is_empty():
		if not dir.current_is_dir() and fname.ends_with(".json"):
			var fpath := hist_dir + "/" + fname
			var f := FileAccess.open(fpath, FileAccess.READ)
			if f != null:
				var raw_text := f.get_as_text().strip_edges()
				f.close()
				if raw_text.is_empty():
					fname = dir.get_next()
					continue
				var parsed = JSON.parse_string(raw_text)
				if parsed is Dictionary:
					var is_practice: bool = bool(parsed.get("practice_mode_active", false))
					var is_finished: bool = bool(parsed.get("is_finished", false))
					if not is_practice:
						var players_list = parsed.get("players", [])
						if players_list is Array:
							for p in players_list:
								if p is Dictionary and str(p.get("name", "")).strip_edges().to_lower() == clean_target:
									var hole_ids: Array = parsed.get("hole_ids", [])
									var holes_count: int = clampi(hole_ids.size(), 1, 36)
									var raw_strokes: int = int(p.get("total_strokes", 0))
									var par := 0
									var hole_pars = parsed.get("hole_pars", {})
									if hole_pars is Dictionary:
										for hid in hole_pars:
											par += int(hole_pars[hid])
									var to_par := raw_strokes - par if par > 0 else 0
									var winners: Array = parsed.get("winners", [])
									var is_single_player: bool = (players_list.size() == 1)
									var is_winner: bool = winners.has(p.get("name", ""))
									var is_loss: bool = (not is_winner and not is_single_player and winners.size() > 0)
									var is_tie: bool = (is_winner and winners.size() > 1)
									var longest_dr := 0.0
									var p_shot_stats = p.get("shot_stats", {})
									if p_shot_stats is Dictionary:
										for hid in p_shot_stats:
											if p_shot_stats[hid] is Array:
												for s in p_shot_stats[hid]:
													if s is Dictionary:
														var clb := str(s.get("club", "")).to_lower()
														var tot_y := float(s.get("total_yds", 0.0))
														if (clb in ["dr", "driver", "1w"] or clb.begins_with("dr")) and tot_y > longest_dr:
															longest_dr = tot_y
									var m_id := str(parsed.get("match_id", fname.get_basename()))
									var played_time := int(parsed.get("unix_time", parsed.get("timestamp", Time.get_unix_time_from_system())))
									var hist_holes: Array = []
									var p_hole_scores = p.get("hole_scores", {})
									if p_hole_scores is Dictionary and hole_ids is Array:
										for i in range(hole_ids.size()):
											var hid = hole_ids[i]
											var h_par = int(hole_pars.get(hid, 4)) if hole_pars is Dictionary else 4
											var h_score = int(p_hole_scores.get(hid, 0))
											if h_score > 0:
												hist_holes.append({
													"hole_number": i + 1,
													"par": h_par,
													"score": h_score
												})

									# Do not upload unplayed stubs
									if raw_strokes <= 0 and hist_holes.is_empty() and longest_dr <= 0.0:
										continue
									var strokes: int = maxi(1, raw_strokes)

									var summary := {
										"schema_version": 1,
										"match_id": m_id,
										"cloud_uid": cloud_uid,
										"player_name": str(p.get("name", player_name)),
										"course_name": str(parsed.get("course_title", parsed.get("course_name", "Unknown Course"))),
										"holes_count": holes_count,
										"strokes": strokes,
										"par": par,
										"to_par": to_par,
										"is_finished": is_finished,
										"is_winner": is_winner,
										"is_loss": is_loss,
										"is_tie": is_tie,
										"is_single_player": is_single_player,
										"match_type": "single_player" if is_single_player else "multiplayer",
										"mulligans_used": int(p.get("mulligans_used", 0)),
										"game_mode": str(parsed.get("game_mode", "Standard")),
										"longest_drive_yds": longest_dr,
										"longest_putt_ft": 0.0,
										"played_at": played_time,
										"created_at": played_time
									}
									if not hist_holes.is_empty():
										summary["holes"] = hist_holes
									var exists := false
									for m in pending_matches:
										if m.get("match_id") == m_id and m.get("cloud_uid") == cloud_uid:
											exists = true
											break
									if not exists:
										pending_matches.append(summary)
										added_any = true
		fname = dir.get_next()
	dir.list_dir_end()
	mark_profile_dirty(player_name)
	if added_any:
		_save_sync_state()


# ── SYNC ENGINE ──────────────────────────────────────────────────────────

func _on_auth_state_changed(is_signed_in: bool, _user: Dictionary) -> void:
	if is_signed_in:
		print("[CloudSync] Sign-in detected. Running startup pull.")
		sync_all_eligible_profiles("startup")


func _check_startup_sync() -> void:
	var auth = _get_auth()
	if auth != null and auth.has_method("is_signed_in") and auth.is_signed_in():
		sync_all_eligible_profiles("startup")


func _on_multiplayer_game_over(winners: Array, _skins: Dictionary = {}) -> void:
	var mp = get_node_or_null("/root/MultiplayerManager")
	if mp == null or mp.practice_mode_active:
		return
	var match_dict = {
		"match_id": mp.current_match_id,
		"course_title": mp.course_title,
		"game_mode": mp.game_mode,
		"practice_mode_active": mp.practice_mode_active,
		"is_finished": mp.is_finished,
		"players": mp.players,
		"winners": winners,
		"hole_pars": mp.call("_get_hole_pars") if mp.has_method("_get_hole_pars") else {},
		"hole_ids": mp.hole_ids
	}
	queue_completed_match(match_dict)


func sync_all_eligible_profiles(reason: String = "manual") -> void:
	if _is_syncing:
		print("[CloudSync] Sync already in progress, skipping %s trigger." % reason)
		return

	var auth = _get_auth()
	if auth != null and auth.has_method("is_cloud_service_paused") and auth.is_cloud_service_paused():
		print("[CloudSync] Cloud service is paused due to budget. Skipping %s sync." % reason)
		return
	if auth != null and auth.has_method("is_signed_in") and not auth.is_signed_in():
		print("[CloudSync] Not signed in. Skipping %s sync." % reason)
		return

	if reason == "manual":
		var remaining := get_manual_sync_cooldown_remaining()
		if remaining > 0.0:
			print("[CloudSync] Manual sync throttled. Cooldown remaining: %.1fs" % remaining)
			sync_throttled.emit(remaining)
			_show_cooldown_toast(int(ceil(remaining)))
			return
		last_manual_sync_timestamp = Time.get_unix_time_from_system()
		_save_sync_state()

	_is_syncing = true
	sync_started.emit()
	var synced: Array[String] = []
	var all_ok := true

	# Also check outgoing link requests on startup / periodic / manual to resolve pending approvals
	if reason in ["startup", "periodic_30m", "manual"]:
		var link_svc = LinkServiceClass.new(firestore, auth)
		await link_svc.check_outgoing_requests()

	var mp = get_node_or_null("/root/MultiplayerManager")
	var registered: Array = []
	if mp != null and mp.has_method("get_registered_players"):
		registered = mp.get_registered_players()

	var my_uid = auth.get_uid() if (auth != null and auth.has_method("get_uid")) else ""

	for p in registered:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var role = str(p.get("link_role", "none"))
		var p_name = str(p.get("name", ""))
		var p_cloud_uid = str(p.get("cloud_uid", ""))

		var is_manual_pass: bool = (reason == "manual")
		if role == "primary":
			if p_cloud_uid.is_empty() and not my_uid.is_empty():
				p_cloud_uid = my_uid
				p["cloud_uid"] = my_uid
				mp.save_registered_players(registered)
			if not p_cloud_uid.is_empty():
				var res = await sync_single_profile(p_name, p_cloud_uid, is_manual_pass)
				if res.get("ok", false):
					synced.append(p_name)
				else:
					all_ok = false
		elif role == "linked" and not p_cloud_uid.is_empty():
			var res = await sync_single_profile(p_name, p_cloud_uid, is_manual_pass)
			if res.get("ok", false):
				synced.append(p_name)
			elif res.get("revoked", false):
				# Graceful degradation: linked access was revoked, but does NOT fail primary sync
				print("[CloudSync] Secondary profile '%s' access was revoked." % p_name)
			else:
				all_ok = false

	_is_syncing = false
	sync_completed.emit(all_ok, synced)
	print("[CloudSync] Sync pass '%s' completed. Synced profiles: %s (all_ok=%s)" % [reason, str(synced), str(all_ok)])


func sync_single_profile(player_name: String, cloud_uid: String, is_manual: bool = false) -> Dictionary:
	if is_manual:
		if _is_syncing:
			print("[CloudSync] Sync already in progress, skipping manual sync for %s." % player_name)
			return {"ok": false, "error": "Sync already in progress", "is_syncing": true}
		var remaining := get_manual_sync_cooldown_remaining()
		if remaining > 0.0:
			print("[CloudSync] Manual sync throttled for %s. Cooldown remaining: %.1fs" % [player_name, remaining])
			sync_throttled.emit(remaining)
			_show_cooldown_toast(int(ceil(remaining)))
			return {
				"ok": false,
				"error": "Sync cooldown active. Please wait %d seconds." % int(ceil(remaining)),
				"throttled": true,
				"cooldown_remaining": remaining
			}
		last_manual_sync_timestamp = Time.get_unix_time_from_system()
		_save_sync_state()

	var client := _get_firestore()
	if client == null:
		return {"ok": false, "error": "No Firestore client"}

	var auth = _get_auth()
	if auth != null and auth.has_method("is_cloud_service_paused") and auth.is_cloud_service_paused():
		return {"ok": false, "error": "Cloud service paused", "budget_paused": true}
	if auth != null and auth.has_method("is_signed_in") and not auth.is_signed_in():
		return {"ok": false, "error": "Not signed in"}

	var mp = get_node_or_null("/root/MultiplayerManager")
	var reg_p: Dictionary = {}
	if mp != null and mp.has_method("get_registered_players"):
		for p in mp.get_registered_players():
			if str(p.get("name", "")).to_lower() == player_name.to_lower():
				reg_p = p
				break

	var is_dirty: bool = is_manual
	for dp in dirty_profiles:
		if str(dp).strip_edges().to_lower() == player_name.strip_edges().to_lower():
			is_dirty = true
			break
	var local_rev = int(reg_p.get("last_synced_rev", 0))

	# 1. Cheap startup read optimization: get profiles/{uid}
	var prof_res = await client.get_doc("profiles/" + cloud_uid)
	var cloud_prof: Dictionary = {}
	if prof_res.get("ok", false) and prof_res.get("data") is Dictionary:
		cloud_prof = prof_res.get("data", {})
	elif prof_res.get("status") == 404:
		# Profile document does not exist yet in Firestore
		cloud_prof = {}
	else:
		var is_403: bool = (prof_res.get("status") == 403) or str(prof_res.get("error", "")).find("PERMISSION_DENIED") != -1 or str(prof_res.get("error", "")).find("403") != -1
		if is_403 and str(reg_p.get("link_role", "")) == "linked":
			return _handle_linked_revocation(player_name, cloud_uid, mp)
		print("[CloudSync] Failed to fetch profile for %s (%s): %s (status: %s)" % [player_name, cloud_uid, prof_res.get("error", "Unknown error"), prof_res.get("status")])
		return {"ok": false, "error": prof_res.get("error", "Failed to fetch profile")}

	var cloud_rev = int(cloud_prof.get("rev", 0))

	# Determine display name: preserve user2's cloud display name when host is syncing a linked profile
	var my_current_uid = auth.get_uid() if (auth != null and auth.has_method("get_uid")) else ""
	var is_owner = (my_current_uid == cloud_uid)
	var cloud_display_name = str(cloud_prof.get("display_name", ""))
	var final_display_name = player_name
	if not is_owner and not cloud_display_name.is_empty():
		final_display_name = cloud_display_name

	var local_ach = _gather_local_achievements(player_name)
	var local_ach_count: int = local_ach.get("unlocked", {}).size()
	var cloud_ach_count: int = int(cloud_prof.get("lifetime", {}).get("achievements_count", 0))

	var needs_stats_sync = is_dirty or is_manual or (local_rev == 0) or (cloud_rev != local_rev) or cloud_prof.is_empty() or (local_ach_count > cloud_ach_count)

	if needs_stats_sync:
		var cloud_stats_doc: Dictionary = {}
		if not cloud_prof.is_empty():
			var stats_res = await client.get_doc("profiles/" + cloud_uid + "/sync/stats")
			if stats_res.get("ok", false) and stats_res.get("data") is Dictionary:
				cloud_stats_doc = stats_res.get("data")
			elif not stats_res.get("ok", false) and stats_res.get("status") != 404:
				var is_403_stats: bool = (stats_res.get("status") == 403) or str(stats_res.get("error", "")).find("PERMISSION_DENIED") != -1 or str(stats_res.get("error", "")).find("403") != -1
				if is_403_stats and str(reg_p.get("link_role", "")) == "linked":
					return _handle_linked_revocation(player_name, cloud_uid, mp)
				print("[CloudSync] Failed to fetch stats for %s (%s): %s (status: %s)" % [player_name, cloud_uid, stats_res.get("error"), stats_res.get("status")])

		# Gather local data
		var local_stats_dict = _gather_local_stats_dict(player_name, reg_p)

		# Merge via pure StatsMerger
		var merged = StatsMerger.merge_profile_stats(local_stats_dict, cloud_stats_doc)

		# Apply merged stats locally
		_apply_merged_stats_locally(player_name, merged)

		# Upload to profiles/{uid}/sync/stats
		var new_rev = maxi(cloud_rev, local_rev) + 1
		merged["rev"] = new_rev
		merged["updated_at"] = int(Time.get_unix_time_from_system())

		var put_stats_res = await client.set_doc("profiles/" + cloud_uid + "/sync/stats", merged)
		if not put_stats_res.get("ok", false):
			var is_403_put: bool = (put_stats_res.get("status") == 403) or str(put_stats_res.get("error", "")).find("PERMISSION_DENIED") != -1 or str(put_stats_res.get("error", "")).find("403") != -1
			if is_403_put and str(reg_p.get("link_role", "")) == "linked":
				return _handle_linked_revocation(player_name, cloud_uid, mp)
			print("[CloudSync] Failed to upload stats for %s (%s): %s (status: %s)" % [player_name, cloud_uid, put_stats_res.get("error"), put_stats_res.get("status")])
			return {"ok": false, "error": put_stats_res.get("error", "Failed to upload stats")}

		# Build effective lifetime stats (merging local records and achievements into lifetime)
		var eff_lifetime: Dictionary = cloud_prof.get("lifetime", {}).duplicate()
		var tombstones_merged: Dictionary = merged.get("tombstones", {})
		var eff_clear_all_ts: int = int(tombstones_merged.get("cleared_all_at", 0))

		var rec_longest_dr = float(merged.get("records", {}).get("longest_drive_yds", merged.get("records", {}).get("longest_drive", 0.0)))
		var dr_cleared = StatsMerger.get_effective_club_clear_ts(tombstones_merged.get("cleared_clubs", {}), "Dr", eff_clear_all_ts) > 0
		if dr_cleared and rec_longest_dr == 0.0:
			eff_lifetime["longest_drive_yds"] = 0.0
			eff_lifetime["longest_drive"] = 0.0
		elif rec_longest_dr > float(eff_lifetime.get("longest_drive_yds", 0.0)) or dr_cleared:
			eff_lifetime["longest_drive_yds"] = rec_longest_dr

		var rec_longest_pt = float(merged.get("records", {}).get("longest_putt_ft", 0.0))
		var pt_cleared = StatsMerger.get_effective_club_clear_ts(tombstones_merged.get("cleared_clubs", {}), "Pt", eff_clear_all_ts) > 0
		if pt_cleared and rec_longest_pt == 0.0:
			eff_lifetime["longest_putt_ft"] = 0.0
		elif rec_longest_pt > float(eff_lifetime.get("longest_putt_ft", 0.0)) or pt_cleared:
			eff_lifetime["longest_putt_ft"] = rec_longest_pt
		var ach_unlocked = merged.get("achievements", {}).get("unlocked", {})
		if ach_unlocked is Dictionary and ach_unlocked.size() > int(eff_lifetime.get("achievements_count", 0)):
			eff_lifetime["achievements_count"] = ach_unlocked.size()
		eff_lifetime["best_courses"] = merged.get("best_courses", {})

		# Build updated profile document
		var updated_profile_doc = {
			"schema_version": 1,
			"owner_uid": cloud_uid,
			"display_name": final_display_name,
			"avatar": reg_p.get("avatar", ""),
			"preferred_tee": reg_p.get("preferred_tee", "Blue"),
			"skill_level": reg_p.get("skill_level", "mid_handicap"),
			"handedness": int(reg_p.get("handedness", 0)),
			"ball_graphic": reg_p.get("ball_graphic", "single_line"),
			"bag": reg_p.get("bag", []),
			"updated_at": int(Time.get_unix_time_from_system()),
			"updated_by_uid": auth.get_uid() if (auth != null and auth.has_method("get_uid")) else cloud_uid,
			"rev": new_rev,
			"lifetime": eff_lifetime,
			"best_courses": merged.get("best_courses", {}),
			"club_summary": _build_club_summary(merged.get("clubs", {}))
		}
		var put_prof_res = await client.set_doc("profiles/" + cloud_uid, updated_profile_doc)
		if not put_prof_res.get("ok", false):
			var is_403_prof: bool = (put_prof_res.get("status") == 403) or str(put_prof_res.get("error", "")).find("PERMISSION_DENIED") != -1 or str(put_prof_res.get("error", "")).find("403") != -1
			if is_403_prof and str(reg_p.get("link_role", "")) == "linked":
				return _handle_linked_revocation(player_name, cloud_uid, mp)
			print("[CloudSync] Failed to upload profile for %s (%s): %s (status: %s)" % [player_name, cloud_uid, put_prof_res.get("error"), put_prof_res.get("status")])
			return {"ok": false, "error": put_prof_res.get("error", "Failed to upload profile")}

		# Sync public_profiles/{cloud_uid} if leaderboard changed
		var leaderboard_opt_in = true
		if auth != null and "leaderboard_opt_in" in auth:
			leaderboard_opt_in = bool(auth.get("leaderboard_opt_in"))
		await _sync_public_leaderboard_profile(client, cloud_uid, final_display_name, reg_p.get("avatar", ""), merged.get("records", {}), leaderboard_opt_in, eff_lifetime, merged.get("achievements", {}))

		# Update registry with new rev and cached lifetime stats
		if mp != null and mp.has_method("get_registered_players"):
			var reg_list = mp.get_registered_players()
			for p in reg_list:
				if str(p.get("name", "")).to_lower() == player_name.to_lower():
					p["last_synced_rev"] = new_rev
					p["last_synced_at"] = int(Time.get_unix_time_from_system())
					p["cloud_lifetime_cache"] = eff_lifetime
					break
			mp.save_registered_players(reg_list)
	else:
		# Rev matched and not dirty: just update cached lifetime stats
		if mp != null and mp.has_method("get_registered_players"):
			var reg_list = mp.get_registered_players()
			for p in reg_list:
				if str(p.get("name", "")).to_lower() == player_name.to_lower():
					p["cloud_lifetime_cache"] = cloud_prof.get("lifetime", {})
					break
			mp.save_registered_players(reg_list)

		var leaderboard_opt_in = true
		if auth != null and "leaderboard_opt_in" in auth:
			leaderboard_opt_in = bool(auth.get("leaderboard_opt_in"))
		await _sync_public_leaderboard_profile(client, cloud_uid, final_display_name, reg_p.get("avatar", ""), cloud_prof.get("records", {}), leaderboard_opt_in, cloud_prof.get("lifetime", {}), local_ach)

	# 2. Upload pending matches for this cloud_uid
	await _upload_pending_matches_for_uid(client, cloud_uid)

	# Clear dirty status
	var was_dirty := false
	for i in range(dirty_profiles.size() - 1, -1, -1):
		if str(dirty_profiles[i]).strip_edges().to_lower() == player_name.strip_edges().to_lower():
			dirty_profiles.remove_at(i)
			was_dirty = true
	if was_dirty:
		_save_sync_state()

	return {"ok": true}


func _gather_local_stats_dict(player_name: String, _reg_p: Dictionary) -> Dictionary:
	var local_dict: Dictionary = {
		"clubs": {},
		"records": {},
		"tombstones": {},
		"achievements": {},
		"swing_issues": {},
		"best_courses": {}
	}

	var mp = get_node_or_null("/root/MultiplayerManager")
	if mp != null and mp.has_method("load_global_club_stats"):
		var stats = mp.load_global_club_stats()
		var matching_key = mp.call("_find_matching_player_key_in_dict", stats, player_name)
		var p_stats: Dictionary = stats.get(matching_key, {}) if not matching_key.is_empty() else {}
		local_dict["records"] = p_stats.get("_records", {})
		local_dict["tombstones"] = p_stats.get("_tombstones", {})
		for clb in p_stats.keys():
			if not str(clb).begins_with("_"):
				local_dict["clubs"][clb] = p_stats[clb]

	# Achievements
	local_dict["achievements"] = _gather_local_achievements(player_name)

	# Swing issues
	var swing_path = "user://player_swing_issues.json"
	if FileAccess.file_exists(swing_path):
		var sf = FileAccess.open(swing_path, FileAccess.READ)
		if sf != null:
			var parsed_s = JSON.parse_string(sf.get_as_text())
			sf.close()
			if parsed_s is Dictionary:
				var p_sw = null
				if parsed_s.has(player_name):
					p_sw = parsed_s[player_name]
				else:
					var p_lower = player_name.strip_edges().to_lower()
					for k in parsed_s.keys():
						if str(k).strip_edges().to_lower() == p_lower:
							p_sw = parsed_s[k]
							break
				if p_sw is Dictionary:
					local_dict["swing_issues"] = p_sw.get("monthly", {})
					var sw_up = int(p_sw.get("updated_at", 0))
					if sw_up == 0 and not local_dict["swing_issues"].is_empty():
						sw_up = int(FileAccess.get_modified_time(swing_path))
						if sw_up == 0:
							sw_up = int(Time.get_unix_time_from_system())
					local_dict["swing_issues_updated_at"] = sw_up
					if p_sw.has("_cleared_at"):
						if not local_dict["tombstones"] is Dictionary:
							local_dict["tombstones"] = {}
						local_dict["tombstones"]["cleared_swing_issues_at"] = int(p_sw["_cleared_at"])

	# Best courses
	if mp != null and mp.has_method("calculate_player_stats"):
		var calc = mp.calculate_player_stats(player_name)
		local_dict["best_courses"] = calc.get("best_courses", {})
		if not local_dict["records"].has("longest_putt_ft"):
			local_dict["records"]["longest_putt_ft"] = float(calc.get("longest_putt_ft", 0.0))

	return local_dict


func _gather_local_achievements(player_name: String) -> Dictionary:
	var unlocked: Dictionary = {}
	var heard: Array = []

	var ach_path = "user://player_achievements.json"
	if FileAccess.file_exists(ach_path):
		var f = FileAccess.open(ach_path, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			f.close()
			if parsed is Dictionary:
				var p_ach = null
				if parsed.has(player_name):
					p_ach = parsed[player_name]
				else:
					var p_lower = player_name.strip_edges().to_lower()
					for k in parsed.keys():
						if str(k).strip_edges().to_lower() == p_lower:
							p_ach = parsed[k]
							break
				if p_ach is Dictionary:
					for k in p_ach:
						if k == "heard_heckles":
							if p_ach[k] is Dictionary:
								for h in p_ach[k].keys():
									heard.append(str(h))
							elif p_ach[k] is Array:
								heard = p_ach[k]
						else:
							var v = p_ach[k]
							if v is Dictionary and v.has("unlocked_at"):
								unlocked[str(k)] = int(v["unlocked_at"])
							else:
								unlocked[str(k)] = int(v)

	# Also overlay in-memory AchievementManager state if available
	var ach_node = get_node_or_null("/root/AchievementManager")
	if ach_node != null and ach_node.has_method("get_unlocked_achievements"):
		var live_unlocked = ach_node.get_unlocked_achievements(player_name)
		if live_unlocked is Dictionary:
			for k in live_unlocked.keys():
				var v = live_unlocked[k]
				if v is Dictionary and v.has("unlocked_at"):
					unlocked[str(k)] = int(v["unlocked_at"])
				elif not unlocked.has(str(k)):
					unlocked[str(k)] = int(v) if v is int else int(Time.get_unix_time_from_system())
		if ach_node.has_method("get_heard_heckles"):
			var live_heckles = ach_node.get_heard_heckles(player_name)
			if live_heckles is Dictionary:
				for h in live_heckles.keys():
					var hs = str(h)
					if not heard.has(hs):
						heard.append(hs)

	return {
		"unlocked": unlocked,
		"heard_heckles": heard
	}


func _apply_merged_stats_locally(player_name: String, merged: Dictionary) -> void:
	var mp = get_node_or_null("/root/MultiplayerManager")
	if mp != null and mp.has_method("load_global_club_stats"):
		var stats = mp.load_global_club_stats()
		var matching_key = mp.call("_find_matching_player_key_in_dict", stats, player_name)
		var target_key = matching_key if not matching_key.is_empty() else player_name
		var new_p_stats = merged.get("clubs", {}).duplicate(true)
		new_p_stats["_records"] = merged.get("records", {}).duplicate(true)
		new_p_stats["_tombstones"] = merged.get("tombstones", {}).duplicate(true)
		stats[target_key] = new_p_stats
		mp.save_global_club_stats(stats)

	# Achievements
	var ach_path = "user://player_achievements.json"
	var all_ach: Dictionary = {}
	if FileAccess.file_exists(ach_path):
		var f = FileAccess.open(ach_path, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			f.close()
			if parsed is Dictionary:
				all_ach = parsed
	var p_ach_target: Dictionary = {}
	var unlocked_dict: Dictionary = merged.get("achievements", {}).get("unlocked", {})
	for aid in unlocked_dict:
		p_ach_target[aid] = {"unlocked_at": unlocked_dict[aid]}
	p_ach_target["heard_heckles"] = merged.get("achievements", {}).get("heard_heckles", [])
	all_ach[player_name] = p_ach_target

	var out_f = FileAccess.open(ach_path, FileAccess.WRITE)
	if out_f != null:
		out_f.store_string(JSON.stringify(all_ach, "\t"))
		out_f.close()

	if has_node("/root/AchievementManager"):
		var ach_node = get_node("/root/AchievementManager")
		if "_player_data" in ach_node and ach_node.get("_player_data") is Dictionary:
			ach_node.get("_player_data")[player_name] = p_ach_target

	# Swing issues
	var swing_path = "user://player_swing_issues.json"
	var all_swing: Dictionary = {}
	if FileAccess.file_exists(swing_path):
		var sf = FileAccess.open(swing_path, FileAccess.READ)
		if sf != null:
			var parsed_s = JSON.parse_string(sf.get_as_text())
			sf.close()
			if parsed_s is Dictionary:
				all_swing = parsed_s
	var sw_data = {
		"monthly": merged.get("swing_issues", {}),
		"all_time": {},
		"updated_at": int(merged.get("swing_issues_updated_at", Time.get_unix_time_from_system()))
	}
	for m in sw_data["monthly"]:
		var m_dict = sw_data["monthly"][m]
		if m_dict is Dictionary:
			for iss in m_dict:
				sw_data["all_time"][iss] = int(sw_data["all_time"].get(iss, 0)) + int(m_dict[iss])
	if merged.get("tombstones", {}).has("cleared_swing_issues_at"):
		sw_data["_cleared_at"] = merged["tombstones"]["cleared_swing_issues_at"]
	all_swing[player_name] = sw_data

	var out_sf = FileAccess.open(swing_path, FileAccess.WRITE)
	if out_sf != null:
		out_sf.store_string(JSON.stringify(all_swing, "\t"))
		out_sf.close()


func _build_club_summary(clubs_dict: Dictionary) -> Dictionary:
	var summary: Dictionary = {}
	for clb in clubs_dict:
		var shots: Array = clubs_dict[clb]
		if shots.is_empty():
			continue
		var count = shots.size()
		var carry_sum := 0.0
		var total_sum := 0.0
		var speed_sum := 0.0
		var club_speed_sum := 0.0
		var spin_sum := 0.0
		var offline_sum := 0.0
		var face_sum := 0.0
		var face_count := 0
		var path_sum := 0.0
		var path_count := 0
		var impact_pts: Array = []

		for s in shots:
			var c_m = float(s.get("CarryDistance", s.get("c", 0.0)))
			var t_m = float(s.get("TotalDistance", s.get("tot", 0.0)))
			carry_sum += c_m * 1.09361
			total_sum += t_m * 1.09361
			speed_sum += float(s.get("BallSpeed", s.get("Speed", s.get("bs", 0.0))))
			club_speed_sum += float(s.get("ClubSpeed", s.get("cs", 0.0)))
			spin_sum += float(s.get("TotalSpin", s.get("sp", 0.0)))
			var side_d = absf(float(s.get("SideDistance", s.get("sd", 0.0))))
			offline_sum += side_d * 1.09361

			if s.has("FaceAngle"):
				face_sum += float(s["FaceAngle"])
				face_count += 1
			elif s.has("ClubFaceAngle"):
				face_sum += float(s["ClubFaceAngle"])
				face_count += 1
			elif s.has("fa"):
				face_sum += float(s["fa"])
				face_count += 1

			if s.has("ClubPath"):
				path_sum += float(s["ClubPath"])
				path_count += 1
			elif s.has("Path"):
				path_sum += float(s["Path"])
				path_count += 1
			elif s.has("cp"):
				path_sum += float(s["cp"])
				path_count += 1

			if s.has("HorizontalFaceImpact") or s.has("VerticalFaceImpact") or s.has("hi") or s.has("vi"):
				impact_pts.append({
					"h": snapped(float(s.get("HorizontalFaceImpact", s.get("hi", 0.0))), 0.1),
					"v": snapped(float(s.get("VerticalFaceImpact", s.get("vi", 0.0))), 0.1)
				})

		var avg_cs = club_speed_sum / count
		var avg_bs = speed_sum / count
		if impact_pts.size() > 50:
			impact_pts = impact_pts.slice(impact_pts.size() - 50)

		summary[clb] = {
			"count": count,
			"carry_yds": carry_sum / count,
			"total_yds": total_sum / count,
			"ball_speed_mph": avg_bs,
			"club_speed_mph": avg_cs,
			"smash": (avg_bs / avg_cs) if avg_cs > 0.0 else 0.0,
			"spin_rpm": int(round(spin_sum / count)),
			"offline_yds": offline_sum / count,
			"avg_offline_yds": offline_sum / count,
			"avg_face_angle": (face_sum / face_count) if face_count > 0 else 0.0,
			"has_face_angle": face_count > 0,
			"face_angle_count": face_count,
			"avg_club_path": (path_sum / path_count) if path_count > 0 else 0.0,
			"has_club_path": path_count > 0,
			"club_path_count": path_count,
			"impact_points": impact_pts,
			"has_impact_data": not impact_pts.is_empty()
		}
	return summary


# ── IDEMPOTENT MATCH UPLOAD ──────────────────────────────────────────────

func _upload_pending_matches_for_uid(client: FirestoreClient, cloud_uid: String) -> void:
	var matches_to_process: Array[Dictionary] = []
	for m in pending_matches:
		if str(m.get("cloud_uid", "")) == cloud_uid:
			matches_to_process.append(m)

	for M in matches_to_process:
		var match_id = str(M.get("match_id", ""))
		if match_id.is_empty():
			continue

		var doc_match_path = "profiles/%s/matches/%s" % [cloud_uid, match_id]
		var match_full_resource = "projects/%s/databases/(default)/documents/%s" % [client.project_id, doc_match_path]
		var profile_full_resource = "projects/%s/databases/(default)/documents/profiles/%s" % [client.project_id, cloud_uid]

		var write1 = {
			"update": {
				"name": match_full_resource,
				"fields": FirestoreClient.dict_to_firestore_fields(M)
			},
			"currentDocument": {
				"exists": false
			}
		}

		var is_finished_match: bool = bool(M.get("is_finished", true))
		var holes_played_in_match: int = int(M.get("holes_count", 0))
		var m_holes = M.get("holes", [])
		if m_holes is Array and not m_holes.is_empty():
			holes_played_in_match = m_holes.size()

		var field_transforms: Array = [
			{"fieldPath": "lifetime.holes_played", "increment": {"integerValue": str(int(holes_played_in_match))}},
			{"fieldPath": "lifetime.total_strokes", "increment": {"integerValue": str(int(round(float(M.get("strokes", 0)))))}},
			{"fieldPath": "lifetime.total_par", "increment": {"integerValue": str(int(round(float(M.get("par", 0)))))}},
		]

		# Only completed matches increment matches_played, win/loss records, scoring averages, and best scores
		if is_finished_match:
			field_transforms.append({"fieldPath": "lifetime.matches_played", "increment": {"integerValue": "1"}})
			if M.get("is_winner", false):
				field_transforms.append({"fieldPath": "lifetime.wins", "increment": {"integerValue": "1"}})
			elif M.get("is_loss", false):
				field_transforms.append({"fieldPath": "lifetime.losses", "increment": {"integerValue": "1"}})
			elif M.get("is_tie", false):
				field_transforms.append({"fieldPath": "lifetime.ties", "increment": {"integerValue": "1"}})
			elif M.get("is_single_player", false):
				field_transforms.append({"fieldPath": "lifetime.single_player_completed", "increment": {"integerValue": "1"}})

			if M.has("to_par"):
				field_transforms.append({"fieldPath": "lifetime.par_diff_sum", "increment": {"integerValue": str(int(round(float(M.get("to_par")))))}})
				field_transforms.append({"fieldPath": "lifetime.par_diff_matches", "increment": {"integerValue": "1"}})

			if M.get("holes_count", 0) == 18 and M.get("game_mode", "") == "Standard" and M.get("mulligans_used", 0) == 0:
				field_transforms.append({"fieldPath": "lifetime.best_to_par_18", "minimum": {"integerValue": str(int(round(float(M.get("to_par", 0)))))}})
				field_transforms.append({"fieldPath": "lifetime.best_gross_18", "minimum": {"integerValue": str(int(round(float(M.get("strokes", 0)))))}})
			elif M.get("holes_count", 0) == 9 and M.get("game_mode", "") == "Standard" and M.get("mulligans_used", 0) == 0:
				field_transforms.append({"fieldPath": "lifetime.best_to_par_9", "minimum": {"integerValue": str(int(round(float(M.get("to_par", 0)))))}})
				field_transforms.append({"fieldPath": "lifetime.best_gross_9", "minimum": {"integerValue": str(int(round(float(M.get("strokes", 0)))))}})

		# Distance records are credited whenever a valid swing occurs
		if float(M.get("longest_drive_yds", 0.0)) > 0.0:
			field_transforms.append({"fieldPath": "lifetime.longest_drive_yds", "maximum": {"doubleValue": float(M.get("longest_drive_yds", 0.0))}})
		if float(M.get("longest_putt_ft", 0.0)) > 0.0:
			field_transforms.append({"fieldPath": "lifetime.longest_putt_ft", "maximum": {"doubleValue": float(M.get("longest_putt_ft", 0.0))}})

		var write2 = {
			"transform": {
				"document": profile_full_resource,
				"fieldTransforms": field_transforms
			}
		}

		var commit_res = await client.commit_writes([write1, write2])
		if commit_res.get("ok", false) or commit_res.get("status") == 409 or str(commit_res.get("error", "")).find("ALREADY_EXISTS") != -1:
			pending_matches.erase(M)
			_save_sync_state()
		else:
			print("[CloudSync] Failed to commit match write for %s: %s" % [match_id, commit_res.get("error")])


# ── REDUNDANT LEADERBOARD WRITE SKIP ─────────────────────────────────────

func _sync_public_leaderboard_profile(client: FirestoreClient, cloud_uid: String, player_name: String, avatar: String, records: Dictionary, opt_in: bool = true, lifetime: Dictionary = {}, achievements: Dictionary = {}) -> void:
	if not opt_in:
		if last_pushed_leaderboard.has(cloud_uid):
			await client.delete_doc("public_profiles/" + cloud_uid)
			last_pushed_leaderboard.erase(cloud_uid)
			_save_sync_state()
		return

	var unlocked_count: int = int(lifetime.get("achievements_count", 0))
	var ach_unlocked = achievements.get("unlocked", {})
	if ach_unlocked is Dictionary and ach_unlocked.size() > 0:
		unlocked_count = maxi(unlocked_count, ach_unlocked.size())

	var longest_dr: float = float(records.get("longest_drive_yds", records.get("longest_drive", lifetime.get("longest_drive_yds", 0.0))))
	var longest_pt: float = float(records.get("longest_putt_ft", lifetime.get("longest_putt_ft", 0.0)))

	var current_projection = {
		"schema_version": 1,
		"uid": cloud_uid,
		"display_name": player_name,
		"avatar": avatar,
		"longest_drive_yds": longest_dr,
		"longest_putt_ft": longest_pt,
		"achievements_count": unlocked_count,
		"matches_played": int(lifetime.get("matches_played", 0)),
		"wins": int(lifetime.get("wins", 0))
	}

	# Firestore rule validRangeOrAbsent requires 18 <= best_gross_18 <= 250 and 9 <= best_gross_9 <= 130
	var bg18 = int(records.get("best_gross_18", lifetime.get("best_gross_18", 0)))
	if bg18 >= 18 and bg18 <= 250:
		current_projection["best_gross_18"] = bg18
		current_projection["best_to_par_18"] = int(records.get("best_to_par_18", lifetime.get("best_to_par_18", 0)))

	var bg9 = int(records.get("best_gross_9", lifetime.get("best_gross_9", 0)))
	if bg9 >= 9 and bg9 <= 130:
		current_projection["best_gross_9"] = bg9
		current_projection["best_to_par_9"] = int(records.get("best_to_par_9", lifetime.get("best_to_par_9", 0)))

	var last_proj = last_pushed_leaderboard.get(cloud_uid, {})
	var changed := false
	if last_proj.is_empty():
		changed = true
	else:
		for k in current_projection.keys():
			if current_projection.get(k) != last_proj.get(k):
				changed = true
				break

	if not changed:
		print("[CloudSync] Leaderboard projection unchanged for %s; skipping public_profiles write." % cloud_uid)
		return

	current_projection["updated_at"] = int(Time.get_unix_time_from_system())
	var res = await client.set_doc("public_profiles/" + cloud_uid, current_projection)
	if res.get("ok", false):
		last_pushed_leaderboard[cloud_uid] = current_projection
		_save_sync_state()
	else:
		print("[CloudSync] Failed to update public leaderboard for %s: %s (status: %s)" % [cloud_uid, res.get("error"), res.get("status")])


func _handle_linked_revocation(player_name: String, cloud_uid: String, mp: Node) -> Dictionary:
	print("[CloudSync] Access to linked profile '%s' (uid: %s) was revoked by owner (403 PERMISSION_DENIED)." % [player_name, cloud_uid])
	if mp != null and mp.has_method("get_registered_players"):
		var reg_list: Array = mp.get_registered_players()
		for p in reg_list:
			if str(p.get("name", "")).to_lower() == player_name.to_lower():
				p["link_role"] = "revoked"
				break
		mp.save_registered_players(reg_list)
	if dirty_profiles.has(player_name):
		dirty_profiles.erase(player_name)
		_save_sync_state()
	_show_revocation_toast(player_name)
	return {"ok": false, "error": "Access revoked by owner", "revoked": true}


func _show_revocation_toast(player_name: String) -> void:
	var msg := "Cloud sync for %s is no longer active (access revoked by owner)." % player_name
	print("[CloudSync] %s" % msg)
	var loop = Engine.get_main_loop()
	if loop is SceneTree and loop.root != null:
		var toast := PanelContainer.new()
		toast.name = "RevocationToast"
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.18, 0.08, 0.08, 0.95)
		style.border_color = Color(0.9, 0.4, 0.4, 1.0)
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		toast.add_theme_stylebox_override("panel", style)
		toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		toast.offset_bottom = -80
		var lbl := Label.new()
		lbl.text = msg
		lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85))
		lbl.add_theme_font_size_override("font_size", 14)
		toast.add_child(lbl)
		loop.root.add_child(toast)
		var tw = toast.create_tween()
		if tw != null:
			tw.tween_interval(4.0)
			tw.tween_property(toast, "modulate:a", 0.0, 0.6)
			tw.tween_callback(toast.queue_free)


func _show_cooldown_toast(remaining_sec: int) -> void:
	var msg := "⏱️ Cloud sync is on cooldown (%ds remaining) to preserve server limits." % remaining_sec
	print("[CloudSync] %s" % msg)
	var loop = Engine.get_main_loop()
	if not (loop is SceneTree and loop.root != null):
		return
	if loop.root.has_node("SyncCooldownToast"):
		return
	var toast := PanelContainer.new()
	toast.name = "SyncCooldownToast"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.16, 0.14, 0.95)
	style.border_color = Color(0.3, 0.7, 0.45, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	toast.add_theme_stylebox_override("panel", style)
	toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast.offset_bottom = -80
	var lbl := Label.new()
	lbl.text = msg
	lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 0.92))
	lbl.add_theme_font_size_override("font_size", 14)
	toast.add_child(lbl)
	loop.root.add_child(toast)
	var tw = toast.create_tween()
	if tw != null:
		tw.tween_interval(3.0)
		tw.tween_property(toast, "modulate:a", 0.0, 0.5)
		tw.tween_callback(toast.queue_free)
