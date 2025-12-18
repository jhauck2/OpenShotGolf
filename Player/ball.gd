extends CharacterBody3D
class_name GolfBall

signal rest

enum BallState {REST, FLIGHT, ROLLOUT}
enum BallType {STANDARD, PREMIUM}

const START_HEIGHT := 0.02

var state: GolfBall.BallState = GolfBall.BallState.REST
var omega := Vector3.ZERO  # Angular velocity (rad/s)
var on_ground := false
var floor_normal := Vector3.UP
var _settings_connected := false

# Surface parameters (base values pulled from physics/surface.gd, then multiplied below).
# TODO - some of these values should not be in ball. Ball type shouldn't matter grass viscosity. 
# Change the *_mult values to create a different “feel” for this ball without touching global settings.
var surface_type: Surface.SurfaceType = Surface.SurfaceType.FAIRWAY
var _kinetic_friction: float = 0.42
var _rolling_friction: float = 0.18
var _grass_viscosity: float = 0.0020
var _critical_angle: float = 0.30  # radians
var _kinetic_mult := 1.0
var _rolling_mult := 1.0
var _grass_mult := 1.0
var _critical_mult := 1.0

# Environment
var _air_density: float
var _air_viscosity: float
var _drag_scale := 1.0
var _lift_scale := 1.0
# Per-ball aerodynamic multipliers. Adjust these to make this ball fly differently (e.g., more lift/less drag).
var _drag_mult := 1.0
var _lift_mult := 1.0

# Shot tracking
var shot_start_pos := Vector3.ZERO
var shot_dir := Vector3(1.0, 0.0, 0.0)  # Normalized horizontal direction
var launch_spin_rpm := 0.0  # Stored for bounce calculations


func _ready() -> void:
	initialize_ball()


func initialize_ball() -> void:
	_connect_settings()
	_update_environment()
	set_surface(GlobalSettings.range_settings.surface_type.value)


func _connect_settings() -> void:
	var settings := GlobalSettings.range_settings

	if not settings.temperature.setting_changed.is_connected(_on_environment_changed):
		settings.temperature.setting_changed.connect(_on_environment_changed)
	if not settings.altitude.setting_changed.is_connected(_on_environment_changed):
		settings.altitude.setting_changed.connect(_on_environment_changed)
	if not settings.range_units.setting_changed.is_connected(_on_environment_changed):
		settings.range_units.setting_changed.connect(_on_environment_changed)
	_drag_scale = _drag_mult
	_lift_scale = _lift_mult
	_settings_connected = true


func _on_environment_changed(_value) -> void:
	_update_environment()


func _on_drag_scale_changed(_value) -> void:
	_drag_scale = _drag_mult


func _on_lift_scale_changed(_value) -> void:
	_lift_scale = _lift_mult


func _update_environment() -> void:
	var settings := GlobalSettings.range_settings
	var units: Enums.Units = settings.range_units.value as Enums.Units
	_air_density = Aerodynamics.get_air_density(
		settings.altitude.value,
		settings.temperature.value,
		units
	)
	_air_viscosity = Aerodynamics.get_dynamic_viscosity(
		settings.temperature.value,
		units
	)


func set_surface(surface: int) -> void:
	surface_type = surface as Surface.SurfaceType
	_apply_surface_params()


func _apply_surface_params() -> void:
	var params := Surface.get_params(surface_type)
	_kinetic_friction = params["u_k"] * _kinetic_mult
	_rolling_friction = params["u_kr"] * _rolling_mult
	_grass_viscosity = params["nu_g"] * _grass_mult
	_critical_angle = params["theta_c"] * _critical_mult
	if OS.is_debug_build():
		print("Surface set to %s -> u_k=%.3f, u_kr=%.3f, nu_g=%.4f, theta_c=%.3f" % [
			str(surface_type), _kinetic_friction, _rolling_friction, _grass_viscosity, _critical_angle
		])


func get_downrange_yards() -> float:
	var delta: Vector3 = position - shot_start_pos
	var meters: float = delta.dot(shot_dir)
	return meters * 1.09361


func _physics_process(delta: float) -> void:
	if state == GolfBall.BallState.REST:
		return

	var was_on_ground := on_ground
	var prev_velocity := velocity

	# Calculate forces and torques using BallPhysics
	var params := _create_physics_params()
	var total_force := BallPhysics.calculate_forces(velocity, omega, was_on_ground, params)
	var total_torque := BallPhysics.calculate_torques(velocity, omega, was_on_ground, params)

	# Update velocity and angular velocity
	velocity += (total_force / BallPhysics.MASS) * delta
	omega += (total_torque / BallPhysics.MOMENT_OF_INERTIA) * delta

	# Safety bounds check
	if _check_out_of_bounds():
		return

	# Move and handle collisions
	var collision := move_and_collide(velocity * delta)
	_handle_collision(collision, was_on_ground, prev_velocity)

	# Check for rest
	if velocity.length() < 0.1 and state != GolfBall.BallState.REST:
		_enter_rest_state()


func _create_physics_params() -> BallPhysics.PhysicsParams:
	return BallPhysics.PhysicsParams.new(
		_air_density,
		_air_viscosity,
		_drag_scale,
		_lift_scale,
		_kinetic_friction,
		_rolling_friction,
		_grass_viscosity,
		_critical_angle,
		floor_normal
	)


func _check_out_of_bounds() -> bool:
	if absf(position.x) > 1000.0 or absf(position.z) > 1000.0:
		print("WARNING: Ball out of bounds at: ", position)
		_enter_rest_state()
		return true

	if position.y < -0.5:
		print("WARNING: Ball fell through ground at: ", position)
		position.y = 0.0
		_enter_rest_state()
		return true

	return false


func _handle_collision(collision: KinematicCollision3D, was_on_ground: bool, prev_velocity: Vector3) -> void:
	var should_debug := Engine.get_physics_frames() % 60 == 0

	if collision:
		var normal := collision.get_normal()

		if _is_ground_normal(normal):
			floor_normal = normal
			var is_landing := (state == GolfBall.BallState.FLIGHT) or prev_velocity.y < -0.5

			if is_landing:
				if state == GolfBall.BallState.FLIGHT:
					_print_impact_debug()

				var params := _create_physics_params()
				var bounce_result := BallPhysics.calculate_bounce(velocity, omega, normal, state, params)
				velocity = bounce_result.new_velocity
				omega = bounce_result.new_omega
				state = bounce_result.new_state

				print("  Velocity after bounce: ", velocity, " (%.2f m/s)" % velocity.length())
				on_ground = false
			else:
				on_ground = true
				if velocity.y < 0:
					velocity.y = 0
		else:
			# Wall collision - damped reflection
			on_ground = false
			floor_normal = Vector3.UP
			velocity = velocity.bounce(normal) * 0.30
	else:
		# No collision - check rolling continuity
		if state != GolfBall.BallState.FLIGHT and was_on_ground and position.y < 0.02 and velocity.y <= 0.0:
			if should_debug and not on_ground:
				print("  NO COLLISION: setting on_ground=true (pos.y=%.4f, vel.y=%.2f)" % [position.y, velocity.y])
			on_ground = true
		else:
			on_ground = false
			floor_normal = Vector3.UP


func _is_ground_normal(normal: Vector3) -> bool:
	return normal.y > 0.7


func _print_impact_debug() -> void:
	print("FIRST IMPACT at pos: ", position, ", downrange: %.2f yds" % get_downrange_yards())
	print("  Velocity at impact: ", velocity, " (%.2f m/s)" % velocity.length())
	print("  Spin at impact: ", omega, " (%.0f rpm)" % (omega.length() / 0.10472))
	print("  Normal: ", floor_normal)


func _enter_rest_state() -> void:
	state = GolfBall.BallState.REST
	velocity = Vector3.ZERO
	omega = Vector3.ZERO
	emit_signal("rest")


func reset() -> void:
	position = Vector3(0.0, START_HEIGHT, 0.0)
	velocity = Vector3.ZERO
	omega = Vector3.ZERO
	launch_spin_rpm = 0.0
	state = GolfBall.BallState.REST
	on_ground = false


func hit() -> void:
	var data := {
		"Speed": 100.0,
		"VLA": 22.0,
		"HLA": -3.1,
		"TotalSpin": 6000.0,
		"SpinAxis": 3.5,
	}
	hit_from_data(data)


func hit_from_data(data: Dictionary) -> void:
	var speed_mps: float = float(data.get("Speed", 0.0)) * 0.44704  # mph to m/s
	var vla_deg: float = float(data.get("VLA", 0.0))
	var hla_deg: float = float(data.get("HLA", 0.0))

	var spin_data := _parse_spin_data(data)
	var total_spin: float = spin_data.total
	var spin_axis: float = spin_data.axis

	# Set state
	state = GolfBall.BallState.FLIGHT
	on_ground = false
	position = Vector3(0.0, START_HEIGHT, 0.0)

	# Calculate initial velocity
	velocity = Vector3(speed_mps, 0, 0) \
		.rotated(Vector3.FORWARD, deg_to_rad(-vla_deg)) \
		.rotated(Vector3.UP, deg_to_rad(-hla_deg))

	# Set shot tracking
	shot_start_pos = position
	var flat_velocity := Vector3(velocity.x, 0.0, velocity.z)
	shot_dir = flat_velocity.normalized() if flat_velocity.length() > 0.001 else Vector3.RIGHT

	# Set angular velocity
	omega = Vector3(0.0, 0.0, total_spin * 0.10472) \
		.rotated(Vector3.RIGHT, deg_to_rad(spin_axis))
	launch_spin_rpm = total_spin

	_print_launch_debug(data, speed_mps, vla_deg, hla_deg, total_spin, spin_axis)


func _parse_spin_data(data: Dictionary) -> Dictionary:
	var has_backspin := data.has("BackSpin")
	var has_sidespin := data.has("SideSpin")
	var has_total := data.has("TotalSpin")
	var has_axis := data.has("SpinAxis")

	var backspin: float = float(data.get("BackSpin", 0.0))
	var sidespin: float = float(data.get("SideSpin", 0.0))
	var total_spin: float = float(data.get("TotalSpin", 0.0))
	var spin_axis: float = float(data.get("SpinAxis", 0.0))

	# Calculate missing values
	if total_spin == 0.0 and (has_backspin or has_sidespin):
		total_spin = sqrt(backspin * backspin + sidespin * sidespin)

	if not has_axis and (has_backspin or has_sidespin):
		spin_axis = rad_to_deg(atan2(sidespin, backspin))

	if has_total and has_axis:
		if not has_backspin:
			backspin = total_spin * cos(deg_to_rad(spin_axis))
		if not has_sidespin:
			sidespin = total_spin * sin(deg_to_rad(spin_axis))

	return {
		"backspin": backspin,
		"sidespin": sidespin,
		"total": total_spin,
		"axis": spin_axis
	}


func _print_launch_debug(data: Dictionary, speed_mps: float, vla: float, hla: float, spin: float, axis: float) -> void:
	print("=== SHOT DEBUG ===")
	print("Kirkland Ball")
	print("Ball: %s" % _get_ball_label())
	print("Speed: %.2f mph (%.2f m/s)" % [data.get("Speed", 0.0), speed_mps])
	print("VLA: %.2f deg, HLA: %.2f deg" % [vla, hla])
	print("Spin: %.0f rpm, Axis: %.2f deg" % [spin, axis])
	print("drag_cf: %.2f, lift_cf: %.2f" % [_drag_scale, _lift_scale])
	print("Air density: %.4f kg/m^3" % _air_density)
	print("Dynamic viscosity: %.11f" % _air_viscosity)

	var Re_initial := _air_density * speed_mps * BallPhysics.RADIUS * 2.0 / _air_viscosity
	var spin_ratio := (spin * 0.10472) * BallPhysics.RADIUS / speed_mps if speed_mps > 0.1 else 0.0
	var Cl_initial := Aerodynamics.get_cl(Re_initial, spin_ratio)
	print("Reynolds number: %.0f" % Re_initial)
	print("Spin ratio: %.3f" % spin_ratio)
	print("Cl (before scale): %.3f, after: %.3f" % [Cl_initial, Cl_initial * _lift_scale])
	print("Initial velocity: ", velocity)
	print("Initial omega: ", omega, " (%.0f rpm)" % (omega.length() / 0.10472))
	print("Shot direction: ", shot_dir)
	print("===================")


func set_env(_value) -> void:
	_update_environment()


func _get_ball_label() -> String:
	match GlobalSettings.range_settings.ball_type.value:
		GolfBall.BallType.PREMIUM:
			return "Premium"
		_:
			return "Standard"
