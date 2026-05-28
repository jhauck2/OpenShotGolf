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

    // The device sends 0x8000 (-32768) for a field it could not measure this
    // shot. Treated as "no reading" rather than a real value, otherwise the
    // sentinel leaks through as a huge negative spin / angle and can drop the
    // whole shot at the plausibility gate.
    private const short InvalidReadingSentinel = unchecked((short)0x8000);

    public static bool TryParseShot(ReadOnlySpan<byte> data, out SquareShotMetrics metrics)
    {
        metrics = default;
        if (!IsShotPacket(data))
        {
            return false;
        }

        // Byte[2] is opaque metadata on the Home device; 0x37 is observed on
        // full-swing frames and 0x13 on putts. ShotType is informational only.
        var shotType = data[2] switch
        {
            0x37 => "full",
            0x13 => "putt",
            _ => "unknown"
        };

        var (ballSpeed, _) = ReadScaledInt16(data, 3, 100.0f);
        var (verticalAngle, _) = ReadScaledInt16(data, 5, 100.0f);
        var (horizontalAngle, _) = ReadScaledInt16(data, 7, 100.0f);
        var (totalSpin, totalSpinValid) = ReadInt16(data, 9);
        var (spinAxis, spinAxisValid) = ReadScaledInt16(data, 11, -100.0f);
        var (backSpin, backSpinValid) = ReadInt16(data, 13);
        var (sideSpin, sideSpinValid) = ReadInt16(data, 15);

        // When total spin and spin axis are known but a spin component was not
        // measured, derive it from the axis (matches squaregolf-connector).
        if (totalSpinValid && spinAxisValid)
        {
            var spinAxisRadians = MathF.PI * spinAxis / 180.0f;
            if (!backSpinValid)
            {
                backSpin = (short)MathF.Round(totalSpin * MathF.Cos(spinAxisRadians));
            }

            if (!sideSpinValid)
            {
                sideSpin = (short)MathF.Round(totalSpin * MathF.Sin(spinAxisRadians));
            }
        }

        metrics = new SquareShotMetrics(
            ballSpeed,
            verticalAngle,
            horizontalAngle,
            totalSpin,
            spinAxis,
            backSpin,
            sideSpin,
            shotType);

        return IsPlausible(metrics);
    }

    private static (float Value, bool Valid) ReadScaledInt16(ReadOnlySpan<byte> data, int offset, float scale)
    {
        var (raw, valid) = ReadInt16(data, offset);
        return (raw / scale, valid);
    }

    private static (short Value, bool Valid) ReadInt16(ReadOnlySpan<byte> data, int offset)
    {
        var raw = BinaryPrimitives.ReadInt16LittleEndian(data[offset..(offset + 2)]);
        return raw == InvalidReadingSentinel ? ((short)0, false) : (raw, true);
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
