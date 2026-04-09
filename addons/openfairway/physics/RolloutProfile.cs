/// <summary>
/// Centralizes all rollout/friction constants from BallPhysics ground force logic.
/// Default values match the prior hardcoded constants for behavioral parity.
/// </summary>
public sealed class RolloutProfile
{
    // --- Velocity scaling ---
    public float ChipSpeedThreshold { get; init; } = 20.0f;
    public float PitchSpeedThreshold { get; init; } = 35.0f;
    public float ChipVelocityScaleMin { get; init; } = 0.60f;
    public float ChipVelocityScaleMax { get; init; } = 0.87f;

    // --- Spin thresholds ---
    public float LowSpinThreshold { get; init; } = 1750.0f;
    public float MidSpinThreshold { get; init; } = 1750.0f;

    // --- Spin friction multipliers ---
    public float LowSpinMultiplierMax { get; init; } = 1.15f;
    public float MidSpinMultiplierMax { get; init; } = 2.25f;
    public float HighSpinMultiplierMax { get; init; } = 2.50f;
    public float HighSpinRampRange { get; init; } = 1000.0f;

    // --- Friction blending ---
    public float FrictionBlendSpeed { get; init; } = 15.0f;
    public float TangentVelocityThreshold { get; init; } = 0.05f;

    // --- Metadata ---
    public string Name { get; init; } = "Default";
    public string Version { get; init; } = "1.0";

    public static RolloutProfile Default { get; } = new();
}
