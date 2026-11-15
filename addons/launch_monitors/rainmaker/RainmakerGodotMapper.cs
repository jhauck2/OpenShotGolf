using System;
using Godot;
using GodotDictionary = Godot.Collections.Dictionary;

namespace LaunchMonitors.Rainmaker;

public static class RainmakerGodotMapper
{
    private const float MetersPerSecondToMph = 2.23694f;

    public static GodotDictionary ToBallData(RainmakerShotMetrics metrics)
    {
        var totalSpin = Math.Max(0, (int)MathF.Round(metrics.TotalSpinRpm));
        var spinAxis = metrics.SpinAxisDeg;

        var spinAxisRadians = MathF.PI * spinAxis / 180.0f;
        var backSpin = (int)MathF.Round(totalSpin * MathF.Cos(spinAxisRadians));
        var sideSpin = (int)MathF.Round(totalSpin * MathF.Sin(spinAxisRadians));

        var speedMph = metrics.BallSpeedMps * MetersPerSecondToMph;

        var data = new GodotDictionary
        {
            ["Speed"] = Variant.From(speedMph),
            ["BallSpeed"] = Variant.From(speedMph),
            ["VLA"] = Variant.From(metrics.VerticalLaunchAngle),
            ["HLA"] = Variant.From(metrics.HorizontalLaunchAngle),
            ["TotalSpin"] = Variant.From(totalSpin),
            ["SpinAxis"] = Variant.From(spinAxis),
            ["BackSpin"] = Variant.From(backSpin),
            ["SideSpin"] = Variant.From(sideSpin),
            ["ShotType"] = Variant.From("normal")
        };

        if (metrics.ClubSpeedMps > 0)
        {
            var clubSpeedMph = metrics.ClubSpeedMps * MetersPerSecondToMph;
            data["ClubSpeed"] = Variant.From(clubSpeedMph);
            if (clubSpeedMph > 0 && speedMph > 0)
            {
                data["SmashFactor"] = Variant.From(speedMph / clubSpeedMph);
            }
        }

        if (MathF.Abs(metrics.ClubPathDeg) > 0.001f)
            data["ClubPath"] = Variant.From(metrics.ClubPathDeg);
        if (MathF.Abs(metrics.FaceAngleDeg) > 0.001f)
            data["FaceAngle"] = Variant.From(metrics.FaceAngleDeg);
        if (MathF.Abs(metrics.AttackAngleDeg) > 0.001f)
            data["AttackAngle"] = Variant.From(metrics.AttackAngleDeg);
        if (data.ContainsKey("FaceAngle") && data.ContainsKey("ClubPath"))
            data["FaceToPath"] = Variant.From(metrics.FaceAngleDeg - metrics.ClubPathDeg);

        return data;
    }
}
