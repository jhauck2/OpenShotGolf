class_name StatsMerger
extends RefCounted

## Pure, stateless sync merger for OpenFairway cloud profiles.
## Merges local and cloud shot lists, records, achievements, swing issues, and tombstones
## non-destructively, enforcing the 200-shots-per-club cap (CLOUD_MAX_SHOTS_PER_CLUB = 200).

const CLOUD_MAX_SHOTS_PER_CLUB := 200


static func merge_profile_stats(local_data: Dictionary, cloud_data: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"schema_version": 1,
		"tombstones": {},
		"records": {},
		"clubs": {},
		"achievements": {
			"unlocked": {},
			"heard_heckles": []
		},
		"swing_issues": {},
		"best_courses": {}
	}

	# ── 1. TOMBSTONES ────────────────────────────────────────────────────────
	var loc_tomb: Dictionary = local_data.get("tombstones", local_data.get("_tombstones", {}))
	var cld_tomb: Dictionary = cloud_data.get("tombstones", cloud_data.get("_tombstones", {}))

	var eff_cleared_all: int = maxi(int(loc_tomb.get("cleared_all_at", 0)), int(cld_tomb.get("cleared_all_at", 0)))
	var eff_cleared_swing: int = maxi(int(loc_tomb.get("cleared_swing_issues_at", loc_tomb.get("_cleared_at", 0))), int(cld_tomb.get("cleared_swing_issues_at", cld_tomb.get("_cleared_at", 0))))

	var loc_clubs_clear: Dictionary = loc_tomb.get("cleared_clubs", {})
	var cld_clubs_clear: Dictionary = cld_tomb.get("cleared_clubs", {})
	var eff_cleared_clubs: Dictionary = {}

	var all_clear_clubs: Array = []
	for c in loc_clubs_clear.keys():
		if not all_clear_clubs.has(str(c)):
			all_clear_clubs.append(str(c))
	for c in cld_clubs_clear.keys():
		if not all_clear_clubs.has(str(c)):
			all_clear_clubs.append(str(c))

	for c in all_clear_clubs:
		var c_str = str(c)
		var loc_ts = get_effective_club_clear_ts(loc_clubs_clear, c_str, 0)
		var cld_ts = get_effective_club_clear_ts(cld_clubs_clear, c_str, 0)
		var clear_ts = maxi(eff_cleared_all, maxi(loc_ts, cld_ts))
		if clear_ts > 0:
			eff_cleared_clubs[c_str] = clear_ts

	result["tombstones"] = {
		"cleared_all_at": eff_cleared_all,
		"cleared_clubs": eff_cleared_clubs,
		"cleared_swing_issues_at": eff_cleared_swing
	}

	# ── 2. CLUBS & SHOT LISTS ────────────────────────────────────────────────
	var loc_clubs: Dictionary = local_data.get("clubs", {})
	var cld_clubs: Dictionary = cloud_data.get("clubs", {})
	if loc_clubs.is_empty():
		for k in local_data.keys():
			if not str(k).begins_with("_") and not k in ["tombstones", "records", "achievements", "swing_issues", "best_courses", "schema_version", "rev", "updated_at"]:
				if local_data[k] is Array:
					loc_clubs[str(k)] = local_data[k]

	var all_clubs: Array = []
	for c in loc_clubs.keys():
		if not all_clubs.has(str(c)):
			all_clubs.append(str(c))
	for c in cld_clubs.keys():
		if not all_clubs.has(str(c)):
			all_clubs.append(str(c))

	for club in all_clubs:
		var club_str = str(club)
		var club_clear_ts = get_effective_club_clear_ts(eff_cleared_clubs, club_str, eff_cleared_all)

		var shots_by_id: Dictionary = {}
		var l_shots = loc_clubs.get(club_str, [])
		if l_shots is Array:
			for s in l_shots:
				if s is Dictionary:
					var sid = _get_or_create_shot_id(s)
					var s_copy = s.duplicate(true)
					s_copy["id"] = sid
					shots_by_id[sid] = s_copy

		var c_shots = cld_clubs.get(club_str, [])
		if c_shots is Array:
			for s in c_shots:
				if s is Dictionary:
					var sid = _get_or_create_shot_id(s)
					if shots_by_id.has(sid):
						var existing = shots_by_id[sid]
						for f in s:
							if not existing.has(f) or (existing[f] == null and s[f] != null):
								existing[f] = s[f]
					else:
						var s_copy = s.duplicate(true)
						s_copy["id"] = sid
						shots_by_id[sid] = s_copy

		# Filter out shots <= tombstone clear timestamp.
		# When club_clear_ts > 0, any shot created prior to or at the clear timestamp
		# (including legacy untimestamped shots where t <= 0) is purged. Only shots
		# hit strictly after the clear survive.
		var surviving_shots: Array = []
		for sid in shots_by_id:
			var s = shots_by_id[sid]
			var t = int(s.get("t", 0))
			if club_clear_ts > 0 and t <= club_clear_ts:
				continue
			surviving_shots.append(s)

		# Chronological sort ascending by t
		surviving_shots.sort_custom(func(a, b):
			return int(a.get("t", 0)) < int(b.get("t", 0))
		)

		# Cap at CLOUD_MAX_SHOTS_PER_CLUB (most recent 200 shots)
		if surviving_shots.size() > CLOUD_MAX_SHOTS_PER_CLUB:
			surviving_shots = surviving_shots.slice(surviving_shots.size() - CLOUD_MAX_SHOTS_PER_CLUB)

		if not surviving_shots.is_empty() or club_clear_ts == 0:
			result["clubs"][club_str] = surviving_shots

	# ── 3. RECORDS ───────────────────────────────────────────────────────────
	var loc_rec: Dictionary = local_data.get("records", local_data.get("_records", {}))
	var cld_rec: Dictionary = cloud_data.get("records", cloud_data.get("_records", {}))
	var max_drive: float = maxf(float(loc_rec.get("longest_drive_yds", loc_rec.get("longest_drive", 0.0))), float(cld_rec.get("longest_drive_yds", cld_rec.get("longest_drive", 0.0))))
	var max_putt: float = maxf(float(loc_rec.get("longest_putt_ft", 0.0)), float(cld_rec.get("longest_putt_ft", 0.0)))

	# If Driver was cleared, recompute or reset longest drive
	var dr_clear_ts = get_effective_club_clear_ts(eff_cleared_clubs, "Dr", eff_cleared_all)
	if dr_clear_ts > 0:
		var dr_shots = result["clubs"].get("Dr", [])
		var best_dr := 0.0
		for s in dr_shots:
			var st = int(s.get("t", 0))
			if st > dr_clear_ts:
				var d_yds = float(s.get("TotalDistance", s.get("CarryDistance", 0.0))) * 1.09361
				if d_yds > best_dr:
					best_dr = d_yds
		max_drive = best_dr

	# If Putter was cleared, recompute or reset longest putt
	var pt_clear_ts = get_effective_club_clear_ts(eff_cleared_clubs, "Pt", eff_cleared_all)
	if pt_clear_ts > 0:
		var pt_shots = result["clubs"].get("Pt", [])
		var best_pt := 0.0
		for s in pt_shots:
			var st = int(s.get("t", 0))
			if st > pt_clear_ts:
				var p_ft = float(s.get("TotalDistance", 0.0)) * 3.28084
				if p_ft > best_pt:
					best_pt = p_ft
		max_putt = best_pt

	if eff_cleared_all > 0:
		if dr_clear_ts == 0:
			max_drive = 0.0
		if pt_clear_ts == 0:
			max_putt = 0.0

	result["records"] = {
		"longest_drive_yds": max_drive,
		"longest_drive": max_drive,
		"longest_putt_ft": max_putt
	}

	# ── 4. ACHIEVEMENTS ──────────────────────────────────────────────────────
	var loc_ach: Dictionary = local_data.get("achievements", {})
	var cld_ach: Dictionary = cloud_data.get("achievements", {})
	var loc_unlocked: Dictionary = loc_ach.get("unlocked", {})
	if loc_unlocked.is_empty() and not loc_ach.has("unlocked"):
		for k in loc_ach.keys():
			if k != "heard_heckles":
				loc_unlocked[k] = loc_ach[k]
	var cld_unlocked: Dictionary = cld_ach.get("unlocked", {})

	var merged_unlocked: Dictionary = {}
	for k in loc_unlocked.keys():
		merged_unlocked[str(k)] = int(loc_unlocked[k])
	for k in cld_unlocked.keys():
		var k_str = str(k)
		var ts = int(cld_unlocked[k])
		if merged_unlocked.has(k_str):
			merged_unlocked[k_str] = mini(merged_unlocked[k_str], ts)
		else:
			merged_unlocked[k_str] = ts

	var loc_heckles: Array = loc_ach.get("heard_heckles", [])
	var cld_heckles: Array = cld_ach.get("heard_heckles", [])
	var merged_heckles: Array = []
	for h in loc_heckles:
		var hs = str(h)
		if not merged_heckles.has(hs):
			merged_heckles.append(hs)
	for h in cld_heckles:
		var hs = str(h)
		if not merged_heckles.has(hs):
			merged_heckles.append(hs)

	# Unlock all_heckles if user has heard all lines
	if merged_heckles.size() >= 18 and not merged_unlocked.has("all_heckles"):
		merged_unlocked["all_heckles"] = int(Time.get_unix_time_from_system())

	result["achievements"] = {
		"unlocked": merged_unlocked,
		"heard_heckles": merged_heckles
	}

	# ── 5. SWING ISSUES ──────────────────────────────────────────────────────
	var loc_swing: Dictionary = local_data.get("swing_issues", {})
	var cld_swing: Dictionary = cloud_data.get("swing_issues", {})
	var loc_swing_updated_at: int = int(local_data.get("swing_issues_updated_at", local_data.get("updated_at", 0)))
	var cld_swing_updated_at: int = int(cloud_data.get("swing_issues_updated_at", cloud_data.get("updated_at", 0)))

	# If swing issues were cleared, purge issues from sides that haven't updated since the clear
	if eff_cleared_swing > 0:
		if loc_swing_updated_at <= eff_cleared_swing:
			loc_swing = {}
		if cld_swing_updated_at <= eff_cleared_swing:
			cld_swing = {}

	var merged_swing: Dictionary = {}

	var all_months: Array = []
	for m in loc_swing.keys():
		if not all_months.has(str(m)):
			all_months.append(str(m))
	for m in cld_swing.keys():
		if not all_months.has(str(m)):
			all_months.append(str(m))

	for m in all_months:
		var m_str = str(m)
		var loc_m = loc_swing.get(m_str, {})
		var cld_m = cld_swing.get(m_str, {})
		if not (loc_m is Dictionary): loc_m = {}
		if not (cld_m is Dictionary): cld_m = {}

		var all_issues: Array = []
		for issue in loc_m.keys():
			if not all_issues.has(str(issue)):
				all_issues.append(str(issue))
		for issue in cld_m.keys():
			if not all_issues.has(str(issue)):
				all_issues.append(str(issue))

		var m_result: Dictionary = {}
		for issue in all_issues:
			var iss_str = str(issue)
			m_result[iss_str] = maxi(int(loc_m.get(iss_str, 0)), int(cld_m.get(iss_str, 0)))
		merged_swing[m_str] = m_result

	var eff_swing_updated_at: int = maxi(loc_swing_updated_at, cld_swing_updated_at)
	if eff_swing_updated_at == 0 and not merged_swing.is_empty():
		eff_swing_updated_at = int(Time.get_unix_time_from_system())
	result["swing_issues"] = merged_swing
	result["swing_issues_updated_at"] = eff_swing_updated_at

	# ── 6. BEST COURSES ──────────────────────────────────────────────────────
	var loc_courses: Dictionary = local_data.get("best_courses", {})
	var cld_courses: Dictionary = cloud_data.get("best_courses", {})
	var merged_courses: Dictionary = {}
	for c in loc_courses.keys():
		merged_courses[str(c)] = loc_courses[c]
	for c in cld_courses.keys():
		var c_str = str(c)
		if not merged_courses.has(c_str):
			merged_courses[c_str] = cld_courses[c]
		else:
			var l_diff = int(merged_courses[c_str].get("diff", 999))
			var c_diff = int(cld_courses[c].get("diff", 999))
			if c_diff < l_diff:
				merged_courses[c_str] = cld_courses[c]
			elif c_diff == l_diff:
				var l_holes = int(merged_courses[c_str].get("holes", 0))
				var c_holes = int(cld_courses[c].get("holes", 0))
				if c_holes > l_holes:
					merged_courses[c_str] = cld_courses[c]

	result["best_courses"] = merged_courses
	return result


static func _get_or_create_shot_id(shot: Dictionary) -> String:
	if shot.has("id") and not str(shot["id"]).strip_edges().is_empty():
		return str(shot["id"])
	var json_str = JSON.stringify(shot)
	return json_str.sha1_text().substr(0, 12)


static func get_effective_club_clear_ts(eff_cleared_clubs: Dictionary, club_name: String, fallback_clear_all: int = 0) -> int:
	var ts = fallback_clear_all
	var c_lower = club_name.to_lower()
	for k in eff_cleared_clubs.keys():
		if str(k).to_lower() == c_lower:
			ts = maxi(ts, int(eff_cleared_clubs[k]))
	return ts

