using System;

namespace OpenShotGolf.LaunchMonitors.Bluetooth;

internal sealed record BluetoothCharacteristicValue(Guid CharacteristicUuid, byte[] Value);
