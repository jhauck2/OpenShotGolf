using System;
using System.Collections.Generic;

namespace LaunchMonitors.Square;

public static class SquareShotDataMapper
{
    private const float MetersPerSecondToMph = 2.23694f;

    public static IReadOnlyDictionary<string, object> ToOsgBallData(SquareShotMetrics metrics)
    {
        // Spin components are already resolved by SquareProtocol (including
        // deriving missing back/side spin from total spin + axis), so only the
        // unsigned-total clamp remains here.
        var totalSpin = Math.Max(0, metrics.TotalSpinRpm);
        var backSpin = metrics.BackSpinRpm;
        var sideSpin = metrics.SideSpinRpm;

        return new Dictionary<string, object>
        {
            { "Speed", metrics.BallSpeedMps * MetersPerSecondToMph },
            { "VLA", metrics.VerticalAngle },
            { "HLA", metrics.HorizontalAngle },
            { "TotalSpin", totalSpin },
            { "SpinAxis", metrics.SpinAxis },
            { "BackSpin", backSpin },
            { "SideSpin", sideSpin },
            { "ShotType", metrics.ShotType }
        };
    }
}
