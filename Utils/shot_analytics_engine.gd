class_name ShotAnalyticsEngine
extends RefCounted

## ShotAnalyticsEngine
## Unified multi-shot analytics, covariance geometry, D-plane classification,
## bag gapping, distance-loss decomposition, micro-milestone coaching, and live range drill evaluator.

const GolfSwingAnalyzer = preload("res://UI/GolferCamera/golf_swing_analyzer.gd")

const BAG_SORT_ORDER: Array[String] = [
	"Dr", "3w", "5w", "7w", "2H", "3H", "4H", "5H",
	"1i", "2i", "3i", "4i", "5i", "6i", "7i", "8i", "9i",
	"Pw", "Gw", "Sw", "Lw"
]


static func _parse_float(raw: Dictionary, keys: Array, fallback: float = NAN) -> float:
	for k in keys:
		if raw.has(k) and raw[k] != null:
			var val = raw[k]
			if typeof(val) == TYPE_INT or typeof(val) == TYPE_FLOAT:
				var f = float(val)
				if not is_nan(f):
					return f
			else:
				var s := str(val).strip_edges()
				if s.is_empty() or s in ["---", "N/A", "n/a", "nan"]:
					continue
				var clean := s.split(" ")[0].replace("+", "").replace("°", "")
				if clean.is_valid_float():
					return float(clean)
	return fallback


static func normalize_shot(raw: Dictionary, index: int = 0) -> Dictionary:
	var club := str(raw.get("club", raw.get("Club", ""))).strip_edges()
	var t := int(raw.get("t", raw.get("timestamp", index)))

	var carry_yds: float = 0.0
	if raw.has("carry_yds"):
		carry_yds = float(raw["carry_yds"])
	else:
		var carry_m := _parse_float(raw, ["CarryDistance", "Carry", "c", "carry_m"], 0.0)
		carry_yds = maxf(0.0, carry_m * 1.09361)

	var total_yds: float = carry_yds
	if raw.has("total_yds"):
		total_yds = float(raw["total_yds"])
	else:
		var total_m := _parse_float(raw, ["TotalDistance", "Distance", "tot", "total_m"], -1.0)
		if total_m >= 0.0:
			total_yds = maxf(0.0, total_m * 1.09361)

	var rollout_yds := maxf(0.0, total_yds - carry_yds)
	if raw.has("rollout_yds"):
		rollout_yds = maxf(0.0, float(raw["rollout_yds"]))
	elif raw.has("Rollout"):
		rollout_yds = maxf(0.0, float(raw["Rollout"]) * 1.09361)

	var signed_offline_yds: float = 0.0
	if raw.has("offline_yds"):
		signed_offline_yds = float(raw["offline_yds"])
	else:
		var side_m := _parse_float(raw, ["SideDistance", "Offline", "sd"], 0.0)
		if absf(side_m) < 0.001 and raw.has("tracer_points") and raw["tracer_points"] is Array:
			var pts: Array = raw["tracer_points"]
			if pts.size() >= 2 and pts[0] is Vector3 and pts[-1] is Vector3:
				side_m = (pts[-1] as Vector3).z - (pts[0] as Vector3).z
		signed_offline_yds = side_m * 1.09361

	var ball_speed := _parse_float(raw, ["BallSpeed", "Speed", "bs", "ball_speed_mph"], 0.0)
	var club_speed := _parse_float(raw, ["ClubSpeed", "cs", "club_speed_mph"], 0.0)
	var smash := _parse_float(raw, ["SmashFactor", "sf", "smash"], 0.0)
	if smash <= 0.1 and club_speed > 5.0 and ball_speed > 5.0:
		smash = ball_speed / club_speed

	var face_angle := _parse_float(raw, ["RawFaceAngle", "FaceAngle", "ClubFaceAngle", "fa"], NAN)
	if is_nan(face_angle) and (raw.has("FaceAngle") or raw.has("ClubFaceAngle")):
		var fa_str := str(raw.get("FaceAngle", raw.get("ClubFaceAngle", ""))).strip_edges()
		var clean_fa := fa_str.replace("O", "").replace("C", "").replace("Sq", "").strip_edges()
		if clean_fa.is_valid_float():
			face_angle = -absf(float(clean_fa)) if fa_str.to_upper().ends_with("C") else float(clean_fa)

	var club_path := _parse_float(raw, ["RawClubPath", "ClubPath", "Path", "cp"], NAN)
	if is_nan(club_path) and (raw.has("ClubPath") or raw.has("Path")):
		var cp_str := str(raw.get("ClubPath", raw.get("Path", ""))).strip_edges()
		var clean_cp := cp_str.replace("I-O", "").replace("O-I", "").replace("In-Out", "").replace("Out-In", "").replace("Str", "").strip_edges()
		if clean_cp.is_valid_float():
			var is_oi := ("O-I" in cp_str.to_upper()) or ("OUT-IN" in cp_str.to_upper())
			club_path = -absf(float(clean_cp)) if is_oi else float(clean_cp)

	var ftp := _parse_float(raw, ["RawFaceToPath", "FaceToPath", "ftp"], NAN)
	if is_nan(ftp) and not is_nan(face_angle) and not is_nan(club_path):
		ftp = face_angle - club_path

	var aoa := _parse_float(raw, ["AttackAngle", "AngleOfAttack", "aoa", "attack_angle"], NAN)
	var dyn_loft := _parse_float(raw, ["DynamicLoft", "dynamic_loft"], NAN)
	var spin_loft := (dyn_loft - aoa) if (not is_nan(dyn_loft) and not is_nan(aoa)) else NAN

	var vla := _parse_float(raw, ["VLA", "VerticalLaunchAngle", "LaunchAngle", "vla"], NAN)
	var hla := _parse_float(raw, ["HLA", "HorizontalLaunchAngle", "hla"], NAN)
	var total_spin := _parse_float(raw, ["TotalSpin", "sp", "spin_rpm"], 0.0)
	var back_spin := _parse_float(raw, ["BackSpin", "back_spin"], NAN)
	var side_spin := _parse_float(raw, ["SideSpin", "side_spin"], NAN)
	var spin_axis := _parse_float(raw, ["SpinAxis", "SideSpinAxis", "spin_axis"], NAN)
	if is_nan(spin_axis) and not is_nan(back_spin) and back_spin > 0.0 and not is_nan(side_spin):
		spin_axis = rad_to_deg(atan2(side_spin, back_spin))

	var apex_ft := _parse_float(raw, ["apex_ft"], NAN)
	if is_nan(apex_ft):
		var apex_m := _parse_float(raw, ["Apex", "apex", "PeakHeight", "MaxHeight"], NAN)
		if not is_nan(apex_m) and apex_m > 0.0:
			apex_ft = apex_m * 3.28084

	var descent_angle := _parse_float(raw, ["DescentAngle", "descent_angle", "landing_angle", "LandAngle"], NAN)
	var hi := _parse_float(raw, ["HorizontalFaceImpact", "hi", "impact_offset_horizontal"], NAN)
	var vi := _parse_float(raw, ["VerticalFaceImpact", "vi", "impact_offset_vertical"], NAN)
	var impact_offset_mm := Vector2(hi, vi).length() if (not is_nan(hi) and not is_nan(vi)) else NAN

	return {
		"index": index + 1,
		"t": t,
		"club": club,
		"carry_yds": snapped(carry_yds, 0.1),
		"total_yds": snapped(total_yds, 0.1),
		"rollout_yds": snapped(rollout_yds, 0.1),
		"signed_offline_yds": snapped(signed_offline_yds, 0.1),
		"abs_offline_yds": snapped(absf(signed_offline_yds), 0.1),
		"ball_speed": ball_speed if ball_speed > 0.0 else NAN,
		"club_speed": club_speed if club_speed > 0.0 else NAN,
		"smash": smash if smash > 0.1 else NAN,
		"face_angle": face_angle,
		"club_path": club_path,
		"face_to_path": ftp,
		"aoa": aoa,
		"dynamic_loft": dyn_loft,
		"spin_loft": spin_loft,
		"vla": vla,
		"hla": hla,
		"total_spin": total_spin if total_spin > 0.0 else NAN,
		"back_spin": back_spin,
		"side_spin": side_spin,
		"spin_axis": spin_axis,
		"apex_ft": apex_ft,
		"descent_angle": descent_angle,
		"hi": hi,
		"vi": vi,
		"impact_offset_mm": impact_offset_mm
	}


static func get_target_corridor_yards(club_name: String, avg_carry_yds: float = 0.0) -> float:
	var raw := club_name.strip_edges().to_lower()
	if raw.is_empty() or raw == "all":
		if avg_carry_yds > 0.0:
			return clampf(roundf(avg_carry_yds * 0.065), 5.0, 16.0)
		return 12.0
	var key: String = GolfSwingAnalyzer._classify_club_discrete(raw)
	match key:
		"driver":
			return 15.0
		"3w", "5w", "hybrid":
			return 12.0
		"4i", "5i":
			return 10.0
		"6i", "7i", "8i":
			return 8.0
		_:
			return 6.0


static func classify_ball_flight(face_angle: float, club_path: float, face_to_path: float, is_lefty: bool = false) -> Dictionary:
	var has_fa := not is_nan(face_angle)
	var has_cp := not is_nan(club_path)
	var ftp := face_to_path
	if is_nan(ftp) and has_fa and has_cp:
		ftp = face_angle - club_path

	var start_metric := 0.0
	if has_fa:
		start_metric = (face_angle * 0.8 + club_path * 0.2) if has_cp else face_angle
	var curve_metric := 0.0 if is_nan(ftp) else ftp

	var start_class := "straight"
	if start_metric > 1.2:
		start_class = "push"
	elif start_metric < -1.2:
		start_class = "pull"

	var curve_class := "straight"
	if curve_metric > 1.2:
		curve_class = "fade"
	elif curve_metric < -1.2:
		curve_class = "draw"

	var shape := "Straight"
	if start_class == "pull" and curve_class == "draw":
		shape = "Pull-Hook"
	elif start_class == "pull" and curve_class == "straight":
		shape = "Straight-Pull"
	elif start_class == "pull" and curve_class == "fade":
		shape = "Pull-Fade"
	elif start_class == "straight" and curve_class == "draw":
		shape = "Straight-Draw"
	elif start_class == "straight" and curve_class == "straight":
		shape = "Straight"
	elif start_class == "straight" and curve_class == "fade":
		shape = "Straight-Fade"
	elif start_class == "push" and curve_class == "draw":
		shape = "Push-Draw"
	elif start_class == "push" and curve_class == "straight":
		shape = "Straight-Push"
	elif start_class == "push" and curve_class == "fade":
		shape = "Push-Slice"

	var start_dir := "Center"
	if start_class == "push":
		start_dir = "Left" if is_lefty else "Right"
	elif start_class == "pull":
		start_dir = "Right" if is_lefty else "Left"

	var curve_dir := "Straight"
	if curve_class == "fade":
		curve_dir = "Left" if is_lefty else "Right"
	elif curve_class == "draw":
		curve_dir = "Right" if is_lefty else "Left"

	var abs_ftp := absf(curve_metric)
	var abs_start := absf(start_metric)
	var is_functional_stock := (
		abs_ftp <= 2.8 and abs_start <= 4.0 and
		(shape in ["Straight", "Push-Draw", "Pull-Fade"] or (abs_ftp <= 2.0 and abs_start <= 1.8))
	)

	return {
		"shape": shape,
		"start_dir": start_dir,
		"curve_dir": curve_dir,
		"is_functional_stock": is_functional_stock
	}


static func compute_covariance_ellipse(points: Array[Vector2]) -> Dictionary:
	if points.size() < 2:
		return {
			"valid": false,
			"mean": points[0] if points.size() == 1 else Vector2.ZERO,
			"std_major": 0.0,
			"std_minor": 0.0,
			"rx80": 0.0,
			"ry80": 0.0,
			"rx95": 0.0,
			"ry95": 0.0,
			"angle_rad": 0.0,
			"area_yd2": 0.0
		}

	var n := float(points.size())
	var mean := Vector2.ZERO
	for p in points:
		mean += p
	mean /= n

	var cxx := 0.0
	var cyy := 0.0
	var cxy := 0.0
	for p in points:
		var dx := p.x - mean.x
		var dy := p.y - mean.y
		cxx += dx * dx
		cyy += dy * dy
		cxy += dx * dy
	cxx /= n
	cyy /= n
	cxy /= n

	var trace := cxx + cyy
	var diff := sqrt(pow(cxx - cyy, 2.0) + 4.0 * cxy * cxy)
	var lambda1 := maxf(0.0, (trace + diff) * 0.5)
	var lambda2 := maxf(0.0, (trace - diff) * 0.5)

	var std_major := sqrt(lambda1)
	var std_minor := sqrt(lambda2)
	var angle_rad := 0.0 if (absf(cxy) < 1e-9 and absf(cxx - cyy) < 1e-9) else 0.5 * atan2(2.0 * cxy, cxx - cyy)

	var rx80: float = snappedf(std_major * 1.7941, 0.1)
	var ry80: float = snappedf(std_minor * 1.7941, 0.1)
	var rx95: float = snappedf(std_major * 2.4477, 0.1)
	var ry95: float = snappedf(std_minor * 2.4477, 0.1)
	var area_yd2: float = snappedf(PI * rx80 * ry80, 0.1)

	return {
		"valid": true,
		"mean": mean,
		"std_major": snapped(std_major, 0.1),
		"std_minor": snapped(std_minor, 0.1),
		"rx80": rx80,
		"ry80": ry80,
		"rx95": rx95,
		"ry95": ry95,
		"angle_rad": angle_rad,
		"area_yd2": area_yd2
	}


static func compute_distance_loss_breakdown(summary: Dictionary, club_name: String, skill_level: String = "mid_handicap") -> Dictionary:
	var avg_carry := float(summary.get("avg_carry_yds", 0.0))
	if avg_carry <= 0.0:
		return {
			"has_data": false,
			"potential_carry_yds": 0.0,
			"total_lost_yds": 0.0,
			"smash_loss_yds": 0.0,
			"launch_spin_loss_yds": 0.0,
			"curve_loss_yds": 0.0,
			"top_opportunity": "Insufficient Data"
		}

	var eff_club := club_name if (not club_name.is_empty() and club_name.to_lower() != "all") else "Driver"
	var norm_skill: String = GolfSwingAnalyzer.normalize_skill_level(skill_level)
	var bench: Dictionary = GolfSwingAnalyzer.get_benchmark(eff_club, norm_skill)
	var ref_bench: Dictionary = GolfSwingAnalyzer.get_benchmark(eff_club, "scratch")
	var mid_ref_carry := (float(ref_bench.get("carry_min", 245.0)) + float(ref_bench.get("carry_max", 265.0))) * 0.5
	var mid_ref_ball := (float(ref_bench.get("ball_speed_min", 150.0)) + float(ref_bench.get("ball_speed_max", 160.0))) * 0.5
	var carry_per_mph := mid_ref_carry / mid_ref_ball if mid_ref_ball > 0.0 else 1.55

	var avg_smash := float(summary.get("avg_smash", NAN))
	var avg_cs := float(summary.get("avg_club_speed", NAN))
	var avg_bs := float(summary.get("avg_ball_speed", NAN))
	var opt_smash := maxf(float(bench.get("smash_max", 1.46)), 0.0 if is_nan(avg_smash) else avg_smash)

	var potential_carry := avg_carry
	var smash_loss := 0.0
	if not is_nan(avg_cs) and avg_cs > 20.0:
		var pot_bs := avg_cs * opt_smash
		potential_carry = maxf(avg_carry, pot_bs * carry_per_mph)
		var actual_bs := avg_bs if (not is_nan(avg_bs) and avg_bs > 15.0) else avg_cs * (opt_smash if is_nan(avg_smash) else avg_smash)
		smash_loss = maxf(0.0, pot_bs - actual_bs) * carry_per_mph
	elif not is_nan(avg_bs) and avg_bs > 20.0:
		potential_carry = maxf(avg_carry, avg_bs * carry_per_mph)

	var avg_ftp := float(summary.get("avg_abs_ftp", NAN))
	var avg_axis := float(summary.get("avg_spin_axis", NAN))
	var abs_curve := avg_ftp if not is_nan(avg_ftp) else (absf(avg_axis) / 2.2 if not is_nan(avg_axis) else 0.0)
	var curve_loss := maxf(0.0, (abs_curve - 2.5) * 1.6)

	var launch_spin_loss := 0.0
	var avg_vla := float(summary.get("avg_vla", NAN))
	var avg_spin := float(summary.get("avg_spin", NAN))
	if not is_nan(avg_vla):
		var vmin := float(bench.get("vla_min", 12.0))
		var vmax := float(bench.get("vla_max", 15.5))
		if avg_vla < vmin:
			launch_spin_loss += (vmin - avg_vla) * 1.4
		elif avg_vla > vmax:
			launch_spin_loss += (avg_vla - vmax) * 1.1
	if not is_nan(avg_spin):
		var spmin := float(bench.get("spin_min", 2400.0))
		var spmax := float(bench.get("spin_max", 3200.0))
		if avg_spin > spmax + 200.0:
			launch_spin_loss += ((avg_spin - spmax) / 500.0) * 3.5
		elif avg_spin < spmin - 300.0:
			launch_spin_loss += ((spmin - avg_spin) / 500.0) * 3.0

	var total_gap := maxf(0.0, potential_carry - avg_carry)
	if total_gap > 0.0:
		smash_loss = minf(smash_loss, total_gap)
		var rem := maxf(0.0, total_gap - smash_loss)
		curve_loss = minf(curve_loss, rem)
		launch_spin_loss = maxf(0.0, rem - curve_loss)
	else:
		smash_loss = 0.0
		curve_loss = 0.0
		launch_spin_loss = 0.0

	var sm_r: float = snappedf(smash_loss, 0.1)
	var ls_r: float = snappedf(launch_spin_loss, 0.1)
	var cv_r: float = snappedf(curve_loss, 0.1)
	var total_lost: float = snappedf(sm_r + ls_r + cv_r, 0.1)

	var top_opp := "Optimized Carry"
	if total_lost >= 2.0:
		if sm_r >= ls_r and sm_r >= cv_r:
			top_opp = "Strike Efficiency (Smash)"
		elif ls_r >= cv_r:
			top_opp = "Launch & Spin Window"
		else:
			top_opp = "Curvature Control"

	return {
		"has_data": true,
		"potential_carry_yds": snapped(avg_carry + total_lost, 0.1),
		"total_lost_yds": total_lost,
		"smash_loss_yds": sm_r,
		"launch_spin_loss_yds": ls_r,
		"curve_loss_yds": cv_r,
		"top_opportunity": top_opp
	}


static func _summarize_normalized(shots: Array[Dictionary], club_name: String, skill_level: String, is_lefty: bool) -> Dictionary:
	var n := shots.size()
	if n == 0:
		return {"count": 0, "corridor_yds": get_target_corridor_yards(club_name, 0.0)}

	var carry_vals: Array[float] = []
	var carry_sum := 0.0
	for s in shots:
		var c := float(s["carry_yds"])
		if c > 0.0:
			carry_vals.append(c)
			carry_sum += c
	var prelim_carry := carry_sum / carry_vals.size() if not carry_vals.is_empty() else 0.0
	var corridor_yds := get_target_corridor_yards(club_name, prelim_carry)

	var abs_off_sum := 0.0
	var signed_off_sum := 0.0
	var off_vals: Array[float] = []
	var in_corridor := 0
	var left_cnt := 0
	var right_cnt := 0
	var total_sum := 0.0
	var total_cnt := 0
	var roll_sum := 0.0

	var bs_sum := 0.0; var bs_cnt := 0
	var cs_sum := 0.0; var cs_cnt := 0
	var sm_sum := 0.0; var sm_cnt := 0
	var fa_abs := 0.0; var fa_sig := 0.0; var fa_vals: Array[float] = []
	var cp_abs := 0.0; var cp_sig := 0.0; var cp_vals: Array[float] = []
	var ftp_abs := 0.0; var ftp_sig := 0.0; var ftp_vals: Array[float] = []
	var vla_sum := 0.0; var vla_cnt := 0
	var hla_sum := 0.0; var hla_cnt := 0
	var aoa_sum := 0.0; var aoa_cnt := 0
	var dl_sum := 0.0; var dl_cnt := 0
	var sl_sum := 0.0; var sl_cnt := 0
	var sp_sum := 0.0; var sp_cnt := 0
	var sa_sum := 0.0; var sa_cnt := 0
	var ap_sum := 0.0; var ap_cnt := 0
	var da_sum := 0.0; var da_cnt := 0
	var hi_sum := 0.0; var vi_sum := 0.0; var hivi_cnt := 0
	var imp_sum := 0.0; var imp_cnt := 0

	var start_mag := 0.0; var curve_mag := 0.0; var attr_cnt := 0
	var flight_counts: Dictionary = {}
	var total_classified := 0
	var stock_cnt := 0
	var ell_pts: Array[Vector2] = []

	for s in shots:
		var so := float(s["signed_offline_yds"])
		var ao := float(s["abs_offline_yds"])
		abs_off_sum += ao
		signed_off_sum += so
		off_vals.append(so)
		if ao <= corridor_yds:
			in_corridor += 1
		elif so < -corridor_yds:
			left_cnt += 1
		else:
			right_cnt += 1

		var cy := float(s["carry_yds"])
		if cy > 0.0:
			ell_pts.append(Vector2(cy, so))
		var ty := float(s["total_yds"])
		if ty > 0.0:
			total_sum += ty
			total_cnt += 1
			roll_sum += float(s["rollout_yds"])

		var bs := float(s["ball_speed"])
		if not is_nan(bs): bs_sum += bs; bs_cnt += 1
		var cs := float(s["club_speed"])
		if not is_nan(cs): cs_sum += cs; cs_cnt += 1
		var sm := float(s["smash"])
		if not is_nan(sm): sm_sum += sm; sm_cnt += 1

		var fa := float(s["face_angle"])
		if not is_nan(fa): fa_abs += absf(fa); fa_sig += fa; fa_vals.append(fa)
		var cp := float(s["club_path"])
		if not is_nan(cp): cp_abs += absf(cp); cp_sig += cp; cp_vals.append(cp)
		var ftp := float(s["face_to_path"])
		if not is_nan(ftp): ftp_abs += absf(ftp); ftp_sig += ftp; ftp_vals.append(ftp)

		if not is_nan(fa) or not is_nan(cp):
			var bf := classify_ball_flight(fa, cp, ftp, is_lefty)
			var sh := str(bf["shape"])
			flight_counts[sh] = int(flight_counts.get(sh, 0)) + 1
			total_classified += 1
			if bool(bf["is_functional_stock"]):
				stock_cnt += 1

		var hla := float(s["hla"])
		var sa := float(s["spin_axis"])
		var st_m := hla if not is_nan(hla) else (fa * 0.8 + (0.0 if is_nan(cp) else cp) * 0.2 if not is_nan(fa) else NAN)
		var cv_m := ftp if not is_nan(ftp) else (sa / 2.2 if not is_nan(sa) else NAN)
		if not is_nan(st_m) and not is_nan(cv_m):
			start_mag += absf(st_m)
			curve_mag += absf(cv_m)
			attr_cnt += 1

		var vla := float(s["vla"])
		if not is_nan(vla): vla_sum += vla; vla_cnt += 1
		if not is_nan(hla): hla_sum += hla; hla_cnt += 1
		var aoa := float(s["aoa"])
		if not is_nan(aoa): aoa_sum += aoa; aoa_cnt += 1
		var dl := float(s["dynamic_loft"])
		if not is_nan(dl): dl_sum += dl; dl_cnt += 1
		var sl := float(s["spin_loft"])
		if not is_nan(sl): sl_sum += sl; sl_cnt += 1
		var sp := float(s["total_spin"])
		if not is_nan(sp): sp_sum += sp; sp_cnt += 1
		if not is_nan(sa): sa_sum += sa; sa_cnt += 1
		var ap := float(s["apex_ft"])
		if not is_nan(ap): ap_sum += ap; ap_cnt += 1
		var da := float(s["descent_angle"])
		if not is_nan(da): da_sum += da; da_cnt += 1
		var hi := float(s["hi"])
		var vi := float(s["vi"])
		if not is_nan(hi) and not is_nan(vi):
			hi_sum += hi; vi_sum += vi; hivi_cnt += 1
		var imp := float(s["impact_offset_mm"])
		if not is_nan(imp): imp_sum += imp; imp_cnt += 1

	var avg_carry := prelim_carry
	var std_carry := _calc_std_dev(carry_vals, avg_carry)
	var avg_signed_off := signed_off_sum / float(n)
	var std_off := _calc_std_dev(off_vals, avg_signed_off)

	var shifted_in := 0
	for so in off_vals:
		if absf(so - avg_signed_off) <= corridor_yds:
			shifted_in += 1
	var pct_in := int(round((float(in_corridor) / float(n)) * 100.0))
	var proj_pct := int(round((float(shifted_in) / float(n)) * 100.0))
	var shift_dir := "Left" if avg_signed_off > 0.5 else ("Right" if avg_signed_off < -0.5 else "On Target")

	var dom_shape := ""
	var dom_cnt := 0
	for k in flight_counts.keys():
		if int(flight_counts[k]) > dom_cnt:
			dom_cnt = int(flight_counts[k])
			dom_shape = str(k)

	var start_pct := 50
	var curve_pct := 50
	if attr_cnt > 0 and (start_mag + curve_mag) > 0.1:
		start_pct = int(round((start_mag / (start_mag + curve_mag)) * 100.0))
		curve_pct = 100 - start_pct

	var miss_pattern := "centered_consistent"
	if n >= 4:
		if absf(avg_signed_off) >= std_off * 0.75 and absf(avg_signed_off) >= corridor_yds * 0.35:
			miss_pattern = "one_way_bias"
		elif std_off >= corridor_yds * 0.85 and absf(avg_signed_off) < std_off * 0.6:
			miss_pattern = "two_way_miss"

	return {
		"count": n,
		"corridor_yds": corridor_yds,
		"avg_carry_yds": snapped(avg_carry, 0.1),
		"avg_total_yds": snapped(total_sum / total_cnt, 0.1) if total_cnt > 0 else snapped(avg_carry, 0.1),
		"avg_rollout_yds": snapped(roll_sum / total_cnt, 0.1) if total_cnt > 0 else 0.0,
		"std_dev_carry": snapped(std_carry, 0.1),
		"carry_consistency_pct": snapped((std_carry / avg_carry) * 100.0, 0.1) if (avg_carry > 5.0 and carry_vals.size() >= 2) else NAN,
		"avg_abs_offline": snapped(abs_off_sum / float(n), 0.1),
		"avg_signed_offline": snapped(avg_signed_off, 0.1),
		"std_dev_offline": snapped(std_off, 0.1),
		"pct_in_corridor": pct_in,
		"pct_left": int(round((float(left_cnt) / float(n)) * 100.0)),
		"pct_right": int(round((float(right_cnt) / float(n)) * 100.0)),
		"avg_ball_speed": snapped(bs_sum / bs_cnt, 0.1) if bs_cnt > 0 else NAN,
		"avg_club_speed": snapped(cs_sum / cs_cnt, 0.1) if cs_cnt > 0 else NAN,
		"avg_smash": snapped(sm_sum / sm_cnt, 0.01) if sm_cnt > 0 else NAN,
		"avg_face": snapped(fa_sig / fa_vals.size(), 0.1) if not fa_vals.is_empty() else NAN,
		"avg_abs_face": snapped(fa_abs / fa_vals.size(), 0.1) if not fa_vals.is_empty() else NAN,
		"std_dev_face": snapped(_calc_std_dev(fa_vals, fa_sig / fa_vals.size()), 0.1) if fa_vals.size() >= 2 else NAN,
		"avg_path": snapped(cp_sig / cp_vals.size(), 0.1) if not cp_vals.is_empty() else NAN,
		"avg_abs_path": snapped(cp_abs / cp_vals.size(), 0.1) if not cp_vals.is_empty() else NAN,
		"std_dev_path": snapped(_calc_std_dev(cp_vals, cp_sig / cp_vals.size()), 0.1) if cp_vals.size() >= 2 else NAN,
		"avg_ftp": snapped(ftp_sig / ftp_vals.size(), 0.1) if not ftp_vals.is_empty() else NAN,
		"avg_abs_ftp": snapped(ftp_abs / ftp_vals.size(), 0.1) if not ftp_vals.is_empty() else NAN,
		"std_dev_ftp": snapped(_calc_std_dev(ftp_vals, ftp_sig / ftp_vals.size()), 0.1) if ftp_vals.size() >= 2 else NAN,
		"avg_vla": snapped(vla_sum / vla_cnt, 0.1) if vla_cnt > 0 else NAN,
		"avg_hla": snapped(hla_sum / hla_cnt, 0.1) if hla_cnt > 0 else NAN,
		"avg_aoa": snapped(aoa_sum / aoa_cnt, 0.1) if aoa_cnt > 0 else NAN,
		"avg_dynamic_loft": snapped(dl_sum / dl_cnt, 0.1) if dl_cnt > 0 else NAN,
		"avg_spin_loft": snapped(sl_sum / sl_cnt, 0.1) if sl_cnt > 0 else NAN,
		"avg_spin": roundf(sp_sum / sp_cnt) if sp_cnt > 0 else NAN,
		"avg_spin_axis": snapped(sa_sum / sa_cnt, 0.1) if sa_cnt > 0 else NAN,
		"avg_apex_ft": snapped(ap_sum / ap_cnt, 0.1) if ap_cnt > 0 else NAN,
		"avg_descent_angle": snapped(da_sum / da_cnt, 0.1) if da_cnt > 0 else NAN,
		"avg_hi": snapped(hi_sum / hivi_cnt, 0.1) if hivi_cnt > 0 else NAN,
		"avg_vi": snapped(vi_sum / hivi_cnt, 0.1) if hivi_cnt > 0 else NAN,
		"avg_impact_offset_mm": snapped(imp_sum / imp_cnt, 0.1) if imp_cnt > 0 else NAN,
		"covariance_ellipse": compute_covariance_ellipse(ell_pts),
		"ball_flight": {
			"counts": flight_counts,
			"dominant_shape": dom_shape,
			"dominant_pct": int(round((float(dom_cnt) / float(total_classified)) * 100.0)) if total_classified > 0 else 0,
			"pct_functional_stock": int(round((float(stock_cnt) / float(total_classified)) * 100.0)) if total_classified > 0 else 0,
			"total_classified": total_classified
		},
		"miss_attribution": {
			"start_pct": start_pct,
			"curve_pct": curve_pct,
			"miss_pattern": miss_pattern,
			"has_data": attr_cnt > 0
		},
		"aim_shift": {
			"shift_yds": snapped(absf(avg_signed_off), 0.1),
			"shift_dir": shift_dir,
			"projected_pct_in_corridor": proj_pct,
			"gain_pct": maxi(0, proj_pct - pct_in)
		}
	}


static func _calc_std_dev(vals: Array[float], mean: float) -> float:
	if vals.size() < 2:
		return 0.0
	var v_sum := 0.0
	for v in vals:
		v_sum += pow(v - mean, 2.0)
	return sqrt(v_sum / float(vals.size()))


static func _build_active_focus(recent: Dictionary, club_name: String, skill_level: String, dist_loss: Dictionary) -> Dictionary:
	var eff_club := club_name if (not club_name.is_empty() and club_name.to_lower() != "all") else "Driver"
	var bench: Dictionary = GolfSwingAnalyzer.get_benchmark(eff_club, skill_level)
	var bench_name := str(bench.get("name", eff_club))
	var candidates: Array[Dictionary] = []

	var imp_off: float = float(recent.get("avg_impact_offset_mm", NAN))
	if not is_nan(imp_off) and imp_off >= 7.5:
		var s1: float = snappedf(maxf(6.5, imp_off - 2.5), 0.1)
		var s2: float = snappedf(maxf(5.0, s1 - 1.5), 0.1)
		candidates.append({
			"strokes": snapped(minf(4.2, (imp_off - 5.0) * 0.45), 0.1),
			"issue_key": "off_center_strike",
			"title": "Center Clubface Strike Location",
			"why": "Averaging %.1f mm off-center, leaking ball speed and adding gear-effect curve." % imp_off,
			"metric_key": "impactOffsetMm",
			"metric_label": "Sweet Spot Offset",
			"unit": "mm",
			"direction": "lower",
			"current_value": imp_off,
			"target_value": 5.0,
			"milestones": [
				{"step": 1, "label": "Keep avg strike under %.1f mm" % s1, "target_val": s1, "pass_rule": "7/10 shots <= %.1f mm" % s1, "status": "achieved" if imp_off <= s1 else "active"},
				{"step": 2, "label": "Tighten strike cluster under %.1f mm" % s2, "target_val": s2, "pass_rule": "7/10 shots <= %.1f mm" % s2, "status": "achieved" if imp_off <= s2 else ("active" if imp_off <= s1 else "upcoming")},
				{"step": 3, "label": "Sustain <= 5.0 mm centering", "target_val": 5.0, "pass_rule": "8/10 shots <= 5.0 mm", "status": "achieved" if imp_off <= 5.0 else "upcoming"}
			]
		})

	var smash: float = float(recent.get("avg_smash", NAN))
	var sm_min: float = float(bench.get("smash_min", 1.40))
	if not is_nan(smash) and smash < sm_min:
		var gap: float = sm_min - smash
		var s1: float = snappedf(minf(sm_min, smash + gap * 0.4), 0.01)
		var s2: float = snappedf(minf(sm_min, smash + gap * 0.75), 0.01)
		candidates.append({
			"strokes": snapped(minf(3.8, gap * 28.0 + float(dist_loss.get("smash_loss_yds", 0.0)) * 0.08), 0.1),
			"issue_key": "low_smash",
			"title": "Raise %s Smash Factor" % bench_name,
			"why": "Averaging %.2f vs %.2f target (costing ~%.0f yds carry)." % [smash, sm_min, float(dist_loss.get("smash_loss_yds", 0.0))],
			"metric_key": "smash",
			"metric_label": "Smash Factor",
			"unit": "",
			"direction": "higher",
			"current_value": smash,
			"target_value": sm_min,
			"milestones": [
				{"step": 1, "label": "Average %.2f+ Smash" % s1, "target_val": s1, "pass_rule": "7/10 strikes >= %.2f" % s1, "status": "achieved" if smash >= s1 else "active"},
				{"step": 2, "label": "Reach %.2f+ Smash" % s2, "target_val": s2, "pass_rule": "7/10 strikes >= %.2f" % s2, "status": "achieved" if smash >= s2 else ("active" if smash >= s1 else "upcoming")},
				{"step": 3, "label": "Lock in %.2f+ efficiency" % sm_min, "target_val": sm_min, "pass_rule": "8/10 strikes >= %.2f" % sm_min, "status": "achieved" if smash >= sm_min else "upcoming"}
			]
		})

	var abs_ftp: float = float(recent.get("avg_abs_ftp", NAN))
	var stock_pct: int = int(recent.get("ball_flight", {}).get("pct_functional_stock", 0))
	if not is_nan(abs_ftp) and abs_ftp > 2.8 and stock_pct < 60:
		var s1: float = snappedf(maxf(2.6, abs_ftp * 0.72), 0.1)
		var s2: float = snappedf(maxf(2.0, abs_ftp * 0.48), 0.1)
		candidates.append({
			"strokes": snapped(minf(4.5, (abs_ftp - 2.0) * 0.75 + 0.5), 0.1),
			"issue_key": "face_open" if float(recent.get("avg_ftp", 0.0)) >= 0.0 else "face_closed",
			"title": "Tighten Face-to-Path Curvature",
			"why": "Averaging %.1f° Face-to-Path, generating %d%% of your lateral miss via curve." % [abs_ftp, int(recent.get("miss_attribution", {}).get("curve_pct", 50))],
			"metric_key": "faceToPath",
			"metric_label": "Face-to-Path Gap",
			"unit": "°",
			"direction": "lower",
			"current_value": abs_ftp,
			"target_value": 2.0,
			"milestones": [
				{"step": 1, "label": "Bring Face-to-Path under ±%.1f°" % s1, "target_val": s1, "pass_rule": "7/10 shots <= ±%.1f°" % s1, "status": "achieved" if abs_ftp <= s1 else "active"},
				{"step": 2, "label": "Narrow Face-to-Path under ±%.1f°" % s2, "target_val": s2, "pass_rule": "7/10 shots <= ±%.1f°" % s2, "status": "achieved" if abs_ftp <= s2 else ("active" if abs_ftp <= s1 else "upcoming")},
				{"step": 3, "label": "Sustain ±2.0° stock curve", "target_val": 2.0, "pass_rule": "8/10 shots <= ±2.0°", "status": "achieved" if abs_ftp <= 2.0 else "upcoming"}
			]
		})

	var corridor: float = float(recent.get("corridor_yds", 12.0))
	var abs_off: float = float(recent.get("avg_abs_offline", 0.0))
	if candidates.is_empty() and abs_off > corridor * 0.7:
		var target_off: float = snappedf(corridor * 0.7, 0.1)
		var s1: float = snappedf(maxf(target_off, abs_off * 0.8), 0.1)
		var s2: float = snappedf(maxf(target_off, abs_off * 0.65), 0.1)
		candidates.append({
			"strokes": snapped(minf(3.5, (abs_off / corridor) * 1.4), 0.1),
			"issue_key": "offline_expanding",
			"title": "Tighten ±%.0f yd Corridor Rate" % corridor,
			"why": "Averaging ±%.1f yds offline (%d%% inside corridor)." % [abs_off, int(recent.get("pct_in_corridor", 0))],
			"metric_key": "absOffline",
			"metric_label": "Avg Offline",
			"unit": "yds",
			"direction": "lower",
			"current_value": abs_off,
			"target_value": target_off,
			"milestones": [
				{"step": 1, "label": "Reduce avg offline under %.1f yds" % s1, "target_val": s1, "pass_rule": "6/10 inside corridor", "status": "achieved" if abs_off <= s1 else "active"},
				{"step": 2, "label": "Reduce avg offline under %.1f yds" % s2, "target_val": s2, "pass_rule": "7/10 inside corridor", "status": "achieved" if abs_off <= s2 else ("active" if abs_off <= s1 else "upcoming")},
				{"step": 3, "label": "Sustain <= %.1f yds avg miss" % target_off, "target_val": target_off, "pass_rule": "8/10 inside corridor", "status": "achieved" if abs_off <= target_off else "upcoming"}
			]
		})

	if candidates.is_empty():
		var pct_in := int(recent.get("pct_in_corridor", 0))
		return {
			"title": "Maintain & Transfer Stock Ball Flight",
			"issue_key": "Pure Ball Strike",
			"why": "Metrics are tracking inside %s target windows." % str(GolfSwingAnalyzer.SKILL_LEVEL_NAMES.get(skill_level, "Mid Handicap")),
			"metric_key": "corridorPct",
			"metric_label": "Corridor Hit Rate",
			"unit": "%",
			"direction": "higher",
			"current_value": float(pct_in),
			"target_value": 75.0,
			"estimated_strokes_saved": 0.3,
			"club_key": eff_club,
			"milestones": [
				{"step": 1, "label": "Hit 7/10 inside corridor", "target_val": 70.0, "pass_rule": "70% target hit rate", "status": "achieved" if pct_in >= 70 else "active"},
				{"step": 2, "label": "Alternate targets every shot", "target_val": 75.0, "pass_rule": "75% random transfer", "status": "upcoming"},
				{"step": 3, "label": "Sustain under pressure", "target_val": 80.0, "pass_rule": "80% target rate", "status": "upcoming"}
			]
		}

	candidates.sort_custom(func(a, b): return float(a["strokes"]) > float(b["strokes"]))
	var top := candidates[0]
	top["estimated_strokes_saved"] = maxf(0.5, float(top["strokes"]))
	top["club_key"] = eff_club
	return top


static func analyze_shot_group(shots: Array, club_name: String = "Driver", skill_level: String = "mid_handicap", is_lefty: bool = false) -> Dictionary:
	var norm_skill: String = GolfSwingAnalyzer.normalize_skill_level(skill_level)
	var normalized: Array[Dictionary] = []
	for i in range(shots.size()):
		if shots[i] is Dictionary:
			normalized.append(normalize_shot(shots[i], i))

	if normalized.is_empty():
		return {"has_data": false, "total_shots": 0}

	normalized.sort_custom(func(a, b): return int(a["t"]) < int(b["t"]))
	var n := normalized.size()
	var recent_slice: Array[Dictionary] = normalized
	var baseline_slice: Array[Dictionary] = normalized
	if n >= 4:
		var win := mini(10, n / 2)
		recent_slice = normalized.slice(n - win, n)
		baseline_slice = normalized.slice(maxi(0, n - win * 2), n - win)
	elif n >= 2:
		var mid := n / 2
		baseline_slice = normalized.slice(0, mid)
		recent_slice = normalized.slice(mid, n)

	var full_summary := _summarize_normalized(normalized, club_name, norm_skill, is_lefty)
	var recent_summary := _summarize_normalized(recent_slice, club_name, norm_skill, is_lefty)
	var baseline_summary := _summarize_normalized(baseline_slice, club_name, norm_skill, is_lefty)

	var eff_club := club_name if (not club_name.is_empty() and club_name.to_lower() != "all") else str(normalized[-1].get("club", "Driver"))
	var dist_loss := compute_distance_loss_breakdown(recent_summary, eff_club, norm_skill)
	var active_focus := _build_active_focus(recent_summary, eff_club, norm_skill, dist_loss)

	var deltas := {
		"offline_delta": snapped(float(recent_summary["avg_abs_offline"]) - float(baseline_summary["avg_abs_offline"]), 0.1),
		"carry_delta": snapped(float(recent_summary["avg_carry_yds"]) - float(baseline_summary["avg_carry_yds"]), 0.1),
		"smash_delta": snapped(float(recent_summary["avg_smash"]) - float(baseline_summary["avg_smash"]), 0.01) if (not is_nan(float(recent_summary["avg_smash"])) and not is_nan(float(baseline_summary["avg_smash"]))) else NAN,
		"face_delta": snapped(float(recent_summary["avg_abs_face"]) - float(baseline_summary["avg_abs_face"]), 0.1) if (not is_nan(float(recent_summary["avg_abs_face"])) and not is_nan(float(baseline_summary["avg_abs_face"]))) else NAN,
		"path_delta": snapped(float(recent_summary["avg_abs_path"]) - float(baseline_summary["avg_abs_path"]), 0.1) if (not is_nan(float(recent_summary["avg_abs_path"])) and not is_nan(float(baseline_summary["avg_abs_path"]))) else NAN,
		"ftp_delta": snapped(float(recent_summary["avg_abs_ftp"]) - float(baseline_summary["avg_abs_ftp"]), 0.1) if (not is_nan(float(recent_summary["avg_abs_ftp"])) and not is_nan(float(baseline_summary["avg_abs_ftp"]))) else NAN
	}

	return {
		"has_data": true,
		"total_shots": n,
		"club_name": eff_club,
		"skill_level": norm_skill,
		"is_lefty": is_lefty,
		"summary": full_summary,
		"recent": recent_summary,
		"baseline": baseline_summary,
		"deltas": deltas,
		"distance_loss": dist_loss,
		"active_focus": active_focus,
		"normalized_shots": normalized
	}


static func analyze_bag_gapping(club_averages: Dictionary) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for order_key in BAG_SORT_ORDER:
		var matched_key := ""
		for k in club_averages.keys():
			if str(k).to_lower() == order_key.to_lower():
				matched_key = str(k)
				break
		if matched_key.is_empty():
			continue
		var c_data: Dictionary = club_averages[matched_key]
		if int(c_data.get("shot_count", 0)) <= 0 or float(c_data.get("avg_carry_m", 0.0)) <= 0.0:
			continue
		var carry_yds: float = snappedf(float(c_data.get("avg_carry_m", 0.0)) * 1.09361, 0.1)
		var total_yds: float = snappedf(maxf(carry_yds, float(c_data.get("avg_total_m", 0.0)) * 1.09361), 0.1)
		items.append({
			"club": matched_key,
			"display_name": str(c_data.get("display_name", matched_key)),
			"shot_count": int(c_data.get("shot_count", 0)),
			"carry_yds": carry_yds,
			"total_yds": total_yds,
			"rollout_yds": snappedf(maxf(0.0, total_yds - carry_yds), 0.1),
			"gap_yds": 0.0,
			"status": "anchor"
		})

	for i in range(1, items.size()):
		var gap: float = snappedf(float(items[i - 1]["carry_yds"]) - float(items[i]["carry_yds"]), 0.1)
		items[i]["gap_yds"] = gap
		if gap < 8.0:
			items[i]["status"] = "overlap"
		elif gap > 18.0:
			items[i]["status"] = "large_gap"
		else:
			items[i]["status"] = "optimal"
	return items


static func evaluate_drill_shot(drill_id: String, shot_data: Dictionary, club_name: String, skill_level: String = "mid_handicap", is_lefty: bool = false, target_config: Dictionary = {}) -> Dictionary:
	var s := normalize_shot(shot_data, 0)
	var eff_club := club_name if not club_name.is_empty() else str(s.get("club", "Driver"))
	var bench: Dictionary = GolfSwingAnalyzer.get_benchmark(eff_club, GolfSwingAnalyzer.normalize_skill_level(skill_level))

	match drill_id:
		"active_focus":
			var m_key := str(target_config.get("metric_key", "absOffline"))
			var target_val := float(target_config.get("target_val", 12.0))
			var direction := str(target_config.get("direction", "lower"))
			var unit := str(target_config.get("unit", ""))
			var measured := NAN
			match m_key:
				"impactOffsetMm": measured = float(s["impact_offset_mm"])
				"smash": measured = float(s["smash"])
				"faceToPath": measured = absf(float(s["face_to_path"])) if not is_nan(float(s["face_to_path"])) else NAN
				"faceAngle": measured = absf(float(s["face_angle"])) if not is_nan(float(s["face_angle"])) else NAN
				"corridorPct":
					var corr := get_target_corridor_yards(eff_club, float(s["carry_yds"]))
					var ok_c := float(s["abs_offline_yds"]) <= corr
					return {
						"passed": ok_c,
						"measured_text": "%.1f yds offline" % float(s["abs_offline_yds"]),
						"target_text": "<= ±%.0f yds" % corr,
						"feedback": "Inside corridor!" if ok_c else "Missed corridor by %.1f yds." % (float(s["abs_offline_yds"]) - corr)
					}
				_:
					measured = float(s["abs_offline_yds"])
			if is_nan(measured):
				return {"passed": false, "measured_text": "No telemetry", "target_text": "%.1f %s" % [target_val, unit], "feedback": "Metric not reported by monitor on this shot."}
			var passed := (measured >= target_val) if direction == "higher" else (measured <= target_val)
			return {
				"passed": passed,
				"measured_text": "%.2f %s" % [measured, unit] if m_key == "smash" else "%.1f %s" % [measured, unit],
				"target_text": "%s %.2f %s" % [">=" if direction == "higher" else "<=", target_val, unit] if m_key == "smash" else "%s %.1f %s" % [">=" if direction == "higher" else "<=", target_val, unit],
				"feedback": "Target hit!" if passed else "Keep working toward target window."
			}

		"start_line_gate":
			var target_deg := float(target_config.get("target_deg", 2.0))
			var angle := float(s["hla"])
			var label := "HLA"
			if is_nan(angle):
				angle = float(s["face_angle"])
				label = "Face"
			if is_nan(angle):
				return {"passed": false, "measured_text": "No HLA/Face", "target_text": "±%.1f°" % target_deg, "feedback": "Requires HLA or Face Angle telemetry."}
			var ok := absf(angle) <= target_deg
			return {
				"passed": ok,
				"measured_text": "%s %+.1f°" % [label, angle],
				"target_text": "±%.1f°" % target_deg,
				"feedback": "Clean start line through the gate!" if ok else "Started %.1f° outside gate." % (absf(angle) - target_deg)
			}

		"curve_control":
			var target_ftp := float(target_config.get("target_deg", 2.5))
			var ftp := float(s["face_to_path"])
			var lbl := "FTP"
			if is_nan(ftp) and not is_nan(float(s["spin_axis"])):
				ftp = float(s["spin_axis"]) / 2.2
				lbl = "Est FTP"
			if is_nan(ftp):
				return {"passed": false, "measured_text": "No Path/SpinAxis", "target_text": "±%.1f°" % target_ftp, "feedback": "Requires Face-to-Path or Spin Axis."}
			var ok := absf(ftp) <= target_ftp
			return {
				"passed": ok,
				"measured_text": "%s %+.1f°" % [lbl, ftp],
				"target_text": "±%.1f°" % target_ftp,
				"feedback": "Stock curve window!" if ok else "Excess curve (%.1f° FTP)." % ftp
			}

		"center_compression":
			var target_sm := float(target_config.get("target_smash", float(bench.get("smash_min", 1.38))))
			var sm := float(s["smash"])
			var imp := float(s["impact_offset_mm"])
			if not is_nan(sm):
				var ok := sm >= target_sm
				return {
					"passed": ok,
					"measured_text": "Smash %.2f" % sm,
					"target_text": ">= %.2f" % target_sm,
					"feedback": "Pure center compression!" if ok else "Below %.2f smash target." % target_sm
				}
			if not is_nan(imp):
				var ok_i := imp <= 8.0
				return {
					"passed": ok_i,
					"measured_text": "%.1f mm offset" % imp,
					"target_text": "<= 8.0 mm",
					"feedback": "Centered sweet-spot strike!" if ok_i else "Off-center (%.1f mm)." % imp
				}
			return {"passed": false, "measured_text": "No Smash/Impact", "target_text": ">= %.2f" % target_sm, "feedback": "Requires Club Speed or Impact telemetry."}

		"differential_feel":
			var rep := int(target_config.get("rep_index", 0)) % 10
			var req_shape := "Draw" if rep < 3 else ("Fade" if rep < 6 else "Straight")
			var ftp := float(s["face_to_path"])
			var axis := float(s["spin_axis"])
			var curve_val := ftp if not is_nan(ftp) else (axis / 2.2 if not is_nan(axis) else NAN)
			if is_nan(curve_val):
				return {"passed": false, "measured_text": "No Curve Data", "target_text": req_shape, "feedback": "Requires Face-to-Path or Spin Axis."}
			var ok := false
			if req_shape == "Draw":
				ok = curve_val <= -0.8
			elif req_shape == "Fade":
				ok = curve_val >= 0.8
			else:
				ok = absf(curve_val) <= 2.2
			var actual_label := "Draw" if curve_val < -0.8 else ("Fade" if curve_val > 0.8 else "Straight")
			return {
				"passed": ok,
				"measured_text": "%s (%+.1f°)" % [actual_label, curve_val],
				"target_text": "Hit %s" % req_shape,
				"feedback": ("Nailed %s on command!" % req_shape) if ok else ("Asked for %s, delivered %s." % [req_shape, actual_label])
			}

		"wedge_ladder":
			var target_yds := float(target_config.get("target_yards", 60.0))
			var tol := maxf(5.0, target_yds * 0.10)
			var carry := float(s["carry_yds"])
			var ok := absf(carry - target_yds) <= tol
			return {
				"passed": ok,
				"measured_text": "%.1f yds carry" % carry,
				"target_text": "%.0f ±%.0f yds" % [target_yds, tol],
				"feedback": "Locked in wedge distance!" if ok else ("%.1f yds %s target." % [absf(carry - target_yds), "long of" if carry > target_yds else "short of"])
			}

	return {"passed": false, "measured_text": "---", "target_text": "---", "feedback": "Unknown drill."}
