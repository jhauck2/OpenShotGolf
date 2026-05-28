using Godot;

/// <summary>
/// Plain resolved physics values that can be validated in tests before
/// being materialized into a Godot PhysicsParams resource at runtime.
/// </summary>
public sealed class ResolvedPhysicsParams(
    float airDensity,
    float airViscosity,
    float dragScale,
    float liftScale,
    float kineticFriction,
    float rollingFriction,
    float grassViscosity,
    float criticalAngle,
    PhysicsEnums.SurfaceType surfaceType,
    Vector3 floorNormal,
    float rolloutImpactSpin,
    float spinbackResponseScale,
    float spinbackThetaBoostMax,
    float spinbackSpinStartRpm,
    float spinbackSpinEndRpm,
    float spinbackSpeedStartMps,
    float spinbackSpeedEndMps,
    float initialLaunchAngleDeg,
    FlightProfile flightProfile = null)
{
    public float AirDensity { get; } = airDensity;
    public float AirViscosity { get; } = airViscosity;
    public float DragScale { get; } = dragScale;
    public float LiftScale { get; } = liftScale;
    public float KineticFriction { get; } = kineticFriction;
    public float RollingFriction { get; } = rollingFriction;
    public float GrassViscosity { get; } = grassViscosity;
    public float CriticalAngle { get; } = criticalAngle;
    public PhysicsEnums.SurfaceType SurfaceType { get; } = surfaceType;
    public Vector3 FloorNormal { get; } = floorNormal;
    public float RolloutImpactSpin { get; } = rolloutImpactSpin;
    public float SpinbackResponseScale { get; } = spinbackResponseScale;
    public float SpinbackThetaBoostMax { get; } = spinbackThetaBoostMax;
    public float SpinbackSpinStartRpm { get; } = spinbackSpinStartRpm;
    public float SpinbackSpinEndRpm { get; } = spinbackSpinEndRpm;
    public float SpinbackSpeedStartMps { get; } = spinbackSpeedStartMps;
    public float SpinbackSpeedEndMps { get; } = spinbackSpeedEndMps;
    public float InitialLaunchAngleDeg { get; } = initialLaunchAngleDeg;
    public FlightProfile FlightProfile { get; } = flightProfile ?? FlightProfile.Default;

    public PhysicsParams ToPhysicsParams()
    {
        return new PhysicsParams(
            AirDensity,
            AirViscosity,
            DragScale,
            LiftScale,
            KineticFriction,
            RollingFriction,
            GrassViscosity,
            CriticalAngle,
            SurfaceType,
            FloorNormal,
            RolloutImpactSpin,
            SpinbackResponseScale,
            SpinbackThetaBoostMax,
            SpinbackSpinStartRpm,
            SpinbackSpinEndRpm,
            SpinbackSpeedStartMps,
            SpinbackSpeedEndMps,
            InitialLaunchAngleDeg,
            FlightProfile
        );
    }
}
