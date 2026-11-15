namespace LaunchMonitors.Rainmaker;

public sealed record RainmakerShotMetrics(
    float BallSpeedMps,
    float VerticalLaunchAngle,
    float HorizontalLaunchAngle,
    float TotalSpinRpm,
    float SpinAxisDeg,
    float ClubSpeedMps = 0f,
    float ClubPathDeg = 0f,
    float FaceAngleDeg = 0f,
    float AttackAngleDeg = 0f);
