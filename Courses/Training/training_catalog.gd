class_name TrainingCatalog
extends RefCounted

## Central catalog of Training Academy categories, structured golf drills,
## target tolerances, launch/smash benchmarks, and active session handoff state.

static var active_session: Dictionary = {}

const CATEGORIES: Array[Dictionary] = [
	{
		"id": "straighter_drives",
		"title": "Hit Straighter Drives",
		"icon": "🎯",
		"tagline": "Keep tee shots in the short grass",
		"accent": Color(0.25, 0.85, 0.55),
		"drills": ["fairway_finder", "dispersion_tightener"]
	},
	{
		"id": "fix_slice",
		"title": "Fix My Slice",
		"icon": "↪️",
		"tagline": "Eliminate the big weak-side curve",
		"accent": Color(1.0, 0.58, 0.25),
		"drills": ["slice_cure", "shot_shaper"]
	},
	{
		"id": "fix_hook",
		"title": "Tame My Hook",
		"icon": "↩️",
		"tagline": "Calm the over-draw and snap hook",
		"accent": Color(0.95, 0.42, 0.52),
		"drills": ["hook_tamer", "shot_shaper"]
	},
	{
		"id": "wedge_dial",
		"title": "Dial In Wedges",
		"icon": "⛳",
		"tagline": "Own the 50–110 yd scoring zone",
		"accent": Color(1.0, 0.85, 0.35),
		"drills": ["wedge_clock", "approach_bullseye"]
	},
	{
		"id": "iron_accuracy",
		"title": "Stick Approach Shots",
		"icon": "📍",
		"tagline": "Hit more greens from 115–175 yds",
		"accent": Color(0.35, 0.82, 1.0),
		"drills": ["approach_bullseye", "dispersion_tightener"]
	},
	{
		"id": "solid_contact",
		"title": "Cleaner Solid Contact",
		"icon": "💥",
		"tagline": "Compress the ball & boost smash factor",
		"accent": Color(0.75, 0.48, 1.0),
		"drills": ["sweet_spot_strike", "dispersion_tightener"]
	},
	{
		"id": "flight_control",
		"title": "Launch & Flight Control",
		"icon": "🚀",
		"tagline": "Send shots through your ideal sky window",
		"accent": Color(0.28, 0.92, 0.82),
		"drills": ["launch_window", "shot_shaper"]
	},
	{
		"id": "full_assessment",
		"title": "Full-Bag Skill Combine",
		"icon": "🏆",
		"tagline": "10-shot diagnostic across your whole bag",
		"accent": Color(1.0, 0.78, 0.22),
		"drills": ["skill_combine", "wedge_clock"]
	}
]

const DRILLS: Dictionary = {
	"fairway_finder": {
		"id": "fairway_finder",
		"name": "Fairway Finder Corridor",
		"category_id": "straighter_drives",
		"short_desc": "Thread tee shots down a glowing fairway runway. Build repeatable start line and calm two-way misses.",
		"why_it_helps": "Narrowing your tee-shot corridor turns penalty strokes into routine par chances.",
		"coaching_cue": "Pick a tight intermediate spot 3 feet ahead of the ball and swing smoothly at 85% tempo.",
		"recommended_club": "Dr",
		"reps": 10,
		"visual_mode": "corridor",
		"gauge_left_label": "LEFT",
		"gauge_right_label": "RIGHT",
		"stage_distances_yds": [240],
		"min_carry_yds": 140.0,
		"thresholds": {"perfect": 6.0, "great": 11.0, "good": 17.0, "ok": 24.0}
	},
	"slice_cure": {
		"id": "slice_cure",
		"name": "Anti-Slice Gate & Release",
		"category_id": "fix_slice",
		"short_desc": "Stay clear of the weak-side hazard barrier by squaring the clubface and swinging smoothly from the inside.",
		"why_it_helps": "Trains face-to-path closure so weak glancing slices transform into strong, straight or drawing flights.",
		"coaching_cue": "Feel your trail elbow tuck toward your hip and let the lead wrist flatten smoothly through impact.",
		"recommended_club": "Dr",
		"reps": 10,
		"visual_mode": "slice_corridor",
		"gauge_left_label": "HOOK",
		"gauge_right_label": "SLICE",
		"stage_distances_yds": [230],
		"min_carry_yds": 135.0,
		"thresholds": {"perfect": 5.5, "great": 10.5, "good": 16.0, "ok": 23.0}
	},
	"hook_tamer": {
		"id": "hook_tamer",
		"name": "Hook Tamer Neutral Path",
		"category_id": "fix_hook",
		"short_desc": "Neutralize aggressive over-draws by keeping body rotation synced with your hands past impact.",
		"why_it_helps": "Stops runaway low-spin curves that dive into trouble by matching clubface release to torso turn.",
		"coaching_cue": "Rotate your chest and lead hip together through impact and feel a slightly held-off, balanced finish.",
		"recommended_club": "Dr",
		"reps": 10,
		"visual_mode": "hook_corridor",
		"gauge_left_label": "HOOK",
		"gauge_right_label": "SLICE",
		"stage_distances_yds": [230],
		"min_carry_yds": 135.0,
		"thresholds": {"perfect": 5.5, "great": 10.5, "good": 16.0, "ok": 23.0}
	},
	"wedge_clock": {
		"id": "wedge_clock",
		"name": "Wedge Distance Ladder",
		"category_id": "wedge_dial",
		"short_desc": "Climb from 50 to 110 yards in 2-shot steps. Dial in swing clock lengths for crisp scoring wedges.",
		"why_it_helps": "Eliminating 20-foot wedge distance misses creates immediate birdie looks inside 100 yards.",
		"coaching_cue": "Control distance with backswing arm length (9-to-3 or 10-to-2) while accelerating smoothly to a balanced finish.",
		"recommended_club": "Sw",
		"reps": 10,
		"visual_mode": "bullseye_ladder",
		"gauge_left_label": "SHORT",
		"gauge_right_label": "LONG",
		"stage_distances_yds": [50, 50, 65, 65, 80, 80, 95, 95, 110, 110],
		"min_carry_yds": 20.0,
		"thresholds": {"perfect": 3.5, "great": 6.5, "good": 10.5, "ok": 15.5}
	},
	"approach_bullseye": {
		"id": "approach_bullseye",
		"name": "Approach Target Roulette",
		"category_id": "iron_accuracy",
		"short_desc": "Attack randomized mid-iron pin distances between 120 and 170 yards—just like real on-course approaches.",
		"why_it_helps": "Random yardages break autopilot range rhythm and train true distance & club-selection calibration.",
		"coaching_cue": "Take one calm rehearsal swing for each new yardage, commit to the line, and brush the turf past the ball.",
		"recommended_club": "7i",
		"reps": 10,
		"visual_mode": "bullseye_random",
		"gauge_left_label": "SHORT",
		"gauge_right_label": "LONG",
		"stage_distances_yds": [120, 135, 150, 165, 140, 125, 155, 170, 130, 145],
		"min_carry_yds": 60.0,
		"thresholds": {"perfect": 5.0, "great": 9.0, "good": 14.5, "ok": 21.0}
	},
	"launch_window": {
		"id": "launch_window",
		"name": "Sky Window Flight Control",
		"category_id": "flight_control",
		"short_desc": "Send every iron or driver shot cleanly through the glowing 3D launch window at your ideal launch angle.",
		"why_it_helps": "Optimizing vertical launch angle maximizes carry efficiency without ballooning or thin low bullets.",
		"coaching_cue": "Keep your sternum stacked over the ball with irons (or behind the ball with driver) for crisp launch.",
		"recommended_club": "7i",
		"reps": 10,
		"visual_mode": "launch_window",
		"gauge_left_label": "LOW",
		"gauge_right_label": "HIGH",
		"stage_distances_yds": [150],
		"min_carry_yds": 60.0,
		"thresholds": {"perfect": 1.5, "great": 3.0, "good": 4.8, "ok": 7.0}
	},
	"sweet_spot_strike": {
		"id": "sweet_spot_strike",
		"name": "Sweet Spot Compression",
		"category_id": "solid_contact",
		"short_desc": "Maximize smash factor and energy transfer. Chase pure, centered strikes rather than raw swing speed.",
		"why_it_helps": "Pure sweet-spot compression adds effortless yardage and shrinks front-to-back distance scatter.",
		"coaching_cue": "Swing at 80% speed, keep head level through strike, and focus on hitting the back-inside dimple cleanly.",
		"recommended_club": "7i",
		"reps": 10,
		"visual_mode": "compression_corridor",
		"gauge_left_label": "WEAK",
		"gauge_right_label": "PURE",
		"stage_distances_yds": [150],
		"min_carry_yds": 60.0,
		"thresholds": {"perfect": 0.03, "great": 0.06, "good": 0.10, "ok": 0.15}
	},
	"shot_shaper": {
		"id": "shot_shaper",
		"name": "Draw & Fade Gate Shaper",
		"category_id": "fix_slice",
		"short_desc": "Alternate intentional draws and fades through the start gate into left and right curved target zones.",
		"why_it_helps": "Learning to bend the ball both ways on command gives you instant control over your clubface.",
		"coaching_cue": "Align body slightly toward the curve target, aim clubface at the landing zone, and swing along your stance.",
		"recommended_club": "7i",
		"reps": 8,
		"visual_mode": "shape_gate",
		"gauge_left_label": "LEFT",
		"gauge_right_label": "RIGHT",
		"stage_distances_yds": [145],
		"min_carry_yds": 65.0,
		"thresholds": {"perfect": 6.0, "great": 10.5, "good": 16.0, "ok": 23.0}
	},
	"dispersion_tightener": {
		"id": "dispersion_tightener",
		"name": "Dispersion Tightener Cluster",
		"category_id": "iron_accuracy",
		"short_desc": "Drop 10 shots into one tight cluster at your stock club carry. Track every landing pin live on the turf!",
		"why_it_helps": "Turns unpredictable distance gaps and wide left/right sprays into one predictable scoring pattern.",
		"coaching_cue": "Match the exact same rhythm and finish balance on every rep—consistency beats max distance.",
		"recommended_club": "7i",
		"reps": 10,
		"visual_mode": "dispersion_circle",
		"gauge_left_label": "SHORT",
		"gauge_right_label": "LONG",
		"stage_distances_yds": [150],
		"min_carry_yds": 60.0,
		"thresholds": {"perfect": 4.5, "great": 8.5, "good": 13.5, "ok": 20.0}
	},
	"skill_combine": {
		"id": "skill_combine",
		"name": "5-Stage Skill Combine",
		"category_id": "full_assessment",
		"short_desc": "Hit 2 shots each at 60, 100, 140, 175 yds plus a Driver Fairway Finale to benchmark your whole bag.",
		"why_it_helps": "Pinpoints exactly which part of your bag costs the most strokes so future training targets it fast.",
		"coaching_cue": "Commit to each new club & target before swinging—treat every 2-shot station like a real golf hole.",
		"recommended_club": "Sw",
		"reps": 10,
		"visual_mode": "combine",
		"gauge_left_label": "SHORT",
		"gauge_right_label": "LONG",
		"stage_distances_yds": [60, 60, 100, 100, 140, 140, 175, 175, 235, 235],
		"min_carry_yds": 30.0,
		"thresholds": {"perfect": 4.5, "great": 8.5, "good": 13.5, "ok": 20.0}
	}
}

const COMBINE_STAGES: Array[Dictionary] = [
	{"stage_name": "Station 1: Scoring Wedge (60 yds)", "mode": "bullseye", "distance_yds": 60, "club": "Sw", "perfect": 3.5, "great": 6.5, "good": 10.5, "ok": 15.5},
	{"stage_name": "Station 2: Full Pitch (100 yds)", "mode": "bullseye", "distance_yds": 100, "club": "Pw", "perfect": 4.5, "great": 8.0, "good": 12.5, "ok": 18.0},
	{"stage_name": "Station 3: Mid Iron (140 yds)", "mode": "bullseye", "distance_yds": 140, "club": "8i", "perfect": 5.5, "great": 9.5, "good": 15.0, "ok": 21.5},
	{"stage_name": "Station 4: Long Approach (175 yds)", "mode": "bullseye", "distance_yds": 175, "club": "5i", "perfect": 7.0, "great": 12.0, "good": 18.5, "ok": 26.0},
	{"stage_name": "Station 5: Driver Fairway Finale", "mode": "corridor", "distance_yds": 235, "club": "Dr", "perfect": 6.5, "great": 11.5, "good": 18.0, "ok": 25.0}
]


static func set_active_session(
	drill_id: String,
	player_name: String,
	difficulty: String = "standard",
	selected_club: String = "",
	diagnosis_reason: String = "",
	is_suggested: bool = false,
	diagnosis_evidence: Array = []
) -> void:
	var drill := get_drill(drill_id)
	var club := selected_club if not selected_club.strip_edges().is_empty() else str(drill.get("recommended_club", "7i"))
	var diff := normalize_difficulty(difficulty)
	active_session = {
		"drill_id": str(drill.get("id", "fairway_finder")),
		"player_name": player_name if not player_name.strip_edges().is_empty() else "Player 1",
		"difficulty": diff,
		"selected_club": club,
		"diagnosis_reason": diagnosis_reason,
		"diagnosis_evidence": diagnosis_evidence.duplicate(),
		"is_suggested": is_suggested
	}


static func get_active_session() -> Dictionary:
	if active_session.is_empty():
		var fallback_drill := get_drill("fairway_finder")
		return {
			"drill_id": str(fallback_drill.get("id", "fairway_finder")),
			"player_name": "Player 1",
			"difficulty": "standard",
			"selected_club": str(fallback_drill.get("recommended_club", "Dr")),
			"diagnosis_reason": "",
			"diagnosis_evidence": [],
			"is_suggested": false
		}
	return active_session.duplicate(true)


static func clear_active_session() -> void:
	active_session.clear()


static func normalize_difficulty(difficulty: String) -> String:
	var d := difficulty.strip_edges().to_lower()
	if d in ["beginner", "standard", "pro"]:
		return d
	return "standard"


static func get_categories() -> Array[Dictionary]:
	return CATEGORIES.duplicate(true)


static func get_category(category_id: String) -> Dictionary:
	for cat in CATEGORIES:
		if str(cat.get("id", "")) == category_id:
			return cat.duplicate(true)
	return CATEGORIES[0].duplicate(true)


static func get_drill(drill_id: String) -> Dictionary:
	if DRILLS.has(drill_id):
		return DRILLS[drill_id].duplicate(true)
	return DRILLS["fairway_finder"].duplicate(true)


static func get_all_drills() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in DRILLS.keys():
		result.append(DRILLS[key].duplicate(true))
	return result


static func get_drills_for_category(category_id: String) -> Array[Dictionary]:
	var cat := get_category(category_id)
	var drill_ids: Array = cat.get("drills", [])
	var result: Array[Dictionary] = []
	for d_id in drill_ids:
		if DRILLS.has(d_id):
			result.append(DRILLS[d_id].duplicate(true))
	if result.is_empty():
		result.append(get_drill("fairway_finder"))
	return result


static func get_difficulty_multiplier(difficulty: String) -> float:
	match normalize_difficulty(difficulty):
		"beginner":
			return 1.40
		"pro":
			return 0.72
		_:
			return 1.0


static func get_difficulty_display_name(difficulty: String) -> String:
	match normalize_difficulty(difficulty):
		"beginner":
			return "Beginner"
		"pro":
			return "Tour Pro"
		_:
			return "Standard"


static func get_optimal_vla_window(club_code: String) -> Dictionary:
	var c := club_code.strip_edges().to_lower()
	if c in ["dr", "driver", "1w"]:
		return {"min": 10.5, "max": 15.5, "ideal": 13.0}
	if c in ["3w", "5w", "2h", "3h", "4h"]:
		return {"min": 12.0, "max": 17.5, "ideal": 14.5}
	if c in ["1i", "2i", "3i", "4i", "5i"]:
		return {"min": 13.0, "max": 18.5, "ideal": 15.8}
	if c in ["6i", "7i", "8i"]:
		return {"min": 16.0, "max": 22.0, "ideal": 19.0}
	if c in ["9i", "pw"]:
		return {"min": 21.0, "max": 27.5, "ideal": 24.2}
	if c in ["gw", "sw", "lw"]:
		return {"min": 25.5, "max": 35.0, "ideal": 30.0}
	return {"min": 15.0, "max": 22.0, "ideal": 18.5}


static func get_expected_smash(club_code: String) -> float:
	var c := club_code.strip_edges().to_lower()
	if c in ["dr", "driver", "1w"]:
		return 1.46
	if c in ["3w", "5w"]:
		return 1.42
	if c in ["2h", "3h", "4h"]:
		return 1.38
	if c in ["1i", "2i", "3i", "4i", "5i"]:
		return 1.35
	if c in ["6i", "7i", "8i"]:
		return 1.31
	if c in ["9i", "pw"]:
		return 1.26
	if c in ["gw", "sw", "lw"]:
		return 1.22
	return 1.31


static func get_default_club_carry_yds(club_code: String) -> float:
	var c := club_code.strip_edges().to_lower()
	match c:
		"dr", "driver", "1w":
			return 235.0
		"3w":
			return 215.0
		"5w":
			return 200.0
		"2h":
			return 195.0
		"3h":
			return 185.0
		"4h":
			return 175.0
		"1i":
			return 205.0
		"2i":
			return 195.0
		"3i":
			return 185.0
		"4i":
			return 175.0
		"5i":
			return 165.0
		"6i":
			return 155.0
		"7i":
			return 145.0
		"8i":
			return 135.0
		"9i":
			return 122.0
		"pw":
			return 108.0
		"gw":
			return 95.0
		"sw":
			return 80.0
		"lw":
			return 65.0
		_:
			return 145.0


static func get_combine_stage_config(shot_index: int) -> Dictionary:
	var station_idx := clampi(int(shot_index / 2), 0, COMBINE_STAGES.size() - 1)
	return COMBINE_STAGES[station_idx].duplicate(true)
