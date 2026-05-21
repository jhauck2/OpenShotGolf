using System;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Godot;
using OpenShotGolf.LaunchMonitors.Square;
using Windows.Devices.Bluetooth;
using Windows.Devices.Bluetooth.Advertisement;
using Windows.Devices.Bluetooth.GenericAttributeProfile;
using Windows.Devices.Enumeration;
using Windows.Storage.Streams;
using GodotDictionary = Godot.Collections.Dictionary;

[GlobalClass]
public partial class SquareLaunchMonitor : Node
{
    private static readonly Guid CommandCharacteristicUuid = Guid.Parse("86602101-6b7e-439a-bdd1-489a3213e9bb");
    private static readonly Guid EventCharacteristicUuid = Guid.Parse("86602102-6b7e-439a-bdd1-489a3213e9bb");
    private static readonly Guid BatteryCharacteristicUuid = GattCharacteristicUuids.BatteryLevel;
    private static readonly Guid FirmwareCharacteristicUuid = Guid.Parse("86602003-6b7e-439a-bdd1-489a3213e9bb");

    private readonly SemaphoreSlim _connectionLock = new(1, 1);
    private readonly SemaphoreSlim _writeLock = new(1, 1);
    private DeviceWatcher? _deviceWatcher;
    private BluetoothLEAdvertisementWatcher? _advertisementWatcher;
    private BluetoothLEDevice? _device;
    private GattSession? _session;
    private GattCharacteristic? _commandCharacteristic;
    private GattCharacteristic? _eventCharacteristic;
    private GattCharacteristic? _batteryCharacteristic;
    private GattCharacteristic? _firmwareCharacteristic;
    private System.Threading.Timer? _heartbeatTimer;
    private byte _sequence;
    private string? _lastPayload;
    private string _clubCode = SquareCommandBuilder.DriverClubCode;
    private int _handedness;

    [Signal]
    public delegate void DeviceDiscoveredEventHandler(string deviceId, string name, int rssi);

    [Signal]
    public delegate void StatusChangedEventHandler(string status);

    [Signal]
    public delegate void ErrorOccurredEventHandler(string message);

    [Signal]
    public delegate void BatteryChangedEventHandler(int level);

    [Signal]
    public delegate void FirmwareChangedEventHandler(string firmware);

    [Signal]
    public delegate void ReadyChangedEventHandler(bool isReady);

    [Signal]
    public delegate void ShotReceivedEventHandler(GodotDictionary shotData);

    public override void _ExitTree()
    {
        StopScan();
        _ = DisconnectAsync();
    }

    public void StartScan()
    {
        try
        {
            StopScan();
            EmitStatus("Scanning");

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
        catch (Exception ex)
        {
            EmitError($"Bluetooth scan failed: {ex.Message}");
        }
    }

    public void StopScan()
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
    }

    public void ConnectToDevice(string deviceId)
    {
        _ = RunAsync(() => ConnectToDeviceAsync(deviceId));
    }

    public void DisconnectFromDevice()
    {
        _ = DisconnectAsync();
    }

    public void SetClub(string clubCode)
    {
        if (string.IsNullOrWhiteSpace(clubCode))
        {
            clubCode = SquareCommandBuilder.DriverClubCode;
        }

        _clubCode = clubCode;
        _ = RunAsync(async () =>
        {
            if (_commandCharacteristic is not null)
            {
                await WriteCommandAsync(SquareCommandBuilder.Club(NextSequence(), _clubCode, _handedness));
            }
        });
    }

    public void SetHandedness(int handedness)
    {
        _handedness = handedness == 1 ? 1 : 0;
    }

    public void SetReady()
    {
        _ = RunAsync(SetReadyAsync);
    }

    private async Task ConnectToDeviceAsync(string deviceId)
    {
        if (string.IsNullOrWhiteSpace(deviceId))
        {
            EmitError("No Square device was selected.");
            return;
        }

        await _connectionLock.WaitAsync();
        try
        {
            StopScan();
            await DisconnectCoreAsync();
            EmitStatus("Connecting");

            _device = await OpenDeviceAsync(deviceId);
            if (_device is null)
            {
                EmitError("Could not open the selected Bluetooth device.");
                EmitStatus("Disconnected");
                return;
            }

            await PairIfNeededAsync(_device);
            _session = await GattSession.FromDeviceIdAsync(_device.BluetoothDeviceId);
            _session.MaintainConnection = true;

            _commandCharacteristic = await GetCharacteristicAsync(CommandCharacteristicUuid);
            _eventCharacteristic = await GetCharacteristicAsync(EventCharacteristicUuid);
            _batteryCharacteristic = await GetCharacteristicAsync(BatteryCharacteristicUuid, required: false);
            _firmwareCharacteristic = await GetCharacteristicAsync(FirmwareCharacteristicUuid, required: false);

            if (_commandCharacteristic is null || _eventCharacteristic is null)
            {
                EmitError("The selected Bluetooth device does not expose the Square command and event channels.");
                await DisconnectCoreAsync();
                EmitStatus("Disconnected");
                return;
            }

            await ReadDeviceInfoAsync();
            await SubscribeToNotificationsAsync();
            EmitStatus("Connected");
            await WriteCommandAsync(SquareCommandBuilder.Heartbeat(NextSequence()));
            await Task.Delay(2000);
            await WriteCommandAsync(SquareCommandBuilder.Club(NextSequence(), _clubCode, _handedness));
            await Task.Delay(3000);
            await SetReadyAsync();

            _heartbeatTimer = new System.Threading.Timer(OnHeartbeatTimer, null, TimeSpan.FromSeconds(5), TimeSpan.FromSeconds(5));
        }
        catch (Exception ex)
        {
            EmitError($"Square connection failed: {ex.Message}");
            EmitStatus("Disconnected");
            await DisconnectCoreAsync();
        }
        finally
        {
            _connectionLock.Release();
        }
    }

    private async Task<BluetoothLEDevice?> OpenDeviceAsync(string deviceId)
    {
        if (ulong.TryParse(deviceId, out var address))
        {
            return await BluetoothLEDevice.FromBluetoothAddressAsync(address);
        }

        return await BluetoothLEDevice.FromIdAsync(deviceId);
    }

    private static async Task PairIfNeededAsync(BluetoothLEDevice device)
    {
        var pairing = device.DeviceInformation.Pairing;
        if (pairing.IsPaired || !pairing.CanPair)
        {
            return;
        }

        var result = await pairing.PairAsync(DevicePairingProtectionLevel.None);
        if (result.Status is not DevicePairingResultStatus.Paired and not DevicePairingResultStatus.AlreadyPaired)
        {
            throw new InvalidOperationException($"Bluetooth pairing returned {result.Status}.");
        }
    }

    private async Task<GattCharacteristic?> GetCharacteristicAsync(Guid uuid, bool required = true)
    {
        if (_device is null)
        {
            return null;
        }

        var servicesResult = await _device.GetGattServicesAsync(BluetoothCacheMode.Uncached);
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

    private async Task ReadDeviceInfoAsync()
    {
        if (_batteryCharacteristic is not null)
        {
            var value = await ReadBytesAsync(_batteryCharacteristic);
            if (value.Length > 0)
            {
                EmitBattery(value[0]);
            }
        }

        if (_firmwareCharacteristic is not null)
        {
            var value = await ReadBytesAsync(_firmwareCharacteristic);
            if (value.Length > 0)
            {
                EmitFirmware(ParseFirmware(value));
            }
        }
    }

    private static async Task<byte[]> ReadBytesAsync(GattCharacteristic characteristic)
    {
        var result = await characteristic.ReadValueAsync(BluetoothCacheMode.Uncached);
        if (result.Status != GattCommunicationStatus.Success)
        {
            return [];
        }

        var reader = DataReader.FromBuffer(result.Value);
        var bytes = new byte[reader.UnconsumedBufferLength];
        reader.ReadBytes(bytes);
        return bytes;
    }

    private static string ParseFirmware(byte[] bytes)
    {
        var text = Encoding.UTF8.GetString(bytes);
        try
        {
            using var doc = JsonDocument.Parse(text);
            if (doc.RootElement.TryGetProperty("lm", out var launchMonitorVersion))
            {
                return launchMonitorVersion.GetString() ?? text;
            }
        }
        catch (JsonException)
        {
            return text;
        }

        return text;
    }

    private async Task SubscribeToNotificationsAsync()
    {
        if (_eventCharacteristic is null)
        {
            throw new InvalidOperationException("Square event channel is not available.");
        }

        _eventCharacteristic.ValueChanged += OnCharacteristicValueChanged;
        var descriptorValue = _eventCharacteristic.CharacteristicProperties.HasFlag(GattCharacteristicProperties.Notify)
            ? GattClientCharacteristicConfigurationDescriptorValue.Notify
            : GattClientCharacteristicConfigurationDescriptorValue.Indicate;

        var status = await _eventCharacteristic.WriteClientCharacteristicConfigurationDescriptorAsync(descriptorValue);
        if (status != GattCommunicationStatus.Success)
        {
            throw new InvalidOperationException($"Bluetooth notification setup returned {status}.");
        }

        if (_batteryCharacteristic is not null)
        {
            _batteryCharacteristic.ValueChanged += OnBatteryValueChanged;
            await _batteryCharacteristic.WriteClientCharacteristicConfigurationDescriptorAsync(
                GattClientCharacteristicConfigurationDescriptorValue.Notify);
        }
    }

    private async Task SetReadyAsync()
    {
        await WriteCommandAsync(SquareCommandBuilder.DetectBall(NextSequence(), mode: 1, spinMode: 1));
        EmitReady(true);
        EmitStatus("Ready");
    }

    private async Task WriteCommandAsync(byte[] command)
    {
        if (_commandCharacteristic is null)
        {
            throw new InvalidOperationException("Square command channel is not available.");
        }

        await _writeLock.WaitAsync();
        try
        {
            using var writer = new DataWriter();
            writer.WriteBytes(command);
            var result = await _commandCharacteristic.WriteValueWithResultAsync(
                writer.DetachBuffer(),
                GattWriteOption.WriteWithResponse);

            if (result.Status != GattCommunicationStatus.Success)
            {
                throw new InvalidOperationException($"Bluetooth write returned {result.Status}.");
            }
        }
        finally
        {
            _writeLock.Release();
        }
    }

    private async Task DisconnectAsync()
    {
        await _connectionLock.WaitAsync();
        try
        {
            await DisconnectCoreAsync();
            EmitStatus("Disconnected");
            EmitReady(false);
        }
        finally
        {
            _connectionLock.Release();
        }
    }

    private async Task DisconnectCoreAsync()
    {
        _heartbeatTimer?.Dispose();
        _heartbeatTimer = null;

        if (_eventCharacteristic is not null)
        {
            _eventCharacteristic.ValueChanged -= OnCharacteristicValueChanged;
            await _eventCharacteristic.WriteClientCharacteristicConfigurationDescriptorAsync(
                GattClientCharacteristicConfigurationDescriptorValue.None);
        }

        if (_batteryCharacteristic is not null)
        {
            _batteryCharacteristic.ValueChanged -= OnBatteryValueChanged;
        }

        _commandCharacteristic = null;
        _eventCharacteristic = null;
        _batteryCharacteristic = null;
        _firmwareCharacteristic = null;
        _lastPayload = null;
        _session?.Dispose();
        _session = null;
        _device?.Dispose();
        _device = null;
    }

    private void OnDeviceAdded(DeviceWatcher sender, DeviceInformation args)
    {
        var name = string.IsNullOrWhiteSpace(args.Name) ? "Bluetooth LE device" : args.Name;
        EmitDeviceDiscovered(args.Id, name, 0);
    }

    private void OnAdvertisementReceived(BluetoothLEAdvertisementWatcher sender, BluetoothLEAdvertisementReceivedEventArgs args)
    {
        var deviceId = args.BluetoothAddress.ToString();
        var name = string.IsNullOrWhiteSpace(args.Advertisement.LocalName)
            ? $"Bluetooth {args.BluetoothAddress:X12}"
            : args.Advertisement.LocalName;

        EmitDeviceDiscovered(deviceId, name, args.RawSignalStrengthInDBm);
    }

    private async void OnCharacteristicValueChanged(GattCharacteristic sender, GattValueChangedEventArgs args)
    {
        try
        {
            var data = ReadBuffer(args.CharacteristicValue);
            await HandleNotificationAsync(data);
        }
        catch (Exception ex)
        {
            EmitError($"Square notification failed: {ex.Message}");
        }
    }

    private void OnBatteryValueChanged(GattCharacteristic sender, GattValueChangedEventArgs args)
    {
        var data = ReadBuffer(args.CharacteristicValue);
        if (data.Length > 0)
        {
            EmitBattery(data[0]);
        }
    }

    private async Task HandleNotificationAsync(byte[] data)
    {
        if (SquareProtocol.TryParseSensor(data, out var sensor))
        {
            var ready = sensor.BallReady && sensor.BallDetected;
            EmitReady(ready);
            return;
        }

        if (!SquareProtocol.TryParseShot(data, out var metrics))
        {
            return;
        }

        var payload = Convert.ToHexString(data);
        if (payload == _lastPayload)
        {
            return;
        }

        _lastPayload = payload;
        EmitReady(false);
        EmitShot(SquareGodotMapper.ToBallData(metrics));
        await Task.Delay(3000);
        await SetReadyAsync();
    }

    private static byte[] ReadBuffer(IBuffer buffer)
    {
        var reader = DataReader.FromBuffer(buffer);
        var data = new byte[reader.UnconsumedBufferLength];
        reader.ReadBytes(data);
        return data;
    }

    private void OnHeartbeatTimer(object? state)
    {
        _ = RunAsync(async () =>
        {
            if (_commandCharacteristic is not null)
            {
                await WriteCommandAsync(SquareCommandBuilder.Heartbeat(NextSequence()));
            }
        });
    }

    private byte NextSequence()
    {
        var sequence = _sequence;
        unchecked
        {
            _sequence++;
        }
        return sequence;
    }

    private async Task RunAsync(Func<Task> action)
    {
        try
        {
            await action();
        }
        catch (Exception ex)
        {
            EmitError(ex.Message);
        }
    }

    private void EmitDeviceDiscovered(string deviceId, string name, int rssi)
    {
        CallDeferred("emit_signal", SignalName.DeviceDiscovered, deviceId, name, rssi);
    }

    private void EmitStatus(string status)
    {
        CallDeferred("emit_signal", SignalName.StatusChanged, status);
    }

    private void EmitError(string message)
    {
        CallDeferred("emit_signal", SignalName.ErrorOccurred, message);
    }

    private void EmitBattery(int level)
    {
        CallDeferred("emit_signal", SignalName.BatteryChanged, level);
    }

    private void EmitFirmware(string firmware)
    {
        CallDeferred("emit_signal", SignalName.FirmwareChanged, firmware);
    }

    private void EmitReady(bool ready)
    {
        CallDeferred("emit_signal", SignalName.ReadyChanged, ready);
    }

    private void EmitShot(GodotDictionary shotData)
    {
        CallDeferred("emit_signal", SignalName.ShotReceived, shotData);
    }
}
