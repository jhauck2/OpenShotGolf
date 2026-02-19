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
    [Export] public Vector3 FloorNormal { get; set; }
    [Export] public float RolloutImpactSpin { get; set; }  // Spin RPM when ball first landed for rollout

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
        Vector3 floorNormal,
        float rolloutImpactSpin = 0.0f)
    {
        AirDensity = airDensity;
        AirViscosity = airViscosity;
        DragScale = dragScale;
        LiftScale = liftScale;
        KineticFriction = kineticFriction;
        RollingFriction = rollingFriction;
        GrassViscosity = grassViscosity;
        CriticalAngle = criticalAngle;
        FloorNormal = floorNormal;
        RolloutImpactSpin = rolloutImpactSpin;
    }
}
