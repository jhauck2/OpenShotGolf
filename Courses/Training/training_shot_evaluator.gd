class_name TrainingShotEvaluator
extends RefCounted

## Rhythm-game-inspired shot evaluator for Training Arena drills.
## Grades each shot across 5 arcade tiers (PERFECT -> OFF TARGET),
## tracks combo streaks & multipliers, computes directional bias for the
## live precision gauge, and generates shot-to-shot trend coaching callouts.

const Catalog = preload("res://Courses/Training/training_catalog.gd")

const TIER_PERFECT := "PERFECT"
const TIER_GREAT := "GREAT"
const TIER_GOOD := "GOOD"
const TIER_OK := "OK"
const TIER_MISS := "MISS"

const TIER_DISPLAY := {
	TIER_PERFECT: {"label": "★ PERFECT! ★", "color": Color(1.0, 0.85, 0.25), "points": 100, "pitch": 1.38},
	TIER_GREAT: {"label": "NICE SHOT!", "color": Color(0.30, 0.96, 0.55), "points": 75, "pitch": 1.18},
	TIER_GOOD: {"label": "GOOD!", "color": Color(0.35, 0.84, 1.0), "points": 45, "pitch": 1.00},
	TIER_OK: {"label": "CLOSE", "color": Color(1.0, 0.78, 0.28), "points": 20, "pitch": 0.78},
	TIER_MISS: {"label": "OFF TARGET", "color": Color(1.0, 0.40, 0.40), "points": 0, "pitch": 0.55}
}


static func get_combo_multiplier(streak: int) -> int:
	if streak >= 6:
		return 4
	if streak >= 4:
		return 3
	if streak >= 2:
		return 2
	return 1


static func _compute_error_ratio(error_value: float, thresholds: Dictionary, diff_mult: float) -> float:
	var p := maxf(0.001, float(thresholds.get("perfect", 5.0)) * diff_mult)
	var gr := maxf(p + 0.001, float(thresholds.get("great", 10.0)) * diff_mult)
	var gd := maxf(gr + 0.001, float(thresholds.get("good", 16.0)) * diff_mult)
	var ok := maxf(gd + 0.001, float(thresholds.get("ok", 23.0)) * diff_mult)

	if error_value <= p:
		return (error_value / p) * 0.35
	if error_value <= gr:
		return 0.35 + ((error_value - p) / (gr - p)) * 0.30
	if error_value <= gd:
		return 0.65 + ((error_value - gr) / (gd - gr)) * 0.35
	if error_value <= ok:
		return 1.00 + ((error_value - gd) / (ok - gd)) * 0.45
	return 1.45 + ((error_value - ok) / ok) * 0.65


static func _tier_from_error_ratio(error_ratio: float) -> String:
	if error_ratio <= 0.35:
		return TIER_PERFECT
	if error_ratio <= 0.65:
		return TIER_GREAT
	if error_ratio <= 1.00:
		return TIER_GOOD
	if error_ratio <= 1.45:
		return TIER_OK
	return TIER_MISS


static func _grade_from_accuracy(avg_accuracy: float) -> String:
	if avg_accuracy >= 88.0:
		return "S"
	if avg_accuracy >= 76.0:
		return "A"
	if avg_accuracy >= 62.0:
		return "B"
	if avg_accuracy >= 46.0:
		return "C"
	return "D"


static func _format_side_dir(side_yds: float) -> String:
	if absf(side_yds) < 1.0:
		return "dead straight"
	return "%.1f yds %s" % [absf(side_yds), "right" if side_yds > 0.0 else "left"]


static func _to_float(v, default_val: float = 0.0) -> float:
	if v == null:
		return default_val
	return float(v)


static func evaluate_shot(
	drill: Dictionary,
	shot_metrics: Dictionary,
	stage_target: Dictionary,
	session_history: Array,
	difficulty: String = "standard",
	handedness: int = 0
) -> Dictionary:
	var visual_mode := str(stage_target.get("mode", drill.get("visual_mode", "corridor")))
	var thresholds: Dictionary = stage_target.get("thresholds", drill.get("thresholds", {"perfect": 5.0, "great": 10.0, "good": 16.0, "ok": 23.0}))
	var diff_mult := Catalog.get_difficulty_multiplier(difficulty)
	var hand_sign := -1.0 if handedness == 1 else 1.0 # +1 => RH, -1 => LH

	var carry_yds := _to_float(shot_metrics.get("carry_yds"), 0.0)
	var total_yds := _to_float(shot_metrics.get("total_yds"), carry_yds)
	var side_yds := _to_float(shot_metrics.get("side_yds"), 0.0) # +Right / -Left
	var vla_deg := _to_float(shot_metrics.get("vla_deg"), 18.0)
	var smash := _to_float(shot_metrics.get("smash_factor"), 0.0)
	var ball_speed := _to_float(shot_metrics.get("ball_speed_mph"), 0.0)
	var club_speed := _to_float(shot_metrics.get("club_speed_mph"), 0.0)
	if smash <= 0.25 and club_speed > 5.0 and ball_speed > 5.0:
		smash = ball_speed / club_speed

	var has_ftp := shot_metrics.has("face_to_path_deg") and shot_metrics["face_to_path_deg"] != null
	var ftp_deg := _to_float(shot_metrics.get("face_to_path_deg"), 0.0)
	var has_spin_axis := shot_metrics.has("spin_axis_deg") and shot_metrics["spin_axis_deg"] != null
	var spin_axis_deg := _to_float(shot_metrics.get("spin_axis_deg"), 0.0)

	var target_yds := float(stage_target.get("distance_yds", 150.0))
	var min_carry_yds := float(stage_target.get("min_carry_yds", drill.get("min_carry_yds", 30.0)))
	var ok_scaled := maxf(0.05, float(thresholds.get("ok", 20.0)) * diff_mult)

	var error_value := 0.0
	var signed_bias := 0.0
	var primary_metric_text := ""
	var coaching_detail := ""

	match visual_mode:
		"corridor":
			var shortfall := maxf(0.0, min_carry_yds - carry_yds) * 0.30
			error_value = absf(side_yds) + shortfall
			signed_bias = clampf(side_yds / ok_scaled, -1.0, 1.0)
			primary_metric_text = "%.1f yds offline (%s) | Carry %.0f yds" % [absf(side_yds), "R" if side_yds > 0.0 else ("L" if side_yds < 0.0 else "C"), carry_yds]
			if shortfall > 1.0:
				coaching_detail = "Short carry (%.0f yds) — swing smoothly through to a full finish." % carry_yds
			elif absf(side_yds) <= float(thresholds.get("perfect", 6.0)) * diff_mult:
				coaching_detail = "Laser start line down the middle (%s)!" % _format_side_dir(side_yds)
			else:
				coaching_detail = "Finished %s — keep your clubface square to your target spot." % _format_side_dir(side_yds)

		"slice_corridor":
			var slice_side_err := side_yds * hand_sign # >0 is slice miss side
			var base_off := slice_side_err * 1.35 if slice_side_err > 0.0 else absf(slice_side_err) * 0.90
			if has_ftp:
				var ftp_hand := ftp_deg * hand_sign
				if ftp_hand > 2.5:
					base_off += (ftp_hand - 2.0) * 0.8
				elif ftp_hand <= 1.5 and ftp_hand >= -3.0:
					base_off *= 0.90
			var shortfall_sc := maxf(0.0, min_carry_yds - carry_yds) * 0.25
			error_value = maxf(0.0, base_off + shortfall_sc)
			signed_bias = clampf(slice_side_err / ok_scaled, -1.0, 1.0)
			primary_metric_text = "%s (%s)" % [_format_side_dir(side_yds), "Slice Side" if slice_side_err > 2.0 else "Controlled"]
			if slice_side_err > float(thresholds.get("great", 10.5)) * diff_mult:
				coaching_detail = "Drifted to your slice side (%.1f yds) — tuck your trail elbow and release the toe!" % absf(side_yds)
			elif slice_side_err <= float(thresholds.get("perfect", 5.5)) * diff_mult and slice_side_err >= -6.0:
				coaching_detail = "Pure neutral/draw release — zero slice!"
			else:
				coaching_detail = "Solid anti-slice swing! Keep feeling that inside-out release."

		"hook_corridor":
			var hook_side_err := -side_yds * hand_sign # >0 is hook miss side
			var base_off_h := hook_side_err * 1.35 if hook_side_err > 0.0 else absf(hook_side_err) * 0.90
			if has_ftp:
				var ftp_hand_h := -ftp_deg * hand_sign # >0 is closed face-to-path
				if ftp_hand_h > 2.5:
					base_off_h += (ftp_hand_h - 2.0) * 0.8
				elif ftp_hand_h <= 1.5 and ftp_hand_h >= -3.0:
					base_off_h *= 0.90
			var shortfall_hk := maxf(0.0, min_carry_yds - carry_yds) * 0.25
			error_value = maxf(0.0, base_off_h + shortfall_hk)
			signed_bias = clampf(-hook_side_err / ok_scaled, -1.0, 1.0)
			primary_metric_text = "%s (%s)" % [_format_side_dir(side_yds), "Hook Side" if hook_side_err > 2.0 else "Neutral"]
			if hook_side_err > float(thresholds.get("great", 10.5)) * diff_mult:
				coaching_detail = "Over-rotated to your hook side (%.1f yds) — turn your chest through impact!" % absf(side_yds)
			else:
				coaching_detail = "Balanced path and held-off release — flight stayed clean!"

		"bullseye", "bullseye_ladder", "bullseye_random", "dispersion_circle":
			var dist_ref := total_yds if visual_mode == "bullseye_ladder" and total_yds > 0.0 else carry_yds
			if shot_metrics.has("dist_to_target_yds") and shot_metrics["dist_to_target_yds"] != null:
				error_value = _to_float(shot_metrics["dist_to_target_yds"])
			else:
				var depth_err := dist_ref - target_yds
				error_value = sqrt(depth_err * depth_err + side_yds * side_yds)
			var depth_bias := dist_ref - target_yds
			signed_bias = clampf(depth_bias / ok_scaled, -1.0, 1.0)
			primary_metric_text = "%.1f yds from pin | Carry %.0f / %d yds" % [error_value, carry_yds, int(target_yds)]
			var short_long := "short" if depth_bias < -1.5 else ("long" if depth_bias > 1.5 else "pin-high")
			coaching_detail = "Finished %.1f yds %s and %s." % [absf(depth_bias), short_long, _format_side_dir(side_yds)]

		"launch_window":
			var club_code := str(stage_target.get("club", drill.get("recommended_club", "7i")))
			var win := Catalog.get_optimal_vla_window(club_code)
			var min_v := float(stage_target.get("min_vla_deg", win["min"]))
			var max_v := float(stage_target.get("max_vla_deg", win["max"]))
			var ideal_v := float(stage_target.get("ideal_vla_deg", win["ideal"]))
			var vla_err := 0.0
			if vla_deg < min_v:
				vla_err = (min_v - vla_deg) + 1.0
			elif vla_deg > max_v:
				vla_err = (vla_deg - max_v) + 1.0
			else:
				vla_err = absf(vla_deg - ideal_v) * 0.55
			var off_pen := maxf(0.0, absf(side_yds) - 12.0) * 0.12
			error_value = vla_err + off_pen
			signed_bias = clampf((vla_deg - ideal_v) / ok_scaled, -1.0, 1.0)
			primary_metric_text = "Launch %.1f° (Window %.0f°–%.0f°)" % [vla_deg, min_v, max_v]
			if vla_deg < min_v:
				coaching_detail = "Launched too low (%.1f°) — avoid leaning ahead; sweep cleanly." % vla_deg
			elif vla_deg > max_v:
				coaching_detail = "Launched too high (%.1f°) — keep hands ahead of the ball through impact." % vla_deg
			else:
				coaching_detail = "Right through the sky window (%.1f° launch)!" % vla_deg

		"compression_corridor":
			var club_c := str(stage_target.get("club", drill.get("recommended_club", "7i")))
			var exp_smash := Catalog.get_expected_smash(club_c)
			if smash > 0.35:
				var deficit := maxf(0.0, exp_smash - smash)
				var off_p := maxf(0.0, absf(side_yds) - 14.0) * 0.003
				error_value = deficit + off_p
				signed_bias = clampf((smash - exp_smash) / ok_scaled, -1.0, 1.0)
				primary_metric_text = "Smash %.2f (Target %.2f) | %s" % [smash, exp_smash, _format_side_dir(side_yds)]
				if deficit <= float(thresholds.get("perfect", 0.03)) * diff_mult:
					coaching_detail = "Pure Tour-grade compression (%.2f smash)!" % smash
				else:
					coaching_detail = "Lost %.2f smash efficiency — focus on ball-first contact at 80%% tempo." % deficit
			else:
				# Fallback when launch monitor doesn't report club speed
				var ref_carry := float(stage_target.get("target_carry_yds", Catalog.get_default_club_carry_yds(club_c)))
				var carry_ratio_err := maxf(0.0, (ref_carry - carry_yds) / maxf(1.0, ref_carry))
				var off_ratio_err := maxf(0.0, absf(side_yds) - 10.0) * 0.004
				error_value = carry_ratio_err + off_ratio_err
				signed_bias = clampf((carry_yds - ref_carry) / (ref_carry * 0.18), -1.0, 1.0)
				primary_metric_text = "Carry %.0f yds (Target %.0f yds) | %s" % [carry_yds, ref_carry, _format_side_dir(side_yds)]
				if carry_yds >= ref_carry * 0.96:
					coaching_detail = "Crisp energy transfer — strong carry on target!"
				else:
					coaching_detail = "Carry dropped to %.0f yds — center the strike on the clubface." % carry_yds

		"shape_gate":
			var req_shape := str(stage_target.get("shape", "draw")) # "draw" or "fade"
			var shape_offset_yds := float(stage_target.get("shape_offset_yds", 12.0))
			# Draw curves left (-Z) for RH, right (+Z) for LH; Fade is opposite
			var desired_sign := (-1.0 if req_shape == "draw" else 1.0) * hand_sign
			var target_z_yds := desired_sign * shape_offset_yds
			var depth_e := carry_yds - target_yds
			var lat_e := side_yds - target_z_yds
			var curve_penalty := 0.0
			var curved_right_way := (spin_axis_deg * desired_sign > 1.5) if has_spin_axis else (side_yds * desired_sign > 2.0)
			if not curved_right_way and absf(side_yds) > 3.0 and (side_yds * desired_sign < -2.0):
				curve_penalty = 6.5
			error_value = sqrt(depth_e * depth_e + lat_e * lat_e) + curve_penalty
			signed_bias = clampf(lat_e / ok_scaled, -1.0, 1.0)
			primary_metric_text = "%s Target: %.1f yds away (%s)" % [req_shape.capitalize(), error_value, _format_side_dir(side_yds)]
			if curve_penalty > 0.0:
				coaching_detail = "Ball missed away from the %s target — align stance to curve it in!" % req_shape
			elif error_value <= float(thresholds.get("great", 10.5)) * diff_mult:
				coaching_detail = "Sweet %s shape right into the target window!" % req_shape
			else:
				coaching_detail = "Good %s shape attempt — dial in start line through the gate." % req_shape

		_:
			error_value = absf(side_yds)
			signed_bias = clampf(side_yds / ok_scaled, -1.0, 1.0)
			primary_metric_text = "%.1f yds offline" % absf(side_yds)
			coaching_detail = _format_side_dir(side_yds)

	var error_ratio := _compute_error_ratio(error_value, thresholds, diff_mult)
	var tier := _tier_from_error_ratio(error_ratio)
	var tier_info: Dictionary = TIER_DISPLAY[tier]
	var accuracy_score := clampi(int(round(100.0 - error_ratio * 56.0)), 0, 100)
	if tier == TIER_PERFECT:
		accuracy_score = clampi(int(round(100.0 - (error_ratio / 0.35) * 9.0)), 91, 100)

	# Combo streak calculation
	var prev_streak := 0
	if not session_history.is_empty():
		prev_streak = int(session_history[session_history.size() - 1].get("streak_after", 0))

	var new_streak := prev_streak
	if tier in [TIER_PERFECT, TIER_GREAT, TIER_GOOD]:
		new_streak = prev_streak + 1
	elif tier == TIER_MISS:
		new_streak = 0
	# TIER_OK holds streak steady without resetting

	var multiplier := get_combo_multiplier(new_streak)
	var points_awarded := int(tier_info["points"]) * multiplier

	# Shot-to-shot trend callout
	var trend_info := _compute_trend_callout(tier, error_ratio, session_history, new_streak)

	return {
		"tier": tier,
		"tier_label": str(tier_info["label"]),
		"tier_color": tier_info["color"],
		"audio_pitch": float(tier_info["pitch"]),
		"points_awarded": points_awarded,
		"multiplier": multiplier,
		"streak_after": new_streak,
		"accuracy_score": accuracy_score,
		"error_value": snappedf(error_value, 0.01),
		"error_ratio": snappedf(error_ratio, 0.001),
		"signed_bias": snappedf(signed_bias, 0.001),
		"trend_type": str(trend_info["type"]),
		"trend_text": str(trend_info["text"]),
		"trend_color": trend_info["color"],
		"primary_metric_text": primary_metric_text,
		"coaching_detail": coaching_detail,
		"carry_yds": carry_yds,
		"total_yds": total_yds,
		"side_yds": side_yds
	}


static func _compute_trend_callout(tier: String, error_ratio: float, session_history: Array, new_streak: int) -> Dictionary:
	if session_history.is_empty():
		if tier == TIER_PERFECT:
			return {"type": "much_closer", "text": "🎯 PURE START! Dead on target!", "color": Color(1.0, 0.85, 0.25)}
		if tier in [TIER_GREAT, TIER_GOOD]:
			return {"type": "steady_good", "text": "✅ STRONG OPENER! Build a combo streak!", "color": Color(0.35, 0.95, 0.55)}
		return {"type": "first", "text": "📏 BASELINE SET — dial the next swing closer!", "color": Color(0.75, 0.85, 0.96)}

	var prev: Dictionary = session_history[session_history.size() - 1]
	var prev_ratio := float(prev.get("error_ratio", error_ratio))
	var delta := error_ratio - prev_ratio

	# Consecutive perfects
	var consec_perfect := 1 if tier == TIER_PERFECT else 0
	if consec_perfect > 0:
		for i in range(session_history.size() - 1, -1, -1):
			if str(session_history[i].get("tier", "")) == TIER_PERFECT:
				consec_perfect += 1
			else:
				break
	if consec_perfect >= 2:
		return {
			"type": "perfect_streak",
			"text": "🔥 ON FIRE! %d Perfects in a row!" % consec_perfect,
			"color": Color(1.0, 0.88, 0.25)
		}

	if tier == TIER_PERFECT:
		return {
			"type": "much_closer",
			"text": "🎯 PURE PERFECTION! Dead in the sweet spot!",
			"color": Color(1.0, 0.88, 0.25)
		}

	if delta <= -0.15:
		return {
			"type": "much_closer",
			"text": "🔥 GETTING MUCH CLOSER! Big jump from last shot!",
			"color": Color(0.30, 0.98, 0.55)
		}

	if delta <= -0.05:
		return {
			"type": "closer",
			"text": "📈 GETTING CLOSER! Dialing right into the zone!",
			"color": Color(0.35, 0.90, 0.72)
		}

	var prev_drifted_worse := false
	if session_history.size() >= 2:
		var prev2: Dictionary = session_history[session_history.size() - 2]
		if prev_ratio - float(prev2.get("error_ratio", prev_ratio)) >= 0.08:
			prev_drifted_worse = true

	if delta >= 0.14 and prev_drifted_worse:
		return {
			"type": "drifting_worse",
			"text": "⚠️ DRIFTING FURTHER AWAY — pause, breathe & swing at 80%!",
			"color": Color(1.0, 0.42, 0.42)
		}

	if delta >= 0.12:
		return {
			"type": "further_away",
			"text": "⚠️ GETTING FURTHER AWAY — check alignment & tempo!",
			"color": Color(1.0, 0.68, 0.28)
		}

	if tier in [TIER_GREAT, TIER_GOOD]:
		var combo_note := " (%dx streak!)" % new_streak if new_streak >= 3 else ""
		return {
			"type": "steady_good",
			"text": "✅ LOCKED IN! Staying right inside the target%s" % combo_note,
			"color": Color(0.35, 0.86, 1.0)
		}

	return {
		"type": "steady_miss",
		"text": "🔄 STILL OUTSIDE — make one small adjustment next swing!",
		"color": Color(1.0, 0.78, 0.35)
	}


static func compute_session_summary(drill: Dictionary, results: Array) -> Dictionary:
	var tier_counts := {
		TIER_PERFECT: 0,
		TIER_GREAT: 0,
		TIER_GOOD: 0,
		TIER_OK: 0,
		TIER_MISS: 0
	}
	if results.is_empty():
		return {
			"total_score": 0,
			"avg_accuracy": 0.0,
			"grade": "D",
			"max_streak": 0,
			"tier_counts": tier_counts,
			"first_half_avg": 0.0,
			"second_half_avg": 0.0,
			"improvement_delta": 0.0,
			"trend_summary": "No shots recorded.",
			"next_step_tip": str(drill.get("coaching_cue", ""))
		}

	var total_score := 0
	var acc_sum := 0.0
	var max_streak := 0
	var mid := int(ceil(float(results.size()) * 0.5))
	var first_sum := 0.0
	var first_cnt := 0
	var second_sum := 0.0
	var second_cnt := 0

	for i in range(results.size()):
		var r: Dictionary = results[i]
		total_score += int(r.get("points_awarded", 0))
		var acc := float(r.get("accuracy_score", 0.0))
		acc_sum += acc
		max_streak = maxi(max_streak, int(r.get("streak_after", 0)))
		var t := str(r.get("tier", TIER_MISS))
		tier_counts[t] = int(tier_counts.get(t, 0)) + 1
		if i < mid:
			first_sum += acc
			first_cnt += 1
		else:
			second_sum += acc
			second_cnt += 1

	var avg_acc := acc_sum / float(results.size())
	var first_avg := first_sum / float(maxi(1, first_cnt))
	var second_avg := second_sum / float(maxi(1, second_cnt)) if second_cnt > 0 else first_avg
	var imp_delta := second_avg - first_avg
	var grade := _grade_from_accuracy(avg_acc)

	var trend_summary := ""
	if results.size() < 2:
		trend_summary = "Complete a full drill to measure mid-session progression."
	elif imp_delta >= 7.0:
		trend_summary = "📈 Strong Finish! Improved +%.0f%% accuracy in the second half." % imp_delta
	elif imp_delta <= -7.0:
		trend_summary = "⚠️ Fatigue or tempo drift late (%.0f%% drop) — try fewer, more deliberate swings." % imp_delta
	else:
		trend_summary = "✅ Steady Execution! Held within %.0f%% from start to finish." % absf(imp_delta)

	var next_tip := str(drill.get("coaching_cue", ""))
	if grade in ["S", "A"]:
		next_tip = "Great command! Try stepping up a difficulty tier or moving to the next recommended drill."

	return {
		"total_score": total_score,
		"avg_accuracy": snappedf(avg_acc, 0.1),
		"grade": grade,
		"max_streak": max_streak,
		"tier_counts": tier_counts,
		"first_half_avg": snappedf(first_avg, 0.1),
		"second_half_avg": snappedf(second_avg, 0.1),
		"improvement_delta": snappedf(imp_delta, 0.1),
		"trend_summary": trend_summary,
		"next_step_tip": next_tip
	}
