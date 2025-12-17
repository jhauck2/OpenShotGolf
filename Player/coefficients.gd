extends Object
class_name Coefficients

const KELVIN_CELCIUS = 273.15

const PRESSURE_AT_SEALEVEL = 101325.0 # Unit: [Pa]
const EARTH_ACCELERATION_SPEED = 9.80665 # Unit: [m/s^2]
const MOLAR_MASS_DRY_AIR = 0.0289644 # Unit: [kg/mol]
const UNIVERSAL_GAS_CONSTANT = 8.314462618 # Unit: [J/(mol*K)]
const GAS_CONSTANT_DRY_AIR = 287.058 # Unit: [J/(kg*K)]
const DYN_VISCOSITY_ZERO_DEGREE = 1.716e-05 # Unit: [kg/(m*s)]
const SUTHERLAND_CONSTANT = 198.72 # Unit: [K] Source: https://www.grc.nasa.gov/www/BGH/viscosity.html
const FEET_TO_METERS = 0.3048

static func FtoC(temp: float) -> float:
	return (temp - 32)* 5/9

static func get_air_density(altitude: float, temp: float) -> float:
	var tempK : float
	var altitudeMeters : float
	if GlobalSettings.range_settings.range_units.value == Enums.Units.IMPERIAL:
		tempK = FtoC(temp) + KELVIN_CELCIUS
		altitudeMeters = altitude * FEET_TO_METERS
	else:
		tempK = temp + KELVIN_CELCIUS
		altitudeMeters = altitude
	
	# calculation through barometric formula. Source: https://en.wikipedia.org/wiki/Barometric_formula
	var exponent = (-EARTH_ACCELERATION_SPEED * MOLAR_MASS_DRY_AIR * altitudeMeters) / (UNIVERSAL_GAS_CONSTANT * tempK)
	var pressure = PRESSURE_AT_SEALEVEL * exp(exponent)
	
	return pressure / (GAS_CONSTANT_DRY_AIR * tempK)
	
static func get_dynamic_air_viscosity(temp: float) -> float:
	var tempK : float
	if GlobalSettings.range_settings.range_units.value == Enums.Units.IMPERIAL:
		tempK = FtoC(temp) + KELVIN_CELCIUS
	else:
		tempK = temp + KELVIN_CELCIUS
	
	# Sutherland formula
	return DYN_VISCOSITY_ZERO_DEGREE * pow((tempK / KELVIN_CELCIUS), 1.5) * (KELVIN_CELCIUS + SUTHERLAND_CONSTANT) / (tempK + SUTHERLAND_CONSTANT)

static func get_Cd(Re: float) -> float:
	if Re < 50000.0:
		return 0.5
	if Re > 200000.0:
		return 0.2
		
	return 1.1948 - 0.0000209661*Re + 1.42472e-10*Re*Re - 3.14383e-16*Re*Re*Re

static func get_Cl(Re: float, S: float) -> float:
	# Maximum Cl cap to prevent ballooning on high-spin shots
	# This applies to ALL code paths
	# 0.55 gives better carry on lower-speed shots while still preventing ballooning
	const CL_MAX = 0.55

	# Low Reynolds number
	if Re < 50000:
		return 0.1

	# For Re > 75k, use ReHighToCl directly
	if Re > 75000:
		return clampf(ReHighToCl(S), 0.0, CL_MAX)

	# Interpolation between polynomial models for 50k <= Re <= 75k
	var Re_values: Array[int] = [50000, 60000, 65000, 70000, 75000]
	var Re_high_index: int = Re_values.size() - 1
	for val in Re_values:
		if Re <= val:
			Re_high_index = Re_values.find(val)
			break
	var Re_low_index: int = max(Re_high_index - 1, 0)

	var ClCallables : Array[Callable] = [Re50kToCl, Re60kToCl, Re65kToCl, Re70kToCl, ReHighToCl]

	# Get lower and upper bounds on Cl based on Re bounds and S
	var Cl_low = ClCallables[Re_low_index].call(S)
	var Cl_high = ClCallables[Re_high_index].call(S)
	var Re_low: float = Re_values[Re_low_index]
	var Re_high: float = Re_values[Re_high_index]
	var weight : float = 0.0
	if Re_high != Re_low:
		weight = (Re - Re_low)/(Re_high - Re_low)

	# Interpolate final Cl value from upper and lower Cl, apply cap
	# Allow natural polynomial output (may be near-zero for low spin cases)
	var Cl_interpolated = lerpf(Cl_low, Cl_high, weight)
	return clampf(Cl_interpolated, 0.0, CL_MAX)

static func Re50kToCl(S: float) -> float:
	return 0.0472121 + 2.84795*S - 23.4342*S*S + 45.4849*S*S*S
	
static func Re60kToCl(S: float) -> float:
	# Polynomial fitted to experimental data - allow natural output including near-zero
	return 0.320524 - 4.7032*S + 14.0613*S*S

static func Re65kToCl(S: float) -> float:
	# Polynomial fitted to experimental data - allow natural output including near-zero
	return 0.266667 - 4*S + 13.3333*S*S

static func Re70kToCl(S: float) -> float:
	# Polynomial fitted to experimental data - allow natural output including near-zero
	return 0.0496189 + 0.00211396*S + 2.34201*S*S
	
static func ReHighToCl(S: float) -> float:
	# Linear model for high Reynolds numbers (Re >= 60k)
	# Calibrated to match GSPro carry distances:
	#   1.8 caused ballooning (45% too high apex)
	#   1.1 was ~10 yards short on carry
	#   1.3 is good for normal spin, but needs cap for high spin
	# Cap at 0.38 to prevent ballooning - apex was 2x too high at 0.45
	var linear_cl = 1.3*S + 0.05
	return min(linear_cl, 0.38)
