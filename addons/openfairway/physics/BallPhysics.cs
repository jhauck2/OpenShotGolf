using Godot;

/// <summary>
/// Pure physics calculations for golf ball motion.
/// Contains all force, torque, and bounce calculations separated from
/// the game object (CharacterBody3D) implementation.
/// </summary>
[GlobalClass]
public partial class BallPhysics : RefCounted
{
    // Ball physical properties
    public const float MASS = 0.04592623f;  // kg (regulation golf ball)
    public const float RADIUS = 0.021335f;  // m (regulation golf ball)
    public const float CROSS_SECTION = Mathf.Pi * RADIUS * RADIUS;  // m²
    public const float MOMENT_OF_INERTIA = 0.4f * MASS * RADIUS * RADIUS;  // kg*m²
    public const float SIMULATION_HZ = 120.0f;  // shared integration rate for runtime + headless
    public const float SIMULATION_DT = 1.0f / SIMULATION_HZ;
    public const float SPIN_DECAY_TAU = 5.0f;  // Spin decay time constant (seconds)
    public static float SPIN_DRAG_MULTIPLIER_COEFF => FlightAerodynamicsModel.SpinDragMultiplierCoeff;
    public static float SPIN_DRAG_MULTIPLIER_MAX => FlightAerodynamicsModel.SpinDragMultiplierMax;
    public static float SPIN_DRAG_MULTIPLIER_HIGH_SPIN_MAX => FlightAerodynamicsModel.SpinDragMultiplierHighSpinMax;
    public static float SPIN_DRAG_MULTIPLIER_ULTRA_HIGH_SPIN_MAX => FlightAerodynamicsModel.SpinDragMultiplierUltraHighSpinMax;
    public static float LOW_LAUNCH_LIFT_RECOVERY_MAX => FlightAerodynamicsModel.LowLaunchLiftRecoveryMax;

    // Read-only properties for GDScript access to constants (private set satisfies [Export] requirement)
    [Export] public float BallMass { get => MASS; private set { } }
    [Export] public float BallRadius { get => RADIUS; private set { } }
    [Export] public float BallCrossSection { get => CROSS_SECTION; private set { } }
    [Export] public float BallMomentOfInertia { get => MOMENT_OF_INERTIA; private set { } }
    [Export] public float SimulationHz { get => SIMULATION_HZ; private set { } }
    [Export] public float SimulationDt { get => SIMULATION_DT; private set { } }
    [Export] public float SpinDecayTau { get => SPIN_DECAY_TAU; private set { } }
    [Export] public float SpinDragMultiplierMax { get => SPIN_DRAG_MULTIPLIER_MAX; private set { } }
    [Export] public float SpinDragMultiplierHighSpinMax { get => SPIN_DRAG_MULTIPLIER_HIGH_SPIN_MAX; private set { } }

    private static readonly RolloutProfile DefaultRollout = RolloutProfile.Default;

    // Gravity force (pre-computed to avoid per-frame allocation), yea--I came up with this :D
    private static readonly Vector3 GravityForce = new(0.0f, -9.81f * MASS, 0.0f);

    private readonly BounceCalculator _bounceCalc = new();

    /// <summary>
    /// Calculate total forces acting on the ball
    /// </summary>
    public Vector3 CalculateForces(
        Vector3 velocity,
        Vector3 omega,
        bool onGround,
        PhysicsParams parameters)
    {
        Vector3 gravity = GravityForce;

        if (onGround)
        {
            // When on ground, normal force cancels gravity vertically
            // while gravity still contributes along the local slope tangent.
            Vector3 floorNormal = parameters.FloorNormal.LengthSquared() > 0.000001f
                ? parameters.FloorNormal.Normalized()
                : Vector3.Up;

            Vector3 gravityAlongSlope = gravity - floorNormal * gravity.Dot(floorNormal);

            // Ground integration is handled in world-space with collision response.
            // Keep the along-slope gravity contribution in horizontal axes only.
            gravityAlongSlope.Y = 0.0f;

            Vector3 groundForces = CalculateGroundForces(velocity, omega, parameters);
            groundForces += gravityAlongSlope;
            groundForces.Y = 0.0f;  // Zero out any vertical component
            return groundForces;
        }
        else
        {
            return gravity + CalculateAirForces(velocity, omega, parameters);
        }
    }

    private float GetSpinFrictionMultiplier(Vector3 omega, float impactSpinRpm, float ballSpeed)
        => GetSpinFrictionMultiplier(omega, impactSpinRpm, ballSpeed, DefaultRollout);

    /// <summary>
    /// Calculate ground friction and drag forces
    /// </summary>
    public Vector3 CalculateGroundForces(
        Vector3 velocity,
        Vector3 omega,
        PhysicsParams parameters)
    {
        // Grass drag
        Vector3 grassDrag = velocity * (-6.0f * Mathf.Pi * RADIUS * parameters.GrassViscosity);
        grassDrag.Y = 0.0f;

        Vector3 friction = CalculateFrictionForce(velocity, omega, parameters);

        // Debug: print every 60 frames (~1 second) when on ground
        bool shouldDebug = Engine.GetPhysicsFrames() % 60 == 0;
        if (shouldDebug)
        {
            float spinMultiplier = GetSpinFrictionMultiplier(omega, parameters.RolloutImpactSpin, velocity.Length());
            Vector3 contactVelocity = velocity + omega.Cross(-parameters.FloorNormal * RADIUS);
            Vector3 tangentVelocity = contactVelocity - parameters.FloorNormal * contactVelocity.Dot(parameters.FloorNormal);
            float tangentVelMag = tangentVelocity.Length();

            if (tangentVelMag < DefaultRollout.TangentVelocityThreshold)
            {
                float effectiveRollingFriction = parameters.RollingFriction * spinMultiplier;
                PhysicsLogger.Verbose($"  ROLLING: vel={velocity.Length():F2} m/s, spin={omega.Length() / ShotSetup.RAD_PER_RPM:F0} rpm, c_rr={effectiveRollingFriction:F3} (×{spinMultiplier:F2})");
            }
            else
            {
                float velocityMag = velocity.Length();
                float baseFriction;
                if (velocityMag < DefaultRollout.FrictionBlendSpeed)
                {
                    float blendFactor = Mathf.Clamp(velocityMag / DefaultRollout.FrictionBlendSpeed, 0.0f, 1.0f);
                    blendFactor = blendFactor * blendFactor;
                    baseFriction = Mathf.Lerp(parameters.RollingFriction, parameters.KineticFriction, blendFactor);
                }
                else
                {
                    baseFriction = parameters.KineticFriction;
                }
                float effectiveFriction = baseFriction * spinMultiplier;
                PhysicsLogger.Verbose($"  SLIPPING: vel={velocityMag:F2} m/s, spin={omega.Length() / ShotSetup.RAD_PER_RPM:F0} rpm, tangent_vel={tangentVelMag:F2}, μ_eff={effectiveFriction:F3} (×{spinMultiplier:F2})");
            }
        }

        return grassDrag + friction;
    }

    private Vector3 CalculateFrictionForce(
        Vector3 velocity,
        Vector3 omega,
        PhysicsParams parameters)
        => CalculateFrictionForce(velocity, omega, parameters, DefaultRollout);

    /// <summary>
    /// Calculate aerodynamic drag and Magnus forces
    /// </summary>
    public Vector3 CalculateAirForces(
        Vector3 velocity,
        Vector3 omega,
        PhysicsParams parameters)
    {
        FlightAerodynamicsSample airSample = SampleFlightAerodynamics(
            velocity,
            omega,
            parameters.AirDensity,
            parameters.AirViscosity,
            parameters.DragScale,
            parameters.LiftScale,
            parameters.InitialLaunchAngleDeg,
            parameters.FlightProfile
        );
        if (!airSample.HasAerodynamics)
            return Vector3.Zero;

        // Drag force (opposite to velocity)
        Vector3 drag = -0.5f * airSample.DragCoefficient * parameters.AirDensity * CROSS_SECTION * velocity * airSample.Speed;

        // Magnus force (perpendicular to velocity and spin axis)
        Vector3 magnus = Vector3.Zero;
        float omegaLen = omega.Length();
        if (omegaLen > 0.1f)
        {
            Vector3 omegaCrossVel = omega.Cross(velocity);
            magnus = 0.5f * airSample.LiftCoefficient * parameters.AirDensity * CROSS_SECTION * omegaCrossVel * airSample.Speed / omegaLen;
        }

        return drag + magnus;
    }

    /// <summary>
    /// Compute spin-drag multiplier with a transitional-Re high-spin relief
    /// window and an ultra-high-spin rebound. This keeps wedge shots from
    /// carrying excessive spin-drag while preserving higher drag in the
    /// checked/flop regime.
    /// </summary>
    public static float GetSpinDragMultiplier(float spinRatio)
    {
        return FlightAerodynamicsModel.GetSpinDragMultiplier(spinRatio);
    }

    public static float GetSpinDragMultiplier(float spinRatio, float reynolds)
    {
        return FlightAerodynamicsModel.GetSpinDragMultiplier(spinRatio, reynolds);
    }

    /// <summary>
    /// Recover a small amount of lift for low-launch, high-Re wood/driver shots.
    /// This branch is intentionally narrow so it only catches the wood1/wood_low
    /// type trajectories without reopening the broader driver and wedge tuning.
    /// </summary>
    public static float GetLowLaunchLiftScale(float initialLaunchAngleDeg, float spinRatio, float reynolds)
    {
        return FlightAerodynamicsModel.GetLowLaunchLiftScale(initialLaunchAngleDeg, spinRatio, reynolds);
    }

    internal static FlightAerodynamicsSample SampleFlightAerodynamics(
        Vector3 velocity,
        Vector3 omega,
        float airDensity,
        float airViscosity,
        float dragScale,
        float liftScale,
        float initialLaunchAngleDeg)
    {
        return FlightAerodynamicsModel.Sample(
            velocity,
            omega,
            airDensity,
            airViscosity,
            dragScale,
            liftScale,
            initialLaunchAngleDeg
        );
    }

    internal static FlightAerodynamicsSample SampleFlightAerodynamics(
        Vector3 velocity,
        Vector3 omega,
        float airDensity,
        float airViscosity,
        float dragScale,
        float liftScale,
        float initialLaunchAngleDeg,
        FlightProfile flightProfile)
    {
        return FlightAerodynamicsModel.Sample(
            velocity,
            omega,
            airDensity,
            airViscosity,
            dragScale,
            liftScale,
            initialLaunchAngleDeg,
            flightProfile
        );
    }

    private static float GetEffectiveCriticalAngle(
        PhysicsParams parameters,
        float currentSpinRpm,
        float impactSpeed,
        PhysicsEnums.BallState currentState)
        => BounceCalculator.GetEffectiveCriticalAngle(parameters, currentSpinRpm, impactSpeed, currentState);

    /// <summary>
    /// Calculate total torques acting on the ball
    /// </summary>
    public Vector3 CalculateTorques(
        Vector3 velocity,
        Vector3 omega,
        bool onGround,
        PhysicsParams parameters)
    {
        if (onGround)
        {
            return CalculateGroundTorques(velocity, omega, parameters);
        }
        else
        {
            // Spin decay torque (exponential decay model)
            return -MOMENT_OF_INERTIA * omega / SPIN_DECAY_TAU;
        }
    }

    /// <summary>
    /// Integrate velocity and spin one step with a shared fixed time step.
    /// Used by both runtime and headless simulators to keep trajectories aligned.
    /// </summary>
    public void IntegrateStep(
        ref Vector3 velocity,
        ref Vector3 omega,
        bool onGround,
        PhysicsParams parameters,
        float dt)
    {
        Vector3 force = CalculateForces(velocity, omega, onGround, parameters);
        Vector3 torque = CalculateTorques(velocity, omega, onGround, parameters);

        velocity += (force / MASS) * dt;
        omega += (torque / MOMENT_OF_INERTIA) * dt;
    }

    /// <summary>
    /// Calculate ground friction torques
    /// </summary>
    public Vector3 CalculateGroundTorques(
        Vector3 velocity,
        Vector3 omega,
        PhysicsParams parameters)
    {
        Vector3 grassTorque = -6.0f * Mathf.Pi * parameters.GrassViscosity * RADIUS * omega;

        Vector3 frictionForce = CalculateFrictionForce(velocity, omega, parameters);

        Vector3 frictionTorque = Vector3.Zero;
        if (frictionForce.Length() > 0.001f)
        {
            frictionTorque = (-parameters.FloorNormal * RADIUS).Cross(frictionForce);
        }

        return frictionTorque + grassTorque;
    }

    public BounceResult CalculateBounce(
        Vector3 vel,
        Vector3 omega,
        Vector3 normal,
        PhysicsEnums.BallState currentState,
        PhysicsParams parameters)
        => _bounceCalc.CalculateBounce(vel, omega, normal, currentState, parameters);

    public float GetCoefficientOfRestitution(float speedNormal)
        => _bounceCalc.GetCoefficientOfRestitution(speedNormal);

    public float GetCoefficientOfRestitution(float speedNormal, BounceProfile bp)
        => _bounceCalc.GetCoefficientOfRestitution(speedNormal, bp);

    public BounceResult CalculateBounce(
        Vector3 vel,
        Vector3 omega,
        Vector3 normal,
        PhysicsEnums.BallState currentState,
        PhysicsParams parameters,
        BounceProfile bp)
        => _bounceCalc.CalculateBounce(vel, omega, normal, currentState, parameters, bp);

    private float GetSpinFrictionMultiplier(Vector3 omega, float impactSpinRpm, float ballSpeed, RolloutProfile rp)
    {
        float currentSpinRpm = omega.Length() / ShotSetup.RAD_PER_RPM;
        float effectiveSpinRpm = Mathf.Max(currentSpinRpm, impactSpinRpm);

        float velocityScale;
        if (ballSpeed < rp.ChipSpeedThreshold)
        {
            velocityScale = Mathf.Lerp(rp.ChipVelocityScaleMin, rp.ChipVelocityScaleMax,
                ballSpeed / rp.ChipSpeedThreshold);
        }
        else if (ballSpeed < rp.PitchSpeedThreshold)
        {
            velocityScale = Mathf.Lerp(rp.ChipVelocityScaleMax, 1.0f,
                (ballSpeed - rp.ChipSpeedThreshold) / (rp.PitchSpeedThreshold - rp.ChipSpeedThreshold));
        }
        else
        {
            velocityScale = 1.0f;
        }

        float spinMultiplier;
        if (effectiveSpinRpm < rp.LowSpinThreshold)
        {
            spinMultiplier = 1.0f + (effectiveSpinRpm / rp.LowSpinThreshold) * (rp.LowSpinMultiplierMax - 1.0f);
        }
        else if (effectiveSpinRpm < rp.MidSpinThreshold)
        {
            float excessSpin = effectiveSpinRpm - rp.LowSpinThreshold;
            float midRange = rp.MidSpinThreshold - rp.LowSpinThreshold;
            spinMultiplier = rp.LowSpinMultiplierMax +
                (excessSpin / midRange) * (rp.MidSpinMultiplierMax - rp.LowSpinMultiplierMax);
        }
        else
        {
            float excessSpin = effectiveSpinRpm - rp.MidSpinThreshold;
            float spinFactor = Mathf.Min(excessSpin / rp.HighSpinRampRange, 1.0f);
            spinMultiplier = rp.MidSpinMultiplierMax +
                spinFactor * (rp.HighSpinMultiplierMax - rp.MidSpinMultiplierMax);
        }

        float scaledMultiplier = 1.0f + (spinMultiplier - 1.0f) * velocityScale;
        return scaledMultiplier;
    }

    private Vector3 CalculateFrictionForce(
        Vector3 velocity,
        Vector3 omega,
        PhysicsParams parameters,
        RolloutProfile rp)
    {
        Vector3 contactVelocity = velocity + omega.Cross(-parameters.FloorNormal * RADIUS);
        Vector3 tangentVelocity = contactVelocity - parameters.FloorNormal * contactVelocity.Dot(parameters.FloorNormal);

        float spinMultiplier = GetSpinFrictionMultiplier(omega, parameters.RolloutImpactSpin, velocity.Length(), rp);
        float tangentVelMag = tangentVelocity.Length();

        if (tangentVelMag < rp.TangentVelocityThreshold)
        {
            Vector3 flatVelocity = velocity - parameters.FloorNormal * velocity.Dot(parameters.FloorNormal);
            Vector3 frictionDir = flatVelocity.Length() > 0.01f ? flatVelocity.Normalized() : Vector3.Zero;
            float effectiveRollingFriction = parameters.RollingFriction * spinMultiplier;
            return frictionDir * (-effectiveRollingFriction * MASS * 9.81f);
        }
        else
        {
            float velocityMag = velocity.Length();
            float baseFriction;

            if (velocityMag < rp.FrictionBlendSpeed)
            {
                float blendFactor = Mathf.Clamp(velocityMag / rp.FrictionBlendSpeed, 0.0f, 1.0f);
                blendFactor = blendFactor * blendFactor;
                baseFriction = Mathf.Lerp(parameters.RollingFriction, parameters.KineticFriction, blendFactor);
            }
            else
            {
                baseFriction = parameters.KineticFriction;
            }

            float effectiveFriction = baseFriction * spinMultiplier;
            Vector3 slipDir = tangentVelMag > 0.01f ? tangentVelocity.Normalized() : Vector3.Zero;
            return slipDir * (-effectiveFriction * MASS * 9.81f);
        }
    }
}
