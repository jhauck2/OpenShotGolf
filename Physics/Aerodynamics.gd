extends Node

# Aerodynamic constants
const KELVIN_CELSIUS : float = 273.15
const PRESSURE_AT_SEALEVEL : float = 101325.0 # Pa
const EARTH_GRAVITY : float = 9.80665 # m/s^2
const MOLAR_MASS_DRY_AIR : float = 0.0289644 # J/(mol*K)
const UNIVERSAL_GAS_CONSTANT : float = 8.314462618 # J/(mol*K)
const GAS_CONSTANT_DRY_AIR : float = 287.058  # J/(kg*K)
const DYN_VISCOSITY_ZERO_DEGREE : float = 1.716e-05 # kg/(m*s)
const SUTHERLAND_CONSTANT : float = 198.72 # (source: NASA)
const FEET_TO_METERS : float = 0.3048

var ClTableLowRe : Resource = null
var ClTableHiRe : Resource = null
var CdTableLowRe : Resource = null
var CdTableHiRe : Resource = null

var density : float = 1.0225 # kg/m3
var viscosity : float # dynamic viscosity


func _ready() -> void:
	# instantiate Cl and Cd tables
	ClTableLowRe = load("res://Physics/LookupTables/cl_data_low_re.gd").new()
	# TODO: Generate data for cl_data_hi_re
	ClTableHiRe = load("res://Physics/LookupTables/cl_data_hi_re.gd").new()
	# TODO: Generate data for cd_data_low_re
	CdTableLowRe = load("res://Physics/LookupTables/cd_data_low_re.gd").new()
	CdTableHiRe = load("res://Physics/LookupTables/cd_data_hi_re.gd").new()
	
	# TODO: move these values to "EnvironmentSettings"
	SetAirDensity(GlobalSettings.range_settings.altitude.value, 
				  GlobalSettings.range_settings.temperature.value,
				  GlobalSettings.range_settings.range_units.value)
				
	SetDynamicViscosity(GlobalSettings.range_settings.temperature.value,
						GlobalSettings.range_settings.range_units.value)
						
	print("Re @ 200 mph = " + str(int(GetRe(200.0*0.44704, BPhysics.RADIUS))))

func FahrenheitToCelsius(tempF : float) -> float:
	return (tempF - 32.0)*5.0/9.0
	

func TempToKelvin(temp: float, units: PhysicsEnums.Units) -> float:
	var tempK : float = 0.0
	
	# Convert to metric if needed
	if (units == PhysicsEnums.Units.IMPERIAL):
		tempK = FahrenheitToCelsius(temp) + KELVIN_CELSIUS
	else:
		tempK = temp + KELVIN_CELSIUS
		
	return tempK

# Calculate air density using the barometric formula
func SetAirDensity(altitude : float, temp : float, units : PhysicsEnums.Units) -> float:
	var tempK : float = TempToKelvin(temp, units)
	var altitudeM : float = 0.0
	
	# Convert to metric if needed
	if (units == PhysicsEnums.Units.IMPERIAL):
		altitudeM = altitude * FEET_TO_METERS
	else:
		altitudeM = altitude
		
	# Barometric formula
	var exponent : float = (-EARTH_GRAVITY*MOLAR_MASS_DRY_AIR*altitudeM) / (UNIVERSAL_GAS_CONSTANT*tempK)
	var pressure : float = PRESSURE_AT_SEALEVEL * exp(exponent)
	
	density = pressure / (GAS_CONSTANT_DRY_AIR*tempK)
	return density

func SetDynamicViscosity(temp: float, units: PhysicsEnums.Units) -> float:
	var tempK :float = TempToKelvin(temp, units)
	
	# Sutherland formula
	viscosity = DYN_VISCOSITY_ZERO_DEGREE*pow(tempK/KELVIN_CELSIUS,1.5)*(KELVIN_CELSIUS+SUTHERLAND_CONSTANT)/(tempK+SUTHERLAND_CONSTANT)
	return viscosity

func GetRe(speed: float, radius: float) -> float:
	return density*speed*radius*2.0/viscosity

# From Bearman & harvey (1976) - Re > 1.26e5 : Cd -> F(spin)
func GetCd(Re: float, spin: float) -> float:
	if Re > 126000.0:
		return GetCdHiRe(spin)
	else:
		return GetCdLowRe(Re, spin)

func GetCdLowRe(Re: float, spin: float) -> float:
		# Get min and max Re values from table
	var ReMin : float = CdTableLowRe.reValues[0]
	var ReMax : float = CdTableLowRe.reValues[-1]
	
	# Get min and max spin values from table
	var spinMin : float = CdTableLowRe.spinValues[0]
	var spinMax : float = CdTableLowRe.spinValues[-1]
	
	var ReIndexBelow : int = 0
	var ReIndexAbove : int = 1
	var spinIndexBelow : int = 0
	var spinIndexAbove : int = 1
	
	# Check for off table
	if Re < ReMin:
		ReIndexAbove = 0
	elif Re > ReMax:
		ReIndexBelow = CdTableLowRe.reValues.size()-1
		ReIndexAbove = CdTableLowRe.reValues.size()-1
	else: # Get bounding values
		for i in range(1, CdTableLowRe.reValues.size()):
			if Re < CdTableLowRe.reValues[i]:
				ReIndexAbove = i
				ReIndexBelow = i - 1
				break
		
	if spin < spinMin:
		spinIndexAbove = 0
	elif spin > spinMax:
		spinIndexBelow = CdTableLowRe.spinValues.size()-1
		spinIndexAbove = CdTableLowRe.spinValues.size()-1
	else:
		for i in range(1, CdTableLowRe.spinValues.size()):
			if spin < CdTableLowRe.spinValues[i]:
				spinIndexAbove = i
				spinIndexBelow = i - 1
				break
	
	if ReIndexBelow == ReIndexBelow:
		if spinIndexBelow == spinIndexAbove:
			return CdTableLowRe.data[spinIndexBelow][ReIndexBelow]
		else:
			var spinBelow : float = CdTableLowRe.spinValues[spinIndexBelow]
			var spinAbove : float = CdTableLowRe.spinValues[spinIndexAbove]
			var weight : float = (spin - spinBelow)/(spinAbove - spinBelow)
			return lerpf(CdTableLowRe.data[spinIndexBelow][ReIndexBelow], CdTableLowRe.data[spinIndexAbove][ReIndexBelow], weight)
	else:
		var spinBelow : float = CdTableLowRe.spinValues[spinIndexBelow]
		var spinAbove : float = CdTableLowRe.spinValues[spinIndexAbove]
		var weightSpin : float = (spin - spinBelow)/(spinAbove - spinBelow)
		var clLowRe : float = lerpf(CdTableLowRe.data[spinIndexBelow][ReIndexBelow], CdTableLowRe.data[spinIndexAbove][ReIndexBelow], weightSpin)
		
		var ClHiRe: float = lerpf(CdTableLowRe.data[spinIndexBelow][ReIndexAbove], CdTableLowRe.data[spinIndexAbove][ReIndexAbove], weightSpin)
		
		var ReBelow : float = CdTableLowRe.reValues[ReIndexBelow]
		var ReAbove : float = CdTableLowRe.revalues[ReIndexAbove]
		var weightRe : float = (Re - ReBelow)/(ReAbove - ReBelow)
		
		return lerpf(clLowRe, ClHiRe, weightRe)

func GetCdHiRe(spin: float) -> float:
	# Get min and max Re values from table
	var spinMin : float = CdTableHiRe.spinValues[0]
	var spinMax : float = CdTableHiRe.spinValues[-1]
	
	# Check for values off-table
	if spin < spinMin:
		return CdTableHiRe.data[0]
	if spin > spinMax:
		return CdTableHiRe.data[-1]
		
	# Get value from table
	# find bounding indices
	var index_below : int = 0
	var index_above : int = 0
	
	for i in range(1,CdTableHiRe.spinValues.size()-1):
		if spin < CdTableHiRe.spinValues[i]:
			index_below = i-1
			index_above = i
			break
	
	var cd_below : float = CdTableHiRe.data[index_below]
	var cd_above : float = CdTableHiRe.data[index_above]
	var weight : float = (spin - CdTableHiRe.spinValues[index_below])/(CdTableHiRe.spinValues[index_above] - CdTableHiRe.spinValues[index_below])
	
	if abs(cd_below - cd_above) < 0.001:
		return cd_below
		
	# interpolate between values
	return lerpf(cd_below, cd_above, weight)

# From Bearman & harvey (1976) - Re > 1.26e5 : Cd -> F(spin)
func GetCl(Re: float, spin: float) -> float:
	if Re > 126000:
		return GetClHiRe(spin)
	else:
		return GetClLowRe(Re, spin)


func GetClHiRe(spin: float) -> float:
		# Get min and max Re values from table
	var spinMin : float = ClTableHiRe.spinValues[0]
	var spinMax : float = ClTableHiRe.spinValues[-1]
	
	# Check for values off-table
	if spin < spinMin:
		return ClTableHiRe.data[0]
	if spin > spinMax:
		return ClTableHiRe.data[-1]
		
	# Get value from table
	# find bounding indices
	var index_below : int = 0
	var index_above : int = 0
	
	for i in range(1,ClTableHiRe.spinValues.size()-1):
		if spin < ClTableHiRe.spinValues[i]:
			index_below = i-1
			index_above = i
			break
	
	var cd_below : float = ClTableHiRe.data[index_below]
	var cd_above : float = ClTableHiRe.data[index_above]
	var weight : float = (spin - ClTableHiRe.spinValues[index_below])/(ClTableHiRe.spinValues[index_above] - ClTableHiRe.spinValues[index_below])
	
	if abs(cd_below - cd_above) < 0.001:
		return cd_below
		
	# interpolate between values
	return lerpf(cd_below, cd_above, weight)


func GetClLowRe(Re: float, spin: float) -> float:
	# Get min and max Re values from table
	var ReMin : float = ClTableLowRe.reValues[0]
	var ReMax : float = ClTableLowRe.reValues[-1]
	
	# Get min and max spin values from table
	var spinMin : float = ClTableLowRe.spinValues[0]
	var spinMax : float = ClTableLowRe.spinValues[-1]
	
	var ReIndexBelow : int = 0
	var ReIndexAbove : int = 1
	var spinIndexBelow : int = 0
	var spinIndexAbove : int = 1
	
	# Check for off table
	if Re < ReMin:
		ReIndexAbove = 0
	elif Re > ReMax:
		ReIndexBelow = ClTableLowRe.reValues.size()-1
		ReIndexAbove = ClTableLowRe.reValues.size()-1
	else: # Get bounding values
		for i in range(1, ClTableLowRe.reValues.size()):
			if Re < ClTableLowRe.reValues[i]:
				ReIndexAbove = i
				ReIndexBelow = i - 1
				break
		
	if spin < spinMin:
		spinIndexAbove = 0
	elif spin > spinMax:
		spinIndexBelow = ClTableLowRe.spinValues.size()-1
		spinIndexAbove = ClTableLowRe.spinValues.size()-1
	else:
		for i in range(1, ClTableLowRe.spinValues.size()):
			if spin < ClTableLowRe.spinValues[i]:
				spinIndexAbove = i
				spinIndexBelow = i - 1
				break
	
	if ReIndexBelow == ReIndexBelow:
		if spinIndexBelow == spinIndexAbove:
			return ClTableLowRe.data[spinIndexBelow][ReIndexBelow]
		else:
			var spinBelow : float = ClTableLowRe.spinValues[spinIndexBelow]
			var spinAbove : float = ClTableLowRe.spinValues[spinIndexAbove]
			var weight : float = (spin - spinBelow)/(spinAbove - spinBelow)
			return lerpf(ClTableLowRe.data[spinIndexBelow][ReIndexBelow], ClTableLowRe.data[spinIndexAbove][ReIndexBelow], weight)
	else:
		var spinBelow : float = ClTableLowRe.spinValues[spinIndexBelow]
		var spinAbove : float = ClTableLowRe.spinValues[spinIndexAbove]
		var weightSpin : float = (spin - spinBelow)/(spinAbove - spinBelow)
		var clLowRe : float = lerpf(ClTableLowRe.data[spinIndexBelow][ReIndexBelow], ClTableLowRe.data[spinIndexAbove][ReIndexBelow], weightSpin)
		
		var ClHiRe: float = lerpf(ClTableLowRe.data[spinIndexBelow][ReIndexAbove], ClTableLowRe.data[spinIndexAbove][ReIndexAbove], weightSpin)
		
		var ReBelow : float = ClTableLowRe.reValues[ReIndexBelow]
		var ReAbove : float = ClTableLowRe.revalues[ReIndexAbove]
		var weightRe : float = (Re - ReBelow)/(ReAbove - ReBelow)
		
		return lerpf(clLowRe, ClHiRe, weightRe)
