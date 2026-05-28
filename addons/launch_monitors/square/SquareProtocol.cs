using System;
using System.Buffers.Binary;

namespace LaunchMonitors.Square;

public static class SquareProtocol
{
    public static bool IsSensorPacket(ReadOnlySpan<byte> data)
    {
        return data.Length >= 17 && data[0] == 0x11 && data[1] == 0x01;
    }

    public static bool IsShotPacket(ReadOnlySpan<byte> data)
    {
        return data.Length >= 17 && data[0] == 0x11 && data[1] == 0x02;
    }

    public static bool TryParseSensor(ReadOnlySpan<byte> data, out SquareSensorData sensor)
    {
        sensor = default;
        if (!IsSensorPacket(data))
        {
            return false;
        }

        sensor = new SquareSensorData(
            data[3] is 0x01 or 0x02,
            data[4] == 0x01,
            BinaryPrimitives.ReadInt32LittleEndian(data[5..9]),
            BinaryPrimitives.ReadInt32LittleEndian(data[9..13]),
            BinaryPrimitives.ReadInt32LittleEndian(data[13..17]));

        return true;
    }

    public static bool TryParseShot(ReadOnlySpan<byte> data, out SquareShotMetrics metrics)
    {
        metrics = default;
        if (!IsShotPacket(data))
        {
            return false;
        }

        var shotType = data[2] switch
        {
            0x37 => "full",
            0x13 => "putt",
            _ => "unknown"
        };

        metrics = new SquareShotMetrics(
            BinaryPrimitives.ReadInt16LittleEndian(data[3..5]) / 100.0f,
            BinaryPrimitives.ReadInt16LittleEndian(data[5..7]) / 100.0f,
            BinaryPrimitives.ReadInt16LittleEndian(data[7..9]) / 100.0f,
            BinaryPrimitives.ReadInt16LittleEndian(data[9..11]),
            BinaryPrimitives.ReadInt16LittleEndian(data[11..13]) / -100.0f,
            BinaryPrimitives.ReadInt16LittleEndian(data[13..15]),
            BinaryPrimitives.ReadInt16LittleEndian(data[15..17]),
            shotType);

        return IsPlausible(metrics);
    }

    private static bool IsPlausible(SquareShotMetrics metrics)
    {
        return metrics.BallSpeedMps > 0
            && metrics.BallSpeedMps < 250
            && metrics.TotalSpinRpm >= 0
            && metrics.TotalSpinRpm < 30_000
            && metrics.VerticalAngle >= 0;
    }
}
