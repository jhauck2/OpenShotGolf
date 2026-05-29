using System;

namespace LaunchMonitors.Common.Bluetooth;

internal sealed record BluetoothCharacteristicValue(Guid CharacteristicUuid, byte[] Value);
