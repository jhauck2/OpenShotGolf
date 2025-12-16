extends Object
class_name SurfaceUtil

# Returns ground interaction parameters for a given surface preset.
# theta_c is the critical bounce angle in radians (from Penner's golf physics)
# https://raypenner.com/golf-physics.pdf
static func get_params(surface: int) -> Dictionary:
	match surface:
		Enums.Surface.ROUGH:
			return {"u_k": 0.15, "u_kr": 0.05, "nu_g": 0.0005, "theta_c": 0.38} # ~22°, high grip
		Enums.Surface.FAIRWAY:
			return {"u_k": 0.42, "u_kr": 0.18, "nu_g": 0.0020, "theta_c": 0.30} # ~17°, medium grip
		Enums.Surface.FIRM:
			return {"u_k": 0.08, "u_kr": 0.02, "nu_g": 0.0002, "theta_c": 0.21} # ~12°, low grip
		_:
			return {"u_k": 0.42, "u_kr": 0.18, "nu_g": 0.0020, "theta_c": 0.30}
