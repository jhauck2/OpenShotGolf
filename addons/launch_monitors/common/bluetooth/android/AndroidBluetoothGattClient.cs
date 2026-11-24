using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Godot;

namespace LaunchMonitors.Common.Bluetooth.Android;

internal sealed partial class AndroidBluetoothGattClient : IBluetoothGattClient
{
    private static readonly string LogPrefix = "[AndroidBLE]";
    
    public event Action<BluetoothDevice>? DeviceDiscovered;
    public event Action<BluetoothCharacteristicValue>? CharacteristicValueChanged;
    public event Action? Disconnected;
    
    private JavaObject? _bluetoothAdapter;
    private JavaObject? _bluetoothScanner;
    private JavaObject? _bluetoothGatt;
    private JavaObject? _scanCallback;
    private JavaObject? _gattCallback;
    
    private AndroidScanListener? _scanListener;
    private AndroidGattListener? _gattListener;
    private BluetoothScanOptions _scanOptions = new(null);
    
    private TaskCompletionSource<bool>? _connectTcs;
    private TaskCompletionSource<bool>? _servicesTcs;
    private TaskCompletionSource<int>? _mtuTcs;
    private readonly ConcurrentDictionary<Guid, TaskCompletionSource<byte[]>> _readTcsMap = new();
    private readonly ConcurrentDictionary<Guid, TaskCompletionSource<bool>> _writeTcsMap = new();
    
    public AndroidBluetoothGattClient()
    {
        InitializeAndroidBle();
    }
    
    private void InitializeAndroidBle()
    {
        _ = GetBluetoothAdapter();
    }

    private JavaObject? GetAndroidContext()
    {
        try
        {
            var helperClass = JavaClassWrapper.Wrap("com.godot.game.GodotBleHelper");
            if (helperClass != null)
            {
                var context = helperClass.Call("getContext").As<JavaObject>();
                if (context != null) return context;
            }
        }
        catch (Exception ex)
        {
            GD.PrintErr($"{LogPrefix} Could not get context via GodotBleHelper: {ex.Message}");
        }

        try
        {
            var activityThreadClass = JavaClassWrapper.Wrap("android.app.ActivityThread");
            if (activityThreadClass != null)
            {
                var context = activityThreadClass.Call("currentApplication").As<JavaObject>();
                if (context != null) return context;
            }
        }
        catch (Exception ex)
        {
            GD.PrintErr($"{LogPrefix} Could not get context via ActivityThread: {ex.Message}");
        }

        try
        {
            var activity = Engine.GetSingleton("GodotAndroid") as JavaObject ?? Engine.GetSingleton("Godot") as JavaObject;
            if (activity != null)
            {
                return activity.Call("getApplicationContext").As<JavaObject>();
            }
        }
        catch (Exception ex)
        {
            GD.PrintErr($"{LogPrefix} Could not get context via Godot singleton: {ex.Message}");
        }

        return null;
    }

    private JavaObject? GetBluetoothAdapter()
    {
        if (_bluetoothAdapter != null) return _bluetoothAdapter;

        try
        {
            var adapterClass = JavaClassWrapper.Wrap("android.bluetooth.BluetoothAdapter");
            if (adapterClass != null)
            {
                _bluetoothAdapter = adapterClass.Call("getDefaultAdapter").As<JavaObject>();
                if (_bluetoothAdapter != null)
                {
                    GD.Print($"{LogPrefix} BluetoothAdapter acquired via JavaClassWrapper.Wrap(\"android.bluetooth.BluetoothAdapter\").getDefaultAdapter().");
                    return _bluetoothAdapter;
                }
            }
        }
        catch (Exception ex)
        {
            GD.PrintErr($"{LogPrefix} BluetoothAdapter.getDefaultAdapter failed: {ex.Message}");
        }

        try
        {
            var context = GetAndroidContext();
            if (context != null)
            {
                var bluetoothManager = context.Call("getSystemService", "bluetooth").As<JavaObject>();
                if (bluetoothManager != null)
                {
                    _bluetoothAdapter = bluetoothManager.Call("getAdapter").As<JavaObject>();
                    if (_bluetoothAdapter != null)
                    {
                        GD.Print($"{LogPrefix} BluetoothAdapter acquired via getSystemService.");
                        return _bluetoothAdapter;
                    }
                }
            }
        }
        catch (Exception ex)
        {
            GD.PrintErr($"{LogPrefix} BluetoothManager.getAdapter failed: {ex.Message}");
        }

        GD.PrintErr($"{LogPrefix} Bluetooth Adapter not available.");
        return null;
    }

    private JavaObject EnsureScannerAvailable()
    {
        OS.RequestPermission("android.permission.BLUETOOTH_SCAN");
        OS.RequestPermission("android.permission.BLUETOOTH_CONNECT");
        OS.RequestPermission("android.permission.ACCESS_FINE_LOCATION");

        var adapter = GetBluetoothAdapter();
        if (adapter == null)
        {
            throw new InvalidOperationException("Bluetooth Adapter not available on this device.");
        }

        bool isEnabled = false;
        try
        {
            isEnabled = adapter.Call("isEnabled").As<bool>();
        }
        catch (Exception ex)
        {
            GD.PrintErr($"{LogPrefix} Failed to check Bluetooth enabled state: {ex}");
        }

        if (!isEnabled)
        {
            throw new InvalidOperationException("Bluetooth is turned off. Please enable Bluetooth in your phone's settings.");
        }

        if (_bluetoothScanner == null)
        {
            try
            {
                _bluetoothScanner = adapter.Call("getBluetoothLeScanner").As<JavaObject>();
            }
            catch (Exception ex)
            {
                GD.PrintErr($"{LogPrefix} Failed to get BluetoothLeScanner: {ex}");
            }
        }

        if (_bluetoothScanner == null)
        {
            throw new InvalidOperationException("Bluetooth LE Scanner not available. Please ensure Bluetooth/Nearby Devices permissions are granted and Location services (GPS) are enabled.");
        }

        return _bluetoothScanner;
    }
    
    public Task StartScanAsync(BluetoothScanOptions options, CancellationToken cancellationToken)
    {
        _scanOptions = options;
        var scanner = EnsureScannerAvailable();
        
        _scanListener = new AndroidScanListener(this);
        var proxy = JavaClassWrapper.CreateProxy(_scanListener, new string[] { "com.godot.game.GodotBleHelper$ScanListener" });
        if (proxy == null)
        {
            throw new InvalidOperationException("Failed to create JNI proxy for ScanListener.");
        }
        
        var helperClass = JavaClassWrapper.Wrap("com.godot.game.GodotBleHelper");
        if (helperClass == null)
        {
            throw new InvalidOperationException("GodotBleHelper class not found. Please verify Android Custom Build is enabled.");
        }

        _scanCallback = helperClass.Call("createScanCallback", proxy).As<JavaObject>();
        if (_scanCallback == null)
        {
            throw new InvalidOperationException("Failed to create ScanCallback from GodotBleHelper.");
        }
        
        scanner.Call("startScan", _scanCallback);
        GD.Print($"{LogPrefix} Started BLE scan.");
        return Task.CompletedTask;
    }
    
    public Task StopScanAsync(CancellationToken cancellationToken)
    {
        if (_bluetoothScanner != null && _scanCallback != null)
        {
            _bluetoothScanner.Call("stopScan", _scanCallback);
            GD.Print($"{LogPrefix} Stopped BLE scan.");
        }
        _scanCallback = null;
        _scanListener = null;
        return Task.CompletedTask;
    }
    
    public async Task ConnectAsync(string deviceId, BluetoothConnectionOptions options, CancellationToken cancellationToken)
    {
        await DisconnectAsync(CancellationToken.None);

        var adapter = GetBluetoothAdapter();
        if (adapter == null)
        {
            throw new InvalidOperationException("Bluetooth Adapter not available.");
        }
        
        var device = adapter.Call("getRemoteDevice", deviceId).As<JavaObject>();
        if (device == null)
        {
            throw new InvalidOperationException($"Could not find device with ID: {deviceId}");
        }
        
        _connectTcs = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
        _servicesTcs = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
        
        _gattListener = new AndroidGattListener(this);
        var proxy = JavaClassWrapper.CreateProxy(_gattListener, new string[] { "com.godot.game.GodotBleHelper$GattListener" });
        if (proxy == null)
        {
            throw new InvalidOperationException("Failed to create JNI proxy for GattListener.");
        }
        
        var helperClass = JavaClassWrapper.Wrap("com.godot.game.GodotBleHelper");
        if (helperClass == null)
        {
            throw new InvalidOperationException("GodotBleHelper class not found. Please verify Android Custom Build is enabled.");
        }

        _gattCallback = helperClass.Call("createGattCallback", proxy).As<JavaObject>();
        if (_gattCallback == null)
        {
            throw new InvalidOperationException("Failed to create GattCallback from GodotBleHelper.");
        }
        
        var context = GetAndroidContext();
        if (context == null)
        {
            throw new InvalidOperationException("Could not obtain Android Application Context for connectGatt.");
        }
        
        _bluetoothGatt = helperClass.Call("connectGatt", device, context, _gattCallback).As<JavaObject>();
        if (_bluetoothGatt == null)
        {
            throw new InvalidOperationException("Failed to initiate connectGatt.");
        }
        
        using (var connectTimeoutCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken))
        {
            connectTimeoutCts.CancelAfter(TimeSpan.FromSeconds(10));
            try
            {
                using (connectTimeoutCts.Token.Register(() => _connectTcs.TrySetCanceled()))
                {
                    var success = await _connectTcs.Task;
                    if (!success)
                    {
                        throw new InvalidOperationException("GATT connection failed or disconnected.");
                    }
                }
            }
            catch (Exception)
            {
                await DisconnectAsync(CancellationToken.None);
                throw;
            }
        }
        
        // Request high MTU for launch monitors (Square Golf shot packets are 25 bytes)
        try
        {
            _mtuTcs = new TaskCompletionSource<int>(TaskCreationOptions.RunContinuationsAsynchronously);
            bool req = helperClass.Call("requestMtu", _bluetoothGatt, 512).As<bool>();
            if (req)
            {
                using var mtuTimeoutCts = new CancellationTokenSource(TimeSpan.FromMilliseconds(1500));
                using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken, mtuTimeoutCts.Token);
                using var reg = linkedCts.Token.Register(() => _mtuTcs.TrySetResult(23));
                int negotiatedMtu = await _mtuTcs.Task;
                GD.Print($"{LogPrefix} Negotiated MTU: {negotiatedMtu} bytes");
            }
        }
        catch (Exception ex)
        {
            GD.PrintErr($"{LogPrefix} MTU request exception or timeout (continuing): {ex.Message}");
        }

        helperClass.Call("discoverServices", _bluetoothGatt);
        using (var servicesTimeoutCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken))
        {
            servicesTimeoutCts.CancelAfter(TimeSpan.FromSeconds(10));
            try
            {
                using (servicesTimeoutCts.Token.Register(() => _servicesTcs.TrySetCanceled()))
                {
                    var success = await _servicesTcs.Task;
                    if (!success)
                    {
                        throw new InvalidOperationException("GATT service discovery failed.");
                    }
                }
            }
            catch (Exception)
            {
                await DisconnectAsync(CancellationToken.None);
                throw;
            }
        }
    }
    
    public Task DisconnectAsync(CancellationToken cancellationToken)
    {
        var wasConnected = _bluetoothGatt != null;
        if (_bluetoothGatt != null)
        {
            try
            {
                var helperClass = JavaClassWrapper.Wrap("com.godot.game.GodotBleHelper");
                if (helperClass != null)
                {
                    helperClass.Call("disconnectGatt", _bluetoothGatt);
                }
                else
                {
                    _bluetoothGatt.Call("disconnect");
                    _bluetoothGatt.Call("close");
                }
            }
            catch (Exception ex)
            {
                GD.PrintErr($"{LogPrefix} Exception during GATT disconnect/close: {ex.Message}");
            }
            _bluetoothGatt = null;
            GD.Print($"{LogPrefix} Disconnected and closed GATT client.");
        }

        _connectTcs?.TrySetCanceled();
        _servicesTcs?.TrySetCanceled();
        _mtuTcs?.TrySetCanceled();
        _connectTcs = null;
        _servicesTcs = null;
        _mtuTcs = null;

        foreach (var kvp in _readTcsMap)
        {
            kvp.Value.TrySetCanceled();
        }
        _readTcsMap.Clear();

        foreach (var kvp in _writeTcsMap)
        {
            kvp.Value.TrySetCanceled();
        }
        _writeTcsMap.Clear();

        if (wasConnected)
        {
            try
            {
                Disconnected?.Invoke();
            }
            catch (Exception ex)
            {
                GD.PrintErr($"{LogPrefix} Exception in Disconnected event handler: {ex.Message}");
            }
        }
        return Task.CompletedTask;
    }

    public IReadOnlyList<BluetoothGattCharacteristicInfo> GetDiscoveredCharacteristics()
    {
        if (_bluetoothGatt == null)
        {
            return Array.Empty<BluetoothGattCharacteristicInfo>();
        }

        try
        {
            var helperClass = JavaClassWrapper.Wrap("com.godot.game.GodotBleHelper");
            if (helperClass == null)
            {
                return Array.Empty<BluetoothGattCharacteristicInfo>();
            }

            var summary = helperClass.Call("getDiscoveredCharacteristicsSummary", _bluetoothGatt).As<string>();
            if (string.IsNullOrWhiteSpace(summary))
            {
                return Array.Empty<BluetoothGattCharacteristicInfo>();
            }

            var list = new List<BluetoothGattCharacteristicInfo>();
            foreach (var line in summary.Split('\n', StringSplitOptions.RemoveEmptyEntries))
            {
                var parts = line.Trim().Split('|');
                if (parts.Length == 3 &&
                    Guid.TryParse(parts[0], out var serviceUuid) &&
                    Guid.TryParse(parts[1], out var charUuid) &&
                    int.TryParse(parts[2], out var propsBitmask))
                {
                    list.Add(new BluetoothGattCharacteristicInfo(
                        serviceUuid,
                        charUuid,
                        MapAndroidProperties(propsBitmask)));
                }
            }

            return list;
        }
        catch (Exception ex)
        {
            GD.PrintErr($"{LogPrefix} Error getting discovered characteristics: {ex.Message}");
            return Array.Empty<BluetoothGattCharacteristicInfo>();
        }
    }

    private static BluetoothCharacteristicProperties MapAndroidProperties(int props)
    {
        var result = BluetoothCharacteristicProperties.None;
        if ((props & 0x02) != 0) result |= BluetoothCharacteristicProperties.Read;
        if ((props & 0x04) != 0) result |= BluetoothCharacteristicProperties.WriteWithoutResponse;
        if ((props & 0x08) != 0) result |= BluetoothCharacteristicProperties.Write;
        if ((props & 0x10) != 0) result |= BluetoothCharacteristicProperties.Notify;
        if ((props & 0x20) != 0) result |= BluetoothCharacteristicProperties.Indicate;
        return result;
    }
    
    public ValueTask DisposeAsync()
    {
        _ = DisconnectAsync(CancellationToken.None);
        return ValueTask.CompletedTask;
    }
    
    public async Task<byte[]> ReadCharacteristicAsync(Guid characteristicUuid, CancellationToken cancellationToken)
    {
        if (_bluetoothGatt == null)
        {
            throw new InvalidOperationException("Not connected to GATT server.");
        }
        
        var helperClass = JavaClassWrapper.Wrap("com.godot.game.GodotBleHelper");
        if (helperClass == null)
        {
            throw new InvalidOperationException("GodotBleHelper class not found.");
        }

        var tcs = new TaskCompletionSource<byte[]>(TaskCreationOptions.RunContinuationsAsynchronously);
        _readTcsMap[characteristicUuid] = tcs;
        
        var initiated = helperClass.Call("readCharacteristic", _bluetoothGatt, characteristicUuid.ToString()).As<bool>();
        if (!initiated)
        {
            _readTcsMap.TryRemove(characteristicUuid, out _);
            throw new InvalidOperationException($"Failed to initiate read on characteristic: {characteristicUuid}");
        }
        
        using (cancellationToken.Register(() => tcs.TrySetCanceled()))
        {
            return await tcs.Task;
        }
    }
    
    public async Task SubscribeToCharacteristicAsync(Guid characteristicUuid, CancellationToken cancellationToken)
    {
        if (_bluetoothGatt == null)
        {
            throw new InvalidOperationException("Not connected to GATT server.");
        }
        
        var helperClass = JavaClassWrapper.Wrap("com.godot.game.GodotBleHelper");
        if (helperClass == null)
        {
            throw new InvalidOperationException("GodotBleHelper class not found.");
        }

        var success = helperClass.Call("subscribeCharacteristic", _bluetoothGatt, characteristicUuid.ToString()).As<bool>();
        if (!success)
        {
            GD.PrintErr($"{LogPrefix} Failed to subscribe to characteristic: {characteristicUuid}");
        }
        else
        {
            GD.Print($"{LogPrefix} Subscribed and enabled notifications for characteristic: {characteristicUuid}");
        }
        
        await Task.Delay(250, cancellationToken);
    }
    
    public async Task WriteCharacteristicAsync(Guid characteristicUuid, byte[] value, BluetoothWriteMode writeMode, CancellationToken cancellationToken)
    {
        if (_bluetoothGatt == null)
        {
            throw new InvalidOperationException("Not connected to GATT server.");
        }
        
        var helperClass = JavaClassWrapper.Wrap("com.godot.game.GodotBleHelper");
        if (helperClass == null)
        {
            throw new InvalidOperationException("GodotBleHelper class not found.");
        }

        int writeType = writeMode == BluetoothWriteMode.WithoutResponse ? 1 : 2;
        
        if (writeMode == BluetoothWriteMode.WithResponse)
        {
            var tcs = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
            _writeTcsMap[characteristicUuid] = tcs;
            
            var initiated = helperClass.Call("writeCharacteristic", _bluetoothGatt, characteristicUuid.ToString(), value, writeType).As<bool>();
            if (!initiated)
            {
                _writeTcsMap.TryRemove(characteristicUuid, out _);
                throw new InvalidOperationException($"Failed to initiate write on characteristic: {characteristicUuid}");
            }
            
            using (cancellationToken.Register(() => tcs.TrySetCanceled()))
            {
                await tcs.Task;
            }
        }
        else
        {
            helperClass.Call("writeCharacteristic", _bluetoothGatt, characteristicUuid.ToString(), value, writeType);
            await Task.Delay(50, cancellationToken);
        }
    }
    
    internal void OnDeviceDiscovered(string deviceId, string name, int rssi)
    {
        try
        {
            if (!IsDeviceNameMatch(name, _scanOptions.DeviceNamePrefix))
            {
                return;
            }
            DeviceDiscovered?.Invoke(new BluetoothDevice(deviceId, name, rssi));
        }
        catch (Exception ex)
        {
            GD.PrintErr($"{LogPrefix} Error in DeviceDiscovered event handler: {ex.Message}");
        }
    }

    private static bool IsDeviceNameMatch(string? name, string? prefix) =>
        BluetoothDeviceFilter.IsDeviceNameMatch(name, prefix);
    
    internal void OnConnectionStateChange(int status, int newState)
    {
        GD.Print($"{LogPrefix} OnConnectionStateChange: status={status}, newState={newState}");
        if (status == 0) // GATT_SUCCESS
        {
            if (newState == 2) // STATE_CONNECTED
            {
                GD.Print($"{LogPrefix} Connected to GATT server.");
                _connectTcs?.TrySetResult(true);
            }
            else if (newState == 0) // STATE_DISCONNECTED
            {
                GD.Print($"{LogPrefix} Disconnected from GATT server.");
                _connectTcs?.TrySetResult(false);
                try
                {
                    Disconnected?.Invoke();
                }
                catch (Exception ex)
                {
                    GD.PrintErr($"{LogPrefix} Error in Disconnected event handler: {ex.Message}");
                }
            }
        }
        else
        {
            GD.PrintErr($"{LogPrefix} GATT error: status={status}, newState={newState}");
            if (_connectTcs != null && !_connectTcs.Task.IsCompleted)
            {
                _connectTcs.TrySetException(new Exception($"GATT connection failed with status: {status}"));
            }
            if (newState == 0)
            {
                try
                {
                    Disconnected?.Invoke();
                }
                catch (Exception ex)
                {
                    GD.PrintErr($"{LogPrefix} Error in Disconnected event handler: {ex.Message}");
                }
            }
        }
    }
    
    internal void OnServicesDiscovered(int status)
    {
        if (status == 0) // GATT_SUCCESS
        {
            GD.Print($"{LogPrefix} GATT Services discovered.");
            _servicesTcs?.TrySetResult(true);
        }
        else
        {
            GD.PrintErr($"{LogPrefix} Services discovery failed with status: {status}");
            _servicesTcs?.TrySetException(new Exception($"GATT services discovery failed with status: {status}"));
        }
    }
    
    internal void OnCharacteristicRead(string uuidStr, byte[] value, int status)
    {
        if (Guid.TryParse(uuidStr, out var uuid) && _readTcsMap.TryRemove(uuid, out var tcs))
        {
            if (status == 0) // GATT_SUCCESS
            {
                tcs.TrySetResult(value);
            }
            else
            {
                tcs.TrySetException(new Exception($"Read characteristic failed with status: {status}"));
            }
        }
    }
    
    internal void OnCharacteristicWrite(string uuidStr, int status)
    {
        if (Guid.TryParse(uuidStr, out var uuid) && _writeTcsMap.TryRemove(uuid, out var tcs))
        {
            if (status == 0) // GATT_SUCCESS
            {
                tcs.TrySetResult(true);
            }
            else
            {
                tcs.TrySetException(new Exception($"Write characteristic failed with status: {status}"));
            }
        }
    }
    
    internal void OnCharacteristicChanged(string uuidStr, byte[] value)
    {
        if (Guid.TryParse(uuidStr, out var uuid))
        {
            try
            {
                CharacteristicValueChanged?.Invoke(new BluetoothCharacteristicValue(uuid, value));
            }
            catch (Exception ex)
            {
                GD.PrintErr($"{LogPrefix} Error in CharacteristicValueChanged event handler: {ex.Message}");
            }
        }
    }
    
    internal void OnMtuChanged(int mtu, int status)
    {
        GD.Print($"{LogPrefix} OnMtuChanged: mtu={mtu}, status={status}");
        _mtuTcs?.TrySetResult(status == 0 ? mtu : 23);
    }
    
    private partial class AndroidScanListener : GodotObject
    {
        private readonly AndroidBluetoothGattClient _client;
        public AndroidScanListener(AndroidBluetoothGattClient client) { _client = client; }
        
        public void onDeviceDiscovered(string deviceId, string name, int rssi)
        {
            _client.OnDeviceDiscovered(deviceId, name, rssi);
        }
    }
    
    private partial class AndroidGattListener : GodotObject
    {
        private readonly AndroidBluetoothGattClient _client;
        public AndroidGattListener(AndroidBluetoothGattClient client) { _client = client; }
        
        public void onConnectionStateChange(int status, int newState)
        {
            _client.OnConnectionStateChange(status, newState);
        }
        
        public void onServicesDiscovered(int status)
        {
            _client.OnServicesDiscovered(status);
        }
        
        public void onCharacteristicRead(string uuid, byte[] value, int status)
        {
            _client.OnCharacteristicRead(uuid, value, status);
        }
        
        public void onCharacteristicWrite(string uuid, int status)
        {
            _client.OnCharacteristicWrite(uuid, status);
        }
        
        public void onCharacteristicChanged(string uuid, byte[] value)
        {
            _client.OnCharacteristicChanged(uuid, value);
        }

        public void onMtuChanged(int mtu, int status)
        {
            _client.OnMtuChanged(mtu, status);
        }
    }
}
