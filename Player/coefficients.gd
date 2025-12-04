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

static func FtoC(temp: float) -> float:
	return (temp - 32)* 5/9

static func get_air_density(altitude: float, temp: float) -> float:
	var tempK : float
	var altitudeMeters : float
	if GlobalSettings.range_settings.range_units.value == Enums.Units.IMPERIAL:
		tempK = FtoC(temp) + KELVIN_CELCIUS
		altitudeMeters = altitude * 0.3048
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
		tempK= FtoC(temp) + KELVIN_CELCIUS
	else:
		tempK = temp + KELVIN_CELCIUS
	
	# Sutherland formula
	return DYN_VISCOSITY_ZERO_DEGREE * pow((tempK / KELVIN_CELCIUS), 1.5) * (KELVIN_CELCIUS + SUTHERLAND_CONSTANT) / (tempK + SUTHERLAND_CONSTANT)

static func get_Cd(Re: float) -> float:
	# Piecewise interpolation based on World Journal of Mechanics 2018 (Jenkins et al.)
	# Commercial balls: Cd ≈ 0.275 ± 0.022 for Re > 8e4, larger at low Re with a drop around 60–70k.
	var cd_points := [
		Vector2(30000.0, 0.45),
		Vector2(50000.0, 0.38),
		Vector2(70000.0, 0.30),
		Vector2(90000.0, 0.275),
		Vector2(130000.0, 0.29),
		Vector2(200000.0, 0.30)
	]
	
	if Re <= cd_points[0].x:
		return cd_points[0].y
	if Re >= cd_points[cd_points.size() - 1].x:
		return cd_points[cd_points.size() - 1].y
	
	for i in range(cd_points.size() - 1):
		var a = cd_points[i]
		var b = cd_points[i + 1]
		if Re >= a.x and Re <= b.x:
			var t: float = (Re - a.x) / (b.x - a.x)
			return lerpf(a.y, b.y, t)
	
	return cd_points[cd_points.size() - 1].y

static func get_Cl(Re: float, S: float) -> float:
	# Low and high S
	if S < 0.05:
		return 0.05
	if S > .35:
		if Re > 12.5e4:
			return .3
		else:
			return -1.34786 + 0.0000354549*Re - 1.847e-10*Re*Re
	
	# Low and high Reynolds number
	if Re < 50000:
		return 0.1
	if Re > 75000:
		return .203 
		
	# Calculations
	var Re_values: Array[int] = [50000, 60000, 65000, 70000, 75000]
	var Re_low_index := 0
	var Re_high_index := 0
	# Get bounding values for Reynolds number
	for val in Re_values:
		if Re > val:
			Re_low_index = Re_values.find(val)
		if Re < val:
			Re_high_index = Re_values.find(val)
			break
	
	var ClCallables : Array[Callable] = [Re50kToCl, Re60kToCl, Re65kToCl, Re70kToCl, Re75kToCl]
	
	# Get lower and upper bounds on Cl based on Re bounds and S
	var Cl_low = ClCallables[Re_low_index].call(S)
	var Cl_high = ClCallables[Re_high_index].call(S)
	var weight : float = (Re - Re_values[Re_low_index])/(Re_values[Re_high_index] - Re_values[Re_low_index])
	
	# Interpolate final Cl value from uper and lower Cl
	return lerpf(Cl_low, Cl_high, weight)

static func Re50kToCl(S: float) -> float:
	return 0.0472121 + 2.84795*S - 23.4342*S*S + 45.4849*S*S*S
	
static func Re60kToCl(S: float) -> float:
	return 0.320524 - 4.7032*S + 14.0613*S*S

static func Re65kToCl(S: float) -> float:
	return 0.266667 - 4*S + 13.3333*S*S
	
static func Re70kToCl(S: float) -> float:
	return 0.0496189 + 0.00211396*S + 2.34201*S*S
	
static func Re75kToCl(S: float) -> float:
	return 1.1*S + 0.01
