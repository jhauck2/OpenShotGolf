using System;
using System.Threading;
using System.Threading.Tasks;

namespace OpenShotGolf.LaunchMonitors.Bluetooth;

internal sealed class UnsupportedBluetoothGattClient(string reason) : IBluetoothGattClient
{
    public event Action<BluetoothDevice>? DeviceDiscovered;

    public event Action<BluetoothCharacteristicValue>? CharacteristicValueChanged;

    public Task StartScanAsync(BluetoothScanOptions options, CancellationToken cancellationToken)
    {
        throw new PlatformNotSupportedException(reason);
    }

    public Task StopScanAsync(CancellationToken cancellationToken)
    {
        return Task.CompletedTask;
    }

    public Task ConnectAsync(string deviceId, BluetoothConnectionOptions options, CancellationToken cancellationToken)
    {
        throw new PlatformNotSupportedException(reason);
    }

    public Task DisconnectAsync(CancellationToken cancellationToken)
    {
        return Task.CompletedTask;
    }

    public Task<byte[]> ReadCharacteristicAsync(Guid characteristicUuid, CancellationToken cancellationToken)
    {
        return Task.FromResult(Array.Empty<byte>());
    }

    public Task SubscribeToCharacteristicAsync(Guid characteristicUuid, CancellationToken cancellationToken)
    {
        throw new PlatformNotSupportedException(reason);
    }

    public Task WriteCharacteristicAsync(
        Guid characteristicUuid,
        byte[] value,
        BluetoothWriteMode writeMode,
        CancellationToken cancellationToken)
    {
        throw new PlatformNotSupportedException(reason);
    }

    public ValueTask DisposeAsync()
    {
        GC.KeepAlive(DeviceDiscovered);
        GC.KeepAlive(CharacteristicValueChanged);
        return ValueTask.CompletedTask;
    }
}
