using System;

namespace LaunchMonitors.Common.Bluetooth;

[Flags]
internal enum BluetoothCharacteristicProperties
{
    None = 0,
    Read = 1 << 0,
    Write = 1 << 1,
    WriteWithoutResponse = 1 << 2,
    Notify = 1 << 3,
    Indicate = 1 << 4
}

internal sealed record BluetoothGattCharacteristicInfo(
    Guid ServiceUuid,
    Guid CharacteristicUuid,
    BluetoothCharacteristicProperties Properties);
