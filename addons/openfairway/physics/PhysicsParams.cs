using Godot;

/// <summary>
/// Physics parameters structure for golf ball simulation.
/// Standalone file so Godot registers it as a global script class for GDScript access.
/// </summary>
[GlobalClass]
public partial class PhysicsParams : Resource
{
    [Export] public float AirDensity { get; set; }
    [Export] public float AirViscosity { get; set; }
    [Export] public float DragScale { get; set; }
    [Export] public float LiftScale { get; set; }
    [Export] public float KineticFriction { get; set; }
    [Export] public float RollingFriction { get; set; }
    [Export] public float GrassViscosity { get; set; }
    [Export] public float CriticalAngle { get; set; }
    [Export] public PhysicsEnums.SurfaceType SurfaceType { get; set; } = PhysicsEnums.SurfaceType.Fairway;
    /// <summary>
    /// Surface/Floor normal at the ball's ground contact point.
    /// Expected to be a unit vector; zero-length is treated as Vector3.Up (flat ground).
    /// </summary>
    [Export] public Vector3 FloorNormal { get; set; }
    [Export] public float RolloutImpactSpin { get; set; }  // Spin RPM when ball first landed for rollout
    [Export] public float SpinbackResponseScale { get; set; } = 1.0f;

    // Spinback parameters — non-zero values enable check/spin-back behavior on steep high-spin impacts.
    [Export] public float SpinbackThetaBoostMax { get; set; }
    [Export] public float SpinbackSpinStartRpm { get; set; }
    [Export] public float SpinbackSpinEndRpm { get; set; }
    [Export] public float SpinbackSpeedStartMps { get; set; }
    [Export] public float SpinbackSpeedEndMps { get; set; }
    [Export] public float InitialLaunchAngleDeg { get; set; }

    public FlightProfile FlightProfile { get; set; } = FlightProfile.Default;

    public PhysicsParams() { }

    public PhysicsParams(
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
        float rolloutImpactSpin = 0.0f,
        float spinbackResponseScale = 1.0f,
        float spinbackThetaBoostMax = 0.0f,
        float spinbackSpinStartRpm = 0.0f,
        float spinbackSpinEndRpm = 0.0f,
        float spinbackSpeedStartMps = 0.0f,
        float spinbackSpeedEndMps = 0.0f,
        float initialLaunchAngleDeg = 0.0f,
        FlightProfile flightProfile = null)
    {
        AirDensity = airDensity;
        AirViscosity = airViscosity;
        DragScale = dragScale;
        LiftScale = liftScale;
        KineticFriction = kineticFriction;
        RollingFriction = rollingFriction;
        GrassViscosity = grassViscosity;
        CriticalAngle = criticalAngle;
        SurfaceType = surfaceType;
        FloorNormal = floorNormal;
        RolloutImpactSpin = rolloutImpactSpin;
        SpinbackResponseScale = spinbackResponseScale;
        SpinbackThetaBoostMax = spinbackThetaBoostMax;
        SpinbackSpinStartRpm = spinbackSpinStartRpm;
        SpinbackSpinEndRpm = spinbackSpinEndRpm;
        SpinbackSpeedStartMps = spinbackSpeedStartMps;
        SpinbackSpeedEndMps = spinbackSpeedEndMps;
        InitialLaunchAngleDeg = initialLaunchAngleDeg;
        FlightProfile = flightProfile ?? FlightProfile.Default;
    }
}
