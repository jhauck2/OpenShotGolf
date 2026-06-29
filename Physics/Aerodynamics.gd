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

var ClTable : Resource = null
var CdTable : Resource = null

var density : float = 1.0225 # kg/m3
var viscosity : float # dynamic viscosity


func _ready() -> void:
	# instantiate Cl and Cd tables
	ClTable = load("res://Physics/LookupTables/cl_data.gd").new()
	CdTable = load("res://Physics/LookupTables/cd_data.gd").new()
	# TODO: move these values to "EnvironmentSettings"
	SetAirDensity(GlobalSettings.range_settings.altitude.value, 
				  GlobalSettings.range_settings.temperature.value,
				  GlobalSettings.range_settings.range_units.value)
				
	SetDynamicViscosity(GlobalSettings.range_settings.temperature.value,
						GlobalSettings.range_settings.range_units.value)

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

func GetCd(Re: float) -> float:
	# Get min and max Re values from table
	var ReMin : float = CdTable.reValues[0]
	var ReMax : float = CdTable.reValues[-1]
	
	# Check for values off-table
	if Re < ReMin:
		return CdTable.data[0]
	if Re > ReMax:
		return CdTable.data[-1]
		
	# Get value from table
	# find bounding indices
	var index_below : int = 0
	var index_above : int = 0
	
	for i in range(1,CdTable.reValues.size()):
		if Re < CdTable.reValues[i]:
			index_below = i-1
			index_above = i
			break
	
	var cd_below : float = CdTable.data[index_below]
	var cd_above : float = CdTable.data[index_above]
	var weight : float = (Re - CdTable.reValues[index_below])/(CdTable.reValues[index_above] - CdTable.reValues[index_below])
	
	if abs(cd_below - cd_above) < 0.001:
		return cd_below
		
	# interpolate between values
	return lerpf(cd_below, cd_above, weight)


func GetCl(Re: float, spin: float) -> float:
	# Get min and max Re values from table
	var ReMin : float = ClTable.reValues[0]
	var ReMax : float = ClTable.reValues[-1]
	
	# Get min and max spin values from table
	var spinMin : float = ClTable.spinValues[0]
	var spinMax : float = ClTable.spinValues[-1]
	
	var ReIndexBelow : int = 0
	var ReIndexAbove : int = 1
	var spinIndexBelow : int = 0
	var spinIndexAbove : int = 1
	
	# Check for off table
	if Re < ReMin:
		ReIndexAbove = 0
	elif Re > ReMax:
		ReIndexBelow = ClTable.reValues.size()-1
		ReIndexAbove = ClTable.reValues.size()-1
	else: # Get bounding values
		for i in range(1, ClTable.reValues.size()):
			if Re < ClTable.reValues[i]:
				ReIndexAbove = i
				ReIndexBelow = i - 1
				break
		
	if spin < spinMin:
		spinIndexAbove = 0
	elif spin > spinMax:
		spinIndexBelow = ClTable.spinValues.size()-1
		spinIndexAbove = ClTable.spinValues.size()-1
	else:
		for i in range(1, ClTable.spinValues.size()):
			if spin < ClTable.spinValues[i]:
				spinIndexAbove = i
				spinIndexBelow = i - 1
				break
	
	if ReIndexBelow == ReIndexBelow:
		if spinIndexBelow == spinIndexAbove:
			return ClTable.data[spinIndexBelow][ReIndexBelow]
		else:
			var spinBelow : float = ClTable.spinValues[spinIndexBelow]
			var spinAbove : float = ClTable.spinValues[spinIndexAbove]
			var weight : float = (spin - spinBelow)/(spinAbove - spinBelow)
			return lerpf(ClTable.data[spinIndexBelow][ReIndexBelow], ClTable.data[spinIndexAbove][ReIndexBelow], weight)
	else:
		var spinBelow : float = ClTable.spinValues[spinIndexBelow]
		var spinAbove : float = ClTable.spinValues[spinIndexAbove]
		var weightSpin : float = (spin - spinBelow)/(spinAbove - spinBelow)
		var clLowRe : float = lerpf(ClTable.data[spinIndexBelow][ReIndexBelow], ClTable.data[spinIndexAbove][ReIndexBelow], weightSpin)
		
		var ClHiRe: float = lerpf(ClTable.data[spinIndexBelow][ReIndexAbove], ClTable.data[spinIndexAbove][ReIndexAbove], weightSpin)
		
		var ReBelow : float = ClTable.reValues[ReIndexBelow]
		var ReAbove : float = ClTable.revalues[ReIndexAbove]
		var weightRe : float = (Re - ReBelow)/(ReAbove - ReBelow)
		
		return lerpf(clLowRe, ClHiRe, weightRe)
