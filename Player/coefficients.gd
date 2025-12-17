class_name Coefficients
extends RefCounted

# Compatibility wrapper that forwards aerodynamic calculations to the new physics/aerodynamics.gd
const Aerodynamics = preload("res://physics/aerodynamics.gd")

static func get_air_density(altitude: float, temp: float) -> float:
	return Aerodynamics.get_air_density(altitude, temp, Enums.Units.IMPERIAL)  # units are handled upstream now

static func get_dynamic_air_viscosity(temp: float) -> float:
	return Aerodynamics.get_dynamic_viscosity(temp, Enums.Units.IMPERIAL)

static func get_cd(Re: float) -> float:
	return Aerodynamics.get_cd(Re)

static func get_cl(Re: float, spin_ratio: float) -> float:
	return Aerodynamics.get_cl(Re, spin_ratio)
