# Square Launch Monitor

BLE integration for the **Square Golf** launch monitor (Home device). Implemented
in C# behind the addon's common Bluetooth transport, exposed to GDScript as a
single Godot `Node` (`SquareLaunchMonitor`) that the autoload
`launch_monitor_manager.gd` drives.

> **Protocol reference:** see [`PROTOCOL.md`](PROTOCOL.md) for the full BLE
> protocol map — transport, handshake, command/notification frame layouts, club
> codes, and how the protocol was reverse-engineered.

## Scope

- Supports the Square **"Home"** device. The **Omni** variant is intentionally
  **not** supported.
- Targets both **Windows** (WinRT) and **Linux** (BlueZ/D-Bus) via the shared
  `common/bluetooth/` transport.

## Files

| File | Role |
| ---- | ---- |
| `SquareLaunchMonitor.cs` | Public Godot `Node`. Exposes `StartScan`/`ConnectToDevice`/`SetClub`/… and re-emits session events as Godot signals (`ShotReceived`, `ReadyChanged`, `StatusChanged`, …). |
| `SquareConnectionSession.cs` | Connection lifecycle + state machine: handshake, heartbeat, club/ready commands, notification routing, shot re-arm. |
| `SquareProtocol.cs` | Binary frame parser (`11 01` sensor, `11 02` shot) incl. invalid-reading sentinel handling and spin decomposition. |
| `SquareCommandBuilder.cs` | Builds outbound command byte frames (`Heartbeat`, `DetectBall`, `Club`). |
| `SquareConnectionOptions.cs` | UUIDs, device-name prefix, and connection/heartbeat timing constants. |
| `SquareShotMetrics.cs` | Parsed shot/sensor value records. |
| `SquareShotDataMapper.cs` | Maps `SquareShotMetrics` → OSG/GSPro ball-data dictionary (units + clamp). |
| `SquareGodotMapper.cs` | Wraps the mapper output into a Godot `Dictionary`. |
| `square_club_catalog.gd` | Club label → 2-byte Square code lookup (`SquareClubCatalog`). |
| [`PROTOCOL.md`](PROTOCOL.md) | Reverse-engineered BLE protocol notes. |

## Signal flow

```
Square device ──BLE──▶ IBluetoothGattClient ──▶ SquareConnectionSession
                                                       │ events
                                                       ▼
                          SquareLaunchMonitor (Godot Node, [Signal]s)
                                                       │
                                                       ▼
                       launch_monitor_manager.gd (re-emits hit_ball, etc.)
                                                       │
                                                       ▼
                                            gameplay (Range, Player)
```

`SquareLaunchMonitor` resolves the platform BLE client via
`BluetoothGattClientFactory.Create()` — see [`../README.md`](../README.md) for the
addon's transport contract and how to add a new monitor.

## Clubs

Club codes live in `square_club_catalog.gd` (`SquareClubCatalog`) and mirror the
`RegularCode` values of the `squaregolf-connector` reference project. The full
table is in [`PROTOCOL.md` §A.5](PROTOCOL.md). Notes:

- `0b06` is the **Approach/Gap wedge (GW)** — the hardware has no distinct lob
  wedge.
- The **alignment stick** (`0008`, `ALIGNMENT_STICK_CODE`) is a special mode
  trigger, not a selectable shot club; the alignment flow that uses it is not yet
  implemented.

## Building & testing

The integration is C#. Build with the project's C# solution
(`dotnet build OpenShotGolf.csproj`) or by opening the project in Godot.
`IBluetoothGattClient` is the seam to mock for unit tests; protocol parsing in
`SquareProtocol` is pure and unit-testable without hardware.
