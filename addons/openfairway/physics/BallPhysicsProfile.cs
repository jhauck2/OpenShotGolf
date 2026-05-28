using System.Collections.Generic;
using System.Text.Json;

/// <summary>
/// Ball-specific physics modifiers. Defaults are neutral so current
/// behavior is preserved until a non-default profile is supplied.
/// </summary>
public sealed class BallPhysicsProfile
{
    private static readonly HashSet<string> RegimeOverrideKnownKeys = new()
    {
        "DragScaleMultiplier", "LiftScaleMultiplier",
        "KineticFrictionMultiplier", "RollingFrictionMultiplier",
        "GrassViscosityMultiplier", "CriticalAngleOffsetRadians",
        "SpinbackThetaBoostMultiplier",
    };

    public float DragScaleMultiplier { get; set; } = 1.01f;
    public float LiftScaleMultiplier { get; set; } = 1.0f;
    public float KineticFrictionMultiplier { get; set; } = 1.0f;
    public float RollingFrictionMultiplier { get; set; } = 1.0f;
    public float GrassViscosityMultiplier { get; set; } = 1.0f;
    public float CriticalAngleOffsetRadians { get; set; } = 0.0f;
    public float SpinbackThetaBoostMultiplier { get; set; } = 1.0f;
    public Dictionary<string, RegimeScaleOverride> RegimeScaleOverrides { get; set; } = BuildDefaultRegimeOverrides();

    public FlightProfile Flight { get; set; }
    public BounceProfile Bounce { get; set; }
    public RolloutProfile Rollout { get; set; }

    public FlightProfile ResolvedFlight => Flight ?? FlightProfile.Default;
    public BounceProfile ResolvedBounce => Bounce ?? BounceProfile.Default;
    public RolloutProfile ResolvedRollout => Rollout ?? RolloutProfile.Default;

    private static readonly HashSet<string> RootKnownKeys = new()
    {
        "DragScaleMultiplier", "LiftScaleMultiplier",
        "KineticFrictionMultiplier", "RollingFrictionMultiplier",
        "GrassViscosityMultiplier", "CriticalAngleOffsetRadians",
        "SpinbackThetaBoostMultiplier",
        "RegimeScaleOverrides",
        "Flight", "Bounce", "Rollout",
    };

    /// <summary>
    /// Creates a BallPhysicsProfile from a JSON string. Only keys present in
    /// the JSON override defaults; unspecified keys keep their default values.
    /// Sub-profiles ("Flight", "Bounce", "Rollout") are partial-merged the same way.
    /// Logs warnings for unknown keys that may indicate typos.
    /// </summary>
    public static BallPhysicsProfile FromJson(string json)
    {
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;
        var profile = new BallPhysicsProfile();

        WarnUnknownKeys(root, RootKnownKeys, "BallPhysicsProfile");

        if (root.TryGetProperty("DragScaleMultiplier", out var v))
            profile.DragScaleMultiplier = v.GetSingle();
        if (root.TryGetProperty("LiftScaleMultiplier", out v))
            profile.LiftScaleMultiplier = v.GetSingle();
        if (root.TryGetProperty("KineticFrictionMultiplier", out v))
            profile.KineticFrictionMultiplier = v.GetSingle();
        if (root.TryGetProperty("RollingFrictionMultiplier", out v))
            profile.RollingFrictionMultiplier = v.GetSingle();
        if (root.TryGetProperty("GrassViscosityMultiplier", out v))
            profile.GrassViscosityMultiplier = v.GetSingle();
        if (root.TryGetProperty("CriticalAngleOffsetRadians", out v))
            profile.CriticalAngleOffsetRadians = v.GetSingle();
        if (root.TryGetProperty("SpinbackThetaBoostMultiplier", out v))
            profile.SpinbackThetaBoostMultiplier = v.GetSingle();
        if (root.TryGetProperty("RegimeScaleOverrides", out var regimeEl) && regimeEl.ValueKind == JsonValueKind.Object)
        {
            foreach (var prop in regimeEl.EnumerateObject())
            {
                WarnUnknownKeys(prop.Value, RegimeOverrideKnownKeys, $"RegimeScaleOverride[{prop.Name}]");
                profile.RegimeScaleOverrides[prop.Name] = ParseRegimeScaleOverride(prop.Value);
            }
        }

        if (root.TryGetProperty("Flight", out var flightEl))
        {
            WarnUnknownKeys(flightEl, FlightProfile.KnownKeys, "FlightProfile");
            profile.Flight = ParseFlightProfile(flightEl);
            foreach (var warning in profile.Flight.Validate())
                PhysicsLogger.Error($"[Profile] {warning}");
        }
        if (root.TryGetProperty("Bounce", out var bounceEl))
            profile.Bounce = ParseBounceProfile(bounceEl);
        if (root.TryGetProperty("Rollout", out var rolloutEl))
            profile.Rollout = ParseRolloutProfile(rolloutEl);

        return profile;
    }

    public RegimeScaleOverride ResolveScaleOverride(
        float speedMph,
        float launchAngleDeg,
        float totalSpinRpm,
        out string regimeKey,
        out string matchedOverrideKey)
    {
        regimeKey = ShotRegimeKey.Build(speedMph, launchAngleDeg, totalSpinRpm);
        matchedOverrideKey = string.Empty;

        if (RegimeScaleOverrides == null || RegimeScaleOverrides.Count == 0)
            return RegimeScaleOverride.Neutral;

        foreach (string candidate in ShotRegimeKey.BuildLookupKeys(speedMph, launchAngleDeg, totalSpinRpm))
        {
            if (RegimeScaleOverrides.TryGetValue(candidate, out var matched))
            {
                matchedOverrideKey = candidate;
                return matched;
            }
        }

        return RegimeScaleOverride.Neutral;
    }

    /// <summary>
    /// Calibrated regime-specific scale overrides derived from FS reference
    /// reference data. These correct systematic carry biases per launch regime
    /// (e.g. chip shots under-carry at low Re, driver shots over-carry at high Re).
    /// </summary>
    private static Dictionary<string, RegimeScaleOverride> BuildDefaultRegimeOverrides()
    {
        return new Dictionary<string, RegimeScaleOverride>
        {
            // Chip shots (speed < 60 mph): systematic under-carry at low Reynolds
            ["C-S0"] = new() { DragScaleMultiplier = 0.70f, LiftScaleMultiplier = 1.20f },
            ["C-S0-V1-P0"] = new() { DragScaleMultiplier = 0.55f, LiftScaleMultiplier = 1.15f },
            ["C-S0-V4-P3"] = new() { DragScaleMultiplier = 0.65f, LiftScaleMultiplier = 1.25f },

            // Slow iron S1a (60-72 mph): larger systematic under-carry, more aggressive corrections
            ["I-S1a-V0-P1"] = new() { DragScaleMultiplier = 0.94f, LiftScaleMultiplier = 1.04f },
            ["I-S1a-V2-P1"] = new() { DragScaleMultiplier = 0.80f, LiftScaleMultiplier = 1.14f },
            ["I-S1a-V2-P2"] = new() { DragScaleMultiplier = 0.82f, LiftScaleMultiplier = 1.13f },
            ["I-S1a-V2-P3"] = new() { DragScaleMultiplier = 0.82f, LiftScaleMultiplier = 1.12f },
            ["I-S1a-V3-P2"] = new() { DragScaleMultiplier = 0.79f, LiftScaleMultiplier = 1.14f },
            ["I-S1a-V3-P3"] = new() { DragScaleMultiplier = 0.94f, LiftScaleMultiplier = 1.04f },
            ["I-S1a-V1-P2"] = new() { DragScaleMultiplier = 0.92f, LiftScaleMultiplier = 1.05f },

            // Mid iron S1b (72-85 mph): smaller corrections
            ["I-S1b-V0-P0"] = new() { DragScaleMultiplier = 0.97f, LiftScaleMultiplier = 1.02f },
            ["I-S1b-V2-P2"] = new() { DragScaleMultiplier = 0.94f, LiftScaleMultiplier = 1.03f },
            ["I-S1b-V2-P3"] = new() { DragScaleMultiplier = 0.97f, LiftScaleMultiplier = 1.01f },
            ["I-S1b-V3-P2"] = new() { DragScaleMultiplier = 0.88f, LiftScaleMultiplier = 1.06f },
            ["I-S1b-V3-P3"] = new() { DragScaleMultiplier = 0.97f, LiftScaleMultiplier = 1.02f },
            ["I-S1b-V1-P2"] = new() { DragScaleMultiplier = 0.98f, LiftScaleMultiplier = 1.01f },

            // Wedge lob (launch > 30 deg, 60-72 mph): under-carry
            ["W-S1a-V3-P3"] = new() { DragScaleMultiplier = 0.83f, LiftScaleMultiplier = 1.10f },

            // Fast iron with high spin: over-carry
            ["I-S3-V2-P3"] = new() { DragScaleMultiplier = 1.11f, LiftScaleMultiplier = 0.94f },
            ["I-S3-V1-P2"] = new() { DragScaleMultiplier = 1.04f, LiftScaleMultiplier = 0.98f },
            ["I-S2-V2-P3"] = new() { DragScaleMultiplier = 1.05f },
            ["I-S2-V2-P4"] = new() { DragScaleMultiplier = 1.06f, LiftScaleMultiplier = 0.95f },

            // Mid-speed iron: over-carry clusters
            ["I-S2-V1-P2"] = new() { DragScaleMultiplier = 1.03f, LiftScaleMultiplier = 0.99f },
            ["I-S2-V0-P2"] = new() { DragScaleMultiplier = 1.06f, LiftScaleMultiplier = 0.96f },

            // Mid-speed iron: under-carry (very low spin)
            ["I-S2-V1-P0"] = new() { DragScaleMultiplier = 0.96f, LiftScaleMultiplier = 1.03f },

            // Mid-speed iron: all short
            ["I-S2-V1-P1"] = new() { DragScaleMultiplier = 0.97f, LiftScaleMultiplier = 1.02f },

            // Driver regime: slight over-carry
            ["D-S3-V1"] = new() { DragScaleMultiplier = 1.04f, LiftScaleMultiplier = 0.99f },
            ["D-S4-V0-P1"] = new() { DragScaleMultiplier = 1.03f, LiftScaleMultiplier = 0.98f },
            ["D-S4-V0-P2"] = new() { DragScaleMultiplier = 1.09f, LiftScaleMultiplier = 0.94f },
            ["D-S4-V1-P0"] = new() { DragScaleMultiplier = 0.98f, LiftScaleMultiplier = 1.02f },
            ["D-S4-V1-P1"] = new() { DragScaleMultiplier = 1.04f },
            ["D-S4-V1-P2"] = new() { DragScaleMultiplier = 1.04f },

            // High-speed wedge (launch > 30 deg, 85-105 mph): over-carry
            ["W-S2-V3-P4"] = new() { DragScaleMultiplier = 1.06f, LiftScaleMultiplier = 0.97f },
        };
    }

    private static void WarnUnknownKeys(JsonElement element, HashSet<string> knownKeys, string context)
    {
        if (element.ValueKind != JsonValueKind.Object)
            return;

        foreach (var prop in element.EnumerateObject())
        {
            if (!knownKeys.Contains(prop.Name))
                PhysicsLogger.Error($"[Profile] Unknown key '{prop.Name}' in {context} — possible typo (will use default)");
        }
    }

    private static FlightProfile ParseFlightProfile(JsonElement el)
    {
        var fp = new FlightProfile();
        // Use reflection-free explicit mapping for all init properties
        return new FlightProfile
        {
            CdPolyA = TryFloat(el, "CdPolyA", fp.CdPolyA),
            CdPolyB = TryFloat(el, "CdPolyB", fp.CdPolyB),
            CdPolyC = TryFloat(el, "CdPolyC", fp.CdPolyC),
            CdPolyD = TryFloat(el, "CdPolyD", fp.CdPolyD),
            HighReCdCap = TryFloat(el, "HighReCdCap", fp.HighReCdCap),
            LowReCdFloor = TryFloat(el, "LowReCdFloor", fp.LowReCdFloor),
            LowReBlendStart = TryFloat(el, "LowReBlendStart", fp.LowReBlendStart),
            CdAt50k = TryFloat(el, "CdAt50k", fp.CdAt50k),
            CdMin = TryFloat(el, "CdMin", fp.CdMin),
            ClMaxBase = TryFloat(el, "ClMaxBase", fp.ClMaxBase),
            ClMaxHighSpin = TryFloat(el, "ClMaxHighSpin", fp.ClMaxHighSpin),
            ClMaxSrTransitionStart = TryFloat(el, "ClMaxSrTransitionStart", fp.ClMaxSrTransitionStart),
            ClMaxSrTransitionEnd = TryFloat(el, "ClMaxSrTransitionEnd", fp.ClMaxSrTransitionEnd),
            SpinDragMultiplierCoeff = TryFloat(el, "SpinDragMultiplierCoeff", fp.SpinDragMultiplierCoeff),
            SpinDragMultiplierMax = TryFloat(el, "SpinDragMultiplierMax", fp.SpinDragMultiplierMax),
            SpinDragMultiplierHighSpinMax = TryFloat(el, "SpinDragMultiplierHighSpinMax", fp.SpinDragMultiplierHighSpinMax),
            SpinDragMultiplierUltraHighSpinMax = TryFloat(el, "SpinDragMultiplierUltraHighSpinMax", fp.SpinDragMultiplierUltraHighSpinMax),
            HighSpinDragSrStart = TryFloat(el, "HighSpinDragSrStart", fp.HighSpinDragSrStart),
            HighSpinDragSrEnd = TryFloat(el, "HighSpinDragSrEnd", fp.HighSpinDragSrEnd),
            HighSpinDragReliefReFullMax = TryFloat(el, "HighSpinDragReliefReFullMax", fp.HighSpinDragReliefReFullMax),
            HighSpinDragReliefReZero = TryFloat(el, "HighSpinDragReliefReZero", fp.HighSpinDragReliefReZero),
            UltraHighSpinDragSrStart = TryFloat(el, "UltraHighSpinDragSrStart", fp.UltraHighSpinDragSrStart),
            UltraHighSpinDragSrEnd = TryFloat(el, "UltraHighSpinDragSrEnd", fp.UltraHighSpinDragSrEnd),
            HighReStart = TryFloat(el, "HighReStart", fp.HighReStart),
            HighReMidSpinGain = TryFloat(el, "HighReMidSpinGain", fp.HighReMidSpinGain),
            HighReSpinGain = TryFloat(el, "HighReSpinGain", fp.HighReSpinGain),
            HighReGainReductionStart = TryFloat(el, "HighReGainReductionStart", fp.HighReGainReductionStart),
            HighReGainReductionEnd = TryFloat(el, "HighReGainReductionEnd", fp.HighReGainReductionEnd),
            HighReGainRecoveryStart = TryFloat(el, "HighReGainRecoveryStart", fp.HighReGainRecoveryStart),
            HighReGainRecoveryEnd = TryFloat(el, "HighReGainRecoveryEnd", fp.HighReGainRecoveryEnd),
            HighSpinClAttenuationStart = TryFloat(el, "HighSpinClAttenuationStart", fp.HighSpinClAttenuationStart),
            HighSpinClAttenuationEnd = TryFloat(el, "HighSpinClAttenuationEnd", fp.HighSpinClAttenuationEnd),
            HighSpinClAttenuationMax = TryFloat(el, "HighSpinClAttenuationMax", fp.HighSpinClAttenuationMax),
            UltraHighSpinClAttenuationStart = TryFloat(el, "UltraHighSpinClAttenuationStart", fp.UltraHighSpinClAttenuationStart),
            UltraHighSpinClAttenuationEnd = TryFloat(el, "UltraHighSpinClAttenuationEnd", fp.UltraHighSpinClAttenuationEnd),
            UltraHighSpinClAttenuationMax = TryFloat(el, "UltraHighSpinClAttenuationMax", fp.UltraHighSpinClAttenuationMax),
            LowReHighSpinClAttenuationMax = TryFloat(el, "LowReHighSpinClAttenuationMax", fp.LowReHighSpinClAttenuationMax),
            LowReUltraHighSpinClAttenuationMax = TryFloat(el, "LowReUltraHighSpinClAttenuationMax", fp.LowReUltraHighSpinClAttenuationMax),
            LowLaunchLiftRecoveryMax = TryFloat(el, "LowLaunchLiftRecoveryMax", fp.LowLaunchLiftRecoveryMax),
            LowLaunchVlaFullDeg = TryFloat(el, "LowLaunchVlaFullDeg", fp.LowLaunchVlaFullDeg),
            LowLaunchVlaZeroDeg = TryFloat(el, "LowLaunchVlaZeroDeg", fp.LowLaunchVlaZeroDeg),
            LowLaunchReStart = TryFloat(el, "LowLaunchReStart", fp.LowLaunchReStart),
            LowLaunchReEnd = TryFloat(el, "LowLaunchReEnd", fp.LowLaunchReEnd),
            LowLaunchSpinRatioFull = TryFloat(el, "LowLaunchSpinRatioFull", fp.LowLaunchSpinRatioFull),
            LowLaunchSpinRatioMax = TryFloat(el, "LowLaunchSpinRatioMax", fp.LowLaunchSpinRatioMax),
            SpinDragProgressiveCapSrStart = TryFloat(el, "SpinDragProgressiveCapSrStart", fp.SpinDragProgressiveCapSrStart),
            SpinDragProgressiveCapSrEnd = TryFloat(el, "SpinDragProgressiveCapSrEnd", fp.SpinDragProgressiveCapSrEnd),
            SpinDragProgressiveCapBoostMax = TryFloat(el, "SpinDragProgressiveCapBoostMax", fp.SpinDragProgressiveCapBoostMax),
            MidSpinClBoostSrStart = TryFloat(el, "MidSpinClBoostSrStart", fp.MidSpinClBoostSrStart),
            MidSpinClBoostSrEnd = TryFloat(el, "MidSpinClBoostSrEnd", fp.MidSpinClBoostSrEnd),
            MidSpinClBoostMax = TryFloat(el, "MidSpinClBoostMax", fp.MidSpinClBoostMax),
            HighLaunchDragBoostMax = TryFloat(el, "HighLaunchDragBoostMax", fp.HighLaunchDragBoostMax),
            HighLaunchDragVlaStartDeg = TryFloat(el, "HighLaunchDragVlaStartDeg", fp.HighLaunchDragVlaStartDeg),
            HighLaunchDragVlaFullDeg = TryFloat(el, "HighLaunchDragVlaFullDeg", fp.HighLaunchDragVlaFullDeg),
            HighLaunchDragSrStart = TryFloat(el, "HighLaunchDragSrStart", fp.HighLaunchDragSrStart),
            HighLaunchDragSrEnd = TryFloat(el, "HighLaunchDragSrEnd", fp.HighLaunchDragSrEnd),
            Name = TryString(el, "Name", "JsonOverride"),
            Version = TryString(el, "Version", fp.Version),
        };
    }

    private static BounceProfile ParseBounceProfile(JsonElement el)
    {
        var bp = new BounceProfile();
        return new BounceProfile
        {
            CorBaseA = TryFloat(el, "CorBaseA", bp.CorBaseA),
            CorBaseB = TryFloat(el, "CorBaseB", bp.CorBaseB),
            CorBaseC = TryFloat(el, "CorBaseC", bp.CorBaseC),
            CorHighSpeedCap = TryFloat(el, "CorHighSpeedCap", bp.CorHighSpeedCap),
            CorHighSpeedThreshold = TryFloat(el, "CorHighSpeedThreshold", bp.CorHighSpeedThreshold),
            CorKillThreshold = TryFloat(el, "CorKillThreshold", bp.CorKillThreshold),
            FlightTangentialRetentionBase = TryFloat(el, "FlightTangentialRetentionBase", bp.FlightTangentialRetentionBase),
            FlightSpinFactorMin = TryFloat(el, "FlightSpinFactorMin", bp.FlightSpinFactorMin),
            FlightSpinFactorDivisor = TryFloat(el, "FlightSpinFactorDivisor", bp.FlightSpinFactorDivisor),
            RolloutLowSpinRetention = TryFloat(el, "RolloutLowSpinRetention", bp.RolloutLowSpinRetention),
            RolloutHighSpinRetention = TryFloat(el, "RolloutHighSpinRetention", bp.RolloutHighSpinRetention),
            RolloutSpinRatioThreshold = TryFloat(el, "RolloutSpinRatioThreshold", bp.RolloutSpinRatioThreshold),
            SpinCorLowSpinThreshold = TryFloat(el, "SpinCorLowSpinThreshold", bp.SpinCorLowSpinThreshold),
            SpinCorLowSpinMaxReduction = TryFloat(el, "SpinCorLowSpinMaxReduction", bp.SpinCorLowSpinMaxReduction),
            SpinCorHighSpinRangeRpm = TryFloat(el, "SpinCorHighSpinRangeRpm", bp.SpinCorHighSpinRangeRpm),
            SpinCorHighSpinAdditionalReduction = TryFloat(el, "SpinCorHighSpinAdditionalReduction", bp.SpinCorHighSpinAdditionalReduction),
            CorVelocityLowThreshold = TryFloat(el, "CorVelocityLowThreshold", bp.CorVelocityLowThreshold),
            CorVelocityMidThreshold = TryFloat(el, "CorVelocityMidThreshold", bp.CorVelocityMidThreshold),
            CorVelocityLowScale = TryFloat(el, "CorVelocityLowScale", bp.CorVelocityLowScale),
            RolloutBounceCorKillThreshold = TryFloat(el, "RolloutBounceCorKillThreshold", bp.RolloutBounceCorKillThreshold),
            RolloutBounceCorScale = TryFloat(el, "RolloutBounceCorScale", bp.RolloutBounceCorScale),
            PennerLowEnergyThreshold = TryFloat(el, "PennerLowEnergyThreshold", bp.PennerLowEnergyThreshold),
            Name = TryString(el, "Name", "JsonOverride"),
            Version = TryString(el, "Version", bp.Version),
        };
    }

    private static RolloutProfile ParseRolloutProfile(JsonElement el)
    {
        var rp = new RolloutProfile();
        return new RolloutProfile
        {
            ChipSpeedThreshold = TryFloat(el, "ChipSpeedThreshold", rp.ChipSpeedThreshold),
            PitchSpeedThreshold = TryFloat(el, "PitchSpeedThreshold", rp.PitchSpeedThreshold),
            ChipVelocityScaleMin = TryFloat(el, "ChipVelocityScaleMin", rp.ChipVelocityScaleMin),
            ChipVelocityScaleMax = TryFloat(el, "ChipVelocityScaleMax", rp.ChipVelocityScaleMax),
            LowSpinThreshold = TryFloat(el, "LowSpinThreshold", rp.LowSpinThreshold),
            MidSpinThreshold = TryFloat(el, "MidSpinThreshold", rp.MidSpinThreshold),
            LowSpinMultiplierMax = TryFloat(el, "LowSpinMultiplierMax", rp.LowSpinMultiplierMax),
            MidSpinMultiplierMax = TryFloat(el, "MidSpinMultiplierMax", rp.MidSpinMultiplierMax),
            HighSpinMultiplierMax = TryFloat(el, "HighSpinMultiplierMax", rp.HighSpinMultiplierMax),
            HighSpinRampRange = TryFloat(el, "HighSpinRampRange", rp.HighSpinRampRange),
            FrictionBlendSpeed = TryFloat(el, "FrictionBlendSpeed", rp.FrictionBlendSpeed),
            Name = TryString(el, "Name", "JsonOverride"),
            Version = TryString(el, "Version", rp.Version),
        };
    }

    private static RegimeScaleOverride ParseRegimeScaleOverride(JsonElement el)
    {
        var scaleOverride = new RegimeScaleOverride();
        return new RegimeScaleOverride
        {
            DragScaleMultiplier = TryFloat(el, "DragScaleMultiplier", scaleOverride.DragScaleMultiplier),
            LiftScaleMultiplier = TryFloat(el, "LiftScaleMultiplier", scaleOverride.LiftScaleMultiplier),
            KineticFrictionMultiplier = TryFloat(el, "KineticFrictionMultiplier", scaleOverride.KineticFrictionMultiplier),
            RollingFrictionMultiplier = TryFloat(el, "RollingFrictionMultiplier", scaleOverride.RollingFrictionMultiplier),
            GrassViscosityMultiplier = TryFloat(el, "GrassViscosityMultiplier", scaleOverride.GrassViscosityMultiplier),
            CriticalAngleOffsetRadians = TryFloat(el, "CriticalAngleOffsetRadians", scaleOverride.CriticalAngleOffsetRadians),
            SpinbackThetaBoostMultiplier = TryFloat(el, "SpinbackThetaBoostMultiplier", scaleOverride.SpinbackThetaBoostMultiplier),
        };
    }

    private static float TryFloat(JsonElement el, string name, float defaultValue)
    {
        return el.TryGetProperty(name, out var prop) ? prop.GetSingle() : defaultValue;
    }

    private static string TryString(JsonElement el, string name, string defaultValue)
    {
        return el.TryGetProperty(name, out var prop) ? prop.GetString() ?? defaultValue : defaultValue;
    }
}
