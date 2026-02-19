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
                // Tall grass rough: shortest rollout.
                // TODO, more testing needed here. 
                // 1. Need game/consumer to dictate these values. 
                // 2. These values are not reacting as state, rough slower, firm faster. 
                new Dictionary
                {
                    { "u_k", 0.62f },      // High slip friction
                    { "u_kr", 0.095f },    // High rolling resistance
                    { "nu_g", 0.0032f },   // Strong vegetation drag
                    { "theta_c", 0.35f }   // ~20°
                },

            PhysicsEnums.SurfaceType.Fairway =>
                // Default fairway tuned to roll ~40% less than prior baseline.
                new Dictionary
                {
                    { "u_k", 0.50f },      // Higher slip friction than prior baseline
                    { "u_kr", 0.050f },    // ~1.67x rolling resistance vs prior baseline
                    { "nu_g", 0.0017f },   // ~1.7x grass drag vs prior baseline
                    { "theta_c", 0.29f }   // ~17°
                },

            PhysicsEnums.SurfaceType.FairwaySoft =>
                // Soft/wet fairway: slower than normal fairway but faster than rough.
                new Dictionary
                {
                    { "u_k", 0.56f },
                    { "u_kr", 0.070f },
                    { "nu_g", 0.0024f },
                    { "theta_c", 0.32f }   // ~18°
                },

            PhysicsEnums.SurfaceType.Firm =>
                // Hard pavement/concrete style lie.
                // Intentionally set to the prior fairway baseline (fast rollout).
                new Dictionary
                {
                    { "u_k", 0.30f },
                    { "u_kr", 0.030f },
                    { "nu_g", 0.0010f },
                    { "theta_c", 0.25f }  // ~14°
                },

            _ =>
                // Default to current normal fairway tuning
                new Dictionary
                {
                    { "u_k", 0.50f },
                    { "u_kr", 0.050f },
                    { "nu_g", 0.0017f },
                    { "theta_c", 0.29f }
                }
        };
    }
}
