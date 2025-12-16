#!/usr/bin/env python
"""
Reynolds Number Calculator for Golf Ball Physics

This script calculates Reynolds numbers for different golf shot speeds
to help tune aerodynamic coefficients (Cd, Cl) in the physics engine.

Reynolds number formula:
    Re = (air_density * speed * diameter) / dynamic_viscosity

Where:
    - air_density: kg/m³
    - speed: m/s
    - diameter: m (ball diameter = 2 * radius)
    - dynamic_viscosity: kg/(m·s)
"""

def calculate_reynolds_number(speed_ms, air_density=1.225, radius=0.02134, viscosity=1.81e-5):
    """
    Calculate Reynolds number for a golf ball.

    Args:
        speed_ms: Ball speed in meters per second
        air_density: Air density in kg/m³ (default: sea level, 15°C)
        radius: Ball radius in meters (default: standard golf ball)
        viscosity: Dynamic air viscosity in kg/(m·s)

    Returns:
        Reynolds number (dimensionless)
    """
    return air_density * speed_ms * radius * 2.0 / viscosity


def mph_to_ms(mph):
    """Convert miles per hour to meters per second."""
    return mph * 0.44704


def ms_to_mph(ms):
    """Convert meters per second to miles per hour."""
    return ms / 0.44704


def main():
    # Standard conditions
    radius = 0.02134  # m (standard golf ball)
    air_density = 1.225  # kg/m³ (sea level, 15°C)
    viscosity = 1.81e-5  # kg/(m·s)

    # Typical golf shot speeds (mph)
    shot_types = [
        ("Slow wedge", 67),
        ("Mid iron", 89),
        ("Driver", 114.5),
        ("Fast driver", 134),
        ("Extreme (long drive)", 180),
    ]

    print("Reynolds Number Analysis for Golf Shots")
    print("=" * 70)
    print(f"Conditions: rho={air_density} kg/m^3, mu={viscosity:.2e} kg/(m*s), r={radius} m")
    print()
    print(f"{'Shot Type':<25} | {'Speed (mph)':<12} | {'Speed (m/s)':<12} | {'Reynolds #':<12}")
    print("-" * 70)

    for shot_type, mph in shot_types:
        ms = mph_to_ms(mph)
        Re = calculate_reynolds_number(ms, air_density, radius, viscosity)
        print(f"{shot_type:<25} | {mph:>12.1f} | {ms:>12.2f} | {Re:>12,.0f}")

    print()
    print("Reynolds Number Thresholds:")
    print("-" * 70)

    # Calculate speed thresholds for key Reynolds numbers
    thresholds = [50000, 75000, 100000, 200000]

    for Re_threshold in thresholds:
        speed_ms = Re_threshold * viscosity / (air_density * radius * 2.0)
        speed_mph = ms_to_mph(speed_ms)
        print(f"Re = {Re_threshold:>6,}: {speed_ms:>6.2f} m/s = {speed_mph:>6.1f} mph")

    print()
    print("Aerodynamic Regime Guidelines:")
    print("-" * 70)
    print("Re < 50k     : Low Reynolds (wedges < 77 mph, chips)")
    print("50k < Re < 75k  : Polynomial interpolation range")
    print("75k < Re < 200k : Linear model range (most normal shots)")
    print("Re > 200k    : Very high Reynolds (long drive competition)")


if __name__ == "__main__":
    main()
