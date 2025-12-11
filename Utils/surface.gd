extends Object
class_name SurfaceUtil

# Returns ground interaction parameters for a given surface preset.
static func get_params(surface: int) -> Dictionary:
	match surface:
		Enums.Surface.FAIRWAY:
			return {"u_k": 0.15, "u_kr": 0.05, "nu_g": 0.0005}
		Enums.Surface.ROUGH:
			return {"u_k": 0.35, "u_kr": 0.15, "nu_g": 0.0015}
		Enums.Surface.FIRM:
			return {"u_k": 0.08, "u_kr": 0.02, "nu_g": 0.0002}
		_:
			return {"u_k": 0.15, "u_kr": 0.05, "nu_g": 0.0005}
