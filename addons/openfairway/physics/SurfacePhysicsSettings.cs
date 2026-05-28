using Godot.Collections;

/// <summary>
/// Typed surface tuning values used to build physics parameters.
/// </summary>
public sealed class SurfacePhysicsSettings(
    PhysicsEnums.SurfaceType surfaceType,
    float kineticFriction,
    float rollingFriction,
    float grassViscosity,
    float criticalAngle,
    float spinbackResponseScale,
    float spinbackThetaBoostMax,
    float spinbackSpinStartRpm,
    float spinbackSpinEndRpm,
    float spinbackSpeedStartMps,
    float spinbackSpeedEndMps)
{
    public PhysicsEnums.SurfaceType SurfaceType { get; } = surfaceType;
    public float KineticFriction { get; } = kineticFriction;
    public float RollingFriction { get; } = rollingFriction;
    public float GrassViscosity { get; } = grassViscosity;
    public float CriticalAngle { get; } = criticalAngle;
    public float SpinbackResponseScale { get; } = spinbackResponseScale;
    public float SpinbackThetaBoostMax { get; } = spinbackThetaBoostMax;
    public float SpinbackSpinStartRpm { get; } = spinbackSpinStartRpm;
    public float SpinbackSpinEndRpm { get; } = spinbackSpinEndRpm;
    public float SpinbackSpeedStartMps { get; } = spinbackSpeedStartMps;
    public float SpinbackSpeedEndMps { get; } = spinbackSpeedEndMps;

    public Dictionary ToDictionary()
    {
        return new Dictionary
        {
            { "u_k", KineticFriction },
            { "u_kr", RollingFriction },
            { "nu_g", GrassViscosity },
            { "theta_c", CriticalAngle },
            { "spinback_response_scale", SpinbackResponseScale },
            { "spinback_theta_boost_max", SpinbackThetaBoostMax },
            { "spinback_spin_start_rpm", SpinbackSpinStartRpm },
            { "spinback_spin_end_rpm", SpinbackSpinEndRpm },
            { "spinback_speed_start_mps", SpinbackSpeedStartMps },
            { "spinback_speed_end_mps", SpinbackSpeedEndMps }
        };
    }
}
