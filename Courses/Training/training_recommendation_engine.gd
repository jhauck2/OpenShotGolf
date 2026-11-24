class_name TrainingRecommendationEngine
extends RefCounted

## Data-driven drill recommendation engine.
## Evaluates a player's recorded club stats, dispersion, launch/delivery telemetry,
## video swing issues, round scoring, and training mastery history to prescribe
## the highest-impact training drill with transparent evidence.

const Catalog = preload("res://Courses/Training/training_catalog.gd")
const ProgressStore = preload("res://Courses/Training/training_progress_store.gd")

const M_TO_YDS := 1.09361
const WEDGE_CLUBS: Array[String] = ["Pw", "Gw", "Sw", "Lw"]
const IRON_CLUBS: Array[String] = ["4i", "5i", "6i", "7i", "8i", "9i"]
const LONG_CLUBS: Array[String] = ["Dr", "3w", "5w", "2H", "3H", "4H"]


static func _get_multiplayer_manager() -> Node:
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree and main_loop.root != null and main_loop.root.has_node("MultiplayerManager"):
		return main_loop.root.get_node("MultiplayerManager")
	return null


static func _map_skill_to_difficulty(skill_level: String) -> String:
	match skill_level.strip_edges().to_lower():
		"beginner", "high_handicap":
			return "beginner"
		"low_handicap", "scratch", "pro", "tour_pro":
			return "pro"
		_:
			return "standard"


static func _safe_mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for v in values:
		total += v
	return total / float(values.size())


static func _safe_stddev(values: Array[float]) -> float:
	if values.size() < 2:
		return 0.0
	var mean := _safe_mean(values)
	var sq_sum := 0.0
	for v in values:
		var d := v - mean
		sq_sum += d * d
	return sqrt(sq_sum / float(values.size()))


static func _extract_shot_side_yds(shot: Dictionary) -> float:
	return float(shot.get("SideDistance", shot.get("Offline", 0.0))) * M_TO_YDS


static func _extract_shot_carry_yds(shot: Dictionary) -> float:
	var c := float(shot.get("CarryDistance", 0.0))
	if c <= 0.0:
		c = float(shot.get("TotalDistance", 0.0))
	return c * M_TO_YDS


static func _extract_shot_ftp(shot: Dictionary) -> Variant:
	if shot.has("FaceToPath") and typeof(shot["FaceToPath"]) in [TYPE_FLOAT, TYPE_INT]:
		return float(shot["FaceToPath"])
	if shot.has("FaceAngle") and shot.has("ClubPath"):
		return float(shot["FaceAngle"]) - float(shot["ClubPath"])
	return null


static func _extract_shot_spin_axis(shot: Dictionary) -> Variant:
	if shot.has("SpinAxis") and typeof(shot["SpinAxis"]) in [TYPE_FLOAT, TYPE_INT]:
		return float(shot["SpinAxis"])
	if shot.has("SideSpin") and shot.has("BackSpin"):
		var bs := float(shot["BackSpin"])
		var ss := float(shot["SideSpin"])
		if absf(bs) > 1.0 or absf(ss) > 1.0:
			return rad_to_deg(atan2(ss, bs))
	return null


static func _extract_shot_vla(shot: Dictionary) -> Variant:
	for k in ["VLA", "VerticalLaunchAngle", "LaunchAngle", "vla"]:
		if shot.has(k) and str(shot[k]) not in ["", "---", "N/A"]:
			var s := str(shot[k]).strip_edges()
			if s.is_valid_float():
				return float(s)
	return null


static func _extract_shot_smash(shot: Dictionary) -> Variant:
	if shot.has("SmashFactor") and float(shot["SmashFactor"]) > 0.35:
		return float(shot["SmashFactor"])
	var bs := float(shot.get("BallSpeed", shot.get("Speed", 0.0)))
	var cs := float(shot.get("ClubSpeed", shot.get("club_speed", 0.0)))
	if bs > 5.0 and cs > 5.0:
		return bs / cs
	return null


static func _get_issue_weight(swing_issues: Dictionary, issue_names: Array) -> int:
	var all_time: Dictionary = swing_issues.get("all_time", {}) if typeof(swing_issues.get("all_time", {})) == TYPE_DICTIONARY else {}
	var monthly: Dictionary = swing_issues.get("monthly", {}) if typeof(swing_issues.get("monthly", {})) == TYPE_DICTIONARY else {}
	var d_dict := Time.get_date_dict_from_system()
	var current_month := "%04d-%02d" % [d_dict.year, d_dict.month]
	var cur_mo_dict: Dictionary = monthly.get(current_month, {}) if typeof(monthly.get(current_month, {})) == TYPE_DICTIONARY else {}

	var score := 0
	for issue in issue_names:
		var mo_cnt := int(cur_mo_dict.get(issue, 0))
		var at_cnt := int(all_time.get(issue, 0))
		score += mo_cnt * 8 + at_cnt * 2
	return mini(score, 38)


static func _sum_all_swing_issues(swing_issues: Dictionary) -> int:
	var all_time: Dictionary = swing_issues.get("all_time", {}) if typeof(swing_issues.get("all_time", {})) == TYPE_DICTIONARY else {}
	var total := 0
	for k in all_time.keys():
		total += int(all_time[k])
	return total


static func _pick_primary_club_from_group(club_averages: Dictionary, candidates: Array, fallback: String) -> String:
	var best_club := fallback
	var best_count := 0
	for c in candidates:
		if club_averages.has(c) and typeof(club_averages[c]) == TYPE_DICTIONARY:
			var cnt := int(club_averages[c].get("shot_count", 0))
			if cnt > best_count:
				best_count = cnt
				best_club = c
	return best_club


static func _gather_group_shots(club_averages: Dictionary, club_stats: Dictionary, clubs: Array) -> Array[Dictionary]:
	var merged: Array[Dictionary] = []
	for c in clubs:
		var arr: Array = []
		if club_averages.has(c) and typeof(club_averages[c]) == TYPE_DICTIONARY and club_averages[c].has("shots"):
			arr = club_averages[c].get("shots", [])
		elif club_stats.has(c) and typeof(club_stats[c]) == TYPE_ARRAY:
			arr = club_stats[c]
		for item in arr:
			if typeof(item) == TYPE_DICTIONARY:
				var copy_shot: Dictionary = item.duplicate()
				copy_shot["_club_code"] = c
				merged.append(copy_shot)
	return merged


static func _apply_mastery_dampening(score: float, drill_id: String, training_history: Dictionary) -> float:
	var drills_hist: Dictionary = training_history.get("drills", {}) if typeof(training_history.get("drills", {})) == TYPE_DICTIONARY else {}
	if drills_hist.has(drill_id) and typeof(drills_hist[drill_id]) == TYPE_DICTIONARY:
		if str(drills_hist[drill_id].get("best_grade", "")) == "S":
			return maxf(5.0, score - 8.0)
	return score


static func _make_candidate(
	drill_id: String,
	score: float,
	headline: String,
	reason: String,
	evidence: Array,
	recommended_club: String,
	suggested_difficulty: String,
	training_history: Dictionary
) -> Dictionary:
	var adjusted_score := _apply_mastery_dampening(score, drill_id, training_history)
	return {
		"drill_id": drill_id,
		"score": snappedf(adjusted_score, 0.1),
		"headline": headline,
		"reason": reason,
		"evidence": evidence,
		"recommended_club": recommended_club,
		"suggested_difficulty": suggested_difficulty
	}


static func recommend_for_player(player_name: String, progress_path: String = ProgressStore.DEFAULT_PROGRESS_PATH) -> Dictionary:
	var mp := _get_multiplayer_manager()
	var club_averages: Dictionary = {}
	var club_stats: Dictionary = {}
	var swing_issues: Dictionary = {"all_time": {}, "monthly": {}}
	var player_stats: Dictionary = {}
	var handedness := 0
	var skill_level := "mid_handicap"

	if mp != null:
		if mp.has_method("calculate_player_club_averages"):
			club_averages = mp.calculate_player_club_averages(player_name)
		if mp.has_method("get_player_club_stats"):
			club_stats = mp.get_player_club_stats(player_name)
		if mp.has_method("get_player_swing_issues"):
			swing_issues = mp.get_player_swing_issues(player_name)
		if mp.has_method("calculate_player_stats"):
			player_stats = mp.calculate_player_stats(player_name)
		if mp.has_method("get_player_handedness"):
			handedness = int(mp.get_player_handedness(player_name))
		if mp.has_method("get_player_skill_level"):
			skill_level = str(mp.get_player_skill_level(player_name))

	var training_history := ProgressStore.get_player_progress(player_name, progress_path)
	return recommend_from_data(club_averages, club_stats, swing_issues, player_stats, handedness, skill_level, training_history)


static func recommend_from_data(
	club_averages: Dictionary,
	club_stats: Dictionary,
	swing_issues: Dictionary,
	player_stats: Dictionary,
	handedness: int = 0,
	skill_level: String = "mid_handicap",
	training_history: Dictionary = {}
) -> Dictionary:
	var suggested_diff := _map_skill_to_difficulty(skill_level)
	var hand_sign := -1.0 if handedness == 1 else 1.0 # +1 => RH (+Z right is slice), -1 => LH (-Z left is slice)

	# Count total valid shots across club_averages or fallback club_stats
	var total_shots := 0
	var clubs_with_data := 0
	var counted_clubs: Dictionary = {}
	for c in club_averages.keys():
		if typeof(club_averages[c]) == TYPE_DICTIONARY:
			var sc := int(club_averages[c].get("shot_count", 0))
			if sc > 0:
				total_shots += sc
				clubs_with_data += 1
				counted_clubs[c] = true
	for c in club_stats.keys():
		if counted_clubs.has(c):
			continue
		if typeof(club_stats[c]) == TYPE_ARRAY and not club_stats[c].is_empty():
			total_shots += club_stats[c].size()
			clubs_with_data += 1

	var total_issues := _sum_all_swing_issues(swing_issues)

	# Cold-start: not enough telemetry yet -> prescribe Full-Bag Skill Combine
	if total_shots < 5 and total_issues == 0:
		var primary_cold := _make_candidate(
			"skill_combine",
			95.0,
			"Start with a 10-Shot Full-Bag Combine",
			"We only see %d recorded shots so far. Complete this quick 5-station combine to benchmark your wedges, irons, and driver!" % total_shots,
			[
				"Recorded shots found: %d (need 5+ for trend diagnostics)" % total_shots,
				"Tests 60, 100, 140, 175 yds + Driver fairway control",
				"Every real shot recorded here powers smarter future suggestions"
			],
			"Sw",
			suggested_diff,
			training_history
		)
		var alt1_cold := _make_candidate(
			"fairway_finder",
			65.0,
			"Build Tee-Shot Confidence",
			"Groove a repeatable driver start line down a forgiving fairway corridor.",
			["Great warmup before playing a course"],
			"Dr",
			suggested_diff,
			training_history
		)
		var alt2_cold := _make_candidate(
			"wedge_clock",
			60.0,
			"Dial In Scoring Wedges",
			"Build reliable distance feel from 50 to 110 yards.",
			["Scoring wedges save the most strokes per round"],
			"Sw",
			suggested_diff,
			training_history
		)
		return {
			"is_cold_start": true,
			"total_shots_analyzed": total_shots,
			"clubs_analyzed": clubs_with_data,
			"suggested_difficulty": suggested_diff,
			"primary": primary_cold,
			"alternatives": [alt1_cold, alt2_cold]
		}

	var candidates: Array[Dictionary] = []

	var long_shots := _gather_group_shots(club_averages, club_stats, LONG_CLUBS)
	var iron_shots := _gather_group_shots(club_averages, club_stats, IRON_CLUBS)
	var wedge_shots := _gather_group_shots(club_averages, club_stats, WEDGE_CLUBS)
	var all_shots: Array[Dictionary] = []
	all_shots.append_array(long_shots)
	all_shots.append_array(iron_shots)
	all_shots.append_array(wedge_shots)

	var primary_long_club := _pick_primary_club_from_group(club_averages, LONG_CLUBS, "Dr")
	var primary_iron_club := _pick_primary_club_from_group(club_averages, IRON_CLUBS, "7i")
	var primary_wedge_club := _pick_primary_club_from_group(club_averages, WEDGE_CLUBS, "Sw")

	# 1 & 2. Slice Cure vs Hook Tamer (directional curve & face-to-path diagnostics)
	var curve_pool := long_shots if long_shots.size() >= 3 else all_shots
	if not curve_pool.is_empty() or total_issues > 0:
		var side_vals: Array[float] = []
		var ftp_vals: Array[float] = []
		var spin_axis_vals: Array[float] = []
		var slice_misses := 0
		var hook_misses := 0
		for s in curve_pool:
			var side_yds := _extract_shot_side_yds(s)
			side_vals.append(side_yds)
			if side_yds * hand_sign > 10.0:
				slice_misses += 1
			elif side_yds * hand_sign < -10.0:
				hook_misses += 1
			var ftp = _extract_shot_ftp(s)
			if ftp != null:
				ftp_vals.append(float(ftp))
			var sa = _extract_shot_spin_axis(s)
			if sa != null:
				spin_axis_vals.append(float(sa))

		var mean_signed_side := _safe_mean(side_vals) # + = Right, - = Left
		var slice_dir_bias := mean_signed_side * hand_sign
		var hook_dir_bias := -slice_dir_bias
		var mean_ftp_hand := _safe_mean(ftp_vals) * hand_sign
		var mean_sa_hand := _safe_mean(spin_axis_vals) * hand_sign

		# Slice score
		var slice_issue_pts := _get_issue_weight(swing_issues, ["Slice / Open Face-to-Path", "Over-the-Top Slice", "Fade / Open Face"])
		var slice_score := float(slice_issue_pts)
		var slice_evidence: Array[String] = []
		if slice_dir_bias >= 5.5 and not side_vals.is_empty():
			slice_score += clampf((slice_dir_bias - 3.0) * 3.1, 10.0, 52.0)
			var miss_dir_word := "left" if handedness == 1 else "right"
			slice_evidence.append("%s average miss: %.1f yds %s (%d/%d big %s misses)" % [
				primary_long_club, slice_dir_bias, miss_dir_word, slice_misses, side_vals.size(), miss_dir_word
			])
		if not ftp_vals.is_empty() and mean_ftp_hand >= 1.6:
			slice_score += clampf(mean_ftp_hand * 5.2, 8.0, 30.0)
			slice_evidence.append("Average Face-to-Path is %.1f° open to swing path" % absf(mean_ftp_hand))
		if not spin_axis_vals.is_empty() and mean_sa_hand >= 4.0:
			slice_score += clampf(mean_sa_hand * 1.4, 6.0, 20.0)
			slice_evidence.append("Average spin axis tilts %.1f° toward slice curve" % absf(mean_sa_hand))
		if slice_issue_pts > 0:
			slice_evidence.append("Recurring slice/open-face pattern flagged in swing history")
		if slice_score >= 18.0:
			candidates.append(_make_candidate(
				"slice_cure",
				slice_score,
				"Fix Your Slice Pattern",
				"Your recent shots consistently miss toward your slice side. This drill locks in an inside path and square clubface release.",
				slice_evidence,
				primary_long_club,
				suggested_diff,
				training_history
			))

		# Hook score
		var hook_issue_pts := _get_issue_weight(swing_issues, ["Hook / Closed Face-to-Path", "Draw / Closed Face"])
		var hook_score := float(hook_issue_pts)
		var hook_evidence: Array[String] = []
		if hook_dir_bias >= 5.5 and not side_vals.is_empty():
			hook_score += clampf((hook_dir_bias - 3.0) * 3.1, 10.0, 52.0)
			var hook_word := "right" if handedness == 1 else "left"
			hook_evidence.append("%s average miss: %.1f yds %s (%d/%d hard %s misses)" % [
				primary_long_club, hook_dir_bias, hook_word, hook_misses, side_vals.size(), hook_word
			])
		if not ftp_vals.is_empty() and mean_ftp_hand <= -1.6:
			hook_score += clampf(absf(mean_ftp_hand) * 5.2, 8.0, 30.0)
			hook_evidence.append("Average Face-to-Path is %.1f° closed to swing path" % absf(mean_ftp_hand))
		if not spin_axis_vals.is_empty() and mean_sa_hand <= -4.0:
			hook_score += clampf(absf(mean_sa_hand) * 1.4, 6.0, 20.0)
			hook_evidence.append("Average spin axis tilts %.1f° toward hook curve" % absf(mean_sa_hand))
		if hook_issue_pts > 0:
			hook_evidence.append("Recurring closed-face / over-draw pattern in swing history")
		if hook_score >= 18.0:
			candidates.append(_make_candidate(
				"hook_tamer",
				hook_score,
				"Tame Your Hook & Over-Draw",
				"Your telemetry shows closed-face misses curving across the centerline. Syncing body turn with hand release straightens flight.",
				hook_evidence,
				primary_long_club,
				suggested_diff,
				training_history
			))

	# 3. Fairway Finder (two-way or wide tee-shot dispersion)
	if not long_shots.is_empty():
		var abs_offs: Array[float] = []
		var left_cnt := 0
		var right_cnt := 0
		for s in long_shots:
			var side_yds := _extract_shot_side_yds(s)
			abs_offs.append(absf(side_yds))
			if side_yds < -8.0:
				left_cnt += 1
			elif side_yds > 8.0:
				right_cnt += 1
		var avg_abs_off := _safe_mean(abs_offs)
		if avg_abs_off >= 9.0:
			var fw_score := clampf((avg_abs_off - 6.0) * 2.4, 15.0, 56.0)
			var two_way := left_cnt > 0 and right_cnt > 0 and float(mini(left_cnt, right_cnt)) / float(long_shots.size()) >= 0.20
			if two_way:
				fw_score += 14.0
			var fw_ev: Array[String] = [
				"%s average offline dispersion: %.1f yds across %d shots" % [primary_long_club, avg_abs_off, long_shots.size()]
			]
			if two_way:
				fw_ev.append("Two-way miss detected (%d left, %d right beyond 8 yds)" % [left_cnt, right_cnt])
			candidates.append(_make_candidate(
				"fairway_finder",
				fw_score,
				"Tighten Your Fairway Corridor",
				"Cutting down tee-shot lateral spray keeps balls in play and sets up shorter, cleaner approach shots.",
				fw_ev,
				primary_long_club,
				suggested_diff,
				training_history
			))

	# 4. Sweet Spot Strike (smash factor & face impact offset)
	var strike_issue_pts := _get_issue_weight(swing_issues, ["Low Smash Factor", "Sub-Optimal Smash Factor", "Early Extension Contact Loss"])
	var max_smash_deficit := 0.0
	var worst_smash_club := primary_iron_club
	var worst_avg_smash := 0.0
	var worst_exp_smash := 0.0
	var max_impact_offset := 0.0
	var impact_club := primary_iron_club

	for c in club_averages.keys():
		var ca = club_averages[c]
		if typeof(ca) != TYPE_DICTIONARY or int(ca.get("shot_count", 0)) == 0:
			continue
		if bool(ca.get("has_smash_factor", false)) and float(ca.get("avg_smash_factor", 0.0)) > 0.35:
			var avg_sm := float(ca.get("avg_smash_factor", 0.0))
			var exp_sm := Catalog.get_expected_smash(str(c))
			var def := exp_sm - avg_sm
			if def > max_smash_deficit:
				max_smash_deficit = def
				worst_smash_club = str(c)
				worst_avg_smash = avg_sm
				worst_exp_smash = exp_sm
		if bool(ca.get("has_impact_data", false)):
			var pts: Array = ca.get("impact_points", [])
			var offsets: Array[float] = []
			for pt in pts:
				if typeof(pt) == TYPE_DICTIONARY:
					var h := float(pt.get("h", 0.0))
					var v := float(pt.get("v", 0.0))
					offsets.append(sqrt(h * h + v * v))
			var mean_off := _safe_mean(offsets)
			if mean_off > max_impact_offset:
				max_impact_offset = mean_off
				impact_club = str(c)

	# Also inspect raw club_stats if club_averages didn't carry computed smash
	if max_smash_deficit <= 0.0:
		for c in club_stats.keys():
			if typeof(club_stats[c]) != TYPE_ARRAY or club_stats[c].is_empty():
				continue
			var sm_vals: Array[float] = []
			for s in club_stats[c]:
				if typeof(s) == TYPE_DICTIONARY:
					var sm = _extract_shot_smash(s)
					if sm != null:
						sm_vals.append(float(sm))
			if not sm_vals.is_empty():
				var avg_sm2 := _safe_mean(sm_vals)
				var exp_sm2 := Catalog.get_expected_smash(str(c))
				var def2 := exp_sm2 - avg_sm2
				if def2 > max_smash_deficit:
					max_smash_deficit = def2
					worst_smash_club = str(c)
					worst_avg_smash = avg_sm2
					worst_exp_smash = exp_sm2

	var strike_score := float(strike_issue_pts)
	var strike_ev: Array[String] = []
	if max_smash_deficit >= 0.03:
		strike_score += clampf(max_smash_deficit * 520.0, 16.0, 58.0)
		strike_ev.append("%s smash factor is %.2f vs %.2f target" % [worst_smash_club, worst_avg_smash, worst_exp_smash])
	if max_impact_offset >= 8.5:
		strike_score += clampf((max_impact_offset - 6.0) * 2.5, 10.0, 32.0)
		strike_ev.append("%s average strike is %.1f mm off the sweet spot" % [impact_club, max_impact_offset])
	if strike_issue_pts > 0:
		strike_ev.append("Off-center / smash factor warnings recorded in swing analysis")
	if strike_score >= 18.0:
		candidates.append(_make_candidate(
			"sweet_spot_strike",
			strike_score,
			"Boost Smash Factor & Solid Strike",
			"Centered contact gives you free ball speed and tighter distance control without swinging harder.",
			strike_evidence_clean(strike_ev),
			worst_smash_club if max_smash_deficit >= 0.03 else impact_club,
			suggested_diff,
			training_history
		))

	# 5. Wedge Clock (wedge carry scatter & target diff)
	if not wedge_shots.is_empty() or bool(player_stats.get("avg_to_par_valid", false)):
		var wedge_carries: Array[float] = []
		var wedge_offs: Array[float] = []
		var wedge_tdiffs: Array[float] = []
		for s in wedge_shots:
			var c_yds := _extract_shot_carry_yds(s)
			if c_yds > 5.0:
				wedge_carries.append(c_yds)
			wedge_offs.append(absf(_extract_shot_side_yds(s)))
			var td := float(s.get("TargetDistance", 0.0)) * M_TO_YDS
			if td > 5.0 and c_yds > 5.0:
				wedge_tdiffs.append(absf(c_yds - td))
		var wedge_std := _safe_stddev(wedge_carries)
		var wedge_avg_off := _safe_mean(wedge_offs)
		var wedge_avg_td := _safe_mean(wedge_tdiffs)

		var wedge_score := 0.0
		var wedge_ev: Array[String] = []
		if wedge_std >= 5.5:
			wedge_score += clampf((wedge_std - 3.5) * 4.5, 14.0, 48.0)
			wedge_ev.append("Wedge carry spread (std dev): ±%.1f yds across %d shots" % [wedge_std, wedge_carries.size()])
		if wedge_avg_td >= 5.5:
			wedge_score += clampf((wedge_avg_td - 3.5) * 4.2, 12.0, 45.0)
			wedge_ev.append("Wedges miss target distance by an average of %.1f yds" % wedge_avg_td)
		if wedge_avg_off >= 5.5:
			wedge_score += clampf((wedge_avg_off - 3.5) * 3.0, 10.0, 30.0)
			wedge_ev.append("Wedge lateral offline avg: %.1f yds" % wedge_avg_off)
		if bool(player_stats.get("avg_to_par_valid", false)) and float(player_stats.get("avg_to_par", 0.0)) >= 9.0:
			wedge_score += 14.0
			wedge_ev.append("Round scoring avg (+%.1f to par) benefits fast from crisp wedges" % float(player_stats.get("avg_to_par", 0.0)))
		if wedge_score >= 18.0:
			candidates.append(_make_candidate(
				"wedge_clock",
				wedge_score,
				"Dial In 50–110 Yd Scoring Wedges",
				"Tightening wedge distance control inside 110 yards creates tap-in pars and easy birdie looks.",
				wedge_ev,
				primary_wedge_club,
				suggested_diff,
				training_history
			))

	# 6. Approach Bullseye (mid/short iron accuracy)
	if not iron_shots.is_empty():
		var iron_offs: Array[float] = []
		var iron_carries: Array[float] = []
		var iron_tdiffs: Array[float] = []
		for s in iron_shots:
			iron_offs.append(absf(_extract_shot_side_yds(s)))
			var cy := _extract_shot_carry_yds(s)
			if cy > 20.0:
				iron_carries.append(cy)
			var td := float(s.get("TargetDistance", 0.0)) * M_TO_YDS
			if td > 20.0 and cy > 20.0:
				iron_tdiffs.append(absf(cy - td))
		var iron_avg_off := _safe_mean(iron_offs)
		var iron_avg_td := _safe_mean(iron_tdiffs)
		var iron_std := _safe_stddev(iron_carries)

		var iron_score := 0.0
		var iron_ev: Array[String] = []
		if iron_avg_off >= 7.5:
			iron_score += clampf((iron_avg_off - 5.0) * 3.2, 12.0, 48.0)
			iron_ev.append("Mid-iron average offline error: %.1f yds (%d shots)" % [iron_avg_off, iron_shots.size()])
		if iron_avg_td >= 7.5:
			iron_score += clampf((iron_avg_td - 5.0) * 3.0, 10.0, 40.0)
			iron_ev.append("Approach distance miss averages %.1f yds from pin" % iron_avg_td)
		if iron_score >= 18.0:
			candidates.append(_make_candidate(
				"approach_bullseye",
				iron_score,
				"Stick More Approach Greens",
				"Dial in randomized iron yardages so approach shots hold the green instead of finding bunkers.",
				iron_ev,
				primary_iron_club,
				suggested_diff,
				training_history
			))

		if iron_std >= 9.5:
			var disp_score := clampf((iron_std - 6.5) * 4.2, 16.0, 52.0)
			candidates.append(_make_candidate(
				"dispersion_tightener",
				disp_score,
				"Shrink Iron Carry Scatter",
				"Your iron distances vary by ±%.1f yds. Clustering shots around stock carry locks in predictable yardages." % iron_std,
				["%s–iron carry standard deviation: ±%.1f yds" % [primary_iron_club, iron_std]],
				primary_iron_club,
				suggested_diff,
				training_history
			))

	# 7. Launch Window (VLA out of optimal range or launch/AoA swing issues)
	var launch_issue_pts := _get_issue_weight(swing_issues, [
		"Low Driver Launch", "High Driver Launch / Pop-up", "Low Wood Launch",
		"High Wood Launch / Scoop", "Scooping Wood Off Turf", "Scooping Hybrid Off Turf",
		"Steep Driver Attack Angle", "Steep Driver Off Turf", "Excessive Driver Spin"
	])
	var max_vla_dev := 0.0
	var vla_club := primary_iron_club
	var observed_vla := 0.0
	var target_vla := 19.0
	for c in club_stats.keys():
		if typeof(club_stats[c]) != TYPE_ARRAY or club_stats[c].is_empty():
			continue
		var vlas: Array[float] = []
		for s in club_stats[c]:
			if typeof(s) == TYPE_DICTIONARY:
				var v = _extract_shot_vla(s)
				if v != null:
					vlas.append(float(v))
		if vlas.size() >= 2:
			var mean_vla := _safe_mean(vlas)
			var win := Catalog.get_optimal_vla_window(str(c))
			var dev := 0.0
			if mean_vla < float(win["min"]):
				dev = float(win["min"]) - mean_vla + 1.0
			elif mean_vla > float(win["max"]):
				dev = mean_vla - float(win["max"]) + 1.0
			else:
				dev = absf(mean_vla - float(win["ideal"])) * 0.4
			if dev > max_vla_dev:
				max_vla_dev = dev
				vla_club = str(c)
				observed_vla = mean_vla
				target_vla = float(win["ideal"])

	var launch_score := float(launch_issue_pts)
	var launch_ev: Array[String] = []
	if max_vla_dev >= 2.2:
		launch_score += clampf(max_vla_dev * 8.5, 16.0, 55.0)
		var high_low := "low" if observed_vla < target_vla else "high"
		launch_ev.append("%s average launch angle is %.1f° (%s vs %.1f° ideal)" % [vla_club, observed_vla, high_low, target_vla])
	if launch_issue_pts > 0:
		launch_ev.append("Launch / angle-of-attack flags detected in swing profile")
	if launch_score >= 18.0:
		candidates.append(_make_candidate(
			"launch_window",
			launch_score,
			"Optimize Launch Angle Window",
			"Sending the ball through the ideal launch window unlocks carry distance and reliable stopping trajectory.",
			launch_ev,
			vla_club,
			suggested_diff,
			training_history
		))

	# Fallback baseline candidates so we ALWAYS return primary + 2 alternatives
	candidates.append(_make_candidate(
		"skill_combine",
		28.0,
		"Full-Bag Skill Combine Benchmark",
		"Test every part of your bag from 60-yard wedges to Driver in one 10-shot session.",
		["Covers scoring wedges, mid-irons, long irons, and tee shots"],
		"Sw",
		suggested_diff,
		training_history
	))
	candidates.append(_make_candidate(
		"fairway_finder",
		22.0,
		"Fairway Finder Tee Accuracy",
		"Dial in straight, playable drives to keep every hole stress-free.",
		["Core accuracy drill for consistent tee shots"],
		primary_long_club,
		suggested_diff,
		training_history
	))
	candidates.append(_make_candidate(
		"approach_bullseye",
		20.0,
		"Approach Target Roulette",
		"Sharpen randomized iron distance control between 120 and 170 yards.",
		["Improves Greens in Regulation percentage"],
		primary_iron_club,
		suggested_diff,
		training_history
	))

	# Deduplicate by drill_id keeping highest score
	var dedup: Dictionary = {}
	for cand in candidates:
		var did := str(cand["drill_id"])
		if not dedup.has(did) or float(cand["score"]) > float(dedup[did]["score"]):
			dedup[did] = cand

	var unique_list: Array[Dictionary] = []
	for did in dedup.keys():
		unique_list.append(dedup[did])

	unique_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)

	var primary: Dictionary = unique_list[0]
	var alts: Array[Dictionary] = []
	for i in range(1, mini(3, unique_list.size())):
		alts.append(unique_list[i])

	return {
		"is_cold_start": false,
		"total_shots_analyzed": total_shots,
		"clubs_analyzed": clubs_with_data,
		"suggested_difficulty": suggested_diff,
		"primary": primary,
		"alternatives": alts
	}


static func strike_evidence_clean(ev: Array) -> Array:
	if ev.is_empty():
		return ["Centered strike boosts carry consistency"]
	return ev
