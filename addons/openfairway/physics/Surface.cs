using Godot;
using Godot.Collections;

/// <summary>
/// Utility class for ground surface physics parameters.
/// Provides friction coefficients and interaction parameters for different
/// playing surfaces based on golf physics research.
/// Reference: https://raypenner.com/golf-physics.pdf
/// </summary>
[GlobalClass]
public partial class Surface : RefCounted
{
    /// <summary>
    /// Returns ground interaction parameters for a given surface type.
    /// Parameters returned:
    /// - u_k: Kinetic friction coefficient (sliding)
    /// - u_kr: Rolling friction coefficient
    /// - nu_g: Grass drag viscosity
    /// - theta_c: Critical bounce angle in radians (from Penner's golf physics)
    /// </summary>
    public Dictionary GetParams(PhysicsEnums.SurfaceType surface)
    {
        return SurfacePhysicsCatalog.Get(surface).ToDictionary();
    }
}
