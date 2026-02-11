/// <summary>
/// Physics-related enumerations for the golf simulation.
/// Used internally by C# physics classes. GDScript consumers use
/// the physics_enums.gd mirror instead (avoids duplicate class name).
/// </summary>
public static class PhysicsEnums
{
    /// <summary>
    /// Ball flight states
    /// </summary>
    public enum BallState
    {
        /// <summary>Ball is stationary</summary>
        Rest,
        /// <summary>Ball is in the air</summary>
        Flight,
        /// <summary>Ball is rolling on ground after landing</summary>
        Rollout
    }

    /// <summary>
    /// Measurement unit systems
    /// </summary>
    public enum Units
    {
        /// <summary>Meters, Celsius, etc.</summary>
        Metric,
        /// <summary>Yards, Fahrenheit, etc.</summary>
        Imperial
    }

    /// <summary>
    /// Ground surface types affecting ball behavior
    /// </summary>
    public enum SurfaceType
    {
        /// <summary>Normal fairway - good conditions with 35-60 yd rollout</summary>
        Fairway,
        /// <summary>Soft/wet fairway - reduced rollout (~20-30 yds)</summary>
        FairwaySoft,
        /// <summary>Longer grass, more friction</summary>
        Rough,
        /// <summary>Hard ground, less friction</summary>
        Firm
    }
}
