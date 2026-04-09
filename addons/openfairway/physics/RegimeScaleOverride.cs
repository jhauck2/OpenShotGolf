/// <summary>
/// Runtime-safe scale modifiers keyed by launch regime. These are intentionally
/// limited to multipliers and offsets already supported by BallPhysicsProfile so
/// regime tuning can stay bounded and predictable.
/// </summary>
public sealed class RegimeScaleOverride
{
    public float DragScaleMultiplier { get; set; } = 1.0f;
    public float LiftScaleMultiplier { get; set; } = 1.0f;
    public float KineticFrictionMultiplier { get; set; } = 1.0f;
    public float RollingFrictionMultiplier { get; set; } = 1.0f;
    public float GrassViscosityMultiplier { get; set; } = 1.0f;
    public float CriticalAngleOffsetRadians { get; set; } = 0.0f;
    public float SpinbackThetaBoostMultiplier { get; set; } = 1.0f;

    public static RegimeScaleOverride Neutral { get; } = new();
}
