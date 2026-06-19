using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using LaunchMonitors.Common.Bluetooth;
using Tmds.DBus;

namespace LaunchMonitors.Common.Bluetooth.Linux;

internal sealed class LinuxBluetoothGattClient : IBluetoothGattClient
{
    private const string BlueZService = "org.bluez";

    private readonly Dictionary<string, object> _emptyOptions = [];
    private readonly Dictionary<Guid, IBlueZGattCharacteristic> _characteristics = [];
    private readonly Dictionary<Guid, IDisposable> _subscriptions = [];
    private readonly HashSet<Guid> _notificationsStarted = [];
    private IBlueZObjectManager? _objectManager;
    private IBlueZAdapter? _adapter;
    private IBlueZDevice? _device;
    private IDisposable? _scanSubscription;
    private BluetoothScanOptions _scanOptions = new(string.Empty);
    private BluetoothConnectionOptions _connectionOptions = new([], [], 4, TimeSpan.FromMilliseconds(700));

    public event Action<BluetoothDevice>? DeviceDiscovered;

    public event Action<BluetoothCharacteristicValue>? CharacteristicValueChanged;

    public async Task StartScanAsync(BluetoothScanOptions options, CancellationToken cancellationToken)
    {
        _scanOptions = options;
        await StopScanAsync(cancellationToken);
        var objectManager = GetObjectManager();
        _adapter = await GetAdapterAsync(cancellationToken);
        _scanSubscription = await objectManager.WatchInterfacesAddedAsync(OnInterfacesAdded, OnWatcherError);

        var managedObjects = ToStringDictionary(await objectManager.GetManagedObjectsAsync());
        EmitKnownDevices(managedObjects);

        await _adapter.SetDiscoveryFilterAsync(BlueZMapper.CreateDiscoveryFilter(options.DeviceNamePrefix));
        await _adapter.StartDiscoveryAsync();
    }

    public async Task StopScanAsync(CancellationToken cancellationToken)
    {
        _scanSubscription?.Dispose();
        _scanSubscription = null;

        if (_adapter is null)
        {
            return;
        }

        try
        {
            await _adapter.StopDiscoveryAsync();
        }
        catch (DBusException ex) when (IsExpectedStopDiscoveryError(ex))
        {
        }
    }

    public async Task ConnectAsync(string deviceId, BluetoothConnectionOptions options, CancellationToken cancellationToken)
    {
        _connectionOptions = options;
        await StopScanAsync(cancellationToken);
        await DisconnectAsync(cancellationToken);

        var objectManager = GetObjectManager();
        _adapter ??= await GetAdapterAsync(cancellationToken);
        var managedObjects = ToStringDictionary(await objectManager.GetManagedObjectsAsync());
        if (!BlueZMapper.TryFindDevicePath(managedObjects, deviceId, out var devicePath))
        {
            throw new InvalidOperationException("The selected Bluetooth device was not found by BlueZ. Scan again before connecting.");
        }

        _device = Connection.System.CreateProxy<IBlueZDevice>(BlueZService, devicePath);
        await ConnectDeviceWithRetryAsync(_device, cancellationToken);

        await WaitForServicesResolvedAsync(_device, cancellationToken);
        managedObjects = ToStringDictionary(await objectManager.GetManagedObjectsAsync());
        LoadCharacteristics(managedObjects, devicePath, options);
    }

    public async Task DisconnectAsync(CancellationToken cancellationToken)
    {
        foreach (var subscription in _subscriptions.Values)
        {
            subscription.Dispose();
        }

        _subscriptions.Clear();

        foreach (var characteristicUuid in _notificationsStarted.ToArray())
        {
            if (_characteristics.TryGetValue(characteristicUuid, out var characteristic))
            {
                await StopNotifyAsync(characteristic);
            }
        }

        _notificationsStarted.Clear();

        if (_device is not null)
        {
            try
            {
                await _device.DisconnectAsync();
            }
            catch (DBusException ex) when (IsBlueZError(ex, "org.bluez.Error.NotConnected")
                || IsBlueZObjectGoneError(ex))
            {
            }
        }

        _device = null;
        _characteristics.Clear();
    }

    public async Task<byte[]> ReadCharacteristicAsync(Guid characteristicUuid, CancellationToken cancellationToken)
    {
        return _characteristics.TryGetValue(characteristicUuid, out var characteristic)
            ? await ReadValueAsync(characteristic)
            : [];
    }

    public async Task SubscribeToCharacteristicAsync(Guid characteristicUuid, CancellationToken cancellationToken)
    {
        if (_subscriptions.ContainsKey(characteristicUuid))
        {
            return;
        }

        if (!_characteristics.TryGetValue(characteristicUuid, out var characteristic))
        {
            throw new InvalidOperationException($"Bluetooth characteristic {characteristicUuid} is not available.");
        }

        var subscription = await characteristic.WatchPropertiesAsync(
            changes => OnCharacteristicPropertiesChanged(characteristicUuid, changes),
            OnWatcherError);
        await characteristic.StartNotifyAsync();
        _subscriptions[characteristicUuid] = subscription;
        _notificationsStarted.Add(characteristicUuid);
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

        await characteristic.WriteValueAsync(value, BlueZMapper.CreateWriteOptions(writeMode));
    }

    public async ValueTask DisposeAsync()
    {
        await StopScanAsync(CancellationToken.None);
        await DisconnectAsync(CancellationToken.None);
    }

    private async Task ConnectDeviceWithRetryAsync(IBlueZDevice device, CancellationToken cancellationToken)
    {
        var attempts = Math.Max(1, _connectionOptions.ServiceDiscoveryMaxAttempts);
        try
        {
            for (var attempt = 1; attempt <= attempts; attempt++)
            {
                cancellationToken.ThrowIfCancellationRequested();
                try
                {
                    await device.ConnectAsync();
                    return;
                }
                catch (DBusException ex) when (IsBlueZError(ex, "org.bluez.Error.AlreadyConnected"))
                {
                    return;
                }
                catch (DBusException ex) when (IsBlueZObjectGoneError(ex))
                {
                    _device = null;
                    throw new InvalidOperationException("The selected Bluetooth device is no longer known to BlueZ. Scan again before connecting.", ex);
                }
                catch (DBusException ex) when (BlueZMapper.IsTransientConnectFailure(ex.ErrorName, ex.ErrorMessage))
                {
                    if (attempt >= attempts)
                    {
                        await TryCancelConnectAsync(device);
                        throw new TimeoutException("The selected Bluetooth device is not ready yet. Wait a moment and try connecting again.", ex);
                    }

                    await TryCancelConnectAsync(device);
                    await Task.Delay(_connectionOptions.ServiceDiscoveryRetryDelay, cancellationToken);
                }
            }
        }
        catch
        {
            _device = null;
            throw;
        }
    }

    private static async Task TryCancelConnectAsync(IBlueZDevice device)
    {
        try
        {
            await device.DisconnectAsync();
        }
        catch (DBusException ex) when (IsBlueZError(ex, "org.bluez.Error.NotConnected")
            || IsBlueZError(ex, "org.bluez.Error.Failed")
            || IsBlueZObjectGoneError(ex))
        {
        }
    }

    private IBlueZObjectManager GetObjectManager()
    {
        return _objectManager ??= Connection.System.CreateProxy<IBlueZObjectManager>(BlueZService, ObjectPath.Root);
    }

    private async Task<IBlueZAdapter> GetAdapterAsync(CancellationToken cancellationToken)
    {
        var objectManager = GetObjectManager();
        var managedObjects = await objectManager.GetManagedObjectsAsync();
        foreach (var (path, interfaces) in managedObjects)
        {
            cancellationToken.ThrowIfCancellationRequested();
            if (interfaces.ContainsKey(BlueZMapper.AdapterInterface))
            {
                return Connection.System.CreateProxy<IBlueZAdapter>(BlueZService, path);
            }
        }

        throw new InvalidOperationException("No BlueZ Bluetooth adapter was found.");
    }

    private async Task WaitForServicesResolvedAsync(IBlueZDevice device, CancellationToken cancellationToken)
    {
        for (var attempt = 1; attempt <= _connectionOptions.ServiceDiscoveryMaxAttempts; attempt++)
        {
            cancellationToken.ThrowIfCancellationRequested();
            if (await device.GetAsync<bool>("ServicesResolved"))
            {
                return;
            }

            if (attempt < _connectionOptions.ServiceDiscoveryMaxAttempts)
            {
                await Task.Delay(_connectionOptions.ServiceDiscoveryRetryDelay, cancellationToken);
            }
        }

        throw new InvalidOperationException("BlueZ did not finish Bluetooth service discovery for the selected device.");
    }

    private void LoadCharacteristics(
        IDictionary<string, IDictionary<string, IDictionary<string, object>>> managedObjects,
        string devicePath,
        BluetoothConnectionOptions options)
    {
        _characteristics.Clear();

        foreach (var uuid in options.RequiredCharacteristicUuids)
        {
            var path = BlueZMapper.FindCharacteristicPath(managedObjects, devicePath, uuid);
            if (path is null)
            {
                throw new InvalidOperationException($"Missing Bluetooth characteristic {uuid}.");
            }

            _characteristics[uuid] = Connection.System.CreateProxy<IBlueZGattCharacteristic>(BlueZService, path);
        }

        foreach (var uuid in options.OptionalCharacteristicUuids)
        {
            var path = BlueZMapper.FindCharacteristicPath(managedObjects, devicePath, uuid);
            if (path is not null)
            {
                _characteristics[uuid] = Connection.System.CreateProxy<IBlueZGattCharacteristic>(BlueZService, path);
            }
        }
    }

    private async Task<byte[]> ReadValueAsync(IBlueZGattCharacteristic characteristic)
    {
        try
        {
            return await characteristic.ReadValueAsync(_emptyOptions);
        }
        catch (DBusException)
        {
            return [];
        }
    }

    private static async Task StopNotifyAsync(IBlueZGattCharacteristic characteristic)
    {
        try
        {
            await characteristic.StopNotifyAsync();
        }
        catch (DBusException ex) when (IsBlueZError(ex, "org.bluez.Error.Failed")
            || IsBlueZError(ex, "org.bluez.Error.NotPermitted")
            || IsBlueZError(ex, "org.bluez.Error.NotSupported")
            || IsBlueZObjectGoneError(ex))
        {
        }
    }

    private void EmitKnownDevices(IDictionary<string, IDictionary<string, IDictionary<string, object>>> managedObjects)
    {
        foreach (var (path, interfaces) in managedObjects)
        {
            if (BlueZMapper.TryCreateDevice(path, interfaces, _scanOptions.DeviceNamePrefix, out var device))
            {
                DeviceDiscovered?.Invoke(device);
            }
        }
    }

    private void OnInterfacesAdded((ObjectPath ObjectPath, IDictionary<string, IDictionary<string, object>> Interfaces) added)
    {
        var path = added.ObjectPath.ToString();
        if (BlueZMapper.TryCreateDevice(path, added.Interfaces, _scanOptions.DeviceNamePrefix, out var device))
        {
            DeviceDiscovered?.Invoke(device);
        }
    }

    private void OnCharacteristicPropertiesChanged(Guid characteristicUuid, PropertyChanges changes)
    {
        var value = changes.Get<byte[]>("Value");
        if (value is { Length: > 0 })
        {
            CharacteristicValueChanged?.Invoke(new BluetoothCharacteristicValue(characteristicUuid, value));
        }
    }

    private static void OnWatcherError(Exception ex)
    {
    }

    private static bool IsExpectedStopDiscoveryError(DBusException ex)
    {
        return IsBlueZError(ex, "org.bluez.Error.NotReady")
            || IsBlueZError(ex, "org.bluez.Error.Failed")
            || IsBlueZError(ex, "org.bluez.Error.NotAuthorized");
    }

    private static bool IsBlueZError(DBusException ex, string errorName)
    {
        return string.Equals(ex.ErrorName, errorName, StringComparison.Ordinal);
    }

    private static bool IsBlueZObjectGoneError(DBusException ex)
    {
        return IsBlueZError(ex, "org.freedesktop.DBus.Error.UnknownObject")
            || IsBlueZError(ex, "org.freedesktop.DBus.Error.UnknownMethod");
    }

    private static Dictionary<string, IDictionary<string, IDictionary<string, object>>> ToStringDictionary(
        IDictionary<ObjectPath, IDictionary<string, IDictionary<string, object>>> managedObjects)
    {
        return managedObjects.ToDictionary(item => item.Key.ToString(), item => item.Value);
    }
}

[DBusInterface("org.freedesktop.DBus.ObjectManager")]
public interface IBlueZObjectManager : IDBusObject
{
    Task<IDictionary<ObjectPath, IDictionary<string, IDictionary<string, object>>>> GetManagedObjectsAsync();

    Task<IDisposable> WatchInterfacesAddedAsync(
        Action<(ObjectPath ObjectPath, IDictionary<string, IDictionary<string, object>> Interfaces)> handler,
        Action<Exception> onError);
}

[DBusInterface(BlueZMapper.AdapterInterface)]
public interface IBlueZAdapter : IDBusObject
{
    Task StartDiscoveryAsync();

    Task StopDiscoveryAsync();

    Task SetDiscoveryFilterAsync(IDictionary<string, object> filter);
}

[DBusInterface(BlueZMapper.DeviceInterface)]
public interface IBlueZDevice : IDBusObject
{
    Task ConnectAsync();

    Task DisconnectAsync();

    Task<T> GetAsync<T>(string property);
}

[DBusInterface(BlueZMapper.GattCharacteristicInterface)]
public interface IBlueZGattCharacteristic : IDBusObject
{
    Task<byte[]> ReadValueAsync(IDictionary<string, object> options);

    Task WriteValueAsync(byte[] value, IDictionary<string, object> options);

    Task StartNotifyAsync();

    Task StopNotifyAsync();

    Task<IDisposable> WatchPropertiesAsync(Action<PropertyChanges> handler, Action<Exception> onError);
}
