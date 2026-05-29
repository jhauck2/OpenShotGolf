using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using LaunchMonitors.Common.Bluetooth;
using Windows.Devices.Bluetooth;
using Windows.Devices.Bluetooth.Advertisement;
using Windows.Devices.Bluetooth.GenericAttributeProfile;
using Windows.Devices.Enumeration;
using Windows.Storage.Streams;

namespace LaunchMonitors.Common.Bluetooth.Windows;

internal sealed class WindowsBluetoothGattClient : IBluetoothGattClient
{
    private static bool AttemptWindowsPairing => false;

    private readonly Dictionary<Guid, GattCharacteristic> _characteristics = [];
    private readonly HashSet<Guid> _subscribedCharacteristicUuids = [];
    private DeviceWatcher? _deviceWatcher;
    private BluetoothLEAdvertisementWatcher? _advertisementWatcher;
    private BluetoothLEDevice? _device;
    private GattSession? _session;
    private BluetoothScanOptions _scanOptions = new(string.Empty);
    private BluetoothConnectionOptions _connectionOptions = new([], [], 4, TimeSpan.FromMilliseconds(700));

    public event Action<BluetoothDevice>? DeviceDiscovered;

    public event Action<BluetoothCharacteristicValue>? CharacteristicValueChanged;

    public async Task StartScanAsync(BluetoothScanOptions options, CancellationToken cancellationToken)
    {
        _scanOptions = options;
        await StopScanAsync(cancellationToken);

        _deviceWatcher = DeviceInformation.CreateWatcher(BluetoothLEDevice.GetDeviceSelector());
        _deviceWatcher.Added += OnDeviceAdded;
        _deviceWatcher.Start();

        _advertisementWatcher = new BluetoothLEAdvertisementWatcher
        {
            ScanningMode = BluetoothLEScanningMode.Active
        };
        _advertisementWatcher.Received += OnAdvertisementReceived;
        _advertisementWatcher.Start();
    }

    public Task StopScanAsync(CancellationToken cancellationToken)
    {
        if (_deviceWatcher is not null)
        {
            _deviceWatcher.Added -= OnDeviceAdded;
            if (_deviceWatcher.Status is DeviceWatcherStatus.Started or DeviceWatcherStatus.EnumerationCompleted)
            {
                _deviceWatcher.Stop();
            }

            _deviceWatcher = null;
        }

        if (_advertisementWatcher is not null)
        {
            _advertisementWatcher.Received -= OnAdvertisementReceived;
            if (_advertisementWatcher.Status == BluetoothLEAdvertisementWatcherStatus.Started)
            {
                _advertisementWatcher.Stop();
            }

            _advertisementWatcher = null;
        }

        return Task.CompletedTask;
    }

    public async Task ConnectAsync(string deviceId, BluetoothConnectionOptions options, CancellationToken cancellationToken)
    {
        _connectionOptions = options;
        await DisconnectAsync(cancellationToken);

        _device = await OpenDeviceWithRetryAsync(deviceId, cancellationToken);
        if (_device is null)
        {
            throw new TimeoutException("The selected Bluetooth device is not ready yet. Wait a moment and try connecting again.");
        }

        await PairIfNeededAsync(_device);
        _session = await GattSession.FromDeviceIdAsync(_device.BluetoothDeviceId);
        _session.MaintainConnection = true;
        await LoadCharacteristicsAsync(options);
    }

    public async Task DisconnectAsync(CancellationToken cancellationToken)
    {
        foreach (var characteristicUuid in _subscribedCharacteristicUuids)
        {
            if (!_characteristics.TryGetValue(characteristicUuid, out var characteristic))
            {
                continue;
            }

            characteristic.ValueChanged -= OnCharacteristicValueChanged;
            await characteristic.WriteClientCharacteristicConfigurationDescriptorAsync(
                GattClientCharacteristicConfigurationDescriptorValue.None);
        }

        _subscribedCharacteristicUuids.Clear();
        _characteristics.Clear();
        _session?.Dispose();
        _session = null;
        _device?.Dispose();
        _device = null;
    }

    public async Task<byte[]> ReadCharacteristicAsync(Guid characteristicUuid, CancellationToken cancellationToken)
    {
        return _characteristics.TryGetValue(characteristicUuid, out var characteristic)
            ? await ReadBytesAsync(characteristic)
            : [];
    }

    public async Task SubscribeToCharacteristicAsync(Guid characteristicUuid, CancellationToken cancellationToken)
    {
        if (_subscribedCharacteristicUuids.Contains(characteristicUuid))
        {
            return;
        }

        if (!_characteristics.TryGetValue(characteristicUuid, out var characteristic))
        {
            throw new InvalidOperationException($"Bluetooth characteristic {characteristicUuid} is not available.");
        }

        characteristic.ValueChanged += OnCharacteristicValueChanged;
        var descriptorValue = characteristic.CharacteristicProperties.HasFlag(GattCharacteristicProperties.Notify)
            ? GattClientCharacteristicConfigurationDescriptorValue.Notify
            : GattClientCharacteristicConfigurationDescriptorValue.Indicate;

        var status = await characteristic.WriteClientCharacteristicConfigurationDescriptorAsync(descriptorValue);
        if (status != GattCommunicationStatus.Success)
        {
            throw new InvalidOperationException($"Bluetooth notification setup returned {status}.");
        }

        _subscribedCharacteristicUuids.Add(characteristicUuid);
    }

    public async Task WriteCharacteristicAsync(
        Guid characteristicUuid,
        byte[] value,
        BluetoothWriteMode writeMode,
        CancellationToken cancellationToken)
    {
        if (!_characteristics.TryGetValue(characteristicUuid, out var characteristic))
        {
            throw new InvalidOperationException($"Bluetooth characteristic {characteristicUuid} is not available.");
        }

        using var writer = new DataWriter();
        writer.WriteBytes(value);
        var result = await characteristic.WriteValueWithResultAsync(
            writer.DetachBuffer(),
            writeMode == BluetoothWriteMode.WithResponse ? GattWriteOption.WriteWithResponse : GattWriteOption.WriteWithoutResponse);

        if (result.Status != GattCommunicationStatus.Success)
        {
            throw new InvalidOperationException($"Bluetooth write returned {result.Status}.");
        }
    }

    public async ValueTask DisposeAsync()
    {
        await StopScanAsync(CancellationToken.None);
        await DisconnectAsync(CancellationToken.None);
    }

    private async Task<BluetoothLEDevice?> OpenDeviceAsync(string deviceId)
    {
        if (ulong.TryParse(deviceId, out var address))
        {
            return await BluetoothLEDevice.FromBluetoothAddressAsync(address);
        }

        return await BluetoothLEDevice.FromIdAsync(deviceId);
    }

    private async Task<BluetoothLEDevice?> OpenDeviceWithRetryAsync(string deviceId, CancellationToken cancellationToken)
    {
        var attempts = Math.Max(1, _connectionOptions.ServiceDiscoveryMaxAttempts);
        for (var attempt = 1; attempt <= attempts; attempt++)
        {
            cancellationToken.ThrowIfCancellationRequested();

            var device = await OpenDeviceAsync(deviceId);
            if (device is not null)
            {
                return device;
            }

            if (attempt < attempts)
            {
                await Task.Delay(_connectionOptions.ServiceDiscoveryRetryDelay, cancellationToken);
            }
        }

        return null;
    }

    private static async Task PairIfNeededAsync(BluetoothLEDevice device)
    {
        var pairing = device.DeviceInformation.Pairing;
        if (pairing.IsPaired || !AttemptWindowsPairing || !pairing.CanPair)
        {
            return;
        }

        await pairing.PairAsync(DevicePairingProtectionLevel.None);
    }

    private async Task LoadCharacteristicsAsync(BluetoothConnectionOptions options)
    {
        _characteristics.Clear();

        foreach (var uuid in options.RequiredCharacteristicUuids)
        {
            var characteristic = await GetCharacteristicAsync(uuid, required: true);
            if (characteristic is not null)
            {
                _characteristics[uuid] = characteristic;
            }
        }

        foreach (var uuid in options.OptionalCharacteristicUuids)
        {
            var characteristic = await GetCharacteristicAsync(uuid, required: false);
            if (characteristic is not null)
            {
                _characteristics[uuid] = characteristic;
            }
        }
    }

    private async Task<GattCharacteristic?> GetCharacteristicAsync(Guid uuid, bool required)
    {
        if (_device is null)
        {
            return null;
        }

        var servicesResult = await GetGattServicesWithRetryAsync(_device);
        if (servicesResult.Status != GattCommunicationStatus.Success)
        {
            if (required)
            {
                throw new InvalidOperationException($"Bluetooth service discovery returned {servicesResult.Status}.");
            }

            return null;
        }

        foreach (var service in servicesResult.Services)
        {
            var characteristicsResult = await service.GetCharacteristicsForUuidAsync(uuid, BluetoothCacheMode.Uncached);
            if (characteristicsResult.Status == GattCommunicationStatus.Success && characteristicsResult.Characteristics.Count > 0)
            {
                return characteristicsResult.Characteristics[0];
            }
        }

        if (required)
        {
            throw new InvalidOperationException($"Missing Bluetooth characteristic {uuid}.");
        }

        return null;
    }

    private async Task<GattDeviceServicesResult> GetGattServicesWithRetryAsync(BluetoothLEDevice device)
    {
        GattDeviceServicesResult? lastResult = null;

        for (var attempt = 1; attempt <= _connectionOptions.ServiceDiscoveryMaxAttempts; attempt++)
        {
            var cacheMode = attempt == 1 ? BluetoothCacheMode.Cached : BluetoothCacheMode.Uncached;
            var result = await device.GetGattServicesAsync(cacheMode);
            if (result.Status == GattCommunicationStatus.Success)
            {
                return result;
            }

            lastResult = result;
            if (attempt < _connectionOptions.ServiceDiscoveryMaxAttempts)
            {
                await Task.Delay(_connectionOptions.ServiceDiscoveryRetryDelay);
            }
        }

        return lastResult!;
    }

    private static async Task<byte[]> ReadBytesAsync(GattCharacteristic characteristic)
    {
        var result = await characteristic.ReadValueAsync(BluetoothCacheMode.Uncached);
        if (result.Status != GattCommunicationStatus.Success)
        {
            return [];
        }

        return ReadBuffer(result.Value);
    }

    private void OnDeviceAdded(DeviceWatcher sender, DeviceInformation args)
    {
        var name = args.Name?.Trim() ?? string.Empty;
        if (IsDeviceNameMatch(name))
        {
            DeviceDiscovered?.Invoke(new BluetoothDevice(args.Id, name, 0));
        }
    }

    private void OnAdvertisementReceived(BluetoothLEAdvertisementWatcher sender, BluetoothLEAdvertisementReceivedEventArgs args)
    {
        var advertisedName = args.Advertisement.LocalName?.Trim() ?? string.Empty;
        if (!IsDeviceNameMatch(advertisedName))
        {
            return;
        }

        DeviceDiscovered?.Invoke(new BluetoothDevice(
            args.BluetoothAddress.ToString(),
            advertisedName,
            args.RawSignalStrengthInDBm));
    }

    private void OnCharacteristicValueChanged(GattCharacteristic sender, GattValueChangedEventArgs args)
    {
        CharacteristicValueChanged?.Invoke(new BluetoothCharacteristicValue(sender.Uuid, ReadBuffer(args.CharacteristicValue)));
    }

    private static byte[] ReadBuffer(IBuffer buffer)
    {
        var reader = DataReader.FromBuffer(buffer);
        var data = new byte[reader.UnconsumedBufferLength];
        reader.ReadBytes(data);
        return data;
    }

    private bool IsDeviceNameMatch(string? name)
    {
        return !string.IsNullOrWhiteSpace(name)
            && name.Trim().StartsWith(_scanOptions.DeviceNamePrefix, StringComparison.OrdinalIgnoreCase);
    }
}
