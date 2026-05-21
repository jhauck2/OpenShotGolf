using System;
using System.Globalization;

namespace OpenShotGolf.LaunchMonitors.Square;

public static class SquareCommandBuilder
{
    public const string DriverClubCode = "0204";

    public static byte[] Heartbeat(byte sequence)
    {
        return FromHex($"1183{sequence:X2}0000000000");
    }

    public static byte[] DetectBall(byte sequence, int mode, int spinMode)
    {
        return FromHex($"1181{sequence:X2}0{mode}1{spinMode}00000000");
    }

    public static byte[] Club(byte sequence, string clubCode, int handedness)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(clubCode);
        return FromHex($"1182{sequence:X2}{clubCode}0{handedness}000000");
    }

    public static byte[] FromHex(string hex)
    {
        if (hex.Length % 2 != 0)
        {
            throw new ArgumentException("Hex values must have an even number of characters.", nameof(hex));
        }

        var bytes = new byte[hex.Length / 2];
        for (var i = 0; i < bytes.Length; i++)
        {
            bytes[i] = byte.Parse(hex.Substring(i * 2, 2), NumberStyles.HexNumber, CultureInfo.InvariantCulture);
        }

        return bytes;
    }
}
