using Godot;

/// <summary>
/// Bounce physics calculations extracted from BallPhysics.
/// Handles impact bounce resolution, coefficient of restitution, and critical angle computation.
/// </summary>
[GlobalClass]
public partial class BounceCalculator : RefCounted
{
    /// <summary>
    /// Calculate bounce physics when ball impacts surface
    /// </summary>
    public BounceResult CalculateBounce(
        Vector3 vel,
        Vector3 omega,
        Vector3 normal,
        PhysicsEnums.BallState currentState,
        PhysicsParams parameters)
    {
        PhysicsEnums.BallState newState = currentState == PhysicsEnums.BallState.Flight
            ? PhysicsEnums.BallState.Rollout
            : currentState;

        // Decompose velocity
        Vector3 velNormal = vel.Project(normal);
        float speedNormal = velNormal.Length();
        Vector3 velTangent = vel - velNormal;
        float speedTangent = velTangent.Length();

        // Decompose angular velocity
        Vector3 omegaNormal = omega.Project(normal);
        Vector3 omegaTangent = omega - omegaNormal;

        // Calculate impact angle from the SURFACE (not from the normal)
        // vel.AngleTo(normal) gives angle to normal, but Penner's critical angle is from surface
        float angleToNormal = vel.AngleTo(normal);
        float impactAngle = Mathf.Abs(angleToNormal - Mathf.Pi / 2.0f);

        // Use tangential spin magnitude for bounce calculation (backspin creates reverse velocity)
        float omegaTangentMagnitude = omegaTangent.Length();

        // Tangential retention based on spin
        float currentSpinRpm = omega.Length() / ShotSetup.RAD_PER_RPM;

        float tangentialRetention;

        if (currentState == PhysicsEnums.BallState.Flight)
        {
            // First bounce from flight: Use spin-based penalty
            float spinFactor = Mathf.Clamp(1.0f - (currentSpinRpm / 8000.0f), 0.40f, 1.0f);
            tangentialRetention = 0.55f * spinFactor;
        }
        else
        {
            // Rollout bounces: Higher retention, no spin penalty
            // Use spin ratio to determine how much velocity to keep
            float ballSpeed = vel.Length();
            float spinRatio = ballSpeed > 0.1f ? (omega.Length() * BallPhysics.RADIUS) / ballSpeed : 0.0f;

            // Low spin ratio = more rollout retention
            if (spinRatio < 0.20f)
            {
                tangentialRetention = Mathf.Lerp(0.85f, 0.70f, spinRatio / 0.20f);
            }
            else
            {
                tangentialRetention = 0.70f;
            }
        }

        if (newState == PhysicsEnums.BallState.Rollout)
        {
            PhysicsLogger.Verbose($"  Bounce: spin={currentSpinRpm:F0} rpm, retention={tangentialRetention:F3}");
        }

        // Calculate new tangential speed
        float newTangentSpeed;

        if (currentState == PhysicsEnums.BallState.Flight)
        {
            // First bounce from flight
            // The Penner model only works for HIGH-ENERGY steep impacts (full wedge shots)
            // For low-energy impacts (chip shots), use simple retention even if angle is steep
            // For shallow-angle impacts (driver shots), use simple retention
            float impactSpeed = vel.Length();
            bool hasSpinbackSurface = parameters.SpinbackThetaBoostMax > 0.0f || parameters.SpinbackResponseScale > 1.0f;
            float effectiveCriticalAngle = GetEffectiveCriticalAngle(parameters, currentSpinRpm, impactSpeed, currentState);
            float impactAngleDeg = Mathf.RadToDeg(impactAngle);
            float criticalAngleDeg = Mathf.RadToDeg(effectiveCriticalAngle);
            bool isSteepImpact = impactAngle >= effectiveCriticalAngle;

            // Surfaces without spinback keep the low-energy guard to prevent unrealistic
            // chip spin-back. Spinback surfaces allow steep-impact Penner behavior even
            // below the threshold so high-spin flop/wedge shots can naturally check/spin back.
            // High backspin (>4000 RPM) indicates a wedge/flop, not a chip — lower the guard.
            float pennerSpeedThreshold = 20.0f;
            if (currentSpinRpm > 4000.0f)
            {
                float spinT = Mathf.Clamp((currentSpinRpm - 4000.0f) / 4000.0f, 0.0f, 1.0f);
                pennerSpeedThreshold = Mathf.Lerp(20.0f, 12.0f, spinT);
            }
            bool shouldUsePenner = isSteepImpact && (impactSpeed >= pennerSpeedThreshold || hasSpinbackSurface);

            if (!shouldUsePenner)
            {
                // Shallow angle OR low energy (chip shots): use simple retention
                // This prevents chip shots from rolling backward even with high spin
                newTangentSpeed = speedTangent * tangentialRetention;
                if (!isSteepImpact)
                {
                    PhysicsLogger.Verbose($"  Bounce: Shallow angle ({impactAngleDeg:F2}° < {criticalAngleDeg:F2}°) - using simple retention");
                }
                else if (impactSpeed < pennerSpeedThreshold && !hasSpinbackSurface)
                {
                    PhysicsLogger.Verbose($"  Bounce: Low energy ({impactSpeed:F2} m/s < {pennerSpeedThreshold:F2} m/s) - using simple retention");
                }
                else
                {
                    PhysicsLogger.Verbose($"  Bounce: Using simple retention (surface={parameters.SurfaceType}, speed={impactSpeed:F2} m/s)");
                }
                PhysicsLogger.Verbose($"    speedTangent={speedTangent:F2} m/s, newTangentSpeed={newTangentSpeed:F2} m/s");
            }
            else
            {
                // Penner tangential model for steep impacts:
                // backspin term can reverse tangential velocity (spin-back) when large enough.
                // Surface response scales how strongly a lie converts spin into reverse tangential motion.
                float spinbackTerm = 2.0f * BallPhysics.RADIUS * omegaTangentMagnitude * Mathf.Max(parameters.SpinbackResponseScale, 0.0f) / 7.0f;
                newTangentSpeed = tangentialRetention * vel.Length() * Mathf.Sin(impactAngle - effectiveCriticalAngle) -
                    spinbackTerm;
                PhysicsLogger.Verbose($"  Bounce: Penner model ({parameters.SurfaceType}) speed={impactSpeed:F2} m/s angle={impactAngleDeg:F2}° crit={criticalAngleDeg:F2}°");
                PhysicsLogger.Verbose($"    speedTangent={speedTangent:F2} m/s, spinbackScale={parameters.SpinbackResponseScale:F2}, newTangentSpeed={newTangentSpeed:F2} m/s");
            }
        }
        else
        {
            // Subsequent bounces during rollout: Simple friction factor (like libgolf)
            // Don't subtract spin - just apply friction to existing tangential velocity
            newTangentSpeed = speedTangent * tangentialRetention;
        }

        if (speedTangent < 0.01f && Mathf.Abs(newTangentSpeed) < 0.01f)
        {
            velTangent = Vector3.Zero;
        }
        else if (newTangentSpeed < 0.0f)
        {
            // Spin-back: reverse tangential direction
            velTangent = -velTangent.Normalized() * Mathf.Abs(newTangentSpeed);
        }
        else
        {
            velTangent = velTangent.LimitLength(newTangentSpeed);
        }

        // Update tangential angular velocity
        if (currentState == PhysicsEnums.BallState.Flight)
        {
            // First bounce: compute omega from tangent speed
            float newOmegaTangent = Mathf.Abs(newTangentSpeed) / BallPhysics.RADIUS;
            if (omegaTangent.Length() < 0.1f || newOmegaTangent < 0.01f)
            {
                omegaTangent = Vector3.Zero;
            }
            else if (newTangentSpeed < 0.0f)
            {
                omegaTangent = -omegaTangent.Normalized() * newOmegaTangent;
            }
            else
            {
                omegaTangent = omegaTangent.LimitLength(newOmegaTangent);
            }
        }
        else
        {
            // Rollout: preserve existing spin, don't force it to match rolling velocity
            // The ball will slip initially, but forcing high spin kills rollout energy
            // Natural spin decay will occur through ground torques
            if (newTangentSpeed > 0.05f)
            {
                // Keep existing spin magnitude but ensure it's in the right direction
                float existingSpinMag = omegaTangent.Length();
                Vector3 tangentDir = velTangent.Length() > 0.01f ? velTangent.Normalized() : Vector3.Right;
                Vector3 rollingAxis = normal.Cross(tangentDir).Normalized();

                // Gradually adjust spin toward rolling direction, but don't increase magnitude
                if (existingSpinMag > 0.05f)
                {
                    omegaTangent = rollingAxis * existingSpinMag;
                }
                else
                {
                    omegaTangent = Vector3.Zero;
                }
            }
            else
            {
                omegaTangent = Vector3.Zero;
            }
        }

        // Coefficient of restitution (speed-dependent and spin-dependent)
        float cor;
        if (currentState == PhysicsEnums.BallState.Flight)
        {
            // First bounce from flight: use base COR, reduced by spin
            // High spin causes ball to "stick" to turf, reducing bounce
            float baseCor = GetCoefficientOfRestitution(speedNormal);

            // Spin-based COR reduction
            float spinRpm = omega.Length() / ShotSetup.RAD_PER_RPM;

            // Velocity scaling: High-spin COR reduction should only apply to high-energy impacts
            // The "bite" effect from spin depends on impact energy, not just spin rate
            float corVelocityScale;
            if (speedNormal < 12.0f)
            {
                // Low-speed impacts (chip shots): Reduced COR penalty
                corVelocityScale = Mathf.Lerp(0.0f, 0.50f, speedNormal / 12.0f);
            }
            else if (speedNormal < 25.0f)
            {
                // Medium-speed impacts: Transition
                corVelocityScale = Mathf.Lerp(0.50f, 1.0f, (speedNormal - 12.0f) / 13.0f);
            }
            else
            {
                // High-speed impacts: Full penalty
                corVelocityScale = 1.0f;
            }

            float spinCORReduction;

            if (spinRpm < 1500.0f)
            {
                // Low spin: Minimal COR reduction (0% to 30%)
                spinCORReduction = (spinRpm / 1500.0f) * 0.30f;
            }
            else
            {
                // High spin: Strong COR reduction (30% to 70%)
                // At 1500 rpm: 30% reduction
                // At 3000+ rpm: 70% reduction (flop shots stick!)
                float excessSpin = spinRpm - 1500.0f;
                float spinFactor = Mathf.Min(excessSpin / 1500.0f, 1.0f);
                float maxReduction = 0.30f + spinFactor * 0.40f;
                spinCORReduction = maxReduction * corVelocityScale;
            }

            cor = baseCor * (1.0f - spinCORReduction);

            // Debug output for first bounce
            if (newState == PhysicsEnums.BallState.Rollout)
            {
                PhysicsLogger.Verbose($"    speedNormal={speedNormal:F2} m/s, spin={spinRpm:F0} rpm");
                PhysicsLogger.Verbose($"    baseCOR={baseCor:F3}, spinReduction={spinCORReduction:F2}, finalCOR={cor:F3}");
                PhysicsLogger.Verbose($"    velNormal will be {speedNormal * cor:F2} m/s");
            }
        }
        else
        {
            // Rollout bounces: kill small bounces aggressively to settle into roll
            if (speedNormal < 4.0f)
            {
                cor = 0.0f;  // Kill small rollout bounces completely
            }
            else
            {
                cor = GetCoefficientOfRestitution(speedNormal) * 0.5f;  // Halve COR for rollout
            }

            if (speedNormal > 0.5f)
            {
                PhysicsLogger.Verbose($"    speedNormal={speedNormal:F2} m/s, COR={cor:F3}, velNormal will be {speedNormal * cor:F2} m/s");
            }
        }

        velNormal = velNormal * -cor;

        Vector3 newOmega = omegaNormal + omegaTangent;
        Vector3 newVelocity = velNormal + velTangent;

        return new BounceResult(newVelocity, newOmega, newState);
    }

    /// <summary>
    /// Get coefficient of restitution based on impact speed
    /// </summary>
    public float GetCoefficientOfRestitution(float speedNormal)
    {
        return GetCoefficientOfRestitution(speedNormal, BounceProfile.Default);
    }

    public float GetCoefficientOfRestitution(float speedNormal, BounceProfile bp)
    {
        if (speedNormal > bp.CorHighSpeedThreshold)
            return bp.CorHighSpeedCap;
        else if (speedNormal < bp.CorKillThreshold)
            return 0.0f;
        else
        {
            return bp.CorBaseA + bp.CorBaseB * speedNormal + bp.CorBaseC * speedNormal * speedNormal;
        }
    }

    // ── Profile-aware overload ──

    public BounceResult CalculateBounce(
        Vector3 vel,
        Vector3 omega,
        Vector3 normal,
        PhysicsEnums.BallState currentState,
        PhysicsParams parameters,
        BounceProfile bp)
    {
        PhysicsEnums.BallState newState = currentState == PhysicsEnums.BallState.Flight
            ? PhysicsEnums.BallState.Rollout
            : currentState;

        Vector3 velNormal = vel.Project(normal);
        float speedNormal = velNormal.Length();
        Vector3 velTangent = vel - velNormal;
        float speedTangent = velTangent.Length();

        Vector3 omegaNormal = omega.Project(normal);
        Vector3 omegaTangent = omega - omegaNormal;

        float angleToNormal = vel.AngleTo(normal);
        float impactAngle = Mathf.Abs(angleToNormal - Mathf.Pi / 2.0f);

        float omegaTangentMagnitude = omegaTangent.Length();
        float currentSpinRpm = omega.Length() / ShotSetup.RAD_PER_RPM;

        float tangentialRetention;

        if (currentState == PhysicsEnums.BallState.Flight)
        {
            float spinFactor = Mathf.Clamp(1.0f - (currentSpinRpm / bp.FlightSpinFactorDivisor), bp.FlightSpinFactorMin, 1.0f);
            tangentialRetention = bp.FlightTangentialRetentionBase * spinFactor;
        }
        else
        {
            float ballSpeed = vel.Length();
            float spinRatio = ballSpeed > 0.1f ? (omega.Length() * BallPhysics.RADIUS) / ballSpeed : 0.0f;

            if (spinRatio < bp.RolloutSpinRatioThreshold)
            {
                tangentialRetention = Mathf.Lerp(bp.RolloutLowSpinRetention, bp.RolloutHighSpinRetention, spinRatio / bp.RolloutSpinRatioThreshold);
            }
            else
            {
                tangentialRetention = bp.RolloutHighSpinRetention;
            }
        }

        if (newState == PhysicsEnums.BallState.Rollout)
        {
            PhysicsLogger.Verbose($"  Bounce: spin={currentSpinRpm:F0} rpm, retention={tangentialRetention:F3}");
        }

        float newTangentSpeed;

        if (currentState == PhysicsEnums.BallState.Flight)
        {
            float impactSpeed = vel.Length();
            bool hasSpinbackSurface = parameters.SpinbackThetaBoostMax > 0.0f || parameters.SpinbackResponseScale > 1.0f;
            float effectiveCriticalAngle = GetEffectiveCriticalAngle(parameters, currentSpinRpm, impactSpeed, currentState);
            float impactAngleDeg = Mathf.RadToDeg(impactAngle);
            float criticalAngleDeg = Mathf.RadToDeg(effectiveCriticalAngle);
            bool isSteepImpact = impactAngle >= effectiveCriticalAngle;

            bool shouldUsePenner = isSteepImpact && (impactSpeed >= bp.PennerLowEnergyThreshold || hasSpinbackSurface);

            if (!shouldUsePenner)
            {
                newTangentSpeed = speedTangent * tangentialRetention;
                if (!isSteepImpact)
                    PhysicsLogger.Verbose($"  Bounce: Shallow angle ({impactAngleDeg:F2}° < {criticalAngleDeg:F2}°) - using simple retention");
                else if (impactSpeed < bp.PennerLowEnergyThreshold && !hasSpinbackSurface)
                    PhysicsLogger.Verbose($"  Bounce: Low energy ({impactSpeed:F2} m/s < {bp.PennerLowEnergyThreshold:F1} m/s) - using simple retention");
                else
                    PhysicsLogger.Verbose($"  Bounce: Using simple retention (surface={parameters.SurfaceType}, speed={impactSpeed:F2} m/s)");
                PhysicsLogger.Verbose($"    speedTangent={speedTangent:F2} m/s, newTangentSpeed={newTangentSpeed:F2} m/s");
            }
            else
            {
                float spinbackTerm = 2.0f * BallPhysics.RADIUS * omegaTangentMagnitude * Mathf.Max(parameters.SpinbackResponseScale, 0.0f) / 7.0f;
                newTangentSpeed = tangentialRetention * vel.Length() * Mathf.Sin(impactAngle - effectiveCriticalAngle) -
                    spinbackTerm;
                PhysicsLogger.Verbose($"  Bounce: Penner model ({parameters.SurfaceType}) speed={impactSpeed:F2} m/s angle={impactAngleDeg:F2}° crit={criticalAngleDeg:F2}°");
                PhysicsLogger.Verbose($"    speedTangent={speedTangent:F2} m/s, spinbackScale={parameters.SpinbackResponseScale:F2}, newTangentSpeed={newTangentSpeed:F2} m/s");
            }
        }
        else
        {
            newTangentSpeed = speedTangent * tangentialRetention;
        }

        if (speedTangent < 0.01f && Mathf.Abs(newTangentSpeed) < 0.01f)
        {
            velTangent = Vector3.Zero;
        }
        else if (newTangentSpeed < 0.0f)
        {
            velTangent = -velTangent.Normalized() * Mathf.Abs(newTangentSpeed);
        }
        else
        {
            velTangent = velTangent.LimitLength(newTangentSpeed);
        }

        if (currentState == PhysicsEnums.BallState.Flight)
        {
            float newOmegaTangent = Mathf.Abs(newTangentSpeed) / BallPhysics.RADIUS;
            if (omegaTangent.Length() < 0.1f || newOmegaTangent < 0.01f)
            {
                omegaTangent = Vector3.Zero;
            }
            else if (newTangentSpeed < 0.0f)
            {
                omegaTangent = -omegaTangent.Normalized() * newOmegaTangent;
            }
            else
            {
                omegaTangent = omegaTangent.LimitLength(newOmegaTangent);
            }
        }
        else
        {
            if (newTangentSpeed > 0.05f)
            {
                float existingSpinMag = omegaTangent.Length();
                Vector3 tangentDir = velTangent.Length() > 0.01f ? velTangent.Normalized() : Vector3.Right;
                Vector3 rollingAxis = normal.Cross(tangentDir).Normalized();

                if (existingSpinMag > 0.05f)
                {
                    omegaTangent = rollingAxis * existingSpinMag;
                }
                else
                {
                    omegaTangent = Vector3.Zero;
                }
            }
            else
            {
                omegaTangent = Vector3.Zero;
            }
        }

        float cor;
        if (currentState == PhysicsEnums.BallState.Flight)
        {
            float baseCor = GetCoefficientOfRestitution(speedNormal, bp);
            float spinRpm = omega.Length() / ShotSetup.RAD_PER_RPM;

            float corVelocityScale;
            if (speedNormal < bp.CorVelocityLowThreshold)
            {
                corVelocityScale = Mathf.Lerp(0.0f, bp.CorVelocityLowScale, speedNormal / bp.CorVelocityLowThreshold);
            }
            else if (speedNormal < bp.CorVelocityMidThreshold)
            {
                corVelocityScale = Mathf.Lerp(bp.CorVelocityLowScale, 1.0f, (speedNormal - bp.CorVelocityLowThreshold) / (bp.CorVelocityMidThreshold - bp.CorVelocityLowThreshold));
            }
            else
            {
                corVelocityScale = 1.0f;
            }

            float spinCORReduction;
            if (spinRpm < bp.SpinCorLowSpinThreshold)
            {
                spinCORReduction = (spinRpm / bp.SpinCorLowSpinThreshold) * bp.SpinCorLowSpinMaxReduction;
            }
            else
            {
                float excessSpin = spinRpm - bp.SpinCorLowSpinThreshold;
                float spinFactor = Mathf.Min(excessSpin / bp.SpinCorHighSpinRangeRpm, 1.0f);
                float maxReduction = bp.SpinCorLowSpinMaxReduction + spinFactor * bp.SpinCorHighSpinAdditionalReduction;
                spinCORReduction = maxReduction * corVelocityScale;
            }

            cor = baseCor * (1.0f - spinCORReduction);

            if (newState == PhysicsEnums.BallState.Rollout)
            {
                PhysicsLogger.Verbose($"    speedNormal={speedNormal:F2} m/s, spin={spinRpm:F0} rpm");
                PhysicsLogger.Verbose($"    baseCOR={baseCor:F3}, spinReduction={spinCORReduction:F2}, finalCOR={cor:F3}");
                PhysicsLogger.Verbose($"    velNormal will be {speedNormal * cor:F2} m/s");
            }
        }
        else
        {
            if (speedNormal < bp.RolloutBounceCorKillThreshold)
            {
                cor = 0.0f;
            }
            else
            {
                cor = GetCoefficientOfRestitution(speedNormal, bp) * bp.RolloutBounceCorScale;
            }

            if (speedNormal > 0.5f)
            {
                PhysicsLogger.Verbose($"    speedNormal={speedNormal:F2} m/s, COR={cor:F3}, velNormal will be {speedNormal * cor:F2} m/s");
            }
        }

        velNormal = velNormal * -cor;

        Vector3 newOmega = omegaNormal + omegaTangent;
        Vector3 newVelocity = velNormal + velTangent;

        return new BounceResult(newVelocity, newOmega, newState);
    }

    /// <summary>
    /// Greens can exhibit stronger check/spinback on steep, high-spin impacts.
    /// Model this as an effective increase in critical angle for high-spin wedge/flop
    /// impacts, while leaving lower-spin/low-speed impacts unchanged.
    /// </summary>
    internal static float GetEffectiveCriticalAngle(
        PhysicsParams parameters,
        float currentSpinRpm,
        float impactSpeed,
        PhysicsEnums.BallState currentState)
    {
        if (currentState != PhysicsEnums.BallState.Flight ||
            parameters.SpinbackThetaBoostMax <= 0.0f)
        {
            return parameters.CriticalAngle;
        }

        float spinRange = parameters.SpinbackSpinEndRpm - parameters.SpinbackSpinStartRpm;
        float spinT = spinRange > 0.0f
            ? Mathf.Clamp((currentSpinRpm - parameters.SpinbackSpinStartRpm) / spinRange, 0.0f, 1.0f)
            : 0.0f;
        spinT = spinT * spinT * (3.0f - 2.0f * spinT);

        float speedRange = parameters.SpinbackSpeedEndMps - parameters.SpinbackSpeedStartMps;
        float speedT = speedRange > 0.0f
            ? Mathf.Clamp((impactSpeed - parameters.SpinbackSpeedStartMps) / speedRange, 0.0f, 1.0f)
            : 0.0f;
        speedT = speedT * speedT * (3.0f - 2.0f * speedT);

        float boost = parameters.SpinbackThetaBoostMax * spinT * speedT;
        return parameters.CriticalAngle + boost;
    }
}
