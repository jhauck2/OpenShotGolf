/// <summary>
/// Single source of truth for surface tuning values.
/// </summary>
public static class SurfacePhysicsCatalog
{
    private static readonly SurfacePhysicsSettings Fairway = new(
        PhysicsEnums.SurfaceType.Fairway,
        kineticFriction: 0.40f,
        rollingFriction: 0.132f,
        grassViscosity: 0.0014f,
        criticalAngle: 0.285f,
        spinbackResponseScale: 0.99f,
        spinbackThetaBoostMax: 0.0f,
        spinbackSpinStartRpm: 0.0f,
        spinbackSpinEndRpm: 0.0f,
        spinbackSpeedStartMps: 0.0f,
        spinbackSpeedEndMps: 0.0f
    );

    private static readonly SurfacePhysicsSettings FairwaySoft = new(
        PhysicsEnums.SurfaceType.FairwaySoft,
        kineticFriction: 0.50f,
        rollingFriction: 0.110f,
        grassViscosity: 0.0020f,
        criticalAngle: 0.31f,
        spinbackResponseScale: 0.84f,
        spinbackThetaBoostMax: 0.0f,
        spinbackSpinStartRpm: 0.0f,
        spinbackSpinEndRpm: 0.0f,
        spinbackSpeedStartMps: 0.0f,
        spinbackSpeedEndMps: 0.0f
    );

    private static readonly SurfacePhysicsSettings Rough = new(
        PhysicsEnums.SurfaceType.Rough,
        kineticFriction: 0.62f,
        rollingFriction: 0.175f,
        grassViscosity: 0.0035f,
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
        kineticFriction: 0.29f,
        rollingFriction: 0.065f,
        grassViscosity: 0.0009f,
        criticalAngle: 0.245f,
        spinbackResponseScale: 0.55f,
        spinbackThetaBoostMax: 0.0f,
        spinbackSpinStartRpm: 0.0f,
        spinbackSpinEndRpm: 0.0f,
        spinbackSpeedStartMps: 0.0f,
        spinbackSpeedEndMps: 0.0f
    );

    private static readonly SurfacePhysicsSettings CartPath = new(
        PhysicsEnums.SurfaceType.CartPath,
        kineticFriction: 0.20f,
        rollingFriction: 0.035f,
        grassViscosity: 0.0003f,
        criticalAngle: 0.20f,
        spinbackResponseScale: 0.0f,
        spinbackThetaBoostMax: 0.0f,
        spinbackSpinStartRpm: 0.0f,
        spinbackSpinEndRpm: 0.0f,
        spinbackSpeedStartMps: 0.0f,
        spinbackSpeedEndMps: 0.0f
    );

    private static readonly SurfacePhysicsSettings Green = new(
        PhysicsEnums.SurfaceType.Green,
        kineticFriction: 0.58f,
        rollingFriction: 0.056f,
        grassViscosity: 0.0009f,
        criticalAngle: 0.36f,
        spinbackResponseScale: 1.12f,
        spinbackThetaBoostMax: 0.12f,
        spinbackSpinStartRpm: 7500.0f,
        spinbackSpinEndRpm: 9500.0f,
        spinbackSpeedStartMps: 8.0f,
        spinbackSpeedEndMps: 20.0f
    );

    private static readonly SurfacePhysicsSettings Bunker = new(
        PhysicsEnums.SurfaceType.Bunker,
        kineticFriction: 0.95f,
        rollingFriction: 0.42f,
        grassViscosity: 0.020f,
        criticalAngle: 0.45f,
        spinbackResponseScale: 0.0f,
        spinbackThetaBoostMax: 0.0f,
        spinbackSpinStartRpm: 0.0f,
        spinbackSpinEndRpm: 0.0f,
        spinbackSpeedStartMps: 0.0f,
        spinbackSpeedEndMps: 0.0f
    );

    public static SurfacePhysicsSettings Get(PhysicsEnums.SurfaceType surface)
    {
        return surface switch
        {
            PhysicsEnums.SurfaceType.Rough => Rough,
            PhysicsEnums.SurfaceType.FairwaySoft => FairwaySoft,
            PhysicsEnums.SurfaceType.Firm => Firm,
            PhysicsEnums.SurfaceType.CartPath => CartPath,
            PhysicsEnums.SurfaceType.Green => Green,
            PhysicsEnums.SurfaceType.Bunker => Bunker,
            _ => Fairway
        };
    }
}
