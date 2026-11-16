/// <summary>
/// Centralizes all bounce/COR constants from BallPhysics.CalculateBounce.
/// Default values match the prior hardcoded constants for behavioral parity.
/// </summary>
public sealed class BounceProfile
{
    // --- COR curve ---
    public float CorBaseA { get; init; } = 0.45f;
    public float CorBaseB { get; init; } = -0.01f;
    public float CorBaseC { get; init; } = 0.0002f;
    public float CorHighSpeedCap { get; init; } = 0.25f;
    public float CorHighSpeedThreshold { get; init; } = 20.0f;
    public float CorKillThreshold { get; init; } = 2.0f;

    // --- Tangential retention (first bounce from flight) ---
    public float FlightTangentialRetentionBase { get; init; } = 0.60f;
    public float FlightSpinFactorMin { get; init; } = 0.15f;
    public float FlightSpinFactorDivisor { get; init; } = 6500.0f;
    public float FlightLowSpinThreshold { get; init; } = 2500.0f;
    public float ShallowImpactRetentionMin { get; init; } = 0.32f;
    public float ShallowImpactRetentionMax { get; init; } = 0.48f;

    // --- Tangential retention (rollout bounces) ---
    public float RolloutLowSpinRetention { get; init; } = 0.865f;
    public float RolloutHighSpinRetention { get; init; } = 0.725f;
    public float RolloutSpinRatioThreshold { get; init; } = 0.20f;

    // --- Spin COR reduction ---
    public float SpinCorLowSpinThreshold { get; init; } = 1500.0f;
    public float SpinCorLowSpinMaxReduction { get; init; } = 0.30f;
    public float SpinCorHighSpinRangeRpm { get; init; } = 1500.0f;
    public float SpinCorHighSpinAdditionalReduction { get; init; } = 0.40f;

    // --- Velocity scaling for COR reduction ---
    public float CorVelocityLowThreshold { get; init; } = 12.0f;
    public float CorVelocityMidThreshold { get; init; } = 25.0f;
    public float CorVelocityLowScale { get; init; } = 0.50f;

    // --- Rollout bounce COR ---
    public float RolloutBounceCorKillThreshold { get; init; } = 4.0f;
    public float RolloutBounceCorScale { get; init; } = 0.5f;

    // --- Penner model ---
    public float PennerLowEnergyThreshold { get; init; } = 20.0f;

    // --- Metadata ---
    public string Name { get; init; } = "Default";
    public string Version { get; init; } = "1.0";

    public static BounceProfile Default { get; } = new()
    {
        Name = "Fairway",
        Version = "1.0",
        FlightTangentialRetentionBase = 0.64f,
        ShallowImpactRetentionMin = 0.62f,
        ShallowImpactRetentionMax = 0.78f,
        RolloutLowSpinRetention = 0.85f,
        RolloutHighSpinRetention = 0.62f
    };

    public static BounceProfile Green { get; } = new()
    {
        Name = "Green",
        Version = "1.0",
        CorBaseA = 0.42f,
        CorHighSpeedCap = 0.22f,
        FlightTangentialRetentionBase = 0.58f,
        ShallowImpactRetentionMin = 0.55f,
        ShallowImpactRetentionMax = 0.70f,
        RolloutLowSpinRetention = 0.88f,
        RolloutHighSpinRetention = 0.74f
    };

    public static BounceProfile Rough { get; } = new()
    {
        Name = "Rough",
        Version = "1.0",
        CorBaseA = 0.28f,
        CorHighSpeedCap = 0.16f,
        CorKillThreshold = 2.5f,
        FlightTangentialRetentionBase = 0.45f,
        ShallowImpactRetentionMin = 0.40f,
        ShallowImpactRetentionMax = 0.52f,
        RolloutLowSpinRetention = 0.60f,
        RolloutHighSpinRetention = 0.45f,
        RolloutBounceCorScale = 0.35f
    };

    public static BounceProfile FairwaySoft { get; } = new()
    {
        Name = "FairwaySoft",
        Version = "1.0",
        CorBaseA = 0.38f,
        CorHighSpeedCap = 0.20f,
        FlightTangentialRetentionBase = 0.55f,
        ShallowImpactRetentionMin = 0.50f,
        ShallowImpactRetentionMax = 0.66f,
        RolloutLowSpinRetention = 0.78f,
        RolloutHighSpinRetention = 0.65f
    };

    public static BounceProfile Firm { get; } = new()
    {
        Name = "Firm",
        Version = "1.0",
        CorBaseA = 0.52f,
        CorHighSpeedCap = 0.30f,
        FlightTangentialRetentionBase = 0.72f,
        ShallowImpactRetentionMin = 0.66f,
        ShallowImpactRetentionMax = 0.82f,
        RolloutLowSpinRetention = 0.90f,
        RolloutHighSpinRetention = 0.78f
    };

    public static BounceProfile CartPath { get; } = new()
    {
        Name = "CartPath",
        Version = "1.0",
        CorBaseA = 0.75f,
        CorBaseB = -0.008f,
        CorBaseC = 0.00015f,
        CorHighSpeedCap = 0.62f,
        CorHighSpeedThreshold = 20.0f,
        CorKillThreshold = 1.0f,
        FlightTangentialRetentionBase = 0.88f,
        ShallowImpactRetentionMin = 0.84f,
        ShallowImpactRetentionMax = 0.94f,
        RolloutLowSpinRetention = 0.94f,
        RolloutHighSpinRetention = 0.84f,
        SpinCorLowSpinMaxReduction = 0.15f,
        SpinCorHighSpinAdditionalReduction = 0.15f,
        RolloutBounceCorKillThreshold = 1.5f,
        RolloutBounceCorScale = 0.75f,
        PennerLowEnergyThreshold = 18.0f
    };

    public static BounceProfile Bunker { get; } = new()
    {
        Name = "Bunker",
        Version = "1.0",
        CorBaseA = 0.08f,
        CorBaseB = -0.003f,
        CorBaseC = 0.00004f,
        CorHighSpeedCap = 0.05f,
        CorHighSpeedThreshold = 15.0f,
        CorKillThreshold = 3.5f,
        FlightTangentialRetentionBase = 0.18f,
        FlightSpinFactorMin = 0.20f,
        FlightSpinFactorDivisor = 4000.0f,
        ShallowImpactRetentionMin = 0.15f,
        ShallowImpactRetentionMax = 0.20f,
        RolloutLowSpinRetention = 0.30f,
        RolloutHighSpinRetention = 0.20f,
        RolloutSpinRatioThreshold = 0.20f,
        RolloutBounceCorKillThreshold = 6.0f,
        RolloutBounceCorScale = 0.15f,
        PennerLowEnergyThreshold = 30.0f
    };

    public static BounceProfile ForSurface(PhysicsEnums.SurfaceType surface, bool isInSand = false)
    {
        if (isInSand || surface == PhysicsEnums.SurfaceType.Bunker)
            return Bunker;

        return surface switch
        {
            PhysicsEnums.SurfaceType.Green => Green,
            PhysicsEnums.SurfaceType.Rough => Rough,
            PhysicsEnums.SurfaceType.FairwaySoft => FairwaySoft,
            PhysicsEnums.SurfaceType.Firm => Firm,
            PhysicsEnums.SurfaceType.CartPath => CartPath,
            _ => Default
        };
    }
}
