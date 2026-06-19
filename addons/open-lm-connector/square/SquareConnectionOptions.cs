using System;

namespace LaunchMonitors.Square;

internal sealed record SquareConnectionOptions(
    string DeviceNamePrefix,
    Guid CommandCharacteristicUuid,
    Guid EventCharacteristicUuid,
    Guid BatteryCharacteristicUuid,
    Guid FirmwareCharacteristicUuid,
    int ServiceDiscoveryMaxAttempts,
    TimeSpan ServiceDiscoveryRetryDelay,
    TimeSpan ConnectionClubDelay,
    TimeSpan ConnectionReadyDelay,
    TimeSpan HeartbeatInterval)
{
    public static SquareConnectionOptions Default { get; } = new(
        DeviceNamePrefix: "SquareGolf",
        CommandCharacteristicUuid: Guid.Parse("86602101-6b7e-439a-bdd1-489a3213e9bb"),
        EventCharacteristicUuid: Guid.Parse("86602102-6b7e-439a-bdd1-489a3213e9bb"),
        BatteryCharacteristicUuid: Guid.Parse("00002a19-0000-1000-8000-00805f9b34fb"),
        FirmwareCharacteristicUuid: Guid.Parse("86602003-6b7e-439a-bdd1-489a3213e9bb"),
        ServiceDiscoveryMaxAttempts: 12,
        ServiceDiscoveryRetryDelay: TimeSpan.FromSeconds(1),
        ConnectionClubDelay: TimeSpan.FromSeconds(2),
        ConnectionReadyDelay: TimeSpan.FromSeconds(3),
        HeartbeatInterval: TimeSpan.FromSeconds(5));
}
