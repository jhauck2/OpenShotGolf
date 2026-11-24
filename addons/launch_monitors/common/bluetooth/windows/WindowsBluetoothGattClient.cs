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
    private readonly Dictionary<Guid, GattCharacteristic> _characteristics = [];
    private readonly List<BluetoothGattCharacteristicInfo> _discoveredCharacteristics = [];
    private readonly List<GattDeviceService> _services = [];
    private readonly HashSet<Guid> _subscribedCharacteristicUuids = [];
    private readonly HashSet<ulong> _discoveredAddresses = [];
    private readonly HashSet<string> _discoveredDeviceIds = [];
    private DeviceWatcher? _deviceWatcher;
    private BluetoothLEAdvertisementWatcher? _advertisementWatcher;
    private BluetoothLEDevice? _device;
    private BluetoothScanOptions _scanOptions = new(string.Empty);
    private BluetoothConnectionOptions _connectionOptions = new([], [], 4, TimeSpan.FromMilliseconds(700));
    private bool _isDisconnecting;
    private bool _isConnected;

    public event Action<BluetoothDevice>? DeviceDiscovered;

    public event Action<BluetoothCharacteristicValue>? CharacteristicValueChanged;

    public event Action? Disconnected;

    public async Task StartScanAsync(BluetoothScanOptions options, CancellationToken cancellationToken)
    {
        _scanOptions = options;
        await StopScanAsync(cancellationToken);

        _discoveredAddresses.Clear();
        _discoveredDeviceIds.Clear();

        _deviceWatcher = DeviceInformation.CreateWatcher(
            BluetoothLEDevice.GetDeviceSelectorFromConnectionStatus(BluetoothConnectionStatus.Connected));
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
        _discoveredAddresses.Clear();
        _discoveredDeviceIds.Clear();

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
        await StopScanAsync(cancellationToken).ConfigureAwait(false);
        await DisconnectAsync(cancellationToken).ConfigureAwait(false);

        using var timeoutCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeoutCts.CancelAfter(TimeSpan.FromSeconds(15));
        var token = timeoutCts.Token;

        _isDisconnecting = false;
        _device = await OpenDeviceWithRetryAsync(deviceId, token).ConfigureAwait(false);
        if (_device is null)
        {
            throw new TimeoutException("The selected Bluetooth device is not ready yet. Wait a moment and try connecting again.");
        }

        _device.ConnectionStatusChanged += OnDeviceConnectionStatusChanged;
        await LoadCharacteristicsAsync(options, token).ConfigureAwait(false);

        _isConnected = true;
    }

    public async Task DisconnectAsync(CancellationToken cancellationToken)
    {
        _isDisconnecting = true;
        _isConnected = false;

        if (_device is not null)
        {
            _device.ConnectionStatusChanged -= OnDeviceConnectionStatusChanged;
        }

        foreach (var characteristicUuid in _subscribedCharacteristicUuids)
        {
            if (!_characteristics.TryGetValue(characteristicUuid, out var characteristic))
            {
                continue;
            }

            characteristic.ValueChanged -= OnCharacteristicValueChanged;
            try
            {
                await characteristic.WriteClientCharacteristicConfigurationDescriptorAsync(
                    GattClientCharacteristicConfigurationDescriptorValue.None);
            }
            catch
            {
                // Ignore cleanup errors on disconnected/disposed characteristics
            }
        }

        _subscribedCharacteristicUuids.Clear();
        _characteristics.Clear();
        _discoveredCharacteristics.Clear();
        ClearServices();
        _device?.Dispose();
        _device = null;
        _isDisconnecting = false;
    }

    public IReadOnlyList<BluetoothGattCharacteristicInfo> GetDiscoveredCharacteristics() =>
        _discoveredCharacteristics.ToArray();

    public async Task<byte[]> ReadCharacteristicAsync(Guid characteristicUuid, CancellationToken cancellationToken)
    {
        return _characteristics.TryGetValue(characteristicUuid, out var characteristic)
            ? await ReadBytesAsync(characteristic, cancellationToken).ConfigureAwait(false)
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

        try
        {
            var status = await characteristic.WriteClientCharacteristicConfigurationDescriptorAsync(descriptorValue).AsTask(cancellationToken).ConfigureAwait(false);
            if (status != GattCommunicationStatus.Success)
            {
                throw new InvalidOperationException($"Bluetooth notification setup returned {status}.");
            }
        }
        catch (System.Runtime.InteropServices.COMException ex) when ((uint)ex.HResult == 0x80650005)
        {
            throw new InvalidOperationException(
                "Garmin Approach R10 requires Bluetooth pairing. Please pair your Approach R10 in Windows Settings (Bluetooth & devices -> Add device), then connect again.");
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

        var writeOption = writeMode == BluetoothWriteMode.WithResponse
            ? GattWriteOption.WriteWithResponse
            : GattWriteOption.WriteWithoutResponse;

        if (writeOption == GattWriteOption.WriteWithResponse &&
            !characteristic.CharacteristicProperties.HasFlag(GattCharacteristicProperties.Write))
        {
            writeOption = GattWriteOption.WriteWithoutResponse;
        }
        else if (writeOption == GattWriteOption.WriteWithoutResponse &&
            !characteristic.CharacteristicProperties.HasFlag(GattCharacteristicProperties.WriteWithoutResponse))
        {
            writeOption = GattWriteOption.WriteWithResponse;
        }

        if (writeOption == GattWriteOption.WriteWithoutResponse)
        {
            var status = await characteristic.WriteValueAsync(writer.DetachBuffer(), GattWriteOption.WriteWithoutResponse).AsTask(cancellationToken).ConfigureAwait(false);
            if (status != GattCommunicationStatus.Success)
            {
                throw new InvalidOperationException($"Bluetooth write returned {status}.");
            }
        }
        else
        {
            var result = await characteristic.WriteValueWithResultAsync(
                writer.DetachBuffer(),
                GattWriteOption.WriteWithResponse).AsTask(cancellationToken).ConfigureAwait(false);

            if (result.Status != GattCommunicationStatus.Success)
            {
                throw new InvalidOperationException($"Bluetooth write returned {result.Status}.");
            }
        }
    }

    public async ValueTask DisposeAsync()
    {
        await StopScanAsync(CancellationToken.None);
        await DisconnectAsync(CancellationToken.None);
    }

    private async Task<BluetoothLEDevice?> OpenDeviceAsync(string deviceId, CancellationToken cancellationToken)
    {
        if (ulong.TryParse(deviceId, out var address))
        {
            return await BluetoothLEDevice.FromBluetoothAddressAsync(address).AsTask(cancellationToken).ConfigureAwait(false);
        }

        return await BluetoothLEDevice.FromIdAsync(deviceId).AsTask(cancellationToken).ConfigureAwait(false);
    }

    private async Task<BluetoothLEDevice?> OpenDeviceWithRetryAsync(string deviceId, CancellationToken cancellationToken)
    {
        var attempts = Math.Max(1, _connectionOptions.ServiceDiscoveryMaxAttempts);
        for (var attempt = 1; attempt <= attempts; attempt++)
        {
            cancellationToken.ThrowIfCancellationRequested();

            var device = await OpenDeviceAsync(deviceId, cancellationToken).ConfigureAwait(false);
            if (device is not null)
            {
                return device;
            }

            if (attempt < attempts)
            {
                await Task.Delay(_connectionOptions.ServiceDiscoveryRetryDelay, cancellationToken).ConfigureAwait(false);
            }
        }

        return null;
    }

    private async Task LoadCharacteristicsAsync(BluetoothConnectionOptions options, CancellationToken cancellationToken)
    {
        if (_device is null)
        {
            throw new InvalidOperationException("Cannot load characteristics because Bluetooth device is not connected.");
        }

        _characteristics.Clear();
        _discoveredCharacteristics.Clear();
        ClearServices();

        var servicesResult = await GetGattServicesWithRetryAsync(_device, cancellationToken).ConfigureAwait(false);
        if (servicesResult.Status != GattCommunicationStatus.Success)
        {
            throw new InvalidOperationException($"Bluetooth service discovery returned {servicesResult.Status}.");
        }

        _services.AddRange(servicesResult.Services);

        foreach (var service in _services)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var characteristics = await GetCharacteristicsWithFallbackAsync(service, cancellationToken).ConfigureAwait(false);
            foreach (var characteristic in characteristics)
            {
                _characteristics.TryAdd(characteristic.Uuid, characteristic);
                _discoveredCharacteristics.Add(new BluetoothGattCharacteristicInfo(
                    service.Uuid,
                    characteristic.Uuid,
                    MapProperties(characteristic.CharacteristicProperties)));
            }
        }

        foreach (var uuid in options.RequiredCharacteristicUuids)
        {
            if (!_characteristics.ContainsKey(uuid))
            {
                throw new InvalidOperationException($"Missing Bluetooth characteristic {uuid}.");
            }
        }
    }

    private static async Task<IReadOnlyList<GattCharacteristic>> GetCharacteristicsWithFallbackAsync(GattDeviceService service, CancellationToken cancellationToken)
    {
        try
        {
            var result = await service.GetCharacteristicsAsync(BluetoothCacheMode.Cached).AsTask(cancellationToken).ConfigureAwait(false);
            if (result.Status == GattCommunicationStatus.Success && result.Characteristics.Count > 0)
            {
                return result.Characteristics;
            }

            var uncachedResult = await service.GetCharacteristicsAsync(BluetoothCacheMode.Uncached).AsTask(cancellationToken).ConfigureAwait(false);
            if (uncachedResult.Status == GattCommunicationStatus.Success)
            {
                return uncachedResult.Characteristics;
            }

            return result.Status == GattCommunicationStatus.Success ? result.Characteristics : uncachedResult.Characteristics;
        }
        catch
        {
            return [];
        }
    }

    private void ClearServices()
    {
        foreach (var service in _services)
        {
            service.Dispose();
        }

        _services.Clear();
    }

    private async Task<GattDeviceServicesResult> GetGattServicesWithRetryAsync(BluetoothLEDevice device, CancellationToken cancellationToken)
    {
        GattDeviceServicesResult? lastResult = null;

        for (var attempt = 1; attempt <= _connectionOptions.ServiceDiscoveryMaxAttempts; attempt++)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var cacheMode = attempt == 1 ? BluetoothCacheMode.Cached : BluetoothCacheMode.Uncached;
            var result = await device.GetGattServicesAsync(cacheMode).AsTask(cancellationToken).ConfigureAwait(false);
            if (result.Status == GattCommunicationStatus.Success)
            {
                return result;
            }

            lastResult = result;
            if (attempt < _connectionOptions.ServiceDiscoveryMaxAttempts)
            {
                await Task.Delay(_connectionOptions.ServiceDiscoveryRetryDelay, cancellationToken).ConfigureAwait(false);
            }
        }

        return lastResult!;
    }

    private static async Task<byte[]> ReadBytesAsync(GattCharacteristic characteristic, CancellationToken cancellationToken)
    {
        var result = await characteristic.ReadValueAsync(BluetoothCacheMode.Uncached).AsTask(cancellationToken).ConfigureAwait(false);
        if (result.Status != GattCommunicationStatus.Success)
        {
            return [];
        }

        return ReadBuffer(result.Value);
    }

    private async void OnDeviceAdded(DeviceWatcher sender, DeviceInformation args)
    {
        var name = args.Name?.Trim() ?? string.Empty;
        if (!IsDeviceNameMatch(name) || !_discoveredDeviceIds.Add(args.Id))
        {
            return;
        }

        try
        {
            using var device = await BluetoothLEDevice.FromIdAsync(args.Id);
            if (device != null && device.ConnectionStatus == BluetoothConnectionStatus.Connected)
            {
                DeviceDiscovered?.Invoke(new BluetoothDevice(args.Id, name, -50));
            }
        }
        catch
        {
            // Device cannot be accessed or is offline
        }
    }

    private void OnAdvertisementReceived(BluetoothLEAdvertisementWatcher sender, BluetoothLEAdvertisementReceivedEventArgs args)
    {
        var advertisedName = args.Advertisement.LocalName?.Trim() ?? string.Empty;
        if (!IsDeviceNameMatch(advertisedName))
        {
            return;
        }

        if (!_discoveredAddresses.Add(args.BluetoothAddress))
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

    private bool IsDeviceNameMatch(string? name) =>
        BluetoothDeviceFilter.IsDeviceNameMatch(name, _scanOptions.DeviceNamePrefix);

    private static BluetoothCharacteristicProperties MapProperties(GattCharacteristicProperties props)
    {
        var result = BluetoothCharacteristicProperties.None;
        if (props.HasFlag(GattCharacteristicProperties.Read))
            result |= BluetoothCharacteristicProperties.Read;
        if (props.HasFlag(GattCharacteristicProperties.Write))
            result |= BluetoothCharacteristicProperties.Write;
        if (props.HasFlag(GattCharacteristicProperties.WriteWithoutResponse))
            result |= BluetoothCharacteristicProperties.WriteWithoutResponse;
        if (props.HasFlag(GattCharacteristicProperties.Notify))
            result |= BluetoothCharacteristicProperties.Notify;
        if (props.HasFlag(GattCharacteristicProperties.Indicate))
            result |= BluetoothCharacteristicProperties.Indicate;
        return result;
    }

    private void OnDeviceConnectionStatusChanged(BluetoothLEDevice sender, object args)
    {
        if (!_isDisconnecting && _isConnected && sender.ConnectionStatus == BluetoothConnectionStatus.Disconnected)
        {
            _isConnected = false;
            Disconnected?.Invoke();
        }
    }
}
