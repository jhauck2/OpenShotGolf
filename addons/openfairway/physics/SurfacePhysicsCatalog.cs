/// <summary>
/// Single source of truth for surface tuning values.
/// </summary>
public static class SurfacePhysicsCatalog
{
    private static readonly SurfacePhysicsSettings Fairway = new(
        PhysicsEnums.SurfaceType.Fairway,
        kineticFriction: 0.50f,
        rollingFriction: 0.050f,
        grassViscosity: 0.0017f,
        criticalAngle: 0.29f,
        spinbackResponseScale: 0.78f,
        spinbackThetaBoostMax: 0.0f,
        spinbackSpinStartRpm: 0.0f,
        spinbackSpinEndRpm: 0.0f,
        spinbackSpeedStartMps: 0.0f,
        spinbackSpeedEndMps: 0.0f
    );

    private static readonly SurfacePhysicsSettings FairwaySoft = new(
        PhysicsEnums.SurfaceType.FairwaySoft,
        kineticFriction: 0.56f,
        rollingFriction: 0.070f,
        grassViscosity: 0.0024f,
        criticalAngle: 0.32f,
        spinbackResponseScale: 0.92f,
        spinbackThetaBoostMax: 0.0f,
        spinbackSpinStartRpm: 0.0f,
        spinbackSpinEndRpm: 0.0f,
        spinbackSpeedStartMps: 0.0f,
        spinbackSpeedEndMps: 0.0f
    );

    private static readonly SurfacePhysicsSettings Rough = new(
        PhysicsEnums.SurfaceType.Rough,
        kineticFriction: 0.62f,
        rollingFriction: 0.095f,
        grassViscosity: 0.0032f,
        criticalAngle: 0.35f,
        spinbackResponseScale: 0.70f,
        spinbackThetaBoostMax: 0.0f,
        spinbackSpinStartRpm: 0.0f,
        spinbackSpinEndRpm: 0.0f,
        spinbackSpeedStartMps: 0.0f,
        spinbackSpeedEndMps: 0.0f
    );

    private static readonly SurfacePhysicsSettings Firm = new(
        PhysicsEnums.SurfaceType.Firm,
        kineticFriction: 0.30f,
        rollingFriction: 0.030f,
        grassViscosity: 0.0010f,
        criticalAngle: 0.25f,
        spinbackResponseScale: 0.60f,
        spinbackThetaBoostMax: 0.0f,
        spinbackSpinStartRpm: 0.0f,
        spinbackSpinEndRpm: 0.0f,
        spinbackSpeedStartMps: 0.0f,
        spinbackSpeedEndMps: 0.0f
    );

    private static readonly SurfacePhysicsSettings Green = new(
        PhysicsEnums.SurfaceType.Green,
        kineticFriction: 0.58f,
        rollingFriction: 0.028f,
        grassViscosity: 0.0009f,
        criticalAngle: 0.36f,
        spinbackResponseScale: 1.12f,
        spinbackThetaBoostMax: 0.12f,
        spinbackSpinStartRpm: 3500.0f,
        spinbackSpinEndRpm: 5500.0f,
        spinbackSpeedStartMps: 8.0f,
        spinbackSpeedEndMps: 20.0f
    );

    public static SurfacePhysicsSettings Get(PhysicsEnums.SurfaceType surface)
    {
        return surface switch
        {
            PhysicsEnums.SurfaceType.Rough => Rough,
            PhysicsEnums.SurfaceType.FairwaySoft => FairwaySoft,
            PhysicsEnums.SurfaceType.Firm => Firm,
            PhysicsEnums.SurfaceType.Green => Green,
            _ => Fairway
        };
    }
}
