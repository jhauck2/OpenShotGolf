using System.Collections.Generic;

/// <summary>
/// Shared launch-regime classifier used by runtime physics and calibration
/// tooling so both paths bucket shots the same way.
/// </summary>
public static class ShotRegimeKey
{
    public static string Build(float speedMph, float launchAngleDeg, float totalSpinRpm)
    {
        return $"{GetFamily(speedMph, launchAngleDeg)}-{GetSpeedBin(speedMph)}-{GetLaunchBin(launchAngleDeg)}-{GetSpinBin(totalSpinRpm)}";
    }

    public static IEnumerable<string> BuildLookupKeys(float speedMph, float launchAngleDeg, float totalSpinRpm)
    {
        string family = GetFamily(speedMph, launchAngleDeg);
        string speed = GetSpeedBin(speedMph);
        string launch = GetLaunchBin(launchAngleDeg);
        string spin = GetSpinBin(totalSpinRpm);

        yield return $"{family}-{speed}-{launch}-{spin}";
        yield return $"{family}-{speed}-{launch}";
        yield return $"{family}-{speed}";
        yield return family;
    }

    public static string GetFamily(float speedMph, float launchAngleDeg)
    {
        if (speedMph < 60.0f)
            return "C";
        if (speedMph > 110.0f && launchAngleDeg < 18.0f)
            return "D";
        if (launchAngleDeg > 30.0f)
            return "W";
        return "I";
    }

    public static string GetSpeedBin(float speedMph)
    {
        if (speedMph < 60.0f)
            return "S0";
        if (speedMph < 72.0f)
            return "S1a";
        if (speedMph < 85.0f)
            return "S1b";
        if (speedMph < 105.0f)
            return "S2";
        if (speedMph < 120.0f)
            return "S3";
        return "S4";
    }

    public static string GetLaunchBin(float launchAngleDeg)
    {
        if (launchAngleDeg < 10.0f)
            return "V0";
        if (launchAngleDeg < 18.0f)
            return "V1";
        if (launchAngleDeg < 25.0f)
            return "V2";
        if (launchAngleDeg < 33.0f)
            return "V3";
        return "V4";
    }

    public static string GetSpinBin(float totalSpinRpm)
    {
        if (totalSpinRpm < 2500.0f)
            return "P0";
        if (totalSpinRpm < 4000.0f)
            return "P1";
        if (totalSpinRpm < 5500.0f)
            return "P2";
        if (totalSpinRpm < 7500.0f)
            return "P3";
        return "P4";
    }
}
