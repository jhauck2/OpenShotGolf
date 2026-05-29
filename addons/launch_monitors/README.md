# addons/launch_monitors

Launch-monitor integrations for OpenShotGolf. Each monitor is a Godot `Node` that emits `hit_ball(Dictionary)` and related lifecycle signals; the autoload `launch_monitor_manager.gd` orchestrates connections and forwards shot data to the gameplay layer.

## Layout

```
addons/launch_monitors/
├── launch_monitor_manager.gd   # autoload (registered in project.godot)
├── square/                     # Square launch monitor (BLE)
│   ├── SquareLaunchMonitor.cs  # public Godot Node, signals + manager facade
│   ├── SquareConnectionSession.cs
│   ├── SquareProtocol.cs       # binary packet parser
│   ├── Square*.cs              # command builder, options, mappers
└── common/                     # shared plumbing — not launch monitors themselves
    ├── bluetooth/              # BLE GATT transport (LaunchMonitors.Common.Bluetooth)
    │   ├── IBluetoothGattClient.cs
    │   ├── BluetoothGattClientFactory.cs
    │   ├── linux/              # BlueZ over D-Bus (Tmds.DBus)
    │   └── windows/            # Windows.Devices.Bluetooth (compiled only on Windows builds)
    └── tcp_server/
        └── TcpServer.cs        # GSPro-protocol TCP listener (LaunchMonitors.Common.Tcp)
```

### Convention

- **`<monitor>/`** — one folder per physical launch monitor. Public Godot `Node` entrypoint plus implementation files.
- **`common/`** — shared plumbing used by monitors or by the gameplay layer to receive shots from external systems. **Not launch monitors themselves.**
  - `common/bluetooth/` — transport layer used by monitor implementations (currently only Square consumes it).
  - `common/tcp_server/` — inbound GSPro listener; receives shot data from *external* launch monitors over TCP, not a monitor itself.

## Pieces

### `launch_monitor_manager.gd` (autoload)

Registered in `project.godot` as `LaunchMonitorManager`. Owns the active monitor instance, exposes scan/connect APIs to UI, and re-emits the monitor's signals so gameplay code (Range, Player) doesn't need to know which monitor is connected.

### `square/`

`SquareLaunchMonitor` wraps `SquareConnectionSession`, which drives the BLE GATT lifecycle through `IBluetoothGattClient` (resolved at runtime by `BluetoothGattClientFactory`). Square is the only consumer of `common/bluetooth/` today.

### `common/bluetooth/`

Cross-platform BLE GATT abstraction. `BluetoothGattClientFactory.Create()` picks the platform implementation:

- **Linux** → `LinuxBluetoothGattClient` via BlueZ over D-Bus. Requires the BlueZ daemon to be running.
- **Windows** → `WindowsBluetoothGattClient` via WinRT (loaded reflectively; compiled only when `GodotTargetPlatform == windows`). The exclusion lives in `OpenShotGolf.csproj`.
- **Other** → `UnsupportedBluetoothGattClient` (throws on use).

`IBluetoothGattClient` is the seam unit tests mock against.

### `common/tcp_server/`

`TcpServer` is a Godot `Node` that listens on TCP port `49152` for GSPro-format JSON payloads and emits `hit_ball(Dictionary)`. It is attached to `Courses/Range/range.tscn` and `Courses/UserCourses/Airways/course.tscn`. This is how OpenShotGolf accepts shots from external monitors (PiTrac, MLM2Pro, etc.) over the network.

## Adding a new launch monitor

1. Create `addons/launch_monitors/<monitor>/` with a public Godot `Node` subclass that emits the same signals (`hit_ball`, `status_changed`, `error_occurred`, `battery_changed`, `firmware_changed`, `ready_changed`).
2. If the monitor uses BLE, depend on `LaunchMonitors.Common.Bluetooth.IBluetoothGattClient` (resolve via the factory). For other transports, add a sibling folder under `common/` (e.g. `common/serial/`) — don't put transports inside the monitor's folder.
3. Wire the monitor into `launch_monitor_manager.gd` so UI can select it.

## Adding a new transport under `common/`

Mirror the `bluetooth/` shape: an `I<Transport>Client.cs` interface, a `<Transport>ClientFactory.cs` that picks the platform impl, and per-platform subfolders (`linux/`, `windows/`, …) with the conditional-compile exclusion added to `OpenShotGolf.csproj` if needed. Namespace under `LaunchMonitors.Common.<Transport>`.
