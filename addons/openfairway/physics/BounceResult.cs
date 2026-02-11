using Godot;

/// <summary>
/// Bounce calculation result.
/// Standalone file so Godot registers it as a global script class for GDScript access.
/// </summary>
[GlobalClass]
public partial class BounceResult : RefCounted
{
    [Export] public Vector3 NewVelocity { get; set; }
    [Export] public Vector3 NewOmega { get; set; }
    [Export] public PhysicsEnums.BallState NewState { get; set; }

    public BounceResult() { }

    public BounceResult(Vector3 vel, Vector3 omg, PhysicsEnums.BallState st)
    {
        NewVelocity = vel;
        NewOmega = omg;
        NewState = st;
    }
}
