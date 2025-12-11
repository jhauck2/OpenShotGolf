# Open Shot Golf Simulator
![img missing](https://github.com/jhauck2/OpenShotGolf/blob/main/Screenshots/Screenshot_20250715_152214.png)

## Table of Contents
- [Overview](#overview)
- [Current State](#current-state)
- [Feature Highlights](#feature-highlights)
- [Ball Physics and Distance Calculation](#ball-physics-and-distance-calculation)
- [Surface and Rollout Tuning](#surface-and-rollout-tuning)
- [Launch Monitor and Networking](#launch-monitor-and-networking)
- [Data Sequence Diagram](#data-sequence-diagram)
- [Sample Data Payload](#sample-data-payload)
- [Build and Run](#build-and-run)
- [Controls](#controls)
- [Project Layout](#project-layout)
- [Future Plans](#future-plans)

## Overview
Open Shot Golf (formerly JaySimG) is an open source golf simulator built with the Godot Engine. It is designed to work out of the box with the PiTrac Launch Monitor and any GSPro-style interface that sends ball data to the configured port. PiTrac project: https://github.com/jamespilgrim/PiTrac

## Current State
- **Launch monitor support:** Officially tested with PiTrac; other GSPro interfaces should work when pointed at the correct port.
- **Game modes:** Driving range with data readouts, club selection, and range session recording.
- **Platforms:** Linux and Windows confirmed; macOS is untested but expected to work.

## Feature Highlights
- GSPro-compatible TCP listener for incoming ball/club data.
- Physics based ball flight with drag, lift (Magnus), grass drag, and friction modeling.
- On-range telemetry: carry, total, apex, offline, and shot trails.
- Environment tuning for temperature and altitude, impacting air density and flight.
- Range session recorder and basic UI for club selection and shot playback.

## Ball Physics and Distance Calculation
- Ball flight is driven by `Player/ball.gd`. Forces include gravity, drag, Magnus lift, grass drag, and frictional torque for bounce and rollout.
- Spin, launch angle, and ball speed are applied in `hit_from_data`, and the ball transitions through FLIGHT, ROLLOUT, and REST states.
- Distance metrics come from `Player/player.gd`: horizontal distance is `Vector2(x, z).length()` in meters, converted to yards in range UI when needed (`Courses/Range/range.gd`). Carry, apex, and offline distances are tracked until the ball rests.

## Surface and Rollout Tuning
- Range settings expose a surface preset (Firm/Fairway/Rough) that maps to ground friction and grass drag parameters in `Player/ball.gd` (`u_k`, `u_kr`, `nu_g`), plus a `drag_scale` multiplier for coarse aerodynamic tuning.
- Firm uses lower friction/grass drag for faster rollout; Rough uses higher values to shorten rollout; Fairway sits between.
- These were limited tested with PiTrac hits with limited ball speeds between 40-80mph. Also compared and tested against what a player would expect on GSPro Practice session rollout (FIRM). These numbers are always subjected to weather (morning dew), slightly longer grass in rough vs shorter, etc. Overall, its a good starting point to give options. In the future the code leaves room to scale to sand, and different types of grass (e.g. FIRM_FESCUE vs FIRM_BERMUDA)
- Defaults are heuristic (tuned for believable rollout) and can be adjusted in the range settings UI. They are not direct measurements from a single study but informed by typical rolling/sliding friction ranges on turf and the drag curve below.
- References: 
  - USGA Green Speed Physics (Stimpmeter deceleration): https://www.waddengolfacademy.com/putting/USGA%20Green%20Speed%20Physics.pdf
  - Jenkins et al., “Drag Coefficients of Golf Balls,” World Journal of Mechanics 2018 (Cd vs Re): https://www.scirp.org/pdf/WJM_2018062515520887.pdf
  - USGA Stimpmeter Booklet (green speed measurement): https://www.usga.org/content/dam/usga/pdf/imported/StimpmeterBookletFINAL.pdf

## Launch Monitor and Networking
- A TCP server in `TCP/tcp_server.gd` listens on port `49152` for GSPro-style JSON payloads. When `ShotDataOptions.ContainsBallData` is true, ball data is emitted to the gameplay layer.
- Good data responses return `{ "Code": 200 }`; malformed data returns a 50x response. Adjust your launch monitor to target the host IP and port `49152`.
- Keyboard shortcuts remain available for local testing without hardware (see Controls).

## Data Sequence Diagram
![System Data Flow](assets/images/dataflow_ssd.png)

## Sample Data Payload
Example GSPro-style message used for socket testing (`assets/data/drive_test_shot.json`):

```json
{
    "DeviceID": "GSPro LM 1.1",
    "Units": "Yards",
    "ShotNumber": 13,
    "APIversion": "1",
    "BallData" : {
        "Speed": 147.5,
        "SpinAxis": -13.2,
        "TotalSpin": 3250.0,
        "BackSpin": 2500.0,
        "SideSpin": -800.0,
        "HLA": 2.3,
        "VLA": 14.3,
        "CarryDistance": 256.5
    },
    "ClubData": {
        "Speed": 0.0,
        "AngleOfAttack": 0.0,
        "FaceToTarget": 0.0,
        "Lie": 0.0,
        "Loft": 0.0,
        "Path": 0.0,
        "SpeedAtImpact": 0.0,
        "VerticalFaceImpact": 0.0,
        "HorizontalFaceImpact": 0.0,
        "ClosureRate": 0.0
    },
    "ShotDataOptions": {
        "ContainsBallData": true,
        "ContainsClubData": false,
        "LaunchMonitorIsReady": true,
        "LaunchMonitorBallDetected": true,
        "IsHeartBeat": false
    }
}
```

## Build and Run
### Install Godot
Download and install Godot 4.5 for your operating system: https://godotengine.org/download

### Clone Repository
- Clone repository into a local folder:  
  `git clone https://github.com/jhauck2/OpenShotGolf.git`

### Import Project
- Open Godot.
- In the Project Manager window, select **Import**.
- Navigate to the `OpenShotGolf` folder and select `project.godot`.

### Run
- Press the play button or `F5` to start the project.
- When opening the project for the first time, Godot errors may appear due to importing add-ons. Simply close and re-open. 
- Set your launch monitor to send data to port `49152`, or use the local hit/reset shortcuts below.
  - Python script `~/Resources/SocketTest/SocketTest.py` could be used to test TCP functionality (defaults to `assets/data/drive_test_shot.json`). 

## Controls
- `h`: Simulate a built-in hit with sample ball data.
- `r`: Reset the ball and clear the shot trail.

## Project Layout
- `Player/`: Ball physics, player controller, and shot metric tracking.
- `TCP/`: TCP server and GSPro-style JSON handling.
- `Courses/Range/`: Range scene, UI, and yardage output.
- `Resources/`, `UI/`, `Utils/`: Art assets, UI components, and helper scripts.

## Future Plans
- Full course play (currently in early design).
- Additional range features and recording improvements.
- Mobile (Android/iOS) builds once platform pipelines are tested.
