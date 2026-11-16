extends Object
class_name PowerCalibration

## Utility class for applying a player-configured power calibration (-10% to +10%)
## to launch monitor ball speed so players can tune for monitors that read hot or cold.
## Defaults to 0% (no adjustment).

const MIN_PERCENT := -10.0
const MAX_PERCENT := 10.0
const DEFAULT_PERCENT := 0.0


static func _get_global_settings() -> Node:
	if Engine.has_singleton("GlobalSettings"):
		return Engine.get_singleton("GlobalSettings")
	var main_loop = Engine.get_main_loop()
	if main_loop != null and main_loop is SceneTree and main_loop.root != null and main_loop.root.has_node("GlobalSettings"):
		return main_loop.root.get_node("GlobalSettings")
	return null


## Calculates the ball speed multiplier for a given calibration percentage (-10 to +10).
static func calculate_multiplier(percent: float) -> float:
	if is_nan(percent) or is_inf(percent):
		return 1.0
	var clamped := clampf(percent, MIN_PERCENT, MAX_PERCENT)
	return 1.0 + (clamped / 100.0)


## Applies power calibration to a shot payload dictionary in-place.
## Guaranteed to be idempotent per shot payload (prevents double-scaling).
static func apply_calibration(data: Dictionary) -> void:
	if data.get("_power_calibration_applied", false):
		return

	var global_settings = _get_global_settings()
	if global_settings == null or not ("range_settings" in global_settings):
		return

	var range_settings = global_settings.range_settings
	if range_settings == null or not ("power_calibration_percent" in range_settings):
		return

	var percent: float = float(range_settings.power_calibration_percent.value)
	if is_nan(percent) or is_inf(percent):
		percent = DEFAULT_PERCENT
	percent = clampf(percent, MIN_PERCENT, MAX_PERCENT)

	data["_power_calibration_applied"] = true
	data["_power_calibration_pct"] = percent

	if is_zero_approx(percent):
		return

	var multiplier := calculate_multiplier(percent)
	if is_nan(multiplier) or is_inf(multiplier) or is_equal_approx(multiplier, 1.0):
		return

	var raw_speed: float = float(data.get("Speed", data.get("BallSpeed", 0.0)))
	if is_nan(raw_speed) or is_inf(raw_speed) or raw_speed <= 0.0:
		return

	var calibrated_speed: float = raw_speed * multiplier
	if is_nan(calibrated_speed) or is_inf(calibrated_speed):
		return

	data["Speed"] = calibrated_speed
	if data.has("BallSpeed"):
		data["BallSpeed"] = calibrated_speed

	# Keep SmashFactor consistent with the calibrated ball speed
	var raw_club_speed: float = float(data.get("ClubSpeed", 0.0))
	if raw_club_speed > 0.1 and not is_nan(raw_club_speed) and not is_inf(raw_club_speed):
		var smash: float = calibrated_speed / raw_club_speed
		if not is_nan(smash) and not is_inf(smash):
			data["SmashFactor"] = smash
	elif data.has("SmashFactor"):
		var raw_smash: float = float(data["SmashFactor"])
		if raw_smash > 0.0 and not is_nan(raw_smash) and not is_inf(raw_smash):
			var smash: float = raw_smash * multiplier
			if not is_nan(smash) and not is_inf(smash):
				data["SmashFactor"] = smash

	print("[PowerCalibration] Applied %+.1f%% power calibration. Speed: %.1f -> %.1f mph" % [
		percent, raw_speed, calibrated_speed
	])
