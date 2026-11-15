extends Node

## TournamentService — Autoload managing asynchronous tournament creation, joining,
## score syncing, and standings. Tournaments are played locally at each player's own pace;
## scores are pushed to Firestore on game-over, on login, and every 30 minutes.
## See docs/multiplayer/TOURNAMENTS.md.

signal tournaments_loaded(tournaments: Array)
signal standings_loaded(tournament_id: String, entries: Array)
signal score_synced(tournament_id: String)
signal tournament_error(code: String, message: String)

const SCORE_SYNC_INTERVAL_SEC := 1800.0  # 30 minutes
const LOCAL_PENDING_FILE := "user://tournament_pending_scores.json"
const LOCAL_JOINED_FILE := "user://tournament_joined.json"

const FirestoreClientClass = preload("res://Utils/Cloud/firestore_client.gd")

var _firestore: FirestoreClient = null
var _sync_timer: Timer = null
var _pending_score_data: Dictionary = {}  # tournament_id -> partial entry dict
var _joined_tournaments: Array[Dictionary] = []  # locally cached list of joined tournaments

const GIMME_SETTINGS_KEYS := [
	"gimme_range_1_enabled", "gimme_range_1_distance",
	"gimme_range_2_enabled", "gimme_range_2_distance",
	"gimme_range_3_enabled", "gimme_range_3_distance"
]
var _saved_tournament_settings: Dictionary = {}
var active_tournament_id: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_load_pending_scores()
	_load_joined_tournaments()

	_sync_timer = Timer.new()
	_sync_timer.name = "TournamentSyncTimer"
	_sync_timer.wait_time = SCORE_SYNC_INTERVAL_SEC
	_sync_timer.one_shot = false
	_sync_timer.timeout.connect(_on_sync_timer_timeout)
	add_child(_sync_timer)
	_sync_timer.start()

	# Hook into CloudAuth for startup sync
	if has_node("/root/CloudAuth"):
		var ca = get_node("/root/CloudAuth")
		if ca.has_signal("auth_state_changed"):
			ca.auth_state_changed.connect(_on_auth_state_changed)

	# Hook into MultiplayerManager for game-over and hole-complete events
	var mp = get_node_or_null("/root/MultiplayerManager")
	if mp != null:
		if mp.has_signal("game_over") and not mp.game_over.is_connected(_on_game_over):
			mp.game_over.connect(_on_game_over)
		if mp.has_signal("hole_completed") and not mp.hole_completed.is_connected(_on_hole_completed):
			mp.hole_completed.connect(_on_hole_completed)


# ── FIRESTORE ACCESS ──────────────────────────────────────────────────────

func _get_firestore() -> FirestoreClient:
	if _firestore != null:
		return _firestore
	var auth = get_node_or_null("/root/CloudAuth")
	_firestore = FirestoreClientClass.new(auth)
	return _firestore


func _get_my_uid() -> String:
	if has_node("/root/CloudAuth"):
		var ca = get_node("/root/CloudAuth")
		if ca.has_method("get_uid"):
			return str(ca.get_uid())
	return ""


func _get_my_display_name() -> String:
	if has_node("/root/CloudAuth"):
		var ca = get_node("/root/CloudAuth")
		var dname := str(ca.get_display_name()).strip_edges() if ca.has_method("get_display_name") else ""
		if not dname.is_empty():
			return dname
		var email := str(ca.get_email()).strip_edges() if ca.has_method("get_email") else ""
		if not email.is_empty():
			return email.split("@")[0]
	return "Golfer"


func _is_signed_in() -> bool:
	if has_node("/root/CloudAuth"):
		var ca = get_node("/root/CloudAuth")
		if ca.has_method("is_authenticated_any"):
			return ca.is_authenticated_any()
	return false


# ── CODE GENERATION ───────────────────────────────────────────────────────

func generate_join_code() -> String:
	const CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code := ""
	for i in range(6):
		code += CHARS[randi() % CHARS.length()]
	return code


# ── CREATE TOURNAMENT ─────────────────────────────────────────────────────

func create_tournament(settings: Dictionary) -> Dictionary:
	if not _is_signed_in():
		return {"ok": false, "error": "You must be signed in to host a tournament."}

	var fs := _get_firestore()
	var uid := _get_my_uid()
	var host_name := _get_my_display_name()
	var code := generate_join_code()

	# Validate end_date
	var end_date_str: String = settings.get("end_date_utc", "")
	if end_date_str.is_empty():
		return {"ok": false, "error": "An end date is required."}

	var max_p: int = int(settings.get("max_players", 20))
	max_p = clampi(max_p, 2, 200)

	var now := int(Time.get_unix_time_from_system())
	var doc_id := "T_%s_%d" % [code, now]

	var doc_data := {
		"tournament_id": doc_id,
		"join_code": code,
		"name": settings.get("name", "%s's Tournament" % host_name),
		"host_uid": uid,
		"host_name": host_name,
		"course_key": settings.get("course_key", ""),
		"course_title": settings.get("course_title", ""),
		"course_length": settings.get("course_length", "Full 18"),
		"game_mode": settings.get("game_mode", "Standard"),
		"wind_speed_mph": float(settings.get("wind_speed_mph", 5.0)),
		"wind_dir_rad": float(settings.get("wind_dir_rad", 0.0)),
		"green_speed": settings.get("green_speed", "Normal"),
		"pin_seed": int(settings.get("pin_seed", randi())),
		"tee": settings.get("tee", "Blue"),
		"visibility": settings.get("visibility", "public"),
		"max_players": max_p,
		"end_date_utc": end_date_str,
		"status": "open",
		"player_count": 1,
		"created_at": now,
		"force_gimmes": bool(settings.get("force_gimmes", false)),
		"gimme_range_1_enabled": bool(settings.get("gimme_range_1_enabled", true)),
		"gimme_range_1_distance": float(settings.get("gimme_range_1_distance", 4.0)),
		"gimme_range_2_enabled": bool(settings.get("gimme_range_2_enabled", false)),
		"gimme_range_2_distance": float(settings.get("gimme_range_2_distance", 10.0)),
		"gimme_range_3_enabled": bool(settings.get("gimme_range_3_enabled", false)),
		"gimme_range_3_distance": float(settings.get("gimme_range_3_distance", 30.0))
	}

	var res := await fs.set_doc("tournaments/%s" % doc_id, doc_data)
	if not res.get("ok", false):
		return {"ok": false, "error": res.get("error", "Failed to create tournament.")}

	# Host auto-joins their own tournament
	var join_res := await _write_entry(doc_id, doc_data, settings.get("player_name", host_name), settings.get("tee", "Blue"))
	if not join_res.get("ok", false):
		return {"ok": false, "error": "Tournament created but failed to register host entry."}

	_cache_joined_tournament(doc_data)

	return {"ok": true, "tournament_id": doc_id, "join_code": code, "data": doc_data}


# ── JOIN TOURNAMENT ───────────────────────────────────────────────────────

func join_tournament(code: String, player_name: String, tee: String) -> Dictionary:
	if not _is_signed_in():
		return {"ok": false, "error": "You must be signed in to join a tournament."}

	var fs := _get_firestore()
	var uid := _get_my_uid()

	# Query by join_code
	var query_res := await fs.run_query("tournaments", [
		{"field": "join_code", "op": "EQUAL", "value": code.to_upper().strip_edges()}
	], [], 1)

	if not query_res.get("ok", false) or query_res.get("documents", []).is_empty():
		return {"ok": false, "error": "Tournament not found. Check the code and try again."}

	var t_doc: Dictionary = query_res["documents"][0]
	var t_id: String = t_doc.get("tournament_id", t_doc.get("_doc_id", ""))
	if t_id.is_empty():
		return {"ok": false, "error": "Invalid tournament data."}

	# Validate: open, not expired, not full
	var validate := _validate_joinable(t_doc, uid)
	if not validate.get("ok", false):
		return validate

	# Write entry
	var entry_res := await _write_entry(t_id, t_doc, player_name, tee)
	if not entry_res.get("ok", false):
		return {"ok": false, "error": entry_res.get("error", "Failed to join tournament.")}

	# Increment player_count
	var new_count: int = int(t_doc.get("player_count", 0)) + 1
	await fs.set_doc("tournaments/%s" % t_id, {"player_count": new_count}, PackedStringArray(["player_count"]))

	_cache_joined_tournament(t_doc)

	return {"ok": true, "tournament_id": t_id, "data": t_doc}


func _validate_joinable(t_doc: Dictionary, uid: String) -> Dictionary:
	var status: String = t_doc.get("status", "open")
	if status != "open":
		return {"ok": false, "error": "This tournament is no longer accepting entries."}

	var end_date_str: String = t_doc.get("end_date_utc", "")
	if not end_date_str.is_empty():
		var end_unix := _parse_date_utc(end_date_str)
		if end_unix > 0 and Time.get_unix_time_from_system() > end_unix:
			return {"ok": false, "error": "This tournament has already ended."}

	var max_p: int = int(t_doc.get("max_players", 20))
	var cur_count: int = int(t_doc.get("player_count", 0))
	if cur_count >= max_p:
		return {"ok": false, "error": "This tournament is full (%d/%d players)." % [cur_count, max_p]}

	return {"ok": true}


func _write_entry(tournament_id: String, t_doc: Dictionary, player_name: String, tee: String) -> Dictionary:
	var fs := _get_firestore()
	var uid := _get_my_uid()
	var now := int(Time.get_unix_time_from_system())

	var entry := {
		"uid": uid,
		"player_name": player_name,
		"tee": tee,
		"joined_at": now,
		"submitted_at": 0,
		"last_synced_at": 0,
		"total_strokes": 0,
		"to_par": 0,
		"holes_completed": 0,
		"hole_scores": {},
		"status": "pending",
		"course_key": t_doc.get("course_key", ""),
		"course_length": t_doc.get("course_length", "Full 18")
	}

	var res := await fs.set_doc("tournaments/%s/entries/%s" % [tournament_id, uid], entry)
	return res


# ── FETCH PUBLIC TOURNAMENTS ───────────────────────────────────────────────

func fetch_public_tournaments(filters: Dictionary = {}) -> Dictionary:
	if not _is_signed_in():
		return {"ok": false, "error": "Sign in required.", "documents": []}

	var fs := _get_firestore()

	var where_filters: Array = [
		{"field": "visibility", "op": "EQUAL", "value": "public"}
	]

	var course_filter: String = filters.get("course_key", "")
	if not course_filter.is_empty():
		where_filters.append({"field": "course_key", "op": "EQUAL", "value": course_filter})

	var time_filter: String = filters.get("time_frame", "all")
	if time_filter != "all":
		var cutoff_ts: float = _time_frame_cutoff(time_filter)
		if cutoff_ts > 0:
			where_filters.append({"field": "created_at", "op": "GREATER_THAN_OR_EQUAL", "value": int(cutoff_ts)})

	var res := await fs.run_query("tournaments", where_filters, [{"field": "created_at", "dir": "DESCENDING"}], 50)
	if res.get("ok", false):
		tournaments_loaded.emit(res.get("documents", []))
	return res


# ── FETCH MY TOURNAMENTS ──────────────────────────────────────────────────

func fetch_my_tournaments() -> Dictionary:
	if not _is_signed_in():
		return {"ok": false, "error": "Sign in required.", "documents": []}

	var uid := _get_my_uid()
	if uid.is_empty():
		return {"ok": false, "error": "No user ID.", "documents": []}

	var fs := _get_firestore()

	# Firestore collectionGroup query on 'entries' where uid == my uid
	# Fallback: load from local cache of joined tournament IDs and fetch each
	var all_tournaments: Array[Dictionary] = []

	for t_cached in _joined_tournaments:
		var t_id: String = t_cached.get("tournament_id", "")
		if t_id.is_empty():
			continue
		var doc_res := await fs.get_doc("tournaments/%s" % t_id)
		if doc_res.get("ok", false):
			all_tournaments.append(doc_res.get("data", {}))

	tournaments_loaded.emit(all_tournaments)
	return {"ok": true, "documents": all_tournaments}


# ── FETCH STANDINGS ────────────────────────────────────────────────────────

func fetch_standings(tournament_id: String) -> Dictionary:
	if not _is_signed_in():
		return {"ok": false, "error": "Sign in required.", "documents": []}

	var fs := _get_firestore()

	# Fetch the tournament meta first to check if it needs locking
	var meta_res := await fs.get_doc("tournaments/%s" % tournament_id)
	if meta_res.get("ok", false):
		var meta: Dictionary = meta_res.get("data", {})
		var status: String = meta.get("status", "open")
		if status == "open":
			var end_date_str: String = meta.get("end_date_utc", "")
			var end_unix := _parse_date_utc(end_date_str)
			if end_unix > 0 and Time.get_unix_time_from_system() > end_unix:
				# Lock the tournament — first reader after deadline closes it
				await fs.set_doc("tournaments/%s" % tournament_id, {"status": "ended"}, PackedStringArray(["status"]))

	# Fetch all entries
	var entries_res := await fs.list_docs("tournaments/%s/entries" % tournament_id, 200)
	if not entries_res.get("ok", false):
		return entries_res

	var raw: Array = entries_res.get("documents", [])

	# Sort: submitted entries by to_par asc (lowest wins), then total_strokes asc,
	# then in_progress (partial), then pending last
	var submitted: Array[Dictionary] = []
	var in_progress: Array[Dictionary] = []
	var pending: Array[Dictionary] = []

	for entry in raw:
		var s: String = entry.get("status", "pending")
		if s == "submitted":
			submitted.append(entry)
		elif s == "in_progress":
			in_progress.append(entry)
		else:
			pending.append(entry)

	submitted.sort_custom(func(a, b):
		var a_par: int = int(a.get("to_par", 999))
		var b_par: int = int(b.get("to_par", 999))
		if a_par != b_par:
			return a_par < b_par
		return int(a.get("total_strokes", 999)) < int(b.get("total_strokes", 999))
	)
	in_progress.sort_custom(func(a, b):
		return int(a.get("holes_completed", 0)) > int(b.get("holes_completed", 0))
	)

	var sorted: Array[Dictionary] = []
	sorted.append_array(submitted)
	sorted.append_array(in_progress)
	sorted.append_array(pending)

	standings_loaded.emit(tournament_id, sorted)
	return {"ok": true, "documents": sorted, "meta": meta_res.get("data", {})}


# ── SCORE SYNCING ─────────────────────────────────────────────────────────

## Called from MultiplayerManager's hole_completed signal during active local play.
## Accumulates hole scores for any matching active tournament entry.
func _on_hole_completed(_scores: Array) -> void:
	var mp := get_node_or_null("/root/MultiplayerManager")
	if mp == null or mp.practice_mode_active or _is_online_match_active():
		return
	_accumulate_scores_from_mp(mp)


## Called from MultiplayerManager's game_over signal.
func _on_game_over(_scores: Array) -> void:
	var mp := get_node_or_null("/root/MultiplayerManager")
	if mp == null or mp.practice_mode_active or _is_online_match_active():
		restore_tournament_settings()
		return
	_accumulate_scores_from_mp(mp)
	# Push immediately on game over
	push_pending_scores()
	restore_tournament_settings()


func apply_tournament_settings(t_doc: Dictionary) -> void:
	var gs = _get_global_settings()
	if gs == null or gs.range_settings == null:
		return

	active_tournament_id = t_doc.get("tournament_id", "")
	var force_gimmes: bool = bool(t_doc.get("force_gimmes", false))
	if not force_gimmes:
		print("[TournamentService] Tournament uses local player gimme settings.")
		return

	_saved_tournament_settings.clear()
	if "suppress_save" in gs:
		gs.suppress_save = true

	for k in GIMME_SETTINGS_KEYS:
		if gs.range_settings.settings.has(k):
			_saved_tournament_settings[k] = gs.range_settings.settings[k].value
			if t_doc.has(k):
				gs.range_settings.settings[k].set_value(t_doc[k])
	print("[TournamentService] Applied forced tournament gimme settings.")


func restore_tournament_settings() -> void:
	active_tournament_id = ""
	if _saved_tournament_settings.is_empty():
		return
	var gs = _get_global_settings()
	if gs != null and gs.range_settings != null:
		for k in _saved_tournament_settings:
			if gs.range_settings.settings.has(k):
				gs.range_settings.settings[k].set_value(_saved_tournament_settings[k])
		if "suppress_save" in gs:
			gs.suppress_save = false
		if gs.has_method("save_settings"):
			gs.save_settings()
	_saved_tournament_settings.clear()
	print("[TournamentService] Restored player local gimme settings.")


func is_tournament_settings_applied() -> bool:
	return not _saved_tournament_settings.is_empty()


func _get_global_settings() -> Node:
	if has_node("/root/GlobalSettings"):
		return get_node("/root/GlobalSettings")
	var loop = Engine.get_main_loop()
	if loop is SceneTree and loop.root != null and loop.root.has_node("GlobalSettings"):
		return loop.root.get_node("GlobalSettings")
	return null


func _is_online_match_active() -> bool:
	var online_session := get_node_or_null("/root/OnlineSession")
	return online_session != null and online_session.get("is_online_match") == true


func _accumulate_scores_from_mp(mp: Node) -> void:
	var course_key: String = _extract_course_key(mp)
	var raw_length: Variant = mp.get("selected_course_length")
	var course_length: String = str(raw_length) if raw_length != null else "Full 18"
	if course_length.is_empty():
		course_length = "Full 18"

	# Find matching joined tournaments
	for t_cached in _joined_tournaments:
		if t_cached.get("course_key", "") != course_key:
			continue
		if t_cached.get("course_length", "Full 18") != course_length:
			continue
		var t_id: String = t_cached.get("tournament_id", "")
		if t_id.is_empty():
			continue

		# Check not expired before accumulating
		var end_date_str: String = t_cached.get("end_date_utc", "")
		var end_unix := _parse_date_utc(end_date_str)
		if end_unix > 0 and Time.get_unix_time_from_system() > end_unix:
			continue

		# Find my local player in this round
		var uid := _get_my_uid()
		var my_player: Dictionary = {}
		for p in mp.players:
			var p_uid: String = p.get("owner_uid", p.get("cloud_uid", ""))
			if p_uid == uid or (uid.is_empty() and not bool(p.get("is_remote", false))):
				my_player = p
				break

		if my_player.is_empty():
			continue

		# Build accumulated hole_scores — merge new scores into existing pending
		var existing_pending: Dictionary = _pending_score_data.get(t_id, {})
		var merged_hole_scores: Dictionary = existing_pending.get("hole_scores", {}).duplicate()
		var player_hole_scores: Dictionary = my_player.get("hole_scores", {})
		for h_id in player_hole_scores:
			merged_hole_scores[h_id] = int(player_hole_scores[h_id])

		var total: int = 0
		for h_id in merged_hole_scores:
			total += int(merged_hole_scores[h_id])

		var holes_done: int = merged_hole_scores.size()
		var expected_holes: int = _expected_hole_count(course_length)
		var is_complete: bool = (holes_done >= expected_holes and mp.is_finished)

		var hole_pars: Dictionary = {}
		if mp.has_method("_get_hole_pars"):
			hole_pars = mp.call("_get_hole_pars")

		var to_par: int = 0
		for h_id in merged_hole_scores:
			var par_val: int = int(hole_pars.get(h_id, 4))
			to_par += int(merged_hole_scores[h_id]) - par_val

		_pending_score_data[t_id] = {
			"tournament_id": t_id,
			"hole_scores": merged_hole_scores,
			"total_strokes": total,
			"to_par": to_par,
			"holes_completed": holes_done,
			"is_complete": is_complete,
			"player_name": my_player.get("name", _get_my_display_name()),
			"tee": my_player.get("tee", "Blue"),
			"updated_at": int(Time.get_unix_time_from_system())
		}

	_save_pending_scores()


func _expected_hole_count(course_length: String) -> int:
	match course_length:
		"Front 9", "Back 9":
			return 9
		_:
			return 18


func _extract_course_key(mp: Node) -> String:
	var raw_cfg: Variant = mp.get("config_path")
	var config_path: String = str(raw_cfg) if raw_cfg != null else ""
	if not config_path.is_empty() and FileAccess.file_exists(config_path):
		var f := FileAccess.open(config_path, FileAccess.READ)
		if f != null:
			var txt := f.get_as_text()
			f.close()
			var parsed = JSON.parse_string(txt)
			if parsed is Dictionary:
				var key: String = parsed.get("Key", parsed.get("key", ""))
				if not key.is_empty():
					return key
	# Fallback: derive from course_title
	var raw_title: Variant = mp.get("course_title")
	var title_str: String = str(raw_title) if raw_title != null else ""
	return title_str.to_lower().replace(" ", "_")


## Push all pending scores to Firestore. Called on timer, login, and game-over.
func push_pending_scores() -> void:
	if not _is_signed_in():
		return
	if _pending_score_data.is_empty():
		return

	var fs := _get_firestore()
	var uid := _get_my_uid()
	if uid.is_empty():
		return

	for t_id in _pending_score_data.keys():
		var pending: Dictionary = _pending_score_data[t_id]
		var is_complete: bool = pending.get("is_complete", false)

		var patch := {
			"hole_scores": pending.get("hole_scores", {}),
			"total_strokes": int(pending.get("total_strokes", 0)),
			"to_par": int(pending.get("to_par", 0)),
			"holes_completed": int(pending.get("holes_completed", 0)),
			"status": "submitted" if is_complete else "in_progress",
			"last_synced_at": int(Time.get_unix_time_from_system()),
			"player_name": pending.get("player_name", _get_my_display_name()),
			"tee": pending.get("tee", "Blue")
		}
		if is_complete:
			patch["submitted_at"] = int(Time.get_unix_time_from_system())

		var mask: PackedStringArray = PackedStringArray(patch.keys())
		var res := await fs.set_doc("tournaments/%s/entries/%s" % [t_id, uid], patch, mask)
		if res.get("ok", false):
			print("[TournamentService] Score synced for tournament %s (complete=%s)" % [t_id, str(is_complete)])
			score_synced.emit(t_id)
			if is_complete:
				# Remove from pending once fully submitted
				_pending_score_data.erase(t_id)
		else:
			print("[TournamentService] Score sync failed for %s: %s" % [t_id, res.get("error", "")])

	_save_pending_scores()


func _on_sync_timer_timeout() -> void:
	push_pending_scores()


func _on_auth_state_changed(is_signed_in: bool, _user: Dictionary) -> void:
	if is_signed_in:
		push_pending_scores()


# ── CHECK IF ACTIVE TOURNAMENT FOR COURSE ────────────────────────────────

## Returns a list of active (open, not expired, joined, not submitted) tournament
## entries matching the given course_key + course_length. Used by game start flow
## to prompt the player.
func get_active_tournament_entries_for_course(course_key: String, course_length: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var now := Time.get_unix_time_from_system()
	for t in _joined_tournaments:
		if t.get("course_key", "") != course_key:
			continue
		if t.get("course_length", "Full 18") != course_length:
			continue
		var end_unix := _parse_date_utc(t.get("end_date_utc", ""))
		if end_unix > 0 and now > end_unix:
			continue
		if t.get("status", "open") != "open":
			continue
		# Check if already fully submitted
		var pending: Dictionary = _pending_score_data.get(t.get("tournament_id", ""), {})
		if pending.get("is_complete", false):
			continue
		result.append(t)
	return result


## Returns how many holes have been completed so far in a pending tournament entry.
func get_holes_completed_for_tournament(tournament_id: String) -> int:
	var pending: Dictionary = _pending_score_data.get(tournament_id, {})
	return int(pending.get("holes_completed", 0))


## Returns the merged hole_scores dict for a pending tournament entry (for resuming).
func get_pending_hole_scores(tournament_id: String) -> Dictionary:
	var pending: Dictionary = _pending_score_data.get(tournament_id, {})
	return pending.get("hole_scores", {}).duplicate()


# ── LOCAL PERSISTENCE ─────────────────────────────────────────────────────

func _save_pending_scores() -> void:
	var f := FileAccess.open(LOCAL_PENDING_FILE, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_pending_score_data))
	f.close()


func _load_pending_scores() -> void:
	if not FileAccess.file_exists(LOCAL_PENDING_FILE):
		return
	var f := FileAccess.open(LOCAL_PENDING_FILE, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if parsed is Dictionary:
		_pending_score_data = parsed


func _cache_joined_tournament(t_doc: Dictionary) -> void:
	var t_id: String = t_doc.get("tournament_id", "")
	if t_id.is_empty():
		return
	for i in range(_joined_tournaments.size()):
		if _joined_tournaments[i].get("tournament_id", "") == t_id:
			_joined_tournaments[i] = t_doc
			_save_joined_tournaments()
			return
	_joined_tournaments.append(t_doc)
	_save_joined_tournaments()


func _save_joined_tournaments() -> void:
	var f := FileAccess.open(LOCAL_JOINED_FILE, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_joined_tournaments))
	f.close()


func _load_joined_tournaments() -> void:
	if not FileAccess.file_exists(LOCAL_JOINED_FILE):
		return
	var f := FileAccess.open(LOCAL_JOINED_FILE, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if parsed is Array:
		for item in parsed:
			if item is Dictionary:
				_joined_tournaments.append(item)


# ── DATE UTILITIES ────────────────────────────────────────────────────────

## Parse "YYYY-MM-DD HH:MM" (UTC) or ISO8601 to Unix timestamp.
func _parse_date_utc(date_str: String) -> int:
	if date_str.is_empty():
		return 0
	# Normalize: replace T with space, strip Z/timezone
	var s := date_str.strip_edges().replace("T", " ")
	if "Z" in s:
		s = s.split("Z")[0]
	if "+" in s:
		s = s.split("+")[0]
	var parts := s.split(" ")
	if parts.size() < 1:
		return 0
	var date_parts := parts[0].split("-")
	if date_parts.size() < 3:
		return 0
	var time_parts: PackedStringArray = PackedStringArray(["0", "0", "0"])
	if parts.size() >= 2:
		var tp := parts[1].split(":")
		for i in range(mini(tp.size(), 3)):
			time_parts[i] = tp[i]

	var dt := Time.get_unix_time_from_datetime_dict({
		"year": int(date_parts[0]),
		"month": int(date_parts[1]),
		"day": int(date_parts[2]),
		"hour": int(time_parts[0]),
		"minute": int(time_parts[1]),
		"second": int(time_parts[2])
	})
	return int(dt)


## Format a Unix timestamp as "Mon DD, YYYY HH:MM UTC"
func format_end_date(unix_ts: int) -> String:
	if unix_ts <= 0:
		return "No end date"
	var dt := Time.get_datetime_dict_from_unix_time(unix_ts)
	var months: Array[String] = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
	var mon: String = months[int(dt.get("month", 1)) - 1]
	return "%s %02d, %d %02d:%02d UTC" % [mon, int(dt.get("day", 1)), int(dt.get("year", 2026)), int(dt.get("hour", 0)), int(dt.get("minute", 0))]


## Returns unix timestamp for the start of a time_frame filter period.
func _time_frame_cutoff(time_frame: String) -> float:
	var now := Time.get_unix_time_from_system()
	match time_frame:
		"today":
			return now - 86400.0
		"this_week":
			return now - 604800.0
		"this_month":
			return now - 2592000.0
		"last_90_days":
			return now - 7776000.0
		_:
			return 0.0


## Check whether a tournament's end date has passed.
func is_tournament_ended(t_doc: Dictionary) -> bool:
	var end_unix := _parse_date_utc(t_doc.get("end_date_utc", ""))
	if end_unix <= 0:
		return false
	return Time.get_unix_time_from_system() > end_unix


## True if the player is already joined (locally cached).
func is_joined(tournament_id: String) -> bool:
	for t in _joined_tournaments:
		if t.get("tournament_id", "") == tournament_id:
			return true
	return false
