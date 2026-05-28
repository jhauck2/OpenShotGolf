using System;
using System.Buffers.Binary;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using NUnit.Framework;
using LaunchMonitors.Common.Bluetooth;
using LaunchMonitors.Square;

namespace OpenShotGolf.Tests.LaunchMonitors.Square;

[TestFixture]
public sealed class SquareConnectionSessionTests
{
    [Test]
    public async Task StartScanUsesSquareDeviceNamePrefix()
    {
        var bluetoothClient = new FakeBluetoothGattClient();
        var session = CreateSession(bluetoothClient);

        await session.StartScanAsync();

        Assert.That(bluetoothClient.ScanOptions?.DeviceNamePrefix, Is.EqualTo("SquareGolf"));
    }

    [Test]
    public async Task ConnectSendsSharedStartupCommands()
    {
        var options = SquareConnectionOptions.Default;
        var bluetoothClient = new FakeBluetoothGattClient();
        bluetoothClient.ReadValues[options.BatteryCharacteristicUuid] = [87];
        bluetoothClient.ReadValues[options.FirmwareCharacteristicUuid] = Encoding.UTF8.GetBytes("""{"lm":"1.2.3"}""");
        var session = CreateSession(bluetoothClient);
        var statuses = new List<string>();
        var readyStates = new List<bool>();
        var batteryLevels = new List<int>();
        var firmwareVersions = new List<string>();
        session.StatusChanged += statuses.Add;
        session.ReadyChanged += readyStates.Add;
        session.BatteryChanged += batteryLevels.Add;
        session.FirmwareChanged += firmwareVersions.Add;

        session.SetHandedness(1);
        await session.SetClubAsync("0305");
        await session.ConnectToDeviceAsync("square-device");

        Assert.That(bluetoothClient.ConnectedDeviceId, Is.EqualTo("square-device"));
        Assert.That(bluetoothClient.ConnectionOptions?.RequiredCharacteristicUuids, Is.EquivalentTo(new[]
        {
            options.CommandCharacteristicUuid,
            options.EventCharacteristicUuid
        }));
        Assert.That(bluetoothClient.ConnectionOptions?.OptionalCharacteristicUuids, Is.EquivalentTo(new[]
        {
            options.BatteryCharacteristicUuid,
            options.FirmwareCharacteristicUuid
        }));
        Assert.That(bluetoothClient.SubscribedCharacteristicUuids, Is.EquivalentTo(new[]
        {
            options.EventCharacteristicUuid,
            options.BatteryCharacteristicUuid
        }));
        Assert.That(bluetoothClient.Writes, Has.Count.EqualTo(3));
        AssertWrite(bluetoothClient.Writes[0], options.CommandCharacteristicUuid, SquareCommandBuilder.Heartbeat(0));
        AssertWrite(bluetoothClient.Writes[1], options.CommandCharacteristicUuid, SquareCommandBuilder.Club(1, "0305", 1));
        AssertWrite(bluetoothClient.Writes[2], options.CommandCharacteristicUuid, SquareCommandBuilder.DetectBall(2, mode: 1, spinMode: 1));
        Assert.That(bluetoothClient.Writes.All(write => write.WriteMode == BluetoothWriteMode.WithResponse), Is.True);
        CollectionAssert.AreEqual(new[] { "Connecting", "Connected", "Ready" }, statuses);
        CollectionAssert.AreEqual(new[] { true }, readyStates);
        CollectionAssert.AreEqual(new[] { 87 }, batteryLevels);
        CollectionAssert.AreEqual(new[] { "1.2.3" }, firmwareVersions);
    }

    [Test]
    public async Task ConnectDeviceNotReadyUsesTransientPath()
    {
        var bluetoothClient = new FakeBluetoothGattClient
        {
            ConnectException = new TimeoutException("The selected Bluetooth device is not ready yet. Wait a moment and try connecting again.")
        };
        var statuses = new List<string>();
        var errors = new List<string>();
        var errorLogs = new List<string>();
        var session = CreateSession(bluetoothClient, logError: errorLogs.Add);
        session.StatusChanged += statuses.Add;
        session.ErrorOccurred += errors.Add;

        await session.ConnectToDeviceAsync("square-device");

        CollectionAssert.AreEqual(new[] { "Connecting", "Disconnected" }, statuses);
        CollectionAssert.AreEqual(
            new[] { "Square device was detected but is not ready yet. Wait a moment and try connecting again." },
            errors);
        Assert.That(errorLogs, Is.Empty);
    }

    [Test]
    public async Task ShotNotificationEmitsOnceAndSetsReadyAgain()
    {
        var options = SquareConnectionOptions.Default;
        var bluetoothClient = new FakeBluetoothGattClient();
        var session = CreateSession(bluetoothClient);
        var shots = new List<SquareShotMetrics>();
        var readyStates = new List<bool>();
        session.ShotReceived += shots.Add;
        session.ReadyChanged += readyStates.Add;
        await session.ConnectToDeviceAsync("square-device");
        bluetoothClient.Writes.Clear();

        var shotPacket = CreateShotPacket();
        bluetoothClient.EmitCharacteristic(options.EventCharacteristicUuid, shotPacket);
        await WaitUntilAsync(() => shots.Count == 1 && bluetoothClient.Writes.Count == 1);
        bluetoothClient.EmitCharacteristic(options.EventCharacteristicUuid, shotPacket);
        await Task.Delay(50);

        Assert.That(shots, Has.Count.EqualTo(1));
        Assert.That(readyStates, Does.Contain(false));
        Assert.That(readyStates, Does.Contain(true));
        AssertWrite(
            bluetoothClient.Writes[0],
            options.CommandCharacteristicUuid,
            SquareCommandBuilder.DetectBall(3, mode: 1, spinMode: 1));
    }

    [Test]
    public async Task SensorNotificationUpdatesReadyState()
    {
        var bluetoothClient = new FakeBluetoothGattClient();
        var session = CreateSession(bluetoothClient);
        var readyStates = new List<bool>();
        session.ReadyChanged += readyStates.Add;
        await session.ConnectToDeviceAsync("square-device");

        bluetoothClient.EmitCharacteristic(SquareConnectionOptions.Default.EventCharacteristicUuid, CreateSensorPacket());
        await WaitUntilAsync(() => readyStates.Count >= 2);

        Assert.That(readyStates[^1], Is.True);
    }

    private static SquareConnectionSession CreateSession(
        FakeBluetoothGattClient bluetoothClient,
        Action<string>? logInfo = null,
        Action<string>? logError = null)
    {
        return new SquareConnectionSession(
            bluetoothClient,
            SquareConnectionOptions.Default with
            {
                ConnectionClubDelay = TimeSpan.Zero,
                ConnectionReadyDelay = TimeSpan.Zero,
                HeartbeatInterval = Timeout.InfiniteTimeSpan
            },
            static (delay, cancellationToken) => Task.CompletedTask,
            logInfo,
            logError);
    }

    private static byte[] CreateShotPacket()
    {
        var packet = new byte[17];
        packet[0] = 0x11;
        packet[1] = 0x02;
        packet[2] = 0x37;
        WriteScaled(packet.AsSpan(3, 2), 44.70f);
        WriteScaled(packet.AsSpan(5, 2), 12.50f);
        WriteScaled(packet.AsSpan(7, 2), -2.25f);
        BinaryPrimitives.WriteInt16LittleEndian(packet.AsSpan(9, 2), 3200);
        WriteScaled(packet.AsSpan(11, 2), 8.50f);
        BinaryPrimitives.WriteInt16LittleEndian(packet.AsSpan(13, 2), 3150);
        BinaryPrimitives.WriteInt16LittleEndian(packet.AsSpan(15, 2), -470);
        return packet;
    }

    private static byte[] CreateSensorPacket()
    {
        var packet = new byte[17];
        packet[0] = 0x11;
        packet[1] = 0x01;
        packet[3] = 0x01;
        packet[4] = 0x01;
        return packet;
    }

    private static void WriteScaled(Span<byte> target, float value)
    {
        BinaryPrimitives.WriteInt16LittleEndian(target, checked((short)MathF.Round(value * 100.0f)));
    }

    private static void AssertWrite(BluetoothWrite write, Guid characteristicUuid, byte[] value)
    {
        Assert.That(write.CharacteristicUuid, Is.EqualTo(characteristicUuid));
        CollectionAssert.AreEqual(value, write.Value);
    }

    private static async Task WaitUntilAsync(Func<bool> condition)
    {
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(2));
        while (!condition())
        {
            if (timeout.IsCancellationRequested)
            {
                Assert.Fail("Timed out waiting for the expected session event.");
            }

            await Task.Delay(10);
        }
    }

    private sealed record BluetoothWrite(Guid CharacteristicUuid, byte[] Value, BluetoothWriteMode WriteMode);

    private sealed class FakeBluetoothGattClient : IBluetoothGattClient
    {
        public List<BluetoothWrite> Writes { get; } = [];

        public Dictionary<Guid, byte[]> ReadValues { get; } = [];

        public List<Guid> SubscribedCharacteristicUuids { get; } = [];

        public string? ConnectedDeviceId { get; private set; }

        public BluetoothScanOptions? ScanOptions { get; private set; }

        public BluetoothConnectionOptions? ConnectionOptions { get; private set; }

        public Exception? ConnectException { get; set; }

        public event Action<BluetoothDevice>? DeviceDiscovered;

        public event Action<BluetoothCharacteristicValue>? CharacteristicValueChanged;

        public Task StartScanAsync(BluetoothScanOptions options, CancellationToken cancellationToken)
        {
            ScanOptions = options;
            DeviceDiscovered?.Invoke(new BluetoothDevice("square-device", "SquareGolf Test", -40));
            return Task.CompletedTask;
        }

        public Task StopScanAsync(CancellationToken cancellationToken)
        {
            return Task.CompletedTask;
        }

        public Task ConnectAsync(string deviceId, BluetoothConnectionOptions options, CancellationToken cancellationToken)
        {
            if (ConnectException is not null)
            {
                throw ConnectException;
            }

            ConnectedDeviceId = deviceId;
            ConnectionOptions = options;
            return Task.CompletedTask;
        }

        public Task DisconnectAsync(CancellationToken cancellationToken)
        {
            ConnectedDeviceId = null;
            return Task.CompletedTask;
        }

        public Task<byte[]> ReadCharacteristicAsync(Guid characteristicUuid, CancellationToken cancellationToken)
        {
            return Task.FromResult(ReadValues.GetValueOrDefault(characteristicUuid, []));
        }

        public Task SubscribeToCharacteristicAsync(Guid characteristicUuid, CancellationToken cancellationToken)
        {
            SubscribedCharacteristicUuids.Add(characteristicUuid);
            return Task.CompletedTask;
        }

        public Task WriteCharacteristicAsync(
            Guid characteristicUuid,
            byte[] value,
            BluetoothWriteMode writeMode,
            CancellationToken cancellationToken)
        {
            Writes.Add(new BluetoothWrite(characteristicUuid, value, writeMode));
            return Task.CompletedTask;
        }

        public void EmitCharacteristic(Guid characteristicUuid, byte[] value)
        {
            CharacteristicValueChanged?.Invoke(new BluetoothCharacteristicValue(characteristicUuid, value));
        }

        public ValueTask DisposeAsync()
        {
            return ValueTask.CompletedTask;
        }
    }
}
