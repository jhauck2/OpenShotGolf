using Godot;
using Godot.Collections;

/// <summary>
/// Shared utilities for parsing launch monitor spin data and building
/// initial physics vectors from shot parameters. Used by both game-layer
/// nodes (GolfBall) and headless simulation (PhysicsAdapter).
/// </summary>
[GlobalClass]
public partial class ShotSetup : RefCounted
{
    public const float MPS_PER_MPH = 0.44704f;
    public const float RAD_PER_RPM = 0.10472f;
    public const float YARDS_PER_METER = 1.09361f;
    public const float FEET_PER_METER = 3.28084f;

    /// <summary>
    /// Normalize spin data from various launch-monitor input formats.
    /// Accepts any combination of BackSpin/SideSpin and TotalSpin/SpinAxis
    /// and fills in the missing values.
    /// Returns Dictionary { "backspin", "sidespin", "total", "axis" } (all floats, RPM / degrees).
    /// </summary>
    public Dictionary ParseSpin(Dictionary data)
    {
        return ParseSpin(data, true);
    }

    /// <summary>
    /// Internal overload that allows callers (such as per-frame UI formatting)
    /// to opt out of emitting consistency warnings every frame.
    /// </summary>
    public Dictionary ParseSpin(Dictionary data, bool emitConsistencyWarnings)
    {
        bool hasBackspin = data.ContainsKey("BackSpin");
        bool hasSidespin = data.ContainsKey("SideSpin");
        bool hasTotal = data.ContainsKey("TotalSpin");
        bool hasAxis = data.ContainsKey("SpinAxis");

        float backspin = (float)(data.ContainsKey("BackSpin") ? data["BackSpin"] : 0.0f);
        float sidespin = (float)(data.ContainsKey("SideSpin") ? data["SideSpin"] : 0.0f);
        float totalSpin = (float)(data.ContainsKey("TotalSpin") ? data["TotalSpin"] : 0.0f);
        float spinAxis = (float)(data.ContainsKey("SpinAxis") ? data["SpinAxis"] : 0.0f);

        // Derive total from components
        if (totalSpin == 0.0f && (hasBackspin || hasSidespin))
        {
            totalSpin = Mathf.Sqrt(backspin * backspin + sidespin * sidespin);
        }

        // Derive axis from components
        if (!hasAxis && (hasBackspin || hasSidespin))
        {
            spinAxis = Mathf.RadToDeg(Mathf.Atan2(sidespin, backspin));
        }

        // Derive components from total + axis
        if (hasTotal && hasAxis)
        {
            if (!hasBackspin)
            {
                backspin = totalSpin * Mathf.Cos(Mathf.DegToRad(spinAxis));
            }
            if (!hasSidespin)
            {
                sidespin = totalSpin * Mathf.Sin(Mathf.DegToRad(spinAxis));
            }
        }

        // Validate consistency: if all three are present, components are ground truth
        // (launch monitors measure backspin/sidespin directly; TotalSpin is derived)
        if (hasBackspin && hasSidespin && hasTotal)
        {
            float computedTotal = Mathf.Sqrt(backspin * backspin + sidespin * sidespin);
            if (Mathf.Abs(computedTotal - totalSpin) > 1.0f)
            {
                if (emitConsistencyWarnings)
                {
                    PhysicsLogger.Info($"  Spin data inconsistent: TotalSpin={totalSpin:F0} but sqrt(BS²+SS²)={computedTotal:F0}, using computed value");
                }
                totalSpin = computedTotal;
                spinAxis = Mathf.RadToDeg(Mathf.Atan2(sidespin, backspin));
            }
        }

        return new Dictionary
        {
            { "backspin", backspin },
            { "sidespin", sidespin },
            { "total", totalSpin },
            { "axis", spinAxis }
        };
    }

    /// <summary>
    /// Convert launch monitor data (mph, degrees, RPM) to physics vectors (m/s, rad/s).
    /// Returns Dictionary { "velocity": Vector3, "omega": Vector3, "shot_direction": Vector3 }.
    /// </summary>
    public Dictionary BuildLaunchVectors(float speedMph, float vlaDeg, float hlaDeg,
                                          float totalSpinRpm, float spinAxisDeg)
    {
        float backspinRpm = totalSpinRpm * Mathf.Cos(Mathf.DegToRad(spinAxisDeg));
        float sidespinRpm = totalSpinRpm * Mathf.Sin(Mathf.DegToRad(spinAxisDeg));

        return BuildLaunchVectorsFromComponents(speedMph, vlaDeg, hlaDeg, backspinRpm, sidespinRpm);
    }

    /// <summary>
    /// Build launch vectors from measured backspin and sidespin components.
    /// The spin vector is constructed in shot-local space, then rotated with
    /// the launch frame so backspin/sidespin stay aligned with the shot plane.
    /// </summary>
    public Dictionary BuildLaunchVectorsFromComponents(float speedMph, float vlaDeg, float hlaDeg,
        float backspinRpm, float sidespinRpm)
    {
        float speedMps = speedMph * MPS_PER_MPH;

        Vector3 velocity = new Vector3(speedMps, 0.0f, 0.0f)
            .Rotated(Vector3.Forward, Mathf.DegToRad(-vlaDeg))
            .Rotated(Vector3.Up, Mathf.DegToRad(-hlaDeg));

        Vector3 omega = new Vector3(0.0f, -sidespinRpm * RAD_PER_RPM, backspinRpm * RAD_PER_RPM)
            .Rotated(Vector3.Up, Mathf.DegToRad(-hlaDeg));

        Vector3 flatVelocity = new Vector3(velocity.X, 0.0f, velocity.Z);
        Vector3 shotDirection = flatVelocity.Length() > 0.001f ? flatVelocity.Normalized() : Vector3.Right;

        return new Dictionary
        {
            { "velocity", velocity },
            { "omega", omega },
            { "shot_direction", shotDirection }
        };
    }
}
