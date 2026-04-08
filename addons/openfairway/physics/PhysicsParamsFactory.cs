using Godot;

/// <summary>
/// Resolves environment, surface, and ball-profile inputs into the final
/// parameters consumed by the physics engine.
/// </summary>
public sealed class PhysicsParamsFactory
{
    public ResolvedPhysicsParams Create(
        float airDensity,
        float airViscosity,
        float dragScale,
        float liftScale,
        PhysicsEnums.SurfaceType surfaceType,
        Vector3 floorNormal,
        float rolloutImpactSpin = 0.0f,
        BallPhysicsProfile ballProfile = null,
        float initialLaunchAngleDeg = 0.0f,
        float launchSpeedMph = 0.0f,
        float launchSpinRpm = 0.0f)
    {
        BallPhysicsProfile profile = ballProfile ?? new BallPhysicsProfile();
        SurfacePhysicsSettings surface = SurfacePhysicsCatalog.Get(surfaceType);
        RegimeScaleOverride regimeScale = profile.ResolveScaleOverride(
            launchSpeedMph,
            initialLaunchAngleDeg,
            launchSpinRpm,
            out _,
            out _
        );

        return new ResolvedPhysicsParams(
            airDensity,
            airViscosity,
            dragScale * profile.DragScaleMultiplier * regimeScale.DragScaleMultiplier,
            liftScale * profile.LiftScaleMultiplier * regimeScale.LiftScaleMultiplier,
            surface.KineticFriction * profile.KineticFrictionMultiplier * regimeScale.KineticFrictionMultiplier,
            surface.RollingFriction * profile.RollingFrictionMultiplier * regimeScale.RollingFrictionMultiplier,
            surface.GrassViscosity * profile.GrassViscosityMultiplier * regimeScale.GrassViscosityMultiplier,
            surface.CriticalAngle + profile.CriticalAngleOffsetRadians + regimeScale.CriticalAngleOffsetRadians,
            surfaceType,
            floorNormal,
            rolloutImpactSpin,
            surface.SpinbackResponseScale,
            surface.SpinbackThetaBoostMax * profile.SpinbackThetaBoostMultiplier * regimeScale.SpinbackThetaBoostMultiplier,
            surface.SpinbackSpinStartRpm,
            surface.SpinbackSpinEndRpm,
            surface.SpinbackSpeedStartMps,
            surface.SpinbackSpeedEndMps,
            initialLaunchAngleDeg,
            profile.ResolvedFlight
        );
    }
}
