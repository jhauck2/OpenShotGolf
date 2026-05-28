using Godot;

/// <summary>
/// Aerodynamic coefficient calculations for golf ball flight simulation.
/// Provides drag (Cd) and lift (Cl) coefficients based on Reynolds number
/// and spin ratio, using polynomial interpolations from wind tunnel data.
/// </summary>
[GlobalClass]
public partial class Aerodynamics : RefCounted
{
	// Physical constants
	private const float KELVIN_CELSIUS = 273.15f;
	private const float PRESSURE_AT_SEALEVEL = 101325.0f;  // Pa
	private const float EARTH_GRAVITY = 9.80665f;  // m/s²
	private const float MOLAR_MASS_DRY_AIR = 0.0289644f;  // kg/mol
	private const float UNIVERSAL_GAS_CONSTANT = 8.314462618f;  // J/(mol*K)
	private const float GAS_CONSTANT_DRY_AIR = 287.058f;  // J/(kg*K)
	private const float DYN_VISCOSITY_ZERO_DEGREE = 1.716e-05f;  // kg/(m*s)
	private const float SUTHERLAND_CONSTANT = 198.72f;  // K (source: NASA)
	private const float FEET_TO_METERS = 0.3048f;

	// Physically realistic coefficient bounds for dimpled golf balls in-play.
	// Sources in project docs (Bearman/Harvey, R&A studies) place Cd and Cl
	// in a narrower range than the prior ad-hoc high-Re fit.
	public const float CL_MAX_BASE = 0.268f;
	public const float CL_MAX_HIGH_SPIN = 0.32f;
	public static float CD_MIN => FlightAerodynamicsModel.CdMin;

	// Read-only property for GDScript access to constants (private set satisfies [Export] requirement)
	[Export] public float ClMax { get => CL_MAX_BASE; private set { } }
	[Export] public float ClMaxHighSpin { get => CL_MAX_HIGH_SPIN; private set { } }
	[Export] public float CdMin { get => CD_MIN; private set { } }

	/// <summary>
	/// Convert Fahrenheit to Celsius
	/// </summary>
	private float FahrenheitToCelsius(float tempF)
	{
		return (tempF - 32.0f) * 5.0f / 9.0f;
	}

	/// <summary>
	/// Calculate air density using the barometric formula.
	/// </summary>
	/// <param name="altitude">Altitude in feet (Imperial) or meters (Metric)</param>
	/// <param name="temp">Temperature in Fahrenheit (Imperial) or Celsius (Metric)</param>
	/// <param name="units">Unit system being used</param>
	/// <returns>Air density in kg/m³</returns>
	public float GetAirDensity(float altitude, float temp, PhysicsEnums.Units units)
	{
		float tempK;
		float altitudeM;

		if (units == PhysicsEnums.Units.Imperial)
		{
			tempK = FahrenheitToCelsius(temp) + KELVIN_CELSIUS;
			altitudeM = altitude * FEET_TO_METERS;
		}
		else
		{
			tempK = temp + KELVIN_CELSIUS;
			altitudeM = altitude;
		}

		// Barometric formula: https://en.wikipedia.org/wiki/Barometric_formula
		float exponent = (-EARTH_GRAVITY * MOLAR_MASS_DRY_AIR * altitudeM) / (UNIVERSAL_GAS_CONSTANT * tempK);
		float pressure = PRESSURE_AT_SEALEVEL * Mathf.Exp(exponent);

		return pressure / (GAS_CONSTANT_DRY_AIR * tempK);
	}

	/// <summary>
	/// Calculate dynamic air viscosity using Sutherland's formula.
	/// </summary>
	/// <param name="temp">Temperature in Fahrenheit (Imperial) or Celsius (Metric)</param>
	/// <param name="units">Unit system being used</param>
	/// <returns>Dynamic viscosity in kg/(m*s)</returns>
	public float GetDynamicViscosity(float temp, PhysicsEnums.Units units)
	{
		float tempK;

		if (units == PhysicsEnums.Units.Imperial)
		{
			tempK = FahrenheitToCelsius(temp) + KELVIN_CELSIUS;
		}
		else
		{
			tempK = temp + KELVIN_CELSIUS;
		}

		// Sutherland formula
		return DYN_VISCOSITY_ZERO_DEGREE * Mathf.Pow(tempK / KELVIN_CELSIUS, 1.5f) *
			(KELVIN_CELSIUS + SUTHERLAND_CONSTANT) / (tempK + SUTHERLAND_CONSTANT);
	}

	/// <summary>
	/// Calculate drag coefficient based on Reynolds number.
	/// Uses polynomial interpolation from wind tunnel data.
	/// </summary>
	/// <param name="Re">Reynolds number</param>
	/// <returns>Drag coefficient (Cd)</returns>
	public float GetCd(float Re)
	{
		return FlightAerodynamicsModel.GetCd(Re);
	}

	/// <summary>
	/// Calculate lift coefficient based on Reynolds number and spin ratio.
	/// Uses polynomial interpolations from wind tunnel data with Reynolds-dependent blending.
	/// </summary>
	/// <param name="Re">Reynolds number</param>
	/// <param name="spinRatio">Spin ratio (omega * radius / velocity)</param>
	/// <returns>Lift coefficient (Cl)</returns>
	public float GetCl(float Re, float spinRatio)
	{
		return FlightAerodynamicsModel.GetCl(Re, spinRatio);
	}
}
