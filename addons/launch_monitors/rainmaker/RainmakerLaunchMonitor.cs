using System;
using System.Threading.Tasks;
using Godot;
using LaunchMonitors.Common;
using LaunchMonitors.Common.Bluetooth;
using LaunchMonitors.Rainmaker;
using GodotDictionary = Godot.Collections.Dictionary;

[GlobalClass]
public partial class RainmakerLaunchMonitor : Node
{
    private const string LogPrefix = "[RainmakerLaunchMonitor]";

    private readonly RainmakerConnectionSession _session = new(
        BluetoothGattClientFactory.Create(),
        logInfo: LogInfo,
        logError: LogError);

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

    public override void _Ready()
    {
        _session.DeviceDiscovered += OnDeviceDiscovered;
        _session.StatusChanged += EmitStatus;
        _session.ErrorOccurred += EmitError;
        _session.BatteryChanged += EmitBattery;
        _session.FirmwareChanged += EmitFirmware;
        _session.ReadyChanged += EmitReady;
        _session.ShotReceived += OnShotReceived;
        LogInfo("Node ready.");
    }

    public override void _ExitTree()
    {
        LogInfo("Node exiting tree. Stopping scan and disconnecting.");
        _session.DeviceDiscovered -= OnDeviceDiscovered;
        _session.StatusChanged -= EmitStatus;
        _session.ErrorOccurred -= EmitError;
        _session.BatteryChanged -= EmitBattery;
        _session.FirmwareChanged -= EmitFirmware;
        _session.ReadyChanged -= EmitReady;
        _session.ShotReceived -= OnShotReceived;
        _ = _session.DisposeAsync();
    }

    public void StartScan()
    {
        _ = RunAsync(() => _session.StartScanAsync());
    }

    public void StopScan()
    {
        _ = RunAsync(() => _session.StopScanAsync());
    }

    public void ConnectToDevice(string deviceId, string pairingCode = "")
    {
        LogInfo($"ConnectToDevice requested for deviceId={deviceId}, codeProvided={!string.IsNullOrEmpty(pairingCode)}");
        _ = RunAsync(() => _session.ConnectToDeviceAsync(deviceId, pairingCode));
    }

    public void DisconnectFromDevice()
    {
        _ = RunAsync(() => _session.DisconnectAsync());
    }

    private void OnDeviceDiscovered(BluetoothDevice device)
    {
        EmitDeviceDiscovered(device.DeviceId, device.Name, device.Rssi);
    }

    private void OnShotReceived(RainmakerShotMetrics metrics)
    {
        LogInfo($"Dispatching Rainmaker shot: Speed={metrics.BallSpeedMps * 2.23694f:F1}mph, VLA={metrics.VerticalLaunchAngle:F1}, Spin={metrics.TotalSpinRpm:F0}rpm");
        EmitShot(RainmakerGodotMapper.ToBallData(metrics));
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
            LogError($"RunAsync failed: {ex}");
        }
    }

    private void EmitDeviceDiscovered(string deviceId, string name, int rssi)
    {
        Callable.From(() => EmitSignal(SignalName.DeviceDiscovered, deviceId, name, rssi)).CallDeferred();
    }

    private void EmitStatus(string status)
    {
        Callable.From(() => EmitSignal(SignalName.StatusChanged, status)).CallDeferred();
    }

    private void EmitError(string message)
    {
        Callable.From(() => EmitSignal(SignalName.ErrorOccurred, message)).CallDeferred();
    }

    private void EmitBattery(int level)
    {
        Callable.From(() => EmitSignal(SignalName.BatteryChanged, level)).CallDeferred();
    }

    private void EmitFirmware(string firmware)
    {
        Callable.From(() => EmitSignal(SignalName.FirmwareChanged, firmware)).CallDeferred();
    }

    private void EmitReady(bool ready)
    {
        Callable.From(() => EmitSignal(SignalName.ReadyChanged, ready)).CallDeferred();
    }

    private void EmitShot(GodotDictionary shotData)
    {
        Callable.From(() => EmitSignal(SignalName.ShotReceived, shotData)).CallDeferred();
    }

    private static void LogInfo(string message)
    {
        DebugLoggerBridge.LogBluetooth($"{LogPrefix} {message}");
    }

    private static void LogError(string message)
    {
        DebugLoggerBridge.LogError($"{LogPrefix} {message}");
    }
}
