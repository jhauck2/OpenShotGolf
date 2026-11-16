extends Object
class_name BallTypePhysics

## Utility class for golf ball type physics adjustments in Heckle Golf Simulator.
##
## Supported ball types:
## - "standard" (Default): 1.0x baseline across distance, spin, rollout, bounce, and aerodynamics.
## - "soft": Tour-soft urethane ball. Slightly less distance (-2% speed, 1.015x drag, 1.01x lift),
##           more spin (+8% launch spin, +15% spinback), and less rollout (-15% rollout, ~1.176x friction).
## - "distance": Firm 2-piece distance ball. More distance (+3% speed, 0.985x drag, 0.99x lift),
##               less spin (-10% launch spin, -15% spinback), and more rollout (+18% rollout, ~0.847x friction).

const TYPE_STANDARD := "standard"
const TYPE_SOFT := "soft"
const TYPE_DISTANCE := "distance"

# Standard Ball (100% unchanged baseline)
const STANDARD_SPEED_MULTIPLIER: float = 1.0
const STANDARD_SPIN_MULTIPLIER: float = 1.0
const STANDARD_ROLLOUT_FACTOR: float = 1.0
const STANDARD_FRICTION_MULTIPLIER: float = 1.0
const STANDARD_BOUNCE_RETENTION: float = 1.0
const STANDARD_SPINBACK_MULTIPLIER: float = 1.0
const STANDARD_DRAG_SCALE: float = 1.0
const STANDARD_LIFT_SCALE: float = 1.0

# Soft Ball (More spin & greenside bite, reduced rollout, slightly less distance)
const SOFT_SPEED_MULTIPLIER: float = 0.98
const SOFT_SPIN_MULTIPLIER: float = 1.08
const SOFT_ROLLOUT_FACTOR: float = 0.85
const SOFT_FRICTION_MULTIPLIER: float = 1.0 / 0.85
const SOFT_BOUNCE_RETENTION: float = 0.921954446 # sqrt(0.85)
const SOFT_SPINBACK_MULTIPLIER: float = 1.15
const SOFT_DRAG_SCALE: float = 1.015
const SOFT_LIFT_SCALE: float = 1.01

# Distance Ball (Extra carry/distance & rollout, lower spin)
const DISTANCE_SPEED_MULTIPLIER: float = 1.03
const DISTANCE_SPIN_MULTIPLIER: float = 0.90
const DISTANCE_ROLLOUT_FACTOR: float = 1.18
const DISTANCE_FRICTION_MULTIPLIER: float = 1.0 / 1.18
const DISTANCE_BOUNCE_RETENTION: float = 1.086278049 # sqrt(1.18)
const DISTANCE_SPINBACK_MULTIPLIER: float = 0.85
const DISTANCE_DRAG_SCALE: float = 0.985
const DISTANCE_LIFT_SCALE: float = 0.99

const _BALL_PROFILES := {
	TYPE_STANDARD: {
		"speed_mult": STANDARD_SPEED_MULTIPLIER,
		"spin_mult": STANDARD_SPIN_MULTIPLIER,
		"rollout_factor": STANDARD_ROLLOUT_FACTOR,
		"friction_mult": STANDARD_FRICTION_MULTIPLIER,
		"bounce_retention": STANDARD_BOUNCE_RETENTION,
		"spinback_mult": STANDARD_SPINBACK_MULTIPLIER,
		"drag_scale": STANDARD_DRAG_SCALE,
		"lift_scale": STANDARD_LIFT_SCALE,
		"index": 0,
		"display_name": "Standard Ball",
		"short_name": "Standard",
	},
	TYPE_SOFT: {
		"speed_mult": SOFT_SPEED_MULTIPLIER,
		"spin_mult": SOFT_SPIN_MULTIPLIER,
		"rollout_factor": SOFT_ROLLOUT_FACTOR,
		"friction_mult": SOFT_FRICTION_MULTIPLIER,
		"bounce_retention": SOFT_BOUNCE_RETENTION,
		"spinback_mult": SOFT_SPINBACK_MULTIPLIER,
		"drag_scale": SOFT_DRAG_SCALE,
		"lift_scale": SOFT_LIFT_SCALE,
		"index": 1,
		"display_name": "Soft Ball",
		"short_name": "Soft",
	},
	TYPE_DISTANCE: {
		"speed_mult": DISTANCE_SPEED_MULTIPLIER,
		"spin_mult": DISTANCE_SPIN_MULTIPLIER,
		"rollout_factor": DISTANCE_ROLLOUT_FACTOR,
		"friction_mult": DISTANCE_FRICTION_MULTIPLIER,
		"bounce_retention": DISTANCE_BOUNCE_RETENTION,
		"spinback_mult": DISTANCE_SPINBACK_MULTIPLIER,
		"drag_scale": DISTANCE_DRAG_SCALE,
		"lift_scale": DISTANCE_LIFT_SCALE,
		"index": 2,
		"display_name": "Distance Ball",
		"short_name": "Distance",
	},
}


## Normalizes any legacy/int/string representation into "standard", "soft", or "distance".
static func normalize_ball_type(ball_type: Variant) -> String:
	if typeof(ball_type) == TYPE_INT or typeof(ball_type) == TYPE_FLOAT:
		return index_to_id(int(ball_type))
	var s := str(ball_type).strip_edges().to_lower()
	if s in ["soft", "soft_ball", "soft ball", "tour_soft", "tour soft", "1"]:
		return TYPE_SOFT
	if s in ["distance", "distance_ball", "distance ball", "firm", "distance_firm", "distance / firm", "2"]:
		return TYPE_DISTANCE
	return TYPE_STANDARD


static func _get_profile(ball_type: String) -> Dictionary:
	return _BALL_PROFILES.get(normalize_ball_type(ball_type), _BALL_PROFILES[TYPE_STANDARD])


static func id_to_index(ball_type: String) -> int:
	return int(_get_profile(ball_type)["index"])


static func index_to_id(idx: int) -> String:
	match idx:
		1:
			return TYPE_SOFT
		2:
			return TYPE_DISTANCE
		_:
			return TYPE_STANDARD


static func id_to_display_name(ball_type: String) -> String:
	return str(_get_profile(ball_type)["display_name"])


static func id_to_short_name(ball_type: String) -> String:
	return str(_get_profile(ball_type)["short_name"])


static func get_speed_multiplier(ball_type: String) -> float:
	return float(_get_profile(ball_type)["speed_mult"])


static func get_spin_multiplier(ball_type: String) -> float:
	return float(_get_profile(ball_type)["spin_mult"])


static func get_rollout_factor(ball_type: String) -> float:
	return float(_get_profile(ball_type)["rollout_factor"])


static func get_friction_multiplier(ball_type: String) -> float:
	return float(_get_profile(ball_type)["friction_mult"])


static func get_bounce_retention_multiplier(ball_type: String) -> float:
	return float(_get_profile(ball_type)["bounce_retention"])


static func get_spinback_multiplier(ball_type: String) -> float:
	return float(_get_profile(ball_type)["spinback_mult"])


static func get_drag_scale_multiplier(ball_type: String) -> float:
	return float(_get_profile(ball_type)["drag_scale"])


static func get_lift_scale_multiplier(ball_type: String) -> float:
	return float(_get_profile(ball_type)["lift_scale"])


## Returns true when the shot payload represents a putting stroke.
static func is_putt_shot(data: Dictionary, fallback_club: String = "") -> bool:
	if data == null:
		return false
	if str(data.get("ShotType", "")).strip_edges().to_lower() == "putt":
		return true
	if data.has("BallData") and data["BallData"] is Dictionary:
		if str(data["BallData"].get("ShotType", "")).strip_edges().to_lower() == "putt":
			return true
	var club_str := str(data.get("Club", data.get("club", "")))
	if club_str.is_empty() and data.has("BallData") and data["BallData"] is Dictionary:
		club_str = str(data["BallData"].get("Club", data["BallData"].get("club", "")))
	if club_str.is_empty():
		club_str = fallback_club
	var c := club_str.strip_edges().to_lower()
	return c in ["pt", "putt", "putter"] or c.begins_with("putt")


static func _get_root_node(node_name: String) -> Node:
	if Engine.has_singleton(node_name):
		return Engine.get_singleton(node_name)
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree and main_loop.root != null and main_loop.root.has_node(node_name):
		return main_loop.root.get_node(node_name)
	return null


## Resolves the active player's configured ball type ("standard", "soft", or "distance").
static func get_active_ball_type() -> String:
	var mp = _get_root_node("MultiplayerManager")
	if mp != null:
		var mp_players = mp.get("players")
		if mp_players is Array and not mp_players.is_empty() and mp.has_method("get_active_player"):
			var active_p = mp.call("get_active_player")
			if active_p is Dictionary and not active_p.is_empty():
				if active_p.has("ball_type"):
					return normalize_ball_type(active_p["ball_type"])
				var ap_name := str(active_p.get("name", "")).strip_edges()
				if not ap_name.is_empty() and mp.has_method("get_player_ball_type"):
					return normalize_ball_type(mp.call("get_player_ball_type", ap_name))

	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree and main_loop.current_scene != null:
		var current_scene = main_loop.current_scene
		if current_scene.has_method("get_active_player_name") and mp != null:
			var scene_player := str(current_scene.call("get_active_player_name")).strip_edges()
			if not scene_player.is_empty() and mp.has_method("get_registered_player"):
				var reg = mp.call("get_registered_player", scene_player)
				if reg is Dictionary and not reg.is_empty():
					return normalize_ball_type(reg.get("ball_type", TYPE_STANDARD))
		var r_ui = current_scene.find_child("RangeUI", true, false)
		if r_ui != null and r_ui.has_method("get_selected_player_name") and mp != null:
			var sel_name := str(r_ui.call("get_selected_player_name")).strip_edges()
			if not sel_name.is_empty() and mp.has_method("get_registered_player"):
				var reg = mp.call("get_registered_player", sel_name)
				if reg is Dictionary and not reg.is_empty():
					return normalize_ball_type(reg.get("ball_type", TYPE_STANDARD))
		var p_node = current_scene.get_node_or_null("Player")
		if p_node == null:
			p_node = current_scene.find_child("Player", true, false)
		if p_node != null:
			var p_ball = p_node.get("ball")
			if p_ball != null and p_ball.has_method("get_ball_type"):
				return normalize_ball_type(p_ball.call("get_ball_type"))

	if mp != null and mp.has_method("get_default_range_profile_name") and mp.has_method("get_registered_player"):
		var def_name := str(mp.call("get_default_range_profile_name")).strip_edges()
		if not def_name.is_empty():
			var reg = mp.call("get_registered_player", def_name)
			if reg is Dictionary and not reg.is_empty():
				return normalize_ball_type(reg.get("ball_type", TYPE_STANDARD))

	var gs = _get_root_node("GlobalSettings")
	if gs != null and "range_settings" in gs and gs.range_settings != null and "ball_type" in gs.range_settings:
		return index_to_id(int(gs.range_settings.ball_type.value))

	return TYPE_STANDARD


## Applies the active or overridden ball type's speed and spin multipliers to a shot payload.
## Idempotent per shot payload and a complete no-op for "standard" or putting strokes.
static func apply_ball_type_to_shot_data(data: Dictionary, ball_type_override: String = "", fallback_club: String = "") -> void:
	if data == null or data.is_empty():
		return
	var ball_type := normalize_ball_type(ball_type_override) if not ball_type_override.is_empty() else get_active_ball_type()
	if ball_type == TYPE_STANDARD:
		return
	if data.get("_ball_type_applied", false):
		return
	if is_putt_shot(data, fallback_club):
		return

	if data.has("BallData") and data["BallData"] is Dictionary:
		apply_ball_type_to_shot_data(data["BallData"], ball_type, fallback_club)

	var speed_mult := get_speed_multiplier(ball_type)
	var spin_mult := get_spin_multiplier(ball_type)

	data["_ball_type_applied"] = true
	data["_ball_type"] = ball_type

	var raw_speed: float = float(data.get("Speed", data.get("BallSpeed", 0.0)))
	if raw_speed > 0.0 and not is_nan(raw_speed) and not is_inf(raw_speed):
		data["_original_ball_type_speed"] = raw_speed
		var adj_speed := raw_speed * speed_mult
		data["Speed"] = adj_speed
		if data.has("BallSpeed"):
			data["BallSpeed"] = adj_speed

	if data.has("TotalSpin"):
		var raw_total_spin := float(data["TotalSpin"])
		data["_original_ball_type_total_spin"] = raw_total_spin
		data["TotalSpin"] = maxf(0.0, raw_total_spin * spin_mult)
	if data.has("total_spin"):
		data["total_spin"] = maxf(0.0, float(data["total_spin"]) * spin_mult)
	if data.has("Spin"):
		data["Spin"] = maxf(0.0, float(data["Spin"]) * spin_mult)

	for spin_key in ["BackSpin", "back_spin", "SideSpin", "side_spin"]:
		if data.has(spin_key):
			data[spin_key] = float(data[spin_key]) * spin_mult

	for dist_key in ["Distance", "CarryDistance", "Carry", "TotalDistance", "distance", "carry", "total_distance", "carry_distance"]:
		if data.has(dist_key) and float(data[dist_key]) > 0.0:
			data["_original_ball_type_" + dist_key] = float(data[dist_key])
			data[dist_key] = float(data[dist_key]) * speed_mult

	var club_speed: float = float(data.get("ClubSpeed", 0.0))
	if club_speed > 0.1 and data.has("Speed"):
		data["SmashFactor"] = float(data["Speed"]) / club_speed
	elif data.has("SmashFactor") and float(data["SmashFactor"]) > 0.0:
		data["SmashFactor"] = float(data["SmashFactor"]) * speed_mult

	if raw_speed > 0.0:
		print("[BallTypePhysics] Applied %s ball adjustments (speed=%.2fx, spin=%.2fx, rollout=%.2fx). Speed: %.1f -> %.1f mph" % [
			id_to_display_name(ball_type), speed_mult, spin_mult, get_rollout_factor(ball_type),
			raw_speed, float(data.get("Speed", raw_speed))
		])
