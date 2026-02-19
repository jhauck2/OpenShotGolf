using System;
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

	// Lift coefficient cap to prevent ballooning on high-spin shots
	public const float CL_MAX = 0.55f;

	// Read-only property for GDScript access to constant (private set satisfies [Export] requirement)
	[Export] public float ClMax { get => CL_MAX; private set { } }

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
		if (Re < 50000.0f)
			return 0.5f;
		if (Re > 200000.0f)
			return 0.2f;

		// Polynomial fit to experimental data
		return 1.1948f - 0.0000209661f * Re + 1.42472e-10f * Re * Re - 3.14383e-16f * Re * Re * Re;
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
		// Low Reynolds number - minimal lift
		if (Re < 50000.0f)
			return 0.1f;

		// High Reynolds number - use linear model directly
		if (Re > 75000.0f)
			return Mathf.Clamp(ClHighRe(spinRatio), 0.0f, CL_MAX);

		// Interpolation between polynomial models for 50k <= Re <= 75k
		int[] reValues = { 50000, 60000, 65000, 70000, 75000 };
		int reHighIndex = reValues.Length - 1;

		for (int i = 0; i < reValues.Length; i++)
		{
			if (Re <= reValues[i])
			{
				reHighIndex = i;
				break;
			}
		}

		int reLowIndex = Mathf.Max(reHighIndex - 1, 0);

		Func<float, float>[] clFunctions = {
			ClRe50k,
			ClRe60k,
			ClRe65k,
			ClRe70k,
			ClHighRe
		};

		float clLow = clFunctions[reLowIndex](spinRatio);
		float clHigh = clFunctions[reHighIndex](spinRatio);
		float reLow = reValues[reLowIndex];
		float reHigh = reValues[reHighIndex];

		float weight = 0.0f;
		if (reHigh != reLow)
		{
			weight = (Re - reLow) / (reHigh - reLow);
		}

		float clInterpolated = Mathf.Lerp(clLow, clHigh, weight);
		return Mathf.Clamp(clInterpolated, 0.0f, CL_MAX);
	}

	// Polynomial models for different Reynolds number ranges
	private float ClRe50k(float S)
	{
		return 0.0472121f + 2.84795f * S - 23.4342f * S * S + 45.4849f * S * S * S;
	}

	private float ClRe60k(float S)
	{
		return 0.320524f - 4.7032f * S + 14.0613f * S * S;
	}

	private float ClRe65k(float S)
	{
		return 0.266667f - 4.0f * S + 13.3333f * S * S;
	}

	private float ClRe70k(float S)
	{
		return 0.0496189f + 0.00211396f * S + 2.34201f * S * S;
	}

	private float ClHighRe(float S)
	{
		// Linear model for high Reynolds numbers (Re >= 75k)
		// Calibrated to match realistic carry distances
		// Cap at 0.38 to prevent ballooning
		float linearCl = 1.3f * S + 0.05f;
		return Mathf.Min(linearCl, 0.38f);
	}
}
