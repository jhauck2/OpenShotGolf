using System;
using System.Collections.Generic;

namespace OpenShotGolf.LaunchMonitors.Square;

public static class SquareShotDataMapper
{
    private const float MetersPerSecondToMph = 2.23694f;

    public static IReadOnlyDictionary<string, object> ToOsgBallData(SquareShotMetrics metrics)
    {
        var totalSpin = Math.Max(0, metrics.TotalSpinRpm);
        var backSpin = metrics.BackSpinRpm;
        var sideSpin = metrics.SideSpinRpm;

        if (backSpin == 0 && sideSpin == 0 && totalSpin > 0)
        {
            var spinAxisRadians = MathF.PI * metrics.SpinAxis / 180.0f;
            backSpin = (int)MathF.Round(totalSpin * MathF.Cos(spinAxisRadians));
            sideSpin = (int)MathF.Round(totalSpin * MathF.Sin(spinAxisRadians));
        }

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

