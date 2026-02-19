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
        return surface switch
        {
            PhysicsEnums.SurfaceType.Rough =>
                // High grip, more friction - ball checks up quickly
                new Dictionary
                {
                    { "u_k", 0.15f },
                    { "u_kr", 0.05f },
                    { "nu_g", 0.0005f },
                    { "theta_c", 0.38f }  // ~22°
                },

            PhysicsEnums.SurfaceType.Fairway =>
                // Firm fairway - good conditions with 50-70 yd rollout for low-spin drivers
                new Dictionary
                {
                    { "u_k", 0.30f },      // Kinetic friction (sliding)
                    { "u_kr", 0.030f },    // Rolling resistance for firm fairway grass
                    { "nu_g", 0.0010f },   // Grass drag viscosity
                    { "theta_c", 0.25f }   // ~14° critical angle - firmer surface
                },

            PhysicsEnums.SurfaceType.FairwaySoft =>
                // Soft/wet fairway - reduced rollout (~20-30 yds)
                new Dictionary
                {
                    { "u_k", 0.42f },      // Higher kinetic friction
                    { "u_kr", 0.18f },     // Higher rolling resistance
                    { "nu_g", 0.0020f },   // More grass drag
                    { "theta_c", 0.30f }   // ~17° - softer surface
                },

            PhysicsEnums.SurfaceType.Firm =>
                // Low grip - ball runs out more
                new Dictionary
                {
                    { "u_k", 0.08f },
                    { "u_kr", 0.02f },
                    { "nu_g", 0.0002f },
                    { "theta_c", 0.21f }  // ~12°
                },

            _ =>
                // Default to normal fairway
                new Dictionary
                {
                    { "u_k", 0.30f },
                    { "u_kr", 0.015f },
                    { "nu_g", 0.0010f },
                    { "theta_c", 0.25f }
                }
        };
    }
}
