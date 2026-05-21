using System;
using System.Buffers.Binary;
using NUnit.Framework;
using OpenShotGolf.LaunchMonitors.Square;

namespace OpenShotGolf.Tests.LaunchMonitors.Square;

[TestFixture]
public sealed class SquareProtocolTests
{
    [Test]
    public void TryParseShotReadsFullShotPacket()
    {
        var packet = CreateShotPacket(
            shotType: 0x37,
            ballSpeedMps: 44.70f,
            verticalAngle: 12.50f,
            horizontalAngle: -2.25f,
            totalSpin: 3200,
            spinAxis: -8.50f,
            backSpin: 3150,
            sideSpin: -470);

        var parsed = SquareProtocol.TryParseShot(packet, out var metrics);

        Assert.That(parsed, Is.True);
        Assert.That(metrics.ShotType, Is.EqualTo("full"));
        Assert.That(metrics.BallSpeedMps, Is.EqualTo(44.70f).Within(0.001f));
        Assert.That(metrics.VerticalAngle, Is.EqualTo(12.50f).Within(0.001f));
        Assert.That(metrics.HorizontalAngle, Is.EqualTo(-2.25f).Within(0.001f));
        Assert.That(metrics.TotalSpinRpm, Is.EqualTo(3200));
        Assert.That(metrics.SpinAxis, Is.EqualTo(-8.50f).Within(0.001f));
        Assert.That(metrics.BackSpinRpm, Is.EqualTo(3150));
        Assert.That(metrics.SideSpinRpm, Is.EqualTo(-470));
    }

    [Test]
    public void TryParseShotRejectsBadPacket()
    {
        var parsed = SquareProtocol.TryParseShot([0x11, 0x02, 0x37], out _);

        Assert.That(parsed, Is.False);
    }

    [Test]
    public void TryParseSensorReadsReadyState()
    {
        var packet = new byte[17];
        packet[0] = 0x11;
        packet[1] = 0x01;
        packet[3] = 0x01;
        packet[4] = 0x01;
        BinaryPrimitives.WriteInt32LittleEndian(packet.AsSpan(5, 4), 10);
        BinaryPrimitives.WriteInt32LittleEndian(packet.AsSpan(9, 4), 20);
        BinaryPrimitives.WriteInt32LittleEndian(packet.AsSpan(13, 4), 30);

        var parsed = SquareProtocol.TryParseSensor(packet, out var sensor);

        Assert.That(parsed, Is.True);
        Assert.That(sensor.BallReady, Is.True);
        Assert.That(sensor.BallDetected, Is.True);
        Assert.That(sensor.PositionX, Is.EqualTo(10));
        Assert.That(sensor.PositionY, Is.EqualTo(20));
        Assert.That(sensor.PositionZ, Is.EqualTo(30));
    }

    [Test]
    public void ToBallDataUsesOsgBallDataShape()
    {
        var metrics = new SquareShotMetrics(
            BallSpeedMps: 44.70f,
            VerticalAngle: 12.50f,
            HorizontalAngle: -2.25f,
            TotalSpinRpm: 3200,
            SpinAxis: -8.50f,
            BackSpinRpm: 3150,
            SideSpinRpm: -470,
            ShotType: "full");

        var ballData = SquareShotDataMapper.ToOsgBallData(metrics);

        Assert.That(ballData.ContainsKey("Speed"), Is.True);
        Assert.That(ballData.ContainsKey("VLA"), Is.True);
        Assert.That(ballData.ContainsKey("HLA"), Is.True);
        Assert.That(ballData.ContainsKey("TotalSpin"), Is.True);
        Assert.That(ballData.ContainsKey("SpinAxis"), Is.True);
        Assert.That((float)ballData["Speed"], Is.EqualTo(99.98f).Within(0.02f));
    }

    private static byte[] CreateShotPacket(
        byte shotType,
        float ballSpeedMps,
        float verticalAngle,
        float horizontalAngle,
        int totalSpin,
        float spinAxis,
        int backSpin,
        int sideSpin)
    {
        var packet = new byte[17];
        packet[0] = 0x11;
        packet[1] = 0x02;
        packet[2] = shotType;
        WriteScaled(packet.AsSpan(3, 2), ballSpeedMps);
        WriteScaled(packet.AsSpan(5, 2), verticalAngle);
        WriteScaled(packet.AsSpan(7, 2), horizontalAngle);
        BinaryPrimitives.WriteInt16LittleEndian(packet.AsSpan(9, 2), checked((short)totalSpin));
        WriteScaled(packet.AsSpan(11, 2), -spinAxis);
        BinaryPrimitives.WriteInt16LittleEndian(packet.AsSpan(13, 2), checked((short)backSpin));
        BinaryPrimitives.WriteInt16LittleEndian(packet.AsSpan(15, 2), checked((short)sideSpin));
        return packet;
    }

    private static void WriteScaled(Span<byte> target, float value)
    {
        BinaryPrimitives.WriteInt16LittleEndian(target, checked((short)MathF.Round(value * 100.0f)));
    }
}
