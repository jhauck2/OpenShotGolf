using System;
using System.Collections.Generic;
using NUnit.Framework;
using OpenShotGolf.LaunchMonitors.Bluetooth;
using OpenShotGolf.LaunchMonitors.Bluetooth.Linux;

namespace OpenShotGolf.Tests.LaunchMonitors.Bluetooth.Linux;

[TestFixture]
public sealed class BlueZMapperTests
{
    [Test]
    public void TryCreateDeviceReadsNameAndRssi()
    {
        var interfaces = new Dictionary<string, IDictionary<string, object>>
        {
            [BlueZMapper.DeviceInterface] = new Dictionary<string, object>
            {
                ["Name"] = "SquareGolf LM",
                ["RSSI"] = (short)-61
            }
        };

        var matched = BlueZMapper.TryCreateDevice(
            "/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF",
            interfaces,
            "SquareGolf",
            out var device);

        Assert.That(matched, Is.True);
        Assert.That(device.DeviceId, Is.EqualTo("/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF"));
        Assert.That(device.Name, Is.EqualTo("SquareGolf LM"));
        Assert.That(device.Rssi, Is.EqualTo(-61));
    }

    [Test]
    public void TryCreateDeviceRejectsOtherNames()
    {
        var interfaces = new Dictionary<string, IDictionary<string, object>>
        {
            [BlueZMapper.DeviceInterface] = new Dictionary<string, object>
            {
                ["Name"] = "Other Device"
            }
        };

        var matched = BlueZMapper.TryCreateDevice(
            "/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF",
            interfaces,
            "SquareGolf",
            out _);

        Assert.That(matched, Is.False);
    }

    [Test]
    public void FindCharacteristicPathMatchesUuidBelowDevice()
    {
        var targetUuid = Guid.Parse("86602102-6b7e-439a-bdd1-489a3213e9bb");
        var managedObjects = new Dictionary<string, IDictionary<string, IDictionary<string, object>>>
        {
            ["/org/bluez/hci0/dev_AA_BB/service000c/char0012"] = new Dictionary<string, IDictionary<string, object>>
            {
                [BlueZMapper.GattCharacteristicInterface] = new Dictionary<string, object>
                {
                    ["UUID"] = targetUuid.ToString()
                }
            },
            ["/org/bluez/hci0/dev_CC_DD/service000c/char0012"] = new Dictionary<string, IDictionary<string, object>>
            {
                [BlueZMapper.GattCharacteristicInterface] = new Dictionary<string, object>
                {
                    ["UUID"] = targetUuid.ToString()
                }
            }
        };

        var path = BlueZMapper.FindCharacteristicPath(managedObjects, "/org/bluez/hci0/dev_AA_BB", targetUuid);

        Assert.That(path, Is.EqualTo("/org/bluez/hci0/dev_AA_BB/service000c/char0012"));
    }

    [Test]
    public void TryFindDevicePathMatchesBluetoothAddress()
    {
        var managedObjects = new Dictionary<string, IDictionary<string, IDictionary<string, object>>>
        {
            ["/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF"] = new Dictionary<string, IDictionary<string, object>>
            {
                [BlueZMapper.DeviceInterface] = new Dictionary<string, object>
                {
                    ["Address"] = "AA:BB:CC:DD:EE:FF"
                }
            }
        };

        var matched = BlueZMapper.TryFindDevicePath(managedObjects, "AA-BB-CC-DD-EE-FF", out var path);

        Assert.That(matched, Is.True);
        Assert.That(path, Is.EqualTo("/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF"));
    }

    [Test]
    public void TryFindDevicePathAcceptsKnownBlueZDevicePath()
    {
        var managedObjects = new Dictionary<string, IDictionary<string, IDictionary<string, object>>>
        {
            ["/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF"] = new Dictionary<string, IDictionary<string, object>>
            {
                [BlueZMapper.DeviceInterface] = new Dictionary<string, object>()
            }
        };

        var matched = BlueZMapper.TryFindDevicePath(
            managedObjects,
            "/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF",
            out var path);

        Assert.That(matched, Is.True);
        Assert.That(path, Is.EqualTo("/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF"));
    }

    [Test]
    public void TryFindDevicePathRejectsUnknownBlueZDevicePath()
    {
        var managedObjects = new Dictionary<string, IDictionary<string, IDictionary<string, object>>>();

        var matched = BlueZMapper.TryFindDevicePath(
            managedObjects,
            "/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF",
            out var path);

        Assert.That(matched, Is.False);
        Assert.That(path, Is.Empty);
    }

    [Test]
    public void TryFindDevicePathMatchesAddressFromBlueZDevicePath()
    {
        var managedObjects = new Dictionary<string, IDictionary<string, IDictionary<string, object>>>
        {
            ["/org/bluez/hci1/dev_AA_BB_CC_DD_EE_FF"] = new Dictionary<string, IDictionary<string, object>>
            {
                [BlueZMapper.DeviceInterface] = new Dictionary<string, object>
                {
                    ["Address"] = "AA:BB:CC:DD:EE:FF"
                }
            }
        };

        var matched = BlueZMapper.TryFindDevicePath(
            managedObjects,
            "/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF",
            out var path);

        Assert.That(matched, Is.True);
        Assert.That(path, Is.EqualTo("/org/bluez/hci1/dev_AA_BB_CC_DD_EE_FF"));
    }

    [Test]
    public void BlueZOptionsUseLeDiscoveryAndWriteRequest()
    {
        var discoveryOptions = BlueZMapper.CreateDiscoveryFilter("SquareGolf");
        var writeOptions = BlueZMapper.CreateWriteOptions(BluetoothWriteMode.WithResponse);
        var writeWithoutResponseOptions = BlueZMapper.CreateWriteOptions(BluetoothWriteMode.WithoutResponse);

        Assert.That(discoveryOptions["Transport"], Is.EqualTo("le"));
        Assert.That(discoveryOptions["Pattern"], Is.EqualTo("SquareGolf"));
        Assert.That(writeOptions["type"], Is.EqualTo("request"));
        Assert.That(writeWithoutResponseOptions["type"], Is.EqualTo("command"));
    }

    [TestCase("org.bluez.Error.Failed", "le-connection-abort-by-local", true)]
    [TestCase("org.bluez.Error.InProgress", "Operation already in progress", true)]
    [TestCase("org.bluez.Error.Failed", "Authentication failed", false)]
    [TestCase("org.bluez.Error.NotReady", "Adapter is not ready", false)]
    public void IsTransientConnectFailureMatchesExpectedBlueZFailures(
        string errorName,
        string errorMessage,
        bool expected)
    {
        var matched = BlueZMapper.IsTransientConnectFailure(errorName, errorMessage);

        Assert.That(matched, Is.EqualTo(expected));
    }
}
