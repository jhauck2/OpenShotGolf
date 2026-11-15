using System;
using System.Buffers.Binary;

namespace LaunchMonitors.Rainmaker;

public static class RainmakerProtocol
{
    // Common standard and placeholder UUIDs for GATT discovery
    public static readonly Guid GenericAccessServiceUuid = Guid.Parse("00001800-0000-1000-8000-00805f9b34fb");
    public static readonly Guid DeviceInfoServiceUuid = Guid.Parse("0000180a-0000-1000-8000-00805f9b34fb");
    public static readonly Guid BatteryServiceUuid = Guid.Parse("0000180f-0000-1000-8000-00805f9b34fb");
    public static readonly Guid BatteryCharacteristicUuid = Guid.Parse("00002a19-0000-1000-8000-00805f9b34fb");
    public static readonly Guid FirmwareCharacteristicUuid = Guid.Parse("00002a28-0000-1000-8000-00805f9b34fb");

    public static bool TryParseShotPacket(ReadOnlySpan<byte> data, out RainmakerShotMetrics metrics)
    {
        metrics = null!;
        if (data.Length < 16)
        {
            return false;
        }

        try
        {
            // Standard launch monitor float32 encoding (speed in m/s, launch angles in deg, spin in rpm)
            float speed = BitConverter.ToSingle(data.Slice(0, 4));
            float vla = BitConverter.ToSingle(data.Slice(4, 4));
            float hla = BitConverter.ToSingle(data.Slice(8, 4));
            float spin = BitConverter.ToSingle(data.Slice(12, 4));
            float spinAxis = data.Length >= 20 ? BitConverter.ToSingle(data.Slice(16, 4)) : 0f;

            if (speed > 5f && speed < 120f)
            {
                metrics = new RainmakerShotMetrics(speed, vla, hla, spin, spinAxis);
                return true;
            }
        }
        catch
        {
            return false;
        }

        return false;
    }
}
