# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OpenShotGolf (OSG) is an open-source golf simulator built with Godot Engine 4.5+. It simulates realistic golf ball physics using aerodynamic models, surface physics, and environmental factors. The project is designed to work with GSPro-compatible launch monitors, particularly PiTrac.

## Build and Run Commands

### Running the Project
```bash
# Run from Godot editor (F5) or via command line
godot --path .
```

### First-Time Setup
When opening the project for the first time, Godot may show import errors for add-ons. Simply close and re-open the editor to resolve.

### Testing TCP Functionality
```bash
# Use the Python socket test script to simulate launch monitor data
python Resources/SocketTest/SocketTest.py
```
This sends sample shot data from `assets/data/drive_test_shot.json` to port 49152.

### Keyboard Controls for Testing
- `h`: Simulate a hit with built-in sample data
- `r`: Reset ball and clear shot trail

## Architecture Overview

### Core Systems

#### 1. Signal-Based Event System
The project uses a centralized event bus pattern:
- **EventBus** (`Utils/EventBus.gd`): Singleton autoload for cross-scene communication
- **SceneManager** (`Utils/SceneManager.gd`): Handles scene transitions

#### 2. Physics Pipeline
The physics system is split across multiple modules:

**Ball State Machine** (`Player/ball.gd` - `GolfBall` class):
- Three states: `REST`, `FLIGHT`, `ROLLOUT`
- Manages state transitions and collision detection
- Handles shot data parsing from launch monitor

**Pure Physics Calculations** (`physics/ball_physics.gd` - `BallPhysics` class):
- Static methods for force/torque calculations
- Separated from game object logic for testability
- Contains bounce physics using Penner's oblique impact model

**Aerodynamics** (`physics/aerodynamics.gd` - `Aerodynamics` class):
- Reynolds number-dependent drag coefficients (Cd)
- Spin ratio-dependent lift coefficients (Cl)
- Air density and viscosity calculations based on temperature/altitude

**Surface Physics** (`physics/surface.gd` - `Surface` class):
- Four surface presets: ROUGH, FAIRWAY, FAIRWAY_SOFT, FIRM
- Each preset defines kinetic friction, rolling friction, grass drag, and critical angle

#### 3. Settings System
Global settings managed through a signal-based system:
- **GlobalSettings** (`Utils/Settings/global_settings.gd`): Singleton autoload
- **RangeSettings** (`Utils/Settings/range_settings.gd`): Typed settings for range environment
- **Setting** class (`Utils/Settings/setting.gd`): Individual setting with change signals
- Settings automatically propagate to ball physics via signal connections

#### 4. TCP Server for Launch Monitor Data
**TcpServer** (`TCP/tcp_server.gd`):
- Listens on port 49152 for GSPro-style JSON payloads
- Emits `hit_ball` signal when valid shot data received
- Responds with HTTP-style status codes (200 for success, 50x for errors)

#### 5. Player/Ball Management
**Player** (`Player/player.gd`):
- Contains and manages GolfBall instance
- Tracks shot metrics (carry, apex, side distance, total distance)
- Manages shot tracers (visual trails) with configurable count
- Connects TCP server and UI to ball physics

### Data Flow
```
Launch Monitor → TCP Server (port 49152) → Player → GolfBall → BallPhysics
                     ↓
                hit_ball signal
                     ↓
              Ball state machine (hit_from_data)
                     ↓
         Physics calculations (_physics_process)
                     ↓
            Forces/Torques → Velocity/Omega updates
                     ↓
              move_and_collide()
                     ↓
         Collision handling → Bounce calculations
                     ↓
           State transitions (FLIGHT → ROLLOUT → REST)
                     ↓
                rest signal
                     ↓
          UI updates with final metrics
```

### Shot Data Format
The project expects GSPro-compatible JSON payloads. See `assets/data/*.json` for examples. Key fields:
- `BallData.Speed`: Ball speed in mph
- `BallData.VLA`: Vertical launch angle (degrees)
- `BallData.HLA`: Horizontal launch angle (degrees)
- `BallData.TotalSpin`: Total spin (rpm)
- `BallData.SpinAxis`: Spin axis angle (degrees)

Alternatively, BackSpin/SideSpin can be provided instead of TotalSpin/SpinAxis.

## Critical Implementation Details

### Physics Constants Location
- Ball properties (mass, radius): `physics/ball_physics.gd`
- Aerodynamic models: `physics/aerodynamics.gd`
- Surface parameters: `physics/surface.gd`

### Distance Calculation
Distance is measured as **downrange distance** (along initial shot direction), not straight-line 2D distance:
```gdscript
var delta: Vector3 = position - shot_start_pos
var meters: float = delta.dot(shot_dir)  # shot_dir is normalized horizontal direction
```
This accounts for curved shots (sidespin) and matches GSPro conventions.

### Unit Conversions
The physics engine uses SI units internally (m, m/s, rad/s, kg). Conversions happen at:
- **Input**: Launch monitor data (mph → m/s, rpm → rad/s, degrees → radians)
- **Output**: UI display (meters → yards)

Conversion constants in `physics/README.md`.

### State Transitions
- `REST → FLIGHT`: On `hit_from_data()` call
- `FLIGHT → ROLLOUT`: First ground collision from flight state
- `ROLLOUT → REST`: Velocity < 0.1 m/s

### Ball Types
Two ball types are implemented via multipliers:
- `STANDARD`: baseline aerodynamics (drag_mult=1.0, lift_mult=1.0)
- `PREMIUM`: lower drag, more lift (drag_mult=0.9, lift_mult=1.1)

Ball type is instantiated in `Player.gd` and can be changed via settings.

## Godot-Specific Conventions

### Autoloads (Singletons)
Defined in `project.godot`:
- `PhantomCameraManager`: Camera system addon
- `SceneManager`: Scene transitions
- `EventBus`: Global event system
- `GlobalSettings`: Centralized settings

Access these anywhere: `GlobalSettings.range_settings.temperature.value`

### Scene Structure
- `.tscn` files are Godot scenes (XML-based scene trees)
- `.gd` files are GDScript code attached to nodes
- Main scene: defined by `run/main_scene` in `project.godot`

### Class Names
Use `class_name` to make scripts globally available:
```gdscript
class_name GolfBall
extends CharacterBody3D
```

### Signals
Godot's built-in observer pattern. Define and emit:
```gdscript
signal rest
# ...
emit_signal("rest")
```
Connect in parent:
```gdscript
ball.rest.connect(_on_ball_rest)
```

## Plugin Dependencies

The project uses several Godot add-ons located in `addons/`:
- **phantom_camera**: Advanced camera system for follow/tracking
- **terrain_3d**: 3D terrain rendering and editing
- **sky_3d**: Dynamic sky and time-of-day system
- **godot-sqlite**: SQLite database support (likely for session recording)

## Testing and Validation

### Manual Testing
1. Use keyboard shortcut `h` to trigger built-in test shot
2. Use Python script `Resources/SocketTest/SocketTest.py` to simulate launch monitor
3. Use shot injector UI (enable via range settings) to manually input shot parameters

### Test Data Files
Sample shots in `assets/data/`:
- `drive_test_shot.json`: Driver shot (~147 mph)
- `approach_test_shot.json`: Iron approach
- `wedge_test_shot.json`: Short wedge
- `wood_low_test_shot.json`: Low trajectory wood
- `bump_test_shot.json`: Bump-and-run chip

### Physics Validation
Compare against GSPro shots using real launch monitor data. Key metrics to verify:
- Carry distance (horizontal distance when ball lands)
- Apex height (maximum height)
- Total distance (carry + rollout)
- Offline distance (side deviation)

### Reynolds Number Analysis
Use `assets/scripts/reynolds_calculator.py` to validate aerodynamic regime assignments for different shot speeds.

## Important Files to Understand

When modifying physics:
- `Player/ball.gd`: Ball state machine and collision handling
- `physics/ball_physics.gd`: Force/torque/bounce calculations
- `physics/aerodynamics.gd`: Cd/Cl coefficient models
- `physics/surface.gd`: Ground interaction parameters

When modifying UI/settings:
- `Utils/Settings/range_settings.gd`: Available settings
- `UI/range_ui.gd`: Main range HUD

When debugging shot data:
- `TCP/tcp_server.gd`: Launch monitor data reception
- `Player/player.gd`: Shot data validation and tracer management

When working on camera behavior:
- The project uses the PhantomCamera add-on (external dependency)
- Camera follows ball based on `camera_follow_mode` setting

## Common Pitfalls

### Physics Modifications
- Never modify ball constants (mass, radius) without understanding impact on ALL physics calculations
- Aerodynamic coefficients are empirically fitted to wind tunnel data - changes should be validated
- Surface friction parameters are tuned against GSPro - changes will affect rollout significantly
- Spin decay tau (3.0s) is artificially low to compensate for lift model - don't increase without adjusting lift

### Distance Calculations
- Always use `get_downrange_yards()` for shot distance, not direct position magnitude
- Distance is calculated along `shot_dir` (2D horizontal direction at launch)
- Carry distance should only be updated while in FLIGHT state

### Settings System
- Always connect to setting signals (`setting_changed`) to react to changes
- Don't modify `GlobalSettings` values directly - use the Setting class interface
- Settings are not persisted to disk automatically (future work)

### Signal Timing
- Use `call_deferred()` when calling physics methods from UI/input to avoid mid-frame updates
- Ball reset/hit should be deferred to next physics frame

## Project Status and Future Work

### Current Limitations
- No wind simulation
- Flat terrain assumption (bounce physics assume flat ground)
- No humidity effects on air density
- Spin decay model doesn't match physical reality (compensates for lift model)

### Planned Refactoring (per physics/README.md)
- Move remaining physics code from `Player/` to `physics/` folder
- Add wind effects
- Implement variable terrain slopes
- Support multiple ball profiles (different manufacturer models)

## References

Physics documentation: `physics/README.md`
Main project README: `README.md`
GSPro disclaimer: `DISCLAIMER.md`
