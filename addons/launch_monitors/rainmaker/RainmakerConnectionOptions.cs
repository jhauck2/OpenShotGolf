using System;

namespace LaunchMonitors.Rainmaker;

public sealed record RainmakerConnectionOptions(
    string DeviceNamePrefix = "Rainmaker",
    string PairingCode = "",
    TimeSpan ConnectionTimeout = default,
    TimeSpan AuthTimeout = default)
{
    public static RainmakerConnectionOptions Default { get; } = new(
        ConnectionTimeout: TimeSpan.FromSeconds(20),
        AuthTimeout: TimeSpan.FromSeconds(15));
}
