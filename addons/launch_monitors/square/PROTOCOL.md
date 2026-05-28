# Square Launch Monitor — BLE Protocol Notes

This document maps what the Square BLE protocol looks like as implemented in this
folder, and records how that mapping was (most plausibly) derived. The Square
protocol is not publicly documented by the vendor; everything here was learned by
observing the device's BLE traffic alongside the official client.

> **Provenance.** The protocol map in Section A is sourced directly from the code
> in this folder — it is verifiable against the files cited inline. The process
> notes in Section B are *reconstructed from code patterns*, not from a recorded
> reverse-engineering session. If something disagrees with the source files, the
> source files win.

---

## Section A — Protocol map (reference)

### A.1 Transport

- BLE GATT, accessed through `LaunchMonitors.Common.Bluetooth.IBluetoothGattClient`
  (`addons/launch_monitors/common/bluetooth/`). The factory picks the per-OS
  implementation:
  - Linux → BlueZ via D-Bus (`Tmds.DBus`).
  - Windows → `Windows.Devices.Bluetooth` (WinRT), loaded reflectively and only
    compiled on Windows builds (see `OpenShotGolf.csproj`).
- Device discovery is name-prefix filtered. The vendor's advertising name starts
  with `SquareGolf` (see `SquareConnectionOptions.Default`).
- Four characteristics are used. The canonical UUIDs are in
  `SquareConnectionOptions.cs`:
  - **Command** — write (`WithResponse`). Outbound frames.
  - **Event** — notify. Inbound sensor + shot frames.
  - **Battery** — standard `0x2A19`. Read + notify.
  - **Firmware** — read. Returns either a raw string or a JSON object with an
    `"lm"` field (see `SquareConnectionSession.ParseFirmware`).

### A.2 Connection handshake

Implemented in `SquareConnectionSession.ConnectToDeviceAsync`
(`SquareConnectionSession.cs:73-120`). Order matters; the delays are not
cosmetic:

1. Connect via the GATT client.
2. Read battery + firmware.
3. Subscribe to **Event** (required) and **Battery** (best-effort) notifications.
4. Write `Heartbeat`.
5. Wait `ConnectionClubDelay` (default **2 s**).
6. Write `Club` with the currently selected club code + handedness.
7. Wait `ConnectionReadyDelay` (default **3 s**).
8. Write `DetectBall(mode=1, spinMode=1)` — the "ready to detect a shot" trigger.
9. Start a heartbeat timer (default **every 5 s**) — periodic `Heartbeat` writes.

After every parsed shot, the session waits `ConnectionReadyDelay` and re-issues
`DetectBall` to arm the next shot (`SquareConnectionSession.cs:295-322`).

### A.3 Outbound command frames

From `SquareCommandBuilder.cs`. `{seq}` is a wrapping byte that increments per
command (`SquareConnectionSession.NextSequence`). Frame lengths are fixed per
command (Heartbeat = 8 bytes, DetectBall and Club = 9 bytes).

| Command     | Bytes (hex)                                  | Source                         |
| ----------- | -------------------------------------------- | ------------------------------ |
| Heartbeat   | `11 83 {seq} 00 00 00 00 00`                 | `SquareCommandBuilder.cs:10`   |
| DetectBall  | `11 81 {seq} 0{mode} 1{spinMode} 00 00 00 00`| `SquareCommandBuilder.cs:15`   |
| Club        | `11 82 {seq} {clubCode_2B} 0{handedness} 00 00 00` | `SquareCommandBuilder.cs:20` |

- `mode` and `spinMode` are single hex digits packed into the upper nibble of
  bytes 3 and 4 — the code path that uses them only ever sends `mode=1,
  spinMode=1` (`SquareConnectionSession.SetReadyAsync`).
- `handedness`: `0` = right-handed, `1` = left-handed (`SetHandedness` coerces
  any other value to `0`).
- `clubCode` is two bytes from the club catalog — see A.5.

### A.4 Inbound frames

From `SquareProtocol.cs`. Both known frame types are ≥17 bytes and start with
`0x11`. The second byte discriminates.

#### Sensor frame — `0x11 0x01 …`

`SquareProtocol.TryParseSensor` (`SquareProtocol.cs:18-34`):

| Offset | Width  | Field                                |
| ------ | ------ | ------------------------------------ |
| 0      | 1      | `0x11` (frame marker)                |
| 1      | 1      | `0x01` (sensor discriminator)        |
| 3      | 1      | `BallReady`: true if value ∈ {0x01, 0x02} |
| 4      | 1      | `BallDetected`: true if value == 0x01     |
| 5      | 4      | `PositionX` (Int32 LE)               |
| 9      | 4      | `PositionY` (Int32 LE)               |
| 13     | 4      | `PositionZ` (Int32 LE)               |

The session converts `BallReady && BallDetected` into the `ReadyChanged(true)`
signal (`SquareConnectionSession.HandleNotificationAsync`). Position bytes are
parsed but currently unused downstream.

#### Shot frame — `0x11 0x02 …`

`SquareProtocol.TryParseShot` (`SquareProtocol.cs:36-62`):

| Offset | Width | Field            | Decode                  |
| ------ | ----- | ---------------- | ----------------------- |
| 0      | 1     | `0x11`           | frame marker            |
| 1      | 1     | `0x02`           | shot discriminator      |
| 2      | 1     | shot type        | `0x37` = full, `0x13` = putt, else `"unknown"` |
| 3      | 2     | ball speed       | Int16 LE ÷ 100 → m/s    |
| 5      | 2     | vertical angle   | Int16 LE ÷ 100 → degrees|
| 7      | 2     | horizontal angle | Int16 LE ÷ 100 → degrees|
| 9      | 2     | total spin       | Int16 LE → rpm          |
| 11     | 2     | spin axis        | Int16 LE ÷ **−100** → degrees (sign flipped) |
| 13     | 2     | back spin        | Int16 LE → rpm          |
| 15     | 2     | side spin        | Int16 LE → rpm          |

Byte 2 (shot type) is **opaque metadata** on the Home device; the `0x37`/`0x13`
mapping is consistent with observed full-swing/putt frames but `ShotType` is
informational only (no downstream consumer).

The spin-axis sign flip is the only field with a negative scale factor — it
exists because the vendor encodes positive-clockwise while OSG/GSPro expect the
opposite convention.

**Invalid-reading sentinel.** Any field the device could not measure this shot is
sent as `0x8000` (`−32768`). `SquareProtocol` maps that to "no reading" (value 0 +
an internal validity flag) rather than passing it through. Without this, an
unmeasured spin leaked through as a huge negative value, and an unmeasured
speed / total spin / vertical angle would fail the plausibility filter below and
**drop the entire shot**.

Frames that parse but fail the plausibility filter
(`SquareProtocol.IsPlausible`, `SquareProtocol.cs:64-71`) are dropped: ball
speed in (0, 250) m/s, total spin in [0, 30000) rpm, vertical angle ≥ 0. This
filter is a guard against partially-understood frames; it is not a documented
vendor constraint.

Duplicate shot frames (identical payload to the previous one) are suppressed in
`SquareConnectionSession.HandleNotificationAsync`.

### A.5 Club codes

From `square_club_catalog.gd`. Two bytes per club, written into bytes 4–5
of the `Club` command (so the on-wire order is `{first_byte}{second_byte}`).
These mirror the `RegularCode` values in the `squaregolf-connector` reference
project.

| Club    | Code   | Byte 1 (id) | Byte 2 (family) |
| ------- | ------ | ----------- | --------------- |
| Driver  | `0204` | `02`        | `04` (driver)   |
| 3 Wood  | `0305` | `03`        | `05` (fwy wood) |
| 5 Wood  | `0505` | `05`        | `05`            |
| 7 Wood  | `0705` | `07`        | `05`            |
| 4 Iron  | `0406` | `04`        | `06` (iron/wedge) |
| 5 Iron  | `0506` | `05`        | `06`            |
| 6 Iron  | `0606` | `06`        | `06`            |
| 7 Iron  | `0706` | `07`        | `06`            |
| 8 Iron  | `0806` | `08`        | `06`            |
| 9 Iron  | `0906` | `09`        | `06`            |
| PW      | `0a06` | `0a`        | `06`            |
| GW      | `0b06` | `0b`        | `06`            |
| SW      | `0c06` | `0c`        | `06`            |
| Putter  | `0107` | `01`        | `07` (putter)   |

The structural pattern is clear: the second byte clusters by club family, and
the first byte is the club number / position within the family. Default is
Driver (`0204`); `SquareCommandBuilder.DriverClubCode` and
`SquareClubCatalog.DEFAULT_CLUB_CODE` are the single sources of truth.

> **`0b06` is the Approach/Gap wedge (GW), not a lob wedge.** The Square hardware
> exposes no distinct lob-wedge code. This code was previously mislabeled "LW"
> in OSG and was corrected to "GW" to match the reference project.

**Alignment stick** — code `0008` (`SquareClubCatalog.ALIGNMENT_STICK_CODE`). The
device treats this as a special "club" used to enter alignment mode rather than a
normal shot club, so it is kept out of the selectable `CLUBS` table. The alignment
flow that consumes it is not yet implemented in OSG (planned).

### A.6 Downstream mapping

`SquareShotDataMapper.ToOsgBallData` (`SquareShotDataMapper.cs`) converts a
parsed `SquareShotMetrics` into the OSG/GSPro ball-data dictionary:

- Speed: m/s → mph (× 2.23694).
- VLA / HLA / SpinAxis pass through.
- TotalSpin is floored at 0.

Back/side-spin **decomposition** lives in `SquareProtocol.TryParseShot`, not the
mapper: when total spin and spin axis are valid but a spin component was not
measured (its sentinel was seen), the parser derives it from `TotalSpin` and
`SpinAxis` (degrees → radians, cos/sin decomposition). This handles
devices/firmwares that emit only total spin + axis without the per-axis split.
The mapper is intentionally thin.

---

## Section B — How this was (probably) derived

> Reconstructed from code shape, not from a logged session.

### B.1 Tooling that matches the evidence

The codebase abstracts at the GATT layer, not raw HCI — that rules out
Wireshark-only HCI sniffing as the *primary* tool and points at one of:

- BlueZ `btmon` on Linux, or
- The Windows Bluetooth BTSnoop log (`btsnoop_hci.log` via the WinRT BLE logs),
  parsed in Wireshark, or
- The **nRF Connect** mobile app, which enumerates services / characteristics
  and lets you write/notify-subscribe manually, or
- A vendor-app capture on Android via the developer-options "enable Bluetooth
  HCI snoop log" toggle.

Any of these gives you the same view: GATT services, characteristic UUIDs,
notification payloads, and command payloads as the vendor app sends them.

### B.2 Sniff-and-replay workflow (the likely path)

1. **Pair the Square with the vendor app while capturing.** Walk through a
   normal session — connect, pick a club, hit a few balls — so the capture
   contains the full lifecycle.
2. **Enumerate GATT services.** Identify which characteristic the vendor app
   *writes to* (→ command), which it *subscribes to for notifications*
   (→ event), and which is the standard `0x2A19` battery service.
3. **Replay the connect sequence.** The vendor app's writes during connect
   reveal the order and the inter-write delays. The codebase pins these as
   `ConnectionClubDelay = 2s` and `ConnectionReadyDelay = 3s` — both are
   round-number safety margins, the signature of "this delay made it work
   reliably."
4. **Derive the club table.** Cycle through clubs in the vendor app. Each club
   change produces one `11 82 {seq} {XX YY} {handedness} …` write. Recording
   one row per club gives you `square_club_catalog.gd`. Family clustering in
   the second byte is something you only see *after* you've tabulated, but
   it's a useful sanity check that no rows are mis-transcribed.
5. **Label notification frames by triggering known events.** Place a ball →
   sensor frame fires. Remove the ball → another sensor frame. Hit a full
   swing → shot frame. Putt → shot frame with a different byte 2. That's where
   `0x11 0x01` vs `0x11 0x02` and `0x37` vs `0x13` come from.
6. **Derive scale factors empirically.** Take a shot with a known ball speed
   (e.g., a slow controlled chip, or compared against another monitor). Bisect
   the 2-byte little-endian slices of the shot frame until one of them, when
   divided by 100, matches the expected m/s. Do the same for spin and angles.
   The `÷ -100` on spin axis is the moment you realise the vendor uses the
   opposite sign convention from GSPro/OSG.
7. **Gate with a plausibility filter.** While the byte map is still
   incomplete, frames that "almost parse" can leak garbage values into
   gameplay. `IsPlausible` is the temporary fence that lets you keep moving
   without wiring every unknown field — it's deliberately conservative.

### B.3 Why this matches the code

A protocol that was *given to you* by the vendor would not have:

- A `÷ -100` field sitting next to six `÷ 100` fields (sign conventions get
  fixed at the spec, not the parser).
- Round-number `2 s` / `3 s` startup delays (a spec would give you a real
  handshake or a ready notification — these delays exist because empirically
  *3 seconds was enough and 2 seconds wasn't*).
- A plausibility filter as the gate between parser and gameplay.
- A two-byte club code with a discoverable family/id structure rather than a
  numeric enum.

All four are signatures of *replayed-and-trimmed vendor traffic*.

### B.4 Playbook for the next launch monitor

Same steps will work for any vendor BLE launch monitor:

1. Capture vendor-app traffic on Windows or Linux (BTSnoop / `btmon`).
2. Identify GATT roles: command (write), event (notify), battery, firmware.
3. Replay the connect handshake from the capture. Pin any required delays.
4. Cycle through configuration UI (club, handedness, mode) and tabulate the
   resulting writes.
5. Trigger known shot events; bisect-decode notification payloads to find
   field offsets and scale factors.
6. Gate the parser with a plausibility filter until the byte map is complete.
7. Add a new folder under `addons/launch_monitors/<monitor>/` and depend on
   `LaunchMonitors.Common.Bluetooth.IBluetoothGattClient` for the transport
   (see `../README.md` for the addon contract).
