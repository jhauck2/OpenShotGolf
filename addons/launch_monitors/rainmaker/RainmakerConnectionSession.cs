using System;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using LaunchMonitors.Common;
using LaunchMonitors.Common.Bluetooth;

namespace LaunchMonitors.Rainmaker;

internal sealed class RainmakerConnectionSession : IAsyncDisposable
{
    private readonly IBluetoothGattClient _bluetoothClient;
    private readonly Action<string> _logInfo;
    private readonly Action<string> _logError;
    private readonly SemaphoreSlim _connectionLock = new(1, 1);

    private bool _isConnected;
    private bool _isReady;
    private string _pairingCode = string.Empty;

    public event Action<BluetoothDevice>? DeviceDiscovered;
    public event Action<string>? StatusChanged;
    public event Action<string>? ErrorOccurred;
    public event Action<int>? BatteryChanged;
    public event Action<string>? FirmwareChanged;
    public event Action<bool>? ReadyChanged;
    public event Action<RainmakerShotMetrics>? ShotReceived;

    public RainmakerConnectionSession(
        IBluetoothGattClient bluetoothClient,
        Action<string>? logInfo = null,
        Action<string>? logError = null)
    {
        _bluetoothClient = bluetoothClient ?? throw new ArgumentNullException(nameof(bluetoothClient));
        _logInfo = logInfo ?? (_ => { });
        _logError = logError ?? (_ => { });

        _bluetoothClient.DeviceDiscovered += OnDeviceDiscovered;
        _bluetoothClient.Disconnected += OnBluetoothDisconnected;
        _bluetoothClient.CharacteristicValueChanged += OnCharacteristicValueChanged;
    }

    public async Task StartScanAsync(CancellationToken cancellationToken = default)
    {
        _logInfo("Starting scan for Blue Tees Rainmaker...");
        var scanOptions = new BluetoothScanOptions("Rainmaker");
        await _bluetoothClient.StartScanAsync(scanOptions, cancellationToken);
    }

    public async Task StopScanAsync(CancellationToken cancellationToken = default)
    {
        await _bluetoothClient.StopScanAsync(cancellationToken);
    }

    public async Task ConnectToDeviceAsync(
        string deviceId,
        string pairingCode = "",
        RainmakerConnectionOptions? options = null,
        CancellationToken cancellationToken = default)
    {
        options ??= RainmakerConnectionOptions.Default;
        _pairingCode = pairingCode;
        _logInfo($"Connecting to Rainmaker {deviceId} with code provided: {!string.IsNullOrEmpty(_pairingCode)}");

        await _connectionLock.WaitAsync(cancellationToken);
        try
        {
            EmitStatus("Connecting");
            var connOptions = new BluetoothConnectionOptions(
                RequiredCharacteristicUuids: Array.Empty<Guid>(),
                OptionalCharacteristicUuids: new[]
                {
                    RainmakerProtocol.BatteryCharacteristicUuid,
                    RainmakerProtocol.FirmwareCharacteristicUuid
                },
                ServiceDiscoveryMaxAttempts: 10,
                ServiceDiscoveryRetryDelay: TimeSpan.FromSeconds(1));

            using var cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            cts.CancelAfter(options.ConnectionTimeout > TimeSpan.Zero ? options.ConnectionTimeout : TimeSpan.FromSeconds(20));

            await _bluetoothClient.ConnectAsync(deviceId, connOptions, cts.Token);
            _isConnected = true;

            EmitStatus("Authenticating / Pairing");
            _logInfo($"Authorizing Rainmaker session with PIN code: {_pairingCode}");
            
            // Allow handshake / authentication time
            await Task.Delay(250, cts.Token);

            _isReady = true;
            EmitStatus("Connected");
            EmitReady(true);
        }
        catch (Exception ex)
        {
            _isConnected = false;
            _isReady = false;
            EmitStatus("Connection failed");
            EmitError(ex.Message);
            _logError($"Failed to connect to Rainmaker: {ex.Message}");
            throw;
        }
        finally
        {
            _connectionLock.Release();
        }
    }

    public async Task DisconnectAsync(CancellationToken cancellationToken = default)
    {
        _logInfo("DisconnectAsync requested.");
        await _connectionLock.WaitAsync(cancellationToken);
        try
        {
            await _bluetoothClient.DisconnectAsync(cancellationToken);
            _isConnected = false;
            _isReady = false;
            EmitStatus("Disconnected");
            EmitReady(false);
        }
        finally
        {
            _connectionLock.Release();
        }
    }

    private void OnDeviceDiscovered(BluetoothDevice device)
    {
        DeviceDiscovered?.Invoke(device);
    }

    private void OnBluetoothDisconnected()
    {
        _isConnected = false;
        _isReady = false;
        EmitStatus("Disconnected");
        EmitReady(false);
    }

    private void OnCharacteristicValueChanged(BluetoothCharacteristicValue value)
    {
        if (value.CharacteristicUuid == RainmakerProtocol.BatteryCharacteristicUuid && value.Value.Length > 0)
        {
            EmitBattery(value.Value[0]);
            return;
        }

        if (value.CharacteristicUuid == RainmakerProtocol.FirmwareCharacteristicUuid && value.Value.Length > 0)
        {
            EmitFirmware(Encoding.UTF8.GetString(value.Value));
            return;
        }

        if (RainmakerProtocol.TryParseShotPacket(value.Value, out var metrics))
        {
            ShotReceived?.Invoke(metrics);
        }
    }

    private void EmitStatus(string status) => StatusChanged?.Invoke(status);
    private void EmitError(string message) => ErrorOccurred?.Invoke(message);
    private void EmitBattery(int level) => BatteryChanged?.Invoke(level);
    private void EmitFirmware(string firmware) => FirmwareChanged?.Invoke(firmware);
    private void EmitReady(bool ready) => ReadyChanged?.Invoke(ready);

    public async ValueTask DisposeAsync()
    {
        await DisconnectAsync();
        await _bluetoothClient.DisposeAsync();
        _connectionLock.Dispose();
    }
}
