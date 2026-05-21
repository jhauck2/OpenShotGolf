using System;
using System.Threading.Tasks;
using Godot;
using OpenShotGolf.LaunchMonitors.Bluetooth;
using OpenShotGolf.LaunchMonitors.Square;
using GodotDictionary = Godot.Collections.Dictionary;

[GlobalClass]
public partial class SquareLaunchMonitor : Node
{
    private const string LogPrefix = "[SquareLaunchMonitor]";

    private readonly SquareConnectionSession _session = new(
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

    public void ConnectToDevice(string deviceId)
    {
        LogInfo($"ConnectToDevice requested for deviceId={deviceId}");
        _ = RunAsync(() => _session.ConnectToDeviceAsync(deviceId));
    }

    public void DisconnectFromDevice()
    {
        _ = RunAsync(() => _session.DisconnectAsync());
    }

    public void SetClub(string clubCode)
    {
        _ = RunAsync(() => _session.SetClubAsync(clubCode));
    }

    public void SetHandedness(int handedness)
    {
        _session.SetHandedness(handedness);
    }

    public void SetReady()
    {
        _ = RunAsync(() => _session.SetReadyAsync());
    }

    private void OnDeviceDiscovered(BluetoothDevice device)
    {
        EmitDeviceDiscovered(device.DeviceId, device.Name, device.Rssi);
    }

    private void OnShotReceived(SquareShotMetrics metrics)
    {
        EmitShot(SquareGodotMapper.ToBallData(metrics));
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

    private static void LogInfo(string message)
    {
        GD.Print($"{LogPrefix} {message}");
    }

    private static void LogError(string message)
    {
        GD.PrintErr($"{LogPrefix} {message}");
    }
}
