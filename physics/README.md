# OpenShotGolf Physics Documentation

This document provides comprehensive documentation of all physics-related systems in OpenShotGolf. This folder is a placeholder for future physics code refactoring.

---

## Table of Contents

1. [Overview](#overview)
2. [File Locations](#file-locations)
3. [Ball Properties](#ball-properties)
4. [Flight Physics](#flight-physics)
   - [Forces During Flight](#forces-during-flight)
   - [Aerodynamic Coefficients](#aerodynamic-coefficients)
   - [Reynolds Number Regimes](#reynolds-number-regimes)
   - [Spin Decay](#spin-decay)
5. [Ground Physics](#ground-physics)
   - [Surface Types](#surface-types)
   - [Friction Model](#friction-model)
   - [Bounce Physics](#bounce-physics)
6. [Environmental Calculations](#environmental-calculations)
   - [Air Density](#air-density)
   - [Dynamic Viscosity](#dynamic-viscosity)
7. [Distance Measurement](#distance-measurement)
8. [Tunable Parameters](#tunable-parameters)
9. [Unit Conversions](#unit-conversions)
10. [References](#references)
11. [Future Work](#future-work)
12. See [GSPro Disclaimer](../DISCLAIMER.md).


---

## Overview

OpenShotGolf simulates golf ball physics using a combination of:
- **Derived formulas** from aerodynamics and mechanics literature
- **Empirically tuned parameters** calibrated against GSPro and real-world data
- **Polynomial interpolations** fitted to wind tunnel experimental data

The simulation handles three ball states:
- `FLIGHT` - Ball in air, subject to gravity, drag, and Magnus forces
- `ROLLOUT` - Ball on ground after first impact, subject to friction
- `REST` - Ball stopped

---

## File Locations

| File | Purpose |
|------|---------|
| `Player/ball.gd` | Main ball physics, state machine, forces, bounce |
| `Player/coefficients.gd` | Aerodynamic coefficients (Cd, Cl), air properties |
| `Player/player.gd` | Shot tracking, distance measurement |
| `Utils/surface.gd` | Surface friction parameters |
| `Utils/Settings/range_settings.gd` | User-adjustable physics settings |

---

## Ball Properties

Standard USGA golf ball properties (physically derived):

| Property | Symbol | Value | Unit | Source |
|----------|--------|-------|------|--------|
| Mass | m | 0.04592623 | kg | USGA max: 45.93g |
| Radius | r | 0.021335 | m | USGA min diameter: 42.67mm |
| Cross-sectional area | A | π×r² = 0.00143 | m² | Derived |
| Moment of inertia | I | 0.4×m×r² = 8.36×10⁻⁶ | kg·m² | Solid sphere approximation |

---

## Flight Physics

### Forces During Flight

The ball experiences four forces during flight:

#### 1. Gravity (Derived)
```
F_g = (0, -9.81 × m, 0)
```

#### 2. Drag Force (Derived + Empirical Cd)
```
F_d = -0.5 × Cd × ρ × A × v × |v|
```
Where:
- `Cd` = drag coefficient (Reynolds-dependent, see below)
- `ρ` = air density (kg/m³)
- `A` = cross-sectional area (m²)
- `v` = velocity vector (m/s)

#### 3. Magnus Force / Lift (Derived + Empirical Cl)
```
F_m = 0.5 × Cl × ρ × A × (ω × v) × |v| / |ω|
```
Where:
- `Cl` = lift coefficient (Reynolds and spin-dependent)
- `ω` = angular velocity vector (rad/s)
- `ω × v` = cross product giving lift direction

#### 4. Spin Decay Torque (Empirical)
```
T_d = -I × ω / τ
```
Where:
- `τ` = spin decay time constant (empirically tuned)

### Aerodynamic Coefficients

Located in `Player/coefficients.gd`.

#### Drag Coefficient Cd(Re)

| Reynolds Number | Cd Value | Type |
|-----------------|----------|------|
| Re < 50,000 | 0.5 | Constant (laminar) |
| 50,000 ≤ Re ≤ 200,000 | Polynomial | Empirical curve fit |
| Re > 200,000 | 0.2 | Constant (turbulent) |

**Polynomial for 50k-200k range:**
```
Cd = 1.1948 - 2.09661×10⁻⁵×Re + 1.42472×10⁻¹⁰×Re² - 3.14383×10⁻¹⁶×Re³
```

#### Lift Coefficient Cl(Re, S)

The spin ratio `S` is defined as:
```
S = ω × r / v
```
Where typical values are 0.05-0.15 for golf shots.

| Reynolds Number | Cl Model | Type |
|-----------------|----------|------|
| Re < 50,000 | 0.1 | Constant |
| 50,000 ≤ Re ≤ 75,000 | Polynomial interpolation | Empirical (wind tunnel data) |
| Re > 75,000 | 1.8×S + 0.05 | Linear model |
| Re > 200,000 | clamp(0.05, 0.4, 1.8×S + 0.05) | Clamped linear |

**Polynomial models for 50k-75k interpolation:**

| Re Value | Polynomial |
|----------|------------|
| 50,000 | 0.0472 + 2.848×S - 23.43×S² + 45.48×S³ |
| 60,000 | max(0.05, 0.321 - 4.703×S + 14.06×S²) |
| 65,000 | max(0.05, 0.267 - 4×S + 13.33×S²) |
| 70,000 | max(0.05, 0.0496 + 0.00211×S + 2.342×S²) |

### Reynolds Number Regimes

Reynolds number calculation:
```
Re = ρ × v × d / μ
```
Where:
- `d` = ball diameter = 2×r
- `μ` = dynamic air viscosity

**Typical golf shot Reynolds numbers:**

| Shot Type | Ball Speed | Re (approx) |
|-----------|------------|-------------|
| Chip | 30-50 mph | 40,000-70,000 |
| Iron | 80-120 mph | 100,000-160,000 |
| Driver | 140-180 mph | 180,000-230,000 |

### Spin Decay

**Parameter:** `spin_decay_tau` (seconds)

**Model:** Exponential decay
```
ω(t) = ω₀ × exp(-t/τ)
```

| Parameter | Value | Type | Notes |
|-----------|-------|------|-------|
| spin_decay_tau | 3.0 | **EMPIRICAL** | Tuned to match GSPro. Physical value ~15-20s |

**Note:** The physically realistic time constant (~17s) produces excessive carry when combined with the current lift model. The lower value compensates for lift model differences.

---

## Ground Physics

### Surface Types

Defined in `Utils/surface.gd`:

| Surface | u_k (kinetic) | u_kr (rolling) | nu_g (grass drag) | theta_c (critical angle) |
|---------|---------------|----------------|-------------------|--------------------------|
| ROUGH | 0.15 | 0.05 | 0.0005 | 0.38 rad (~22°) |
| FAIRWAY | 0.42 | 0.18 | 0.0020 | 0.30 rad (~17°) |
| FIRM | 0.08 | 0.02 | 0.0002 | 0.21 rad (~12°) |

**Parameter types:**
- `u_k`, `u_kr`: **EMPIRICAL** - tuned to match GSPro rollout
- `nu_g`: **EMPIRICAL** - grass drag viscosity
- `theta_c`: **EMPIRICAL** - from Penner's golf physics, surface-dependent

### Friction Model

#### On Ground Forces

**Grass drag:**
```
F_gd = -6π × r × nu_g × v
```

**Contact point velocity:**
```
v_contact = v_center + ω × r_contact
```
Where `r_contact = -floor_normal × r`

**Friction force:**
- If `|v_tangent| < 0.05 m/s` (rolling): `F_f = -u_kr × m × g × direction`
- If `|v_tangent| ≥ 0.05 m/s` (slipping): `F_f = -u_k × m × g × slip_direction`

**Friction torque:**
```
T_f = r_contact × F_f
```

### Bounce Physics

Based on Penner's "The Physics of Golf" oblique impact model.

#### Velocity Decomposition
- `vel_norm` = velocity component parallel to surface normal
- `vel_orth` = velocity component tangent to surface

#### Critical Angle (theta_c)

The critical angle determines whether the ball slides or grips during impact. Surface-dependent constant from Penner's research.

| Surface | theta_c | Effect |
|---------|---------|--------|
| ROUGH | 22° | High grip, ball checks |
| FAIRWAY | 17° | Medium grip |
| FIRM | 12° | Low grip, ball releases |

#### Orthogonal Velocity After Bounce
```
v2_orth = (5/7) × v × sin(θ₁ - θc) - (2/7) × r × |ωn|
```
Where:
- `θ₁` = impact angle (angle between velocity and normal)
- `θc` = critical angle
- `ωn` = normal component of angular velocity

#### Normal Coefficient of Restitution

| Normal Speed | e (COR) | Type |
|--------------|---------|------|
| > 20 m/s | 0.12 | Constant |
| ≤ 20 m/s | 0.510 - 0.0375×vn + 0.000903×vn² | **EMPIRICAL** polynomial |

```
vel_norm_after = -e × vel_norm_before
```

---

## Environmental Calculations

### Air Density

Calculated via barometric formula (derived):

```
P = P₀ × exp((-g × M × h) / (R × T))
ρ = P / (R_air × T)
```

| Constant | Value | Unit |
|----------|-------|------|
| P₀ (sea level pressure) | 101,325 | Pa |
| g (gravity) | 9.80665 | m/s² |
| M (molar mass dry air) | 0.0289644 | kg/mol |
| R (universal gas constant) | 8.314463 | J/(mol·K) |
| R_air (specific gas constant) | 287.058 | J/(kg·K) |

### Dynamic Viscosity

Calculated via Sutherland's formula (derived):

```
μ = μ₀ × (T/T₀)^1.5 × (T₀ + S) / (T + S)
```

| Constant | Value | Unit | Source |
|----------|-------|------|--------|
| μ₀ | 1.716×10⁻⁵ | kg/(m·s) | Reference viscosity at 0°C |
| S (Sutherland constant) | 198.72 | K | NASA |

---

## Distance Measurement

### Downrange Distance (GSPro-compatible)

Distance measured along initial shot direction:
```
distance = (position - start_position) · shot_direction
```

This accounts for curved shots (sidespin) more accurately than direct 2D distance.

### Unit Conversion
```
yards = meters × 1.09361
```

---

## Tunable Parameters

### User-Adjustable (range_settings.gd)

| Parameter | Default | Range | Effect |
|-----------|---------|-------|--------|
| drag_scale | 1.0 | 0.5-1.5 | Multiplier on Cd |
| lift_scale | 1.33 | 0.8-2.0 | Multiplier on Cl |
| temperature | 75°F | -40 to 120 | Affects air density |
| altitude | 0 ft | -1000 to 10000 | Affects air density |
| surface_type | FAIRWAY | ROUGH/FAIRWAY/FIRM | Ground interaction |

### Code Constants (Empirically Tuned)

| Parameter | Location | Value | Notes |
|-----------|----------|-------|-------|
| spin_decay_tau | ball.gd | 3.0s | Compensates for lift model |
| lift_scale default | range_settings.gd | 1.33 | Boosts lift to match real balls |
| COR polynomial | ball.gd | see above | Fitted to bounce data |
| Cl polynomials | coefficients.gd | see above | Wind tunnel curve fits |
| Cd polynomial | coefficients.gd | see above | Wind tunnel curve fit |

---

## Unit Conversions

| Conversion | Factor |
|------------|--------|
| mph → m/s | × 0.44704 |
| m/s → mph | × 2.23694 |
| yards → meters | × 0.9144 |
| meters → yards | × 1.09361 |
| feet → meters | × 0.3048 |
| rpm → rad/s | × 0.10472 (2π/60) |
| rad/s → rpm | × 9.5493 (60/2π) |
| degrees → radians | × π/180 |

---

## References

### Primary Sources

1. **Penner, A.R.** - "The Physics of Golf"
   - https://raypenner.com/golf-physics.pdf
   - Bounce physics, critical angle, oblique impact model

2. **Bearman, P.W. & Harvey, J.K.** - "Golf Ball Aerodynamics"
   - Wind tunnel data for Cd and Cl coefficients
   - Reynolds number regime transitions

3. **NASA Glenn Research Center** - Sutherland's Law
   - https://www.grc.nasa.gov/www/BGH/viscosity.html
   - Dynamic viscosity calculation

4. **Wikipedia** - Barometric Formula
   - https://en.wikipedia.org/wiki/Barometric_formula
   - Air density calculation

### Golf Simulation References

5. **Other Sim Software** - Other sim software was used to compare OSG shots
   - Real world launch monitor and range shots were taken to compare against OSG shots
   - Simulated shots were used for calibration, distance calculation, and flight.

---

## Future Work

### Planned Refactoring

- [ ] Move physics code from `Player/` to `physics/` folder
- [ ] Separate aerodynamics into dedicated module
- [ ] Create bounce physics module
- [ ] Add wind effects
- [ ] Implement variable terrain slopes
- [ ] Add ball-specific profiles (different ball models)

### Known Limitations

1. **Spin decay model** - Current empirical tau doesn't match physical reality; compensates for lift model
2. **Lift coefficient model** - Linear model for high Re may underestimate lift for high-spin shots
3. **No wind** - Wind forces not yet implemented
4. **Flat terrain assumption** - Bounce physics assume flat ground normal
5. **No humidity** - Air density calculation ignores humidity effects

### Calibration Needed

- Validate against multiple launch monitor brands (PiTrac, Garmin R10, etc.)
- Test across full range of shot types (driver, irons, wedges)
- Compare rollout distances on different surface types

---

*Last updated: 15-12-2025*
