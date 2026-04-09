using Godot;

internal readonly struct FlightAerodynamicsSample
{
    public float Speed { get; }
    public float SpinRatio { get; }
    public float Reynolds { get; }
    public float SpinDragMultiplier { get; }
    public float LowLaunchLiftScale { get; }
    public float DragCoefficient { get; }
    public float LiftCoefficient { get; }

    public bool HasAerodynamics => Speed >= FlightAerodynamicsModel.MinAerodynamicSpeed;

    public FlightAerodynamicsSample(
        float speed,
        float spinRatio,
        float reynolds,
        float spinDragMultiplier,
        float lowLaunchLiftScale,
        float dragCoefficient,
        float liftCoefficient)
    {
        Speed = speed;
        SpinRatio = spinRatio;
        Reynolds = reynolds;
        SpinDragMultiplier = spinDragMultiplier;
        LowLaunchLiftScale = lowLaunchLiftScale;
        DragCoefficient = dragCoefficient;
        LiftCoefficient = liftCoefficient;
    }
}

internal static class FlightAerodynamicsModel
{
    internal const float MinAerodynamicSpeed = 0.5f;

    // Legacy accessors — kept so existing references (Aerodynamics.cs, BallPhysics.cs) still compile.
    // These read from the default profile singleton.
    internal static float CdMin => FlightProfile.Default.CdMin;
    internal static float SpinDragMultiplierCoeff => FlightProfile.Default.SpinDragMultiplierCoeff;
    internal static float SpinDragMultiplierMax => FlightProfile.Default.SpinDragMultiplierMax;
    internal static float SpinDragMultiplierHighSpinMax => FlightProfile.Default.SpinDragMultiplierHighSpinMax;
    internal static float SpinDragMultiplierUltraHighSpinMax => FlightProfile.Default.SpinDragMultiplierUltraHighSpinMax;
    internal static float LowLaunchLiftRecoveryMax => FlightProfile.Default.LowLaunchLiftRecoveryMax;

    // ── backward-compatible overloads (delegate to Default profile) ──

    internal static FlightAerodynamicsSample Sample(
        Vector3 velocity,
        Vector3 omega,
        float airDensity,
        float airViscosity,
        float dragScale,
        float liftScale,
        float initialLaunchAngleDeg)
    {
        return Sample(velocity, omega, airDensity, airViscosity, dragScale, liftScale, initialLaunchAngleDeg, FlightProfile.Default);
    }

    internal static float GetCd(float reynolds)
    {
        return GetCd(reynolds, FlightProfile.Default);
    }

    internal static float GetCl(float reynolds, float spinRatio)
    {
        return GetCl(reynolds, spinRatio, FlightProfile.Default);
    }

    internal static float GetSpinDragMultiplier(float spinRatio)
    {
        return GetSpinDragMultiplier(spinRatio, FlightProfile.Default.HighSpinDragReliefReFullMax, FlightProfile.Default);
    }

    internal static float GetSpinDragMultiplier(float spinRatio, float reynolds)
    {
        return GetSpinDragMultiplier(spinRatio, reynolds, FlightProfile.Default);
    }

    internal static float GetLowLaunchLiftScale(float initialLaunchAngleDeg, float spinRatio, float reynolds)
    {
        return GetLowLaunchLiftScale(initialLaunchAngleDeg, spinRatio, reynolds, FlightProfile.Default);
    }

    internal static float GetHighLaunchDragScale(float initialLaunchAngleDeg, float spinRatio)
    {
        return GetHighLaunchDragScale(initialLaunchAngleDeg, spinRatio, FlightProfile.Default);
    }

    internal static float GetMidSpinClBoost(float spinRatio)
    {
        return GetMidSpinClBoost(spinRatio, FlightProfile.Default);
    }

    internal static float GetClMax(float spinRatio)
    {
        return GetClMax(spinRatio, FlightProfile.Default);
    }

    // ── profile-aware implementations ──

    internal static FlightAerodynamicsSample Sample(
        Vector3 velocity,
        Vector3 omega,
        float airDensity,
        float airViscosity,
        float dragScale,
        float liftScale,
        float initialLaunchAngleDeg,
        FlightProfile p)
    {
        float speed = velocity.Length();
        if (speed < MinAerodynamicSpeed)
        {
            return new FlightAerodynamicsSample(
                0.0f, 0.0f, 0.0f, 1.0f, 1.0f, 0.0f, 0.0f
            );
        }

        float spinRatio = omega.Length() * BallPhysics.RADIUS / speed;
        float reynolds = airDensity * speed * BallPhysics.RADIUS * 2.0f / airViscosity;
        float spinDragMultiplier = GetSpinDragMultiplier(spinRatio, reynolds, p);
        float lowLaunchLiftScale = GetLowLaunchLiftScale(initialLaunchAngleDeg, spinRatio, reynolds, p);
        float highLaunchDragScale = GetHighLaunchDragScale(initialLaunchAngleDeg, spinRatio, p);
        float dragCoefficient = GetCd(reynolds, p) * spinDragMultiplier * dragScale * highLaunchDragScale;
        float liftCoefficient = GetCl(reynolds, spinRatio, p) * liftScale * lowLaunchLiftScale;
        liftCoefficient *= GetMidSpinClBoost(spinRatio, p);

        return new FlightAerodynamicsSample(
            speed, spinRatio, reynolds, spinDragMultiplier,
            lowLaunchLiftScale, dragCoefficient, liftCoefficient
        );
    }

    internal static float GetCd(float reynolds, FlightProfile p)
    {
        if (reynolds > 200000.0f)
            return p.HighReCdCap;

        if (reynolds >= 50000.0f)
        {
            return p.CdPolyA + p.CdPolyB * reynolds +
                p.CdPolyC * reynolds * reynolds +
                p.CdPolyD * reynolds * reynolds * reynolds;
        }

        if (reynolds <= p.LowReBlendStart)
            return p.LowReCdFloor;

        float t = SafeSmoothStep01(reynolds, p.LowReBlendStart, 50000.0f);
        return Mathf.Lerp(p.LowReCdFloor, p.CdAt50k, t);
    }

    internal static float GetCl(float reynolds, float spinRatio, FlightProfile p)
    {
        float spin = Mathf.Max(0.0f, spinRatio);
        if (spin <= 0.0f)
            return 0.0f;

        float dynamicClMax = GetClMax(spin, p);

        if (reynolds < 50000.0f)
        {
            if (reynolds <= 30000.0f)
                return 0.0f;

            float lowReT = SmoothStep01((reynolds - 30000.0f) / 20000.0f);
            float clAt50k = Mathf.Clamp(ClRe50k(spin), 0.0f, dynamicClMax);
            float clBeforeAtten = clAt50k * lowReT;

            return ApplyLowReHighSpinLiftAttenuation(spin, clBeforeAtten, p);
        }

        if (reynolds >= p.HighReStart)
        {
            return ApplyHighSpinLiftAttenuation(spin, Mathf.Clamp(ClHighRe(spin, p), 0.0f, dynamicClMax), p);
        }

        int[] reValues = { 50000, 60000, 65000, 70000, 75000 };
        int reHighIndex = reValues.Length - 1;

        for (int i = 0; i < reValues.Length; i++)
        {
            if (reynolds <= reValues[i])
            {
                reHighIndex = i;
                break;
            }
        }

        int reLowIndex = Mathf.Max(reHighIndex - 1, 0);

        float clLow = Mathf.Max(0.0f, ClAtReynoldsIndex(reLowIndex, spin, p));
        float clHigh = Mathf.Max(0.0f, ClAtReynoldsIndex(reHighIndex, spin, p));
        float reLow = reValues[reLowIndex];
        float reHigh = reValues[reHighIndex];
        float weight = reHigh != reLow ? (reynolds - reLow) / (reHigh - reLow) : 0.0f;

        float clInterpolated = Mathf.Lerp(clLow, clHigh, weight);
        float clClamped = Mathf.Clamp(clInterpolated, 0.0f, dynamicClMax);

        return ApplyLowReHighSpinLiftAttenuation(spin, clClamped, p);
    }

    internal static float GetSpinDragMultiplier(float spinRatio, float reynolds, FlightProfile p)
    {
        if (spinRatio <= 0.0f)
            return 1.0f;

        float highSpinWeight = SafeSmoothStep01(spinRatio, p.HighSpinDragSrStart, p.HighSpinDragSrEnd);
        float reReliefWeight = 1.0f - SafeSmoothStep01(reynolds, p.HighSpinDragReliefReFullMax, p.HighSpinDragReliefReZero);
        float reliefWeight = highSpinWeight * reReliefWeight;
        float effectiveCap = Mathf.Lerp(p.SpinDragMultiplierMax, p.SpinDragMultiplierHighSpinMax, reliefWeight);

        float progressiveBoost = p.SpinDragProgressiveCapBoostMax
            * SafeSmoothStep01(spinRatio, p.SpinDragProgressiveCapSrStart, p.SpinDragProgressiveCapSrEnd);
        effectiveCap += progressiveBoost;

        float ultraHighSpinWeight = SafeSmoothStep01(spinRatio, p.UltraHighSpinDragSrStart, p.UltraHighSpinDragSrEnd);
        effectiveCap = Mathf.Lerp(effectiveCap, p.SpinDragMultiplierUltraHighSpinMax, ultraHighSpinWeight);

        float spinDragMultiplier = 1.0f + p.SpinDragMultiplierCoeff * spinRatio * spinRatio;
        return Mathf.Min(spinDragMultiplier, effectiveCap);
    }

    internal static float GetLowLaunchLiftScale(float initialLaunchAngleDeg, float spinRatio, float reynolds, FlightProfile p)
    {
        float launchFactor = SafeSmoothStep01(p.LowLaunchVlaZeroDeg - initialLaunchAngleDeg, 0.0f, p.LowLaunchVlaZeroDeg - p.LowLaunchVlaFullDeg);
        if (launchFactor <= 0.0f)
            return 1.0f;

        float reFactor = SafeSmoothStep01(reynolds, p.LowLaunchReStart, p.LowLaunchReEnd);
        if (reFactor <= 0.0f)
            return 1.0f;

        float spinFactor = 1.0f - SafeSmoothStep01(spinRatio, p.LowLaunchSpinRatioFull, p.LowLaunchSpinRatioMax);
        if (spinFactor <= 0.0f)
            return 1.0f;

        float recoveryWeight = launchFactor * reFactor * spinFactor;
        return Mathf.Lerp(1.0f, p.LowLaunchLiftRecoveryMax, recoveryWeight);
    }

    internal static float GetHighLaunchDragScale(float initialLaunchAngleDeg, float spinRatio, FlightProfile p)
    {
        float launchFactor = SafeSmoothStep01(initialLaunchAngleDeg, p.HighLaunchDragVlaStartDeg, p.HighLaunchDragVlaFullDeg);
        if (launchFactor <= 0.0f)
            return 1.0f;

        float spinFactor = SafeSmoothStep01(spinRatio, p.HighLaunchDragSrStart, p.HighLaunchDragSrEnd);
        if (spinFactor <= 0.0f)
            return 1.0f;

        float boostWeight = launchFactor * spinFactor;
        return Mathf.Lerp(1.0f, p.HighLaunchDragBoostMax, boostWeight);
    }

    internal static float GetMidSpinClBoost(float spinRatio, FlightProfile p)
    {
        if (p.MidSpinClBoostMax <= 0.0f)
            return 1.0f;
        float t = SafeSmoothStep01(spinRatio, p.MidSpinClBoostSrStart, p.MidSpinClBoostSrEnd);
        float bell = t * (1.0f - t) * 4.0f;
        return 1.0f + p.MidSpinClBoostMax * bell;
    }

    internal static float GetClMax(float spinRatio, FlightProfile p)
    {
        if (spinRatio <= p.ClMaxSrTransitionStart)
        {
            return p.ClMaxBase;
        }
        else if (spinRatio >= p.ClMaxSrTransitionEnd)
        {
            return p.ClMaxHighSpin;
        }
        else
        {
            float t = SafeSmoothStep01(spinRatio, p.ClMaxSrTransitionStart, p.ClMaxSrTransitionEnd);
            return Mathf.Lerp(p.ClMaxBase, p.ClMaxHighSpin, t);
        }
    }

    private static float ClAtReynoldsIndex(int index, float spinRatio, FlightProfile p) => index switch
    {
        0 => ClRe50k(spinRatio),
        1 => ClRe60k(spinRatio),
        2 => ClRe65k(spinRatio),
        3 => ClRe70k(spinRatio),
        _ => ClHighRe(spinRatio, p),
    };

    // Cl polynomial curves — these stay hardcoded (not extracted to profile)
    private static float ClRe50k(float spinRatio)
    {
        return 0.0472121f + 2.84795f * spinRatio - 23.4342f * spinRatio * spinRatio +
            45.4849f * spinRatio * spinRatio * spinRatio;
    }

    private static float ClRe60k(float spinRatio)
    {
        return 0.320524f - 4.7032f * spinRatio + 14.0613f * spinRatio * spinRatio;
    }

    private static float ClRe65k(float spinRatio)
    {
        return 0.266667f - 4.0f * spinRatio + 13.3333f * spinRatio * spinRatio;
    }

    private static float ClRe70k(float spinRatio)
    {
        return 0.0496189f + 0.00211396f * spinRatio + 2.34201f * spinRatio * spinRatio;
    }

    private static float ClHighRe(float spinRatio, FlightProfile p)
    {
        float effectiveGain = GetHighReSpinGain(spinRatio, p);
        float dynamicClMax = GetClMax(spinRatio, p);
        return dynamicClMax * spinRatio * effectiveGain / (1.0f + spinRatio * effectiveGain);
    }

    private static float ApplyHighSpinLiftAttenuation(float spinRatio, float cl, FlightProfile p)
    {
        float attenuationT = SafeSmoothStep01(spinRatio, p.HighSpinClAttenuationStart, p.HighSpinClAttenuationEnd);
        float attenuation = 1.0f - p.HighSpinClAttenuationMax * attenuationT;

        float ultraHighSpinAttenuationT = SafeSmoothStep01(spinRatio, p.UltraHighSpinClAttenuationStart, p.UltraHighSpinClAttenuationEnd);
        float ultraHighSpinAttenuation = 1.0f - p.UltraHighSpinClAttenuationMax * ultraHighSpinAttenuationT;

        return cl * attenuation * ultraHighSpinAttenuation;
    }

    private static float ApplyLowReHighSpinLiftAttenuation(float spinRatio, float cl, FlightProfile p)
    {
        float attenuationT = SafeSmoothStep01(spinRatio, p.HighSpinClAttenuationStart, p.HighSpinClAttenuationEnd);
        float attenuation = 1.0f - p.LowReHighSpinClAttenuationMax * attenuationT;

        float ultraHighSpinAttenuationT = SafeSmoothStep01(spinRatio, p.UltraHighSpinClAttenuationStart, p.UltraHighSpinClAttenuationEnd);
        float ultraHighSpinAttenuation = 1.0f - p.LowReUltraHighSpinClAttenuationMax * ultraHighSpinAttenuationT;

        return cl * attenuation * ultraHighSpinAttenuation;
    }

    private static float GetHighReSpinGain(float spinRatio, FlightProfile p)
    {
        if (spinRatio <= p.HighReGainReductionStart)
            return p.HighReSpinGain;

        if (spinRatio < p.HighReGainReductionEnd)
        {
            float reductionT = SafeSmoothStep01(spinRatio, p.HighReGainReductionStart, p.HighReGainReductionEnd);
            return Mathf.Lerp(p.HighReSpinGain, p.HighReMidSpinGain, reductionT);
        }

        if (spinRatio <= p.HighReGainRecoveryStart)
            return p.HighReMidSpinGain;

        if (spinRatio < p.HighReGainRecoveryEnd)
        {
            float recoveryT = SafeSmoothStep01(spinRatio, p.HighReGainRecoveryStart, p.HighReGainRecoveryEnd);
            return Mathf.Lerp(p.HighReMidSpinGain, p.HighReSpinGain, recoveryT);
        }

        return p.HighReSpinGain;
    }

    private static float SmoothStep01(float t)
    {
        float clampedT = Mathf.Clamp(t, 0.0f, 1.0f);
        return clampedT * clampedT * (3.0f - 2.0f * clampedT);
    }

    /// <summary>
    /// SmoothStep with safe division: when (end - start) is near zero,
    /// returns 1 if value >= end, else 0. Prevents NaN propagation from
    /// degenerate FlightProfile ranges where start == end.
    /// </summary>
    private static float SafeSmoothStep01(float value, float start, float end)
    {
        float range = end - start;
        if (Mathf.Abs(range) < 1e-6f)
            return value >= end ? 1.0f : 0.0f;
        return SmoothStep01((value - start) / range);
    }
}
