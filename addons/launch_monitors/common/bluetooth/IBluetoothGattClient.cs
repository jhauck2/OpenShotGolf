using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace LaunchMonitors.Common.Bluetooth;

internal interface IBluetoothGattClient : IAsyncDisposable
{
    event Action<BluetoothDevice>? DeviceDiscovered;

    event Action<BluetoothCharacteristicValue>? CharacteristicValueChanged;

    event Action? Disconnected;

    Task StartScanAsync(BluetoothScanOptions options, CancellationToken cancellationToken);

    Task StopScanAsync(CancellationToken cancellationToken);

    Task ConnectAsync(string deviceId, BluetoothConnectionOptions options, CancellationToken cancellationToken);

    Task DisconnectAsync(CancellationToken cancellationToken);

    Task<byte[]> ReadCharacteristicAsync(Guid characteristicUuid, CancellationToken cancellationToken);

    Task SubscribeToCharacteristicAsync(Guid characteristicUuid, CancellationToken cancellationToken);

    Task WriteCharacteristicAsync(
        Guid characteristicUuid,
        byte[] value,
        BluetoothWriteMode writeMode,
        CancellationToken cancellationToken);

    IReadOnlyList<BluetoothGattCharacteristicInfo> GetDiscoveredCharacteristics() =>
        Array.Empty<BluetoothGattCharacteristicInfo>();
}
