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
		tempK= FtoC(temp) + KELVIN_CELCIUS
	else:
		tempK = temp + KELVIN_CELCIUS
	
	# Sutherland formula
	return DYN_VISCOSITY_ZERO_DEGREE * pow((tempK / KELVIN_CELCIUS), 1.5) * (KELVIN_CELCIUS + SUTHERLAND_CONSTANT) / (tempK + SUTHERLAND_CONSTANT)

static func get_Cd(Re: float, S: float) -> float:
	
	if S < 0.47:
		if Re < 50000:
			return 0.5 # TODO: This needs work
		if Re < 238000:
			# Re and S are in the range for LT-DS1
			# Cd lookup table valid for 0 < S < 0.47, 5e4 < Re < 2.38e5
			var cd_lookup_table := [ #Spin factor - monotonically increasing, Cd
				[0.0, 0.271],
				[0.069819, 0.271],
				[0.073252, 0.275],
				[0.0805116, 0.28],
				[0.087273, 0.28],
				[0.10064, 0.3],
				[0.11834, 0.31],
				[0.1465, 0.33],
				[0.15303, 0.36], 
				[0.17186, 0.37],
				[0.18313, 0.385],
				[0.21976, 0.4],
				[0.30605, 0.45],
				[0.39896, 0.525],
				[0.47846, 0.55]
			]
			var cd_low_index := 0
			var cd_high_index := 0
			for i in range(cd_lookup_table.size()):
				if S < cd_lookup_table[i][0]:
					cd_high_index = i
					cd_low_index = max(0, i-1)
					break
					
			# Interpolate
			if cd_high_index == cd_low_index:
				return cd_lookup_table[cd_high_index][1]
			
			var cd_low = cd_lookup_table[cd_low_index][1]
			var cd_high = cd_lookup_table[cd_high_index][1]
			var S_low = cd_lookup_table[cd_low_index][0]
			var S_high = cd_lookup_table[cd_high_index][0]
			var weight = (S - S_low)/(S_high - S_low)
			return lerpf(cd_low, cd_high, weight)
			
		else: # Re > 238000
			return 0.2
	
	else: # S > 0.47
		if Re < 12057:
			return 0.55 # TODO: needs checking
		if Re < 15332: # Right S/Re combo for ILT-DS2
			return 0.66 # TODO: Implement iterpolated lookup tables from dataset 2
		else:
			return 0.5


static func get_Cl(Re: float, S: float) -> float:
	if S < 0.47:
		if Re < 50000:
			return 0.1 # TODO: This needs work
		if Re < 238000:
			# Re and S are in the range for LT-DS1
			# Cd lookup table valid for 0 < S < 0.47, 5e4 < Re < 2.38e5
			var cl_lookup_table := [ #Spin factor - monotonically increasing, Cd
				[0.0, 0.0],
				[0.01745, 0.1],
				[0.02864, 0.12],
				[0.04026, 0.13],
				[0.051, 0.15],
				[0.71, 0.17],
				[0.09467, 0.2],
				[0.1465, 0.33],
				[0.17186, 0.295], 
				[0.211976, 0.345],
				[0.25505, 0.375],
				[0.3192, 0.4],
				[0.39896, 0.43],
				[0.47846, 0.45]
			]
			var cl_low_index := 0
			var cl_high_index := 0
			for i in range(cl_lookup_table.size()):
				if S < cl_lookup_table[i][0]:
					cl_high_index = i
					cl_low_index = max(0, i-1)
					break
					
			# Interpolate
			if cl_high_index == cl_low_index:
				return cl_lookup_table[cl_high_index][1]
			
			var cl_low = cl_lookup_table[cl_low_index][1]
			var cl_high = cl_lookup_table[cl_high_index][1]
			var S_low = cl_lookup_table[cl_low_index][0]
			var S_high = cl_lookup_table[cl_high_index][0]
			var weight = (S - S_low)/(S_high - S_low)
			return lerpf(cl_low, cl_high, weight)
			
		else: # Re > 238000
			return 0.15
	
	else: # S > 0.47
		if Re < 12057:
			return 0.085 # TODO: needs checking
		if Re < 15332: # Right S/Re combo for ILT-DS2
			return 0.1 # TODO: Implement iterpolated lookup tables from dataset 2
		else:
			return 0.13
