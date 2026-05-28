using Godot;
using Godot.Collections;

/// <summary>
/// Adapter/utility for simulating shots from JSON data (headless simulation)
/// </summary>
[GlobalClass]
public partial class PhysicsAdapter : RefCounted
{
    private const float YARDS_PER_METER = ShotSetup.YARDS_PER_METER;
    private const float FEET_PER_METER = ShotSetup.FEET_PER_METER;
    private const float START_HEIGHT = 0.02f;
    private const float DEFAULT_TEMP_F = 75.0f;
    private const float DEFAULT_ALT_FT = 0.0f;
    private const float MAX_TIME = 12.0f;
    private const float DT = BallPhysics.SIMULATION_DT;

    private readonly BallPhysics _physics = new();
    private readonly Aerodynamics _aero = new();
    private readonly PhysicsParamsFactory _physicsParamsFactory = new();
    private readonly ShotSetup _shotSetup = new();
    private BallPhysicsProfile _ballProfile = new();

    /// <summary>
    /// Load a BallPhysicsProfile from a JSON string. Only keys present in
    /// the JSON override defaults. Subsequent simulations use this profile.
    /// </summary>
    public void LoadProfileFromJson(string json)
    {
        _ballProfile = BallPhysicsProfile.FromJson(json);
    }

    /// <summary>
    /// Simulate a shot from JSON data and return carry/total distances
    /// </summary>
    public Dictionary SimulateShotFromJson(Dictionary shot)
    {
        return SimulateShotFromJson(shot, PhysicsEnums.SurfaceType.Fairway, Vector3.Up);
    }

    /// <summary>
    /// Simulate a shot using a specific BallPhysicsProfile override.
    /// </summary>
    public Dictionary SimulateShotWithProfile(Dictionary shot, BallPhysicsProfile profile)
    {
        var saved = _ballProfile;
        _ballProfile = profile ?? new BallPhysicsProfile();
        var result = SimulateShotFromJson(shot, PhysicsEnums.SurfaceType.Fairway, Vector3.Up);
        _ballProfile = saved;
        return result;
    }

    /// <summary>
    /// Carry-only simulation with a full BallPhysicsProfile override, including
    /// launch-regime scale overrides.
    /// </summary>
    public Dictionary SimulateCarryOnlyWithProfile(Dictionary shot, BallPhysicsProfile profile)
    {
        var saved = _ballProfile;
        _ballProfile = profile ?? new BallPhysicsProfile();
        var result = SimulateCarryOnlyInternal(shot, null);
        _ballProfile = saved;
        return result;
    }

    /// <summary>
    /// Simulate a shot from JSON data on a specific surface and floor normal.
    /// Useful for regression checks such as green/slope-specific rollout behavior.
    /// </summary>
    public Dictionary SimulateShotFromJson(Dictionary shot, PhysicsEnums.SurfaceType surface, Vector3 floorNormal)
    {
        var ballDict = shot.ContainsKey("BallData") ? (Dictionary)shot["BallData"] : shot;
        if (ballDict == null || ballDict.Count == 0)
        {
            PhysicsLogger.PushError("Shot JSON missing BallData");
            return new Dictionary();
        }

        float speedMph = (float)(ballDict.ContainsKey("Speed") ? ballDict["Speed"] : 0.0);
        float vla = (float)(ballDict.ContainsKey("VLA") ? ballDict["VLA"] : 0.0);
        float hla = (float)(ballDict.ContainsKey("HLA") ? ballDict["HLA"] : 0.0);
        var spinData = _shotSetup.ParseSpin(ballDict);
        float backspin = (float)spinData["backspin"];
        float sidespin = (float)spinData["sidespin"];
        float totalSpin = (float)spinData["total"];
        float spinAxis = (float)spinData["axis"];
        RegimeScaleOverride regimeScale = _ballProfile.ResolveScaleOverride(speedMph, vla, totalSpin, out string regimeKey, out string matchedOverrideKey);
        if (!string.IsNullOrEmpty(matchedOverrideKey))
            PhysicsLogger.Info($"[Regime] {regimeKey} matched={matchedOverrideKey} drag={regimeScale.DragScaleMultiplier:F3} lift={regimeScale.LiftScaleMultiplier:F3}");

        var launch = _shotSetup.BuildLaunchVectorsFromComponents(speedMph, vla, hla, backspin, sidespin);
        Vector3 velocity = (Vector3)launch["velocity"];
        Vector3 omega = (Vector3)launch["omega"];
        Vector3 shotDir = (Vector3)launch["shot_direction"];

        Vector3 contactNormal = floorNormal.LengthSquared() > 0.000001f ? floorNormal.Normalized() : Vector3.Up;
        var parameters = CreateParams(contactNormal, surface, vla, speedMph, totalSpin);

        Vector3 pos = new Vector3(0.0f, START_HEIGHT, 0.0f);
        PhysicsEnums.BallState state = PhysicsEnums.BallState.Flight;
        bool onGround = false;
        float carryM = 0.0f;
        bool carryRecorded = false;
        float hangTimeS = 0.0f;
        float apexM = pos.Y;
        bool firstImpactSpinback = false;
        float landingSpeedMps = 0.0f;
        float landingAngleDeg = 0.0f;
        float firstImpactTangentIn = 0.0f;
        float firstImpactTangentOut = 0.0f;

        FlightAerodynamicsSample initialAirSample = BallPhysics.SampleFlightAerodynamics(
            velocity,
            omega,
            parameters.AirDensity,
            parameters.AirViscosity,
            parameters.DragScale,
            parameters.LiftScale,
            parameters.InitialLaunchAngleDeg,
            parameters.FlightProfile
        );
        float peakCl = 0.0f;

        int steps = (int)(MAX_TIME / DT);
        for (int i = 0; i < steps; i++)
        {
            if (!onGround)
            {
                FlightAerodynamicsSample airSample = BallPhysics.SampleFlightAerodynamics(
                    velocity,
                    omega,
                    parameters.AirDensity,
                    parameters.AirViscosity,
                    parameters.DragScale,
                    parameters.LiftScale,
                    parameters.InitialLaunchAngleDeg,
                    parameters.FlightProfile
                );
                if (airSample.HasAerodynamics)
                {
                    peakCl = Mathf.Max(peakCl, airSample.LiftCoefficient);
                }
            }

            _physics.IntegrateStep(ref velocity, ref omega, onGround, parameters, DT);

            pos += velocity * DT;
            apexM = Mathf.Max(apexM, pos.Y);

            bool hasImpact = pos.Y <= 0.0f && (velocity.Y < -0.01f || state == PhysicsEnums.BallState.Flight);
            if (hasImpact)
            {
                pos.Y = 0.0f;
                float preImpactSpeed = velocity.Length();
                float preImpactNormalSpeed = Mathf.Abs(velocity.Dot(contactNormal));
                Vector3 preImpactTangent = velocity - contactNormal * velocity.Dot(contactNormal);
                var bounce = _physics.CalculateBounce(velocity, omega, contactNormal, state, parameters);
                velocity = bounce.NewVelocity;
                omega = bounce.NewOmega;
                state = bounce.NewState;
                onGround = state != PhysicsEnums.BallState.Flight;
                velocity.Y = Mathf.Max(velocity.Y, 0.0f);

                if (!carryRecorded)
                {
                    Vector3 postImpactTangent = velocity - contactNormal * velocity.Dot(contactNormal);
                    float preTanMag = preImpactTangent.Length();
                    float postTanMag = postImpactTangent.Length();

                    firstImpactTangentIn = preTanMag;
                    firstImpactTangentOut = postTanMag;
                    landingSpeedMps = preImpactSpeed;
                    landingAngleDeg = Mathf.RadToDeg(Mathf.Atan2(preImpactNormalSpeed, Mathf.Max(preTanMag, 0.0001f)));

                    if (preTanMag > 0.01f && postTanMag > 0.01f)
                    {
                        float directionDot = preImpactTangent.Normalized().Dot(postImpactTangent.Normalized());
                        firstImpactSpinback = directionDot < -0.001f;
                        if (firstImpactSpinback)
                        {
                            firstImpactTangentOut = -postTanMag;
                        }
                    }
                }

                if (!carryRecorded)
                {
                    carryM = Mathf.Max(pos.Dot(shotDir), 0.0f);
                    carryRecorded = true;
                    hangTimeS = (i + 1) * DT;
                }
            }
            else
            {
                if (pos.Y < 0.0f)
                {
                    pos.Y = 0.0f;
                    velocity.Y = Mathf.Max(velocity.Y, 0.0f);
                }
                onGround = state != PhysicsEnums.BallState.Flight && pos.Y <= 0.02f;
            }

            float speed = velocity.Length();
            if (onGround && speed < 0.05f && omega.Length() < 0.5f)
            {
                state = PhysicsEnums.BallState.Rest;
                velocity = Vector3.Zero;
                omega = Vector3.Zero;
                break;
            }
        }

        float totalM = Mathf.Max(pos.Dot(shotDir), 0.0f);
        if (!carryRecorded)
        {
            carryM = totalM;
        }

        return new Dictionary
        {
            { "carry_yd", carryM * YARDS_PER_METER },
            { "total_yd", totalM * YARDS_PER_METER },
            { "carry_yd_first_impact", carryM * YARDS_PER_METER },
            { "apex_ft", apexM * FEET_PER_METER },
            { "hang_time_s", hangTimeS },
            { "flight_time_s", hangTimeS },
            { "first_impact_time_s", hangTimeS },
            { "landing_speed_mps", landingSpeedMps },
            { "landing_angle_deg", landingAngleDeg },
            { "initial_re", initialAirSample.Reynolds },
            { "initial_spin_ratio", initialAirSample.SpinRatio },
            { "initial_launch_angle_deg", vla },
            { "initial_low_launch_lift_scale", initialAirSample.LowLaunchLiftScale },
            { "initial_spin_drag_multiplier", initialAirSample.SpinDragMultiplier },
            { "initial_backspin_rpm", backspin },
            { "initial_sidespin_rpm", sidespin },
            { "initial_total_spin_rpm", totalSpin },
            { "initial_spin_axis_deg", spinAxis },
            { "initial_cd", initialAirSample.DragCoefficient },
            { "initial_cl", initialAirSample.LiftCoefficient },
            { "peak_cl", peakCl },
            { "launch_regime_key", regimeKey },
            { "matched_regime_override_key", matchedOverrideKey },
            { "surface", surface.ToString() },
            { "first_impact_spinback", firstImpactSpinback },
            { "first_impact_tangent_in_mps", firstImpactTangentIn },
            { "first_impact_tangent_out_mps", firstImpactTangentOut }
        };
    }

    /// <summary>
    /// Carry-only simulation for rapid calibration from GDScript or C#.
    /// Runs flight loop only and stops at first ground impact (no bounce or rollout).
    /// </summary>
    public Dictionary SimulateCarryOnlyFromJson(Dictionary shot)
    {
        return SimulateCarryOnlyInternal(shot, null);
    }

    /// <summary>
    /// Carry-only simulation for rapid calibration.
    /// Runs flight loop only and stops at first ground impact (no bounce or rollout).
    /// Accepts an optional <see cref="FlightProfile"/> override for C# A/B testing.
    /// </summary>
    public Dictionary SimulateCarryOnly(Dictionary shot, FlightProfile flightProfile = null)
    {
        return SimulateCarryOnlyInternal(shot, flightProfile);
    }

    private Dictionary SimulateCarryOnlyInternal(Dictionary shot, FlightProfile flightProfile)
    {
        var ballDict = shot.ContainsKey("BallData") ? (Dictionary)shot["BallData"] : shot;
        if (ballDict == null || ballDict.Count == 0)
        {
            PhysicsLogger.PushError("Shot JSON missing BallData");
            return new Dictionary();
        }

        float speedMph = (float)(ballDict.ContainsKey("Speed") ? ballDict["Speed"] : 0.0);
        float vla = (float)(ballDict.ContainsKey("VLA") ? ballDict["VLA"] : 0.0);
        float hla = (float)(ballDict.ContainsKey("HLA") ? ballDict["HLA"] : 0.0);
        var spinData = _shotSetup.ParseSpin(ballDict);
        float backspin = (float)spinData["backspin"];
        float sidespin = (float)spinData["sidespin"];
        float totalSpin = (float)spinData["total"];
        float spinAxis = (float)spinData["axis"];

        var launch = _shotSetup.BuildLaunchVectorsFromComponents(speedMph, vla, hla, backspin, sidespin);
        Vector3 velocity = (Vector3)launch["velocity"];
        Vector3 omega = (Vector3)launch["omega"];
        Vector3 shotDir = (Vector3)launch["shot_direction"];

        string regimeKey = ShotRegimeKey.Build(speedMph, vla, totalSpin);
        string matchedOverrideKey = string.Empty;
        float dragScale = 1.0f;
        float liftScale = 1.0f;
        FlightProfile fp;
        if (flightProfile != null)
        {
            fp = flightProfile;
        }
        else
        {
            RegimeScaleOverride regimeScale = _ballProfile.ResolveScaleOverride(
                speedMph,
                vla,
                totalSpin,
                out regimeKey,
                out matchedOverrideKey
            );
            if (!string.IsNullOrEmpty(matchedOverrideKey))
                PhysicsLogger.Info($"[Regime] {regimeKey} matched={matchedOverrideKey} drag={regimeScale.DragScaleMultiplier:F3} lift={regimeScale.LiftScaleMultiplier:F3}");
            dragScale = _ballProfile.DragScaleMultiplier * regimeScale.DragScaleMultiplier;
            liftScale = _ballProfile.LiftScaleMultiplier * regimeScale.LiftScaleMultiplier;
            fp = _ballProfile.ResolvedFlight;
        }

        float airDensity = _aero.GetAirDensity(DEFAULT_ALT_FT, DEFAULT_TEMP_F, PhysicsEnums.Units.Imperial);
        float airViscosity = _aero.GetDynamicViscosity(DEFAULT_TEMP_F, PhysicsEnums.Units.Imperial);

        FlightAerodynamicsSample initialAirSample = BallPhysics.SampleFlightAerodynamics(
            velocity, omega, airDensity, airViscosity, dragScale, liftScale, vla, fp
        );

        Vector3 pos = new Vector3(0.0f, START_HEIGHT, 0.0f);
        float apexM = pos.Y;
        float peakCl = 0.0f;

        int steps = (int)(MAX_TIME / DT);
        float carryM = 0.0f;
        float hangTimeS = 0.0f;
        float landingSpeedMps = 0.0f;
        float landingAngleDeg = 0.0f;

        for (int i = 0; i < steps; i++)
        {
            FlightAerodynamicsSample airSample = BallPhysics.SampleFlightAerodynamics(
                velocity, omega, airDensity, airViscosity, dragScale, liftScale, vla, fp
            );
            if (airSample.HasAerodynamics)
            {
                peakCl = Mathf.Max(peakCl, airSample.LiftCoefficient);
            }

            // Inline flight integration (gravity + air forces only)
            Vector3 gravity = new Vector3(0.0f, -9.81f * BallPhysics.MASS, 0.0f);
            Vector3 airForces = Vector3.Zero;
            if (airSample.HasAerodynamics)
            {
                Vector3 drag = -0.5f * airSample.DragCoefficient * airDensity * BallPhysics.CROSS_SECTION * velocity * airSample.Speed;
                Vector3 magnus = Vector3.Zero;
                float omegaLen = omega.Length();
                if (omegaLen > 0.1f)
                {
                    Vector3 omegaCrossVel = omega.Cross(velocity);
                    magnus = 0.5f * airSample.LiftCoefficient * airDensity * BallPhysics.CROSS_SECTION * omegaCrossVel * airSample.Speed / omegaLen;
                }
                airForces = drag + magnus;
            }

            Vector3 force = gravity + airForces;
            Vector3 torque = -BallPhysics.MOMENT_OF_INERTIA * omega / BallPhysics.SPIN_DECAY_TAU;

            velocity += (force / BallPhysics.MASS) * DT;
            omega += (torque / BallPhysics.MOMENT_OF_INERTIA) * DT;
            pos += velocity * DT;
            apexM = Mathf.Max(apexM, pos.Y);

            if (pos.Y <= 0.0f && velocity.Y < -0.01f)
            {
                pos.Y = 0.0f;
                carryM = Mathf.Max(pos.Dot(shotDir), 0.0f);
                hangTimeS = (i + 1) * DT;
                landingSpeedMps = velocity.Length();
                float normalSpeed = Mathf.Abs(velocity.Y);
                float tangentSpeed = new Vector3(velocity.X, 0, velocity.Z).Length();
                landingAngleDeg = Mathf.RadToDeg(Mathf.Atan2(normalSpeed, Mathf.Max(tangentSpeed, 0.0001f)));
                break;
            }
        }

        if (hangTimeS == 0.0f)
        {
            carryM = Mathf.Max(pos.Dot(shotDir), 0.0f);
            hangTimeS = MAX_TIME;
        }

        return new Dictionary
        {
            { "carry_yd", carryM * YARDS_PER_METER },
            { "apex_ft", apexM * FEET_PER_METER },
            { "hang_time_s", hangTimeS },
            { "landing_speed_mps", landingSpeedMps },
            { "landing_angle_deg", landingAngleDeg },
            { "initial_re", initialAirSample.Reynolds },
            { "initial_spin_ratio", initialAirSample.SpinRatio },
            { "initial_launch_angle_deg", vla },
            { "initial_low_launch_lift_scale", initialAirSample.LowLaunchLiftScale },
            { "initial_spin_drag_multiplier", initialAirSample.SpinDragMultiplier },
            { "initial_backspin_rpm", backspin },
            { "initial_sidespin_rpm", sidespin },
            { "initial_total_spin_rpm", totalSpin },
            { "initial_spin_axis_deg", spinAxis },
            { "initial_cd", initialAirSample.DragCoefficient },
            { "initial_cl", initialAirSample.LiftCoefficient },
            { "peak_cl", peakCl },
            { "launch_regime_key", regimeKey },
            { "matched_regime_override_key", matchedOverrideKey },
            { "flight_profile_name", fp.Name }
        };
    }

    private PhysicsParams CreateParams(
        Vector3 floorNormal,
        PhysicsEnums.SurfaceType surface,
        float initialLaunchAngleDeg,
        float launchSpeedMph,
        float launchSpinRpm)
    {
        float airDensity = _aero.GetAirDensity(DEFAULT_ALT_FT, DEFAULT_TEMP_F, PhysicsEnums.Units.Imperial);
        float airViscosity = _aero.GetDynamicViscosity(DEFAULT_TEMP_F, PhysicsEnums.Units.Imperial);

        return _physicsParamsFactory.Create(
            airDensity,
            airViscosity,
            1.0f,
            1.0f,
            surface,
            floorNormal,
            rolloutImpactSpin: 0.0f,
            ballProfile: _ballProfile,
            initialLaunchAngleDeg: initialLaunchAngleDeg,
            launchSpeedMph: launchSpeedMph,
            launchSpinRpm: launchSpinRpm
        ).ToPhysicsParams();
    }
}
