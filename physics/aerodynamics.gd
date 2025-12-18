class_name Aerodynamics

# Aerodynamic coefficient calculations for golf ball flight simulation.
# Provides drag (Cd) and lift (Cl) coefficients based on Reynolds number
# and spin ratio, using polynomial interpolations from wind tunnel data.

# Physical constants
const KELVIN_CELSIUS := 273.15
const PRESSURE_AT_SEALEVEL := 101325.0  # Pa
const EARTH_GRAVITY := 9.80665  # m/s^2
const MOLAR_MASS_DRY_AIR := 0.0289644  # kg/mol
const UNIVERSAL_GAS_CONSTANT := 8.314462618  # J/(mol*K)
const GAS_CONSTANT_DRY_AIR := 287.058  # J/(kg*K)
const DYN_VISCOSITY_ZERO_DEGREE := 1.716e-05  # kg/(m*s)
const SUTHERLAND_CONSTANT := 198.72  # K (source: NASA)
const FEET_TO_METERS := 0.3048

# Lift coefficient cap to prevent ballooning on high-spin shots
const CL_MAX := 0.55


static func fahrenheit_to_celsius(temp_f: float) -> float:
	return (temp_f - 32.0) * 5.0 / 9.0


# Calculate air density using the barometric formula.
static func get_air_density(altitude: float, temp: float, units: Enums.Units) -> float:
	var temp_k: float
	var altitude_m: float

	if units == Enums.Units.IMPERIAL:
		temp_k = fahrenheit_to_celsius(temp) + KELVIN_CELSIUS
		altitude_m = altitude * FEET_TO_METERS
	else:
		temp_k = temp + KELVIN_CELSIUS
		altitude_m = altitude

	# Barometric formula: https://en.wikipedia.org/wiki/Barometric_formula
	var exponent := (-EARTH_GRAVITY * MOLAR_MASS_DRY_AIR * altitude_m) / (UNIVERSAL_GAS_CONSTANT * temp_k)
	var pressure := PRESSURE_AT_SEALEVEL * exp(exponent)

	return pressure / (GAS_CONSTANT_DRY_AIR * temp_k)


# Calculate dynamic air viscosity using Sutherland's formula.
static func get_dynamic_viscosity(temp: float, units: Enums.Units) -> float:
	var temp_k: float

	if units == Enums.Units.IMPERIAL:
		temp_k = fahrenheit_to_celsius(temp) + KELVIN_CELSIUS
	else:
		temp_k = temp + KELVIN_CELSIUS

	# Sutherland formula
	return DYN_VISCOSITY_ZERO_DEGREE * pow(temp_k / KELVIN_CELSIUS, 1.5) * \
		(KELVIN_CELSIUS + SUTHERLAND_CONSTANT) / (temp_k + SUTHERLAND_CONSTANT)


# Calculate drag coefficient based on Reynolds number.
static func get_cd(Re: float) -> float:
	if Re < 50000.0:
		return 0.5
	if Re > 200000.0:
		return 0.2

	# Polynomial fit to experimental data
	return 1.1948 - 0.0000209661 * Re + 1.42472e-10 * Re * Re - 3.14383e-16 * Re * Re * Re


# Calculate lift coefficient based on Reynolds number and spin ratio.
static func get_cl(Re: float, spin_ratio: float) -> float:
	# Low Reynolds number - minimal lift
	if Re < 50000:
		return 0.1

	# High Reynolds number - use linear model directly
	if Re > 75000:
		return clampf(_cl_high_re(spin_ratio), 0.0, CL_MAX)

	# Interpolation between polynomial models for 50k <= Re <= 75k
	var Re_values: Array[int] = [50000, 60000, 65000, 70000, 75000]
	var Re_high_index: int = Re_values.size() - 1

	for i in range(Re_values.size()):
		if Re <= Re_values[i]:
			Re_high_index = i
			break

	var Re_low_index: int = maxi(Re_high_index - 1, 0)

	var cl_functions: Array[Callable] = [
		_cl_re_50k,
		_cl_re_60k,
		_cl_re_65k,
		_cl_re_70k,
		_cl_high_re
	]

	var cl_low: float = cl_functions[Re_low_index].call(spin_ratio)
	var cl_high: float = cl_functions[Re_high_index].call(spin_ratio)
	var Re_low: float = Re_values[Re_low_index]
	var Re_high: float = Re_values[Re_high_index]

	var weight := 0.0
	if Re_high != Re_low:
		weight = (Re - Re_low) / (Re_high - Re_low)

	var cl_interpolated := lerpf(cl_low, cl_high, weight)
	return clampf(cl_interpolated, 0.0, CL_MAX)


# Polynomial models for different Reynolds number ranges
static func _cl_re_50k(S: float) -> float:
	return 0.0472121 + 2.84795 * S - 23.4342 * S * S + 45.4849 * S * S * S


static func _cl_re_60k(S: float) -> float:
	return 0.320524 - 4.7032 * S + 14.0613 * S * S


static func _cl_re_65k(S: float) -> float:
	return 0.266667 - 4.0 * S + 13.3333 * S * S


static func _cl_re_70k(S: float) -> float:
	return 0.0496189 + 0.00211396 * S + 2.34201 * S * S


static func _cl_high_re(S: float) -> float:
	# Linear model for high Reynolds numbers (Re >= 75k)
	# Calibrated to match realistic carry distances
	# Cap at 0.38 to prevent ballooning
	var linear_cl := 1.3 * S + 0.05
	return minf(linear_cl, 0.38)
