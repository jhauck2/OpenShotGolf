using System;

namespace OpenShotGolf.LaunchMonitors.Bluetooth;

internal static class BluetoothGattClientFactory
{
    private const string WindowsClientTypeName = "OpenShotGolf.LaunchMonitors.Bluetooth.Windows.WindowsBluetoothGattClient";

    public static IBluetoothGattClient Create()
    {
        if (OperatingSystem.IsWindows())
        {
            return CreateWindowsClient();
        }

        if (OperatingSystem.IsLinux())
        {
            return new Linux.LinuxBluetoothGattClient();
        }

        return new UnsupportedBluetoothGattClient("Bluetooth GATT support is only available on Windows and Linux.");
    }

    private static IBluetoothGattClient CreateWindowsClient()
    {
        var type = typeof(BluetoothGattClientFactory).Assembly.GetType(WindowsClientTypeName);
        if (type is null)
        {
            throw new PlatformNotSupportedException("Windows Bluetooth support was not included in this build.");
        }

        return Activator.CreateInstance(type) as IBluetoothGattClient
            ?? throw new InvalidOperationException("Windows Bluetooth support could not be created.");
    }
}
