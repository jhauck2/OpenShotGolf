using System;
using System.Collections.Generic;

namespace LaunchMonitors.Common.Bluetooth;

internal sealed record BluetoothConnectionOptions(
    IReadOnlyCollection<Guid> RequiredCharacteristicUuids,
    IReadOnlyCollection<Guid> OptionalCharacteristicUuids,
    int ServiceDiscoveryMaxAttempts,
    TimeSpan ServiceDiscoveryRetryDelay);
