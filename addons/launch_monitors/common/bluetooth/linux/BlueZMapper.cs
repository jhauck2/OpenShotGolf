using System;
using System.Collections.Generic;
using LaunchMonitors.Common.Bluetooth;

namespace LaunchMonitors.Common.Bluetooth.Linux;

internal static class BlueZMapper
{
    public const string AdapterInterface = "org.bluez.Adapter1";
    public const string DeviceInterface = "org.bluez.Device1";
    public const string GattCharacteristicInterface = "org.bluez.GattCharacteristic1";

    public static Dictionary<string, object> CreateDiscoveryFilter(string deviceNamePrefix)
    {
        return new Dictionary<string, object>
        {
            ["Transport"] = "le",
            ["Pattern"] = deviceNamePrefix,
            ["DuplicateData"] = false
        };
    }

    public static Dictionary<string, object> CreateWriteOptions(BluetoothWriteMode writeMode)
    {
        return new Dictionary<string, object>
        {
            ["type"] = writeMode == BluetoothWriteMode.WithResponse ? "request" : "command"
        };
    }

    public static bool TryCreateDevice(
        string devicePath,
        IDictionary<string, IDictionary<string, object>> interfaces,
        string deviceNamePrefix,
        out BluetoothDevice device)
    {
        device = new BluetoothDevice(string.Empty, string.Empty, 0);
        if (!interfaces.TryGetValue(DeviceInterface, out var properties))
        {
            return false;
        }

        var name = GetString(properties, "Name") ?? GetString(properties, "Alias") ?? string.Empty;
        if (!IsDeviceNameMatch(name, deviceNamePrefix))
        {
            return false;
        }

        device = new BluetoothDevice(devicePath, name, GetRssi(properties));
        return true;
    }

    public static string? FindCharacteristicPath(
        IDictionary<string, IDictionary<string, IDictionary<string, object>>> managedObjects,
        string devicePath,
        Guid characteristicUuid)
    {
        foreach (var (path, interfaces) in managedObjects)
        {
            if (!path.StartsWith($"{devicePath}/", StringComparison.Ordinal)
                || !interfaces.TryGetValue(GattCharacteristicInterface, out var properties))
            {
                continue;
            }

            var uuid = GetString(properties, "UUID");
            if (Guid.TryParse(uuid, out var parsedUuid) && parsedUuid == characteristicUuid)
            {
                return path;
            }
        }

        return null;
    }

    public static bool TryFindDevicePath(
        IDictionary<string, IDictionary<string, IDictionary<string, object>>> managedObjects,
        string deviceId,
        out string devicePath)
    {
        devicePath = string.Empty;
        var normalizedAddress = string.Empty;
        if (deviceId.StartsWith("/org/bluez/", StringComparison.Ordinal))
        {
            if (managedObjects.TryGetValue(deviceId, out var directInterfaces)
                && directInterfaces.ContainsKey(DeviceInterface))
            {
                devicePath = deviceId;
                return true;
            }

            normalizedAddress = NormalizeAddress(GetAddressFromBlueZDevicePath(deviceId));
        }
        else
        {
            normalizedAddress = NormalizeAddress(deviceId);
        }

        if (normalizedAddress.Length == 0)
        {
            return false;
        }

        foreach (var (path, interfaces) in managedObjects)
        {
            if (!interfaces.TryGetValue(DeviceInterface, out var properties))
            {
                continue;
            }

            var address = GetString(properties, "Address");
            if (string.Equals(NormalizeAddress(address), normalizedAddress, StringComparison.OrdinalIgnoreCase)
                || path.EndsWith($"/dev_{normalizedAddress.Replace(':', '_')}", StringComparison.OrdinalIgnoreCase))
            {
                devicePath = path;
                return true;
            }
        }

        return false;
    }

    public static bool IsDeviceNameMatch(string? name, string deviceNamePrefix)
    {
        return !string.IsNullOrWhiteSpace(name)
            && name.Trim().StartsWith(deviceNamePrefix, StringComparison.OrdinalIgnoreCase);
    }

    public static bool IsTransientConnectFailure(string? errorName, string? errorMessage)
    {
        if (string.Equals(errorName, "org.bluez.Error.InProgress", StringComparison.Ordinal))
        {
            return true;
        }

        return string.Equals(errorName, "org.bluez.Error.Failed", StringComparison.Ordinal)
            && !string.IsNullOrWhiteSpace(errorMessage)
            && errorMessage.Contains("le-connection-abort-by-local", StringComparison.OrdinalIgnoreCase);
    }

    public static string? GetString(IDictionary<string, object> properties, string name)
    {
        return properties.TryGetValue(name, out var value) ? value as string : null;
    }

    private static int GetRssi(IDictionary<string, object> properties)
    {
        if (!properties.TryGetValue("RSSI", out var value))
        {
            return 0;
        }

        return value switch
        {
            short shortValue => shortValue,
            int intValue => intValue,
            _ => 0
        };
    }

    private static string NormalizeAddress(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return string.Empty;
        }

        var normalized = value.Trim().Replace('-', ':').Replace('_', ':');
        if (normalized.Length == 12 && !normalized.Contains(':', StringComparison.Ordinal))
        {
            return string.Join(
                ':',
                normalized[0..2],
                normalized[2..4],
                normalized[4..6],
                normalized[6..8],
                normalized[8..10],
                normalized[10..12]);
        }

        return normalized;
    }

    private static string GetAddressFromBlueZDevicePath(string devicePath)
    {
        var deviceSegmentIndex = devicePath.LastIndexOf("/dev_", StringComparison.Ordinal);
        return deviceSegmentIndex < 0
            ? string.Empty
            : devicePath[(deviceSegmentIndex + "/dev_".Length)..];
    }
}
