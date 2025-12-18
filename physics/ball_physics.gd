class_name BallPhysics
extends RefCounted

# Pure physics calculations for golf ball motion.
# Contains all force, torque, and bounce calculations separated from the game object.

# Ball physical properties (USGA regulation)
const MASS := 0.04592623  # kg
const RADIUS := 0.021335  # m
const CROSS_SECTION := PI * RADIUS * RADIUS  # m^2
const MOMENT_OF_INERTIA := 0.4 * MASS * RADIUS * RADIUS  # kg*m^2
const SPIN_DECAY_TAU := 3.0  # Spin decay time constant (seconds)


# Physics parameters structure
class PhysicsParams:
	var air_density: float
	var air_viscosity: float
	var drag_scale: float
	var lift_scale: float
	var kinetic_friction: float
	var rolling_friction: float
	var grass_viscosity: float
	var critical_angle: float
	var floor_normal: Vector3

	func _init(
		p_air_density: float,
		p_air_viscosity: float,
		p_drag_scale: float,
		p_lift_scale: float,
		p_kinetic_friction: float,
		p_rolling_friction: float,
		p_grass_viscosity: float,
		p_critical_angle: float,
		p_floor_normal: Vector3
	) -> void:
		air_density = p_air_density
		air_viscosity = p_air_viscosity
		drag_scale = p_drag_scale
		lift_scale = p_lift_scale
		kinetic_friction = p_kinetic_friction
		rolling_friction = p_rolling_friction
		grass_viscosity = p_grass_viscosity
		critical_angle = p_critical_angle
		floor_normal = p_floor_normal


# Calculate total forces acting on the ball
static func calculate_forces(
	velocity: Vector3,
	omega: Vector3,
	on_ground: bool,
	params: PhysicsParams
) -> Vector3:
	var gravity := Vector3(0.0, -9.81 * MASS, 0.0)

	if on_ground:
		return gravity + calculate_ground_forces(velocity, omega, params)
	else:
		return gravity + calculate_air_forces(velocity, omega, params)


# Calculate ground friction and drag forces
static func calculate_ground_forces(
	velocity: Vector3,
	omega: Vector3,
	params: PhysicsParams
) -> Vector3:
	# Grass drag
	var grass_drag := velocity * (-6.0 * PI * RADIUS * params.grass_viscosity)
	grass_drag.y = 0.0

	# Contact point velocity for friction calculation
	var contact_velocity := velocity + omega.cross(-params.floor_normal * RADIUS)
	var tangent_velocity := contact_velocity - params.floor_normal * contact_velocity.dot(params.floor_normal)

	var friction := Vector3.ZERO
	var tangent_vel_mag := tangent_velocity.length()

	# Debug: print every 60 frames (~1 second) when on ground
	var should_debug := Engine.get_physics_frames() % 60 == 0

	if tangent_vel_mag < 0.05:
		# Pure rolling - use proper rolling resistance (c_rr), not sliding friction
		# Rolling resistance coefficient for fairway: 0.015-0.025 (not 0.18!)
		var flat_velocity := velocity - params.floor_normal * velocity.dot(params.floor_normal)
		var friction_dir := flat_velocity.normalized() if flat_velocity.length() > 0.01 else Vector3.ZERO
		var rolling_resistance := 0.020  # c_rr for fairway grass
		friction = friction_dir * (-rolling_resistance * MASS * 9.81)
		if should_debug:
			print("  ROLLING: vel=%.2f m/s, spin=%.0f rpm, c_rr=%.3f" % [velocity.length(), (omega.length() / 0.10472), rolling_resistance])
	else:
		# Slipping - kinetic friction
		var slip_dir := tangent_velocity.normalized()
		friction = slip_dir * (-params.kinetic_friction * MASS * 9.81)
		if should_debug:
			print("  SLIPPING: vel=%.2f m/s, spin=%.0f rpm, tangent_vel=%.2f, mu_k=%.2f" % [velocity.length(), (omega.length() / 0.10472), tangent_vel_mag, params.kinetic_friction])

	return grass_drag + friction


# Calculate aerodynamic drag and Magnus forces
static func calculate_air_forces(
	velocity: Vector3,
	omega: Vector3,
	params: PhysicsParams
) -> Vector3:
	var speed := velocity.length()
	if speed < 0.5:
		return Vector3.ZERO

	var spin_ratio := omega.length() * RADIUS / speed
	var reynolds := params.air_density * speed * RADIUS * 2.0 / params.air_viscosity

	var cd := Aerodynamics.get_cd(reynolds) * params.drag_scale
	var cl := Aerodynamics.get_cl(reynolds, spin_ratio) * params.lift_scale

	# Drag force (opposite to velocity)
	var drag := -0.5 * cd * params.air_density * CROSS_SECTION * velocity * speed

	# Magnus force (perpendicular to velocity and spin axis)
	var magnus := Vector3.ZERO
	var omega_len := omega.length()
	if omega_len > 0.1:
		var omega_cross_vel := omega.cross(velocity)
		magnus = 0.5 * cl * params.air_density * CROSS_SECTION * omega_cross_vel * speed / omega_len

	return drag + magnus


# Calculate total torques acting on the ball
static func calculate_torques(
	velocity: Vector3,
	omega: Vector3,
	on_ground: bool,
	params: PhysicsParams
) -> Vector3:
	if on_ground:
		return calculate_ground_torques(velocity, omega, params)
	else:
		# Spin decay torque (exponential decay model)
		return -MOMENT_OF_INERTIA * omega / SPIN_DECAY_TAU


# Calculate ground friction torques
static func calculate_ground_torques(
	velocity: Vector3,
	omega: Vector3,
	params: PhysicsParams
) -> Vector3:
	var friction_torque := Vector3.ZERO
	var grass_torque := -6.0 * PI * params.grass_viscosity * RADIUS * omega

	# Calculate friction for torque
	var contact_velocity := velocity + omega.cross(-params.floor_normal * RADIUS)
	var tangent_velocity := contact_velocity - params.floor_normal * contact_velocity.dot(params.floor_normal)

	var friction_force := Vector3.ZERO
	if tangent_velocity.length() < 0.05:
		# Pure rolling - use proper rolling resistance
		var flat_velocity := velocity - params.floor_normal * velocity.dot(params.floor_normal)
		var friction_dir := flat_velocity.normalized() if flat_velocity.length() > 0.01 else Vector3.ZERO
		var rolling_resistance := 0.020  # c_rr for fairway grass
		friction_force = friction_dir * (-rolling_resistance * MASS * 9.81)
	else:
		var slip_dir := tangent_velocity.normalized()
		friction_force = slip_dir * (-params.kinetic_friction * MASS * 9.81)

	if friction_force.length() > 0.001:
		friction_torque = (-params.floor_normal * RADIUS).cross(friction_force)

	return friction_torque + grass_torque


# Bounce calculation result
class BounceResult:
	var new_velocity: Vector3
	var new_omega: Vector3
	var new_state: GolfBall.BallState

	func _init(vel: Vector3, omg: Vector3, st: GolfBall.BallState) -> void:
		new_velocity = vel
		new_omega = omg
		new_state = st


# Calculate bounce physics when ball impacts surface
static func calculate_bounce(
	vel: Vector3,
	omega: Vector3,
	normal: Vector3,
	current_state: GolfBall.BallState,
	params: PhysicsParams
) -> BounceResult:
	var new_state := GolfBall.BallState.ROLLOUT if current_state == GolfBall.BallState.FLIGHT else current_state

	# Decompose velocity
	var vel_normal := vel.project(normal)
	var speed_normal := vel_normal.length()
	var vel_tangent := vel - vel_normal
	var speed_tangent := vel_tangent.length()

	# Decompose angular velocity
	var omega_normal := omega.project(normal)
	var omega_tangent := omega - omega_normal

	var impact_angle := vel.angle_to(normal)

	# Use tangential spin magnitude for bounce calculation (backspin creates reverse velocity)
	var omega_tangent_magnitude: float = omega_tangent.length()

	# Tangential retention based on spin
	var current_spin_rpm := omega.length() / 0.10472

	var tangential_retention: float

	if current_state == GolfBall.BallState.FLIGHT:
		# First bounce from flight: Use spin-based penalty
		var spin_factor := clampf(1.0 - (current_spin_rpm / 8000.0), 0.40, 1.0)
		tangential_retention = 0.55 * spin_factor
	else:
		# Rollout bounces: Higher retention, no spin penalty
		# Use spin ratio to determine how much velocity to keep
		var ball_speed := vel.length()
		var spin_ratio := (omega.length() * RADIUS) / ball_speed if ball_speed > 0.1 else 0.0

		# Low spin ratio = more rollout retention
		if spin_ratio < 0.20:
			tangential_retention = lerpf(0.85, 0.70, spin_ratio / 0.20)
		else:
			tangential_retention = 0.70

	if new_state == GolfBall.BallState.ROLLOUT:
		print("  Bounce: spin=%.0f rpm, retention=%.3f" % [
			current_spin_rpm, tangential_retention
		])

	# Calculate new tangential speed
	var new_tangent_speed: float

	if current_state == GolfBall.BallState.FLIGHT:
		# First bounce from flight: Use Penner model - backspin creates reverse velocity
		new_tangent_speed = tangential_retention * vel.length() * sin(impact_angle - params.critical_angle) - \
			2.0 * RADIUS * omega_tangent_magnitude / 7.0
	else:
		# Subsequent bounces during rollout: Simple friction factor (like libgolf)
		# Don't subtract spin - just apply friction to existing tangential velocity
		new_tangent_speed = speed_tangent * tangential_retention

	if speed_tangent < 0.01 or new_tangent_speed <= 0.0:
		vel_tangent = Vector3.ZERO
	else:
		vel_tangent = vel_tangent.limit_length(new_tangent_speed)

	# Update tangential angular velocity
	if current_state == GolfBall.BallState.FLIGHT:
		# First bounce: compute omega from tangent speed
		var new_omega_tangent := new_tangent_speed / RADIUS
		if omega_tangent.length() < 0.1 or new_omega_tangent <= 0.0:
			omega_tangent = Vector3.ZERO
		else:
			omega_tangent = omega_tangent.limit_length(new_omega_tangent)
	else:
		# Rollout: preserve existing spin direction, apply decay factor
		# Don't force spin to match velocity - let friction torque handle spin naturally
		# This is where I think the bug could be fixed for high ball speed, low apex lack of distance. 
		# Rollout: force spin to match rolling velocity to avoid prolonged slipping
		# TODO - used to be this. But now workaround starts on line 278. 
		# If reverted, rpm is high on 2nd bounce, then not stable. 
		# if new_tangent_speed > 0.1:
		# 	# Set spin for pure rolling: omega = v/r in direction of velocity
		# 	var tangent_dir := vel_tangent.normalized() if vel_tangent.length() > 0.01 else Vector3.RIGHT
		# 	var rolling_axis := normal.cross(tangent_dir).normalized()
		# 	omega_tangent = rolling_axis * (new_tangent_speed / RADIUS)
		# else:
		# 	omega_tangent = Vector3.ZERO

		var omega_decay := 0.5  # Reduce spin by 50% on bounce
		omega_tangent = omega_tangent * omega_decay

	# Coefficient of restitution (speed-dependent)
	var cor: float
	if current_state == GolfBall.BallState.FLIGHT:
		# First bounce from flight: use full COR
		cor = get_coefficient_of_restitution(speed_normal)
	else:
		# Rollout bounces: kill small bounces aggressively to settle into roll
		if speed_normal < 4.0:
			cor = 0.0  # Kill small rollout bounces completely
		else:
			cor = get_coefficient_of_restitution(speed_normal) * 0.5  # Halve COR for rollout

	vel_normal = vel_normal * -cor

	var new_omega := omega_normal + omega_tangent
	var new_velocity := vel_normal + vel_tangent

	return BounceResult.new(new_velocity, new_omega, new_state)


# Get coefficient of restitution based on impact speed
static func get_coefficient_of_restitution(speed_normal: float) -> float:
	if speed_normal > 20.0:
		return 0.25  # High speed impacts
	elif speed_normal < 2.0:
		return 0.0  # Kill very small bounces
	else:
		# Typical COR curve for golf ball on turf
		return 0.45 - 0.0100 * speed_normal + 0.0002 * speed_normal * speed_normal
