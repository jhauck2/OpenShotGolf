class_name Surface

# Utility class for ground surface physics parameters.
# Provides friction coefficients and interaction parameters for different playing surfaces.
enum SurfaceType {FAIRWAY, FAIRWAY_SOFT, ROUGH, FIRM}
## Returns ground interaction parameters for a given surface type.
## Parameters returned:
## - u_k: Kinetic friction coefficient (sliding)
## - u_kr: Rolling friction coefficient
## - nu_g: Grass drag viscosity
## - theta_c: Critical bounce angle in radians (from Penner's golf physics)
static func get_params(surface: SurfaceType) -> Dictionary:
	match surface:
		SurfaceType.ROUGH:
			# High grip, more friction - ball checks up quickly
			return {
				"u_k": 0.15,
				"u_kr": 0.05,
				"nu_g": 0.0005,
				"theta_c": 0.38  # ~22 deg
			}
		SurfaceType.FAIRWAY:
			# Normal fairway - good conditions with 30-40 yd rollout, low rpm, high ball speed, low apex.
			return {
				"u_k": 0.30,      # Lower kinetic friction for less skid loss
				"u_kr": 0.015,    # Proper rolling resistance
				"nu_g": 0.0010,   # Less grass drag for better rollout
				"theta_c": 0.25   # ~14 deg - firmer surface
			}
		SurfaceType.FAIRWAY_SOFT:
			# Soft/wet fairway - reduced rollout (~20-30 yds)
			return {
				"u_k": 0.42,      # Higher kinetic friction
				"u_kr": 0.18,     # Higher rolling resistance
				"nu_g": 0.0020,   # More grass drag
				"theta_c": 0.30   # ~17 deg - softer surface
			}
		SurfaceType.FIRM:
			# Low grip - ball runs out more
			return {
				"u_k": 0.08,
				"u_kr": 0.02,
				"nu_g": 0.0002,
				"theta_c": 0.21  # ~12 deg
			}
		_:
			# Default to normal fairway
			return {
				"u_k": 0.30,
				"u_kr": 0.015,
				"nu_g": 0.0010,
				"theta_c": 0.25
			}
