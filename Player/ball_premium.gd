extends CharacterBody3D

signal rest

const START_HEIGHT := 0.02

# C# addon instances
var _physics
var _aero
var _surface
var _shot_setup

var state: int = PhysicsEnums.BallState.Rest
var omega := Vector3.ZERO  # Angular velocity (rad/s)
var on_ground := false
var floor_normal := Vector3.UP
var _settings_connected := false

# Surface parameters (base values from C# Surface addon, then multiplied below).
# Change the *_mult values to tune this ball independently of global settings.
var surface_type: int = PhysicsEnums.SurfaceType.Fairway
var _kinetic_friction := 0.0
var _rolling_friction := 0.0
var _grass_viscosity := 0.0
var _critical_angle := 0.0  # radians
var _kinetic_mult := 0.8
var _rolling_mult := 0.6
var _grass_mult := 0.5
var _critical_mult := 0.9

# Environment
var _air_density: float
var _air_viscosity: float
var _drag_scale := 1.0
var _lift_scale := 1.0
# Premium-only aerodynamic multipliers; tweak these for less drag / more lift, etc.
var _drag_mult := 0.90
var _lift_mult := 1.10

# Shot tracking
var shot_start_pos := Vector3.ZERO
var shot_direction := Vector3(1.0, 0.0, 0.0)  # Normalized horizontal direction
var launch_spin_rpm := 0.0  # Stored for bounce calculations

# Ball physics constants (cached from C# addon in _ready)
var _ball_mass: float
var _ball_radius: float
var _ball_moi: float
var _openfairway_error_reported: Dictionary = {}

const OPENFAIRWAY_CLASS_PATHS := {
	"BallPhysics": "res://addons/openfairway/physics/BallPhysics.cs",
	"Aerodynamics": "res://addons/openfairway/physics/Aerodynamics.cs",
	"Surface": "res://addons/openfairway/physics/Surface.cs",
	"PhysicsParams": "res://addons/openfairway/physics/PhysicsParams.cs",
	"ShotSetup": "res://addons/openfairway/physics/ShotSetup.cs",
}
const DEFAULT_BALL_MASS := 0.04592623
const DEFAULT_BALL_RADIUS := 0.021335
const DEFAULT_BALL_MOI := 0.4 * DEFAULT_BALL_MASS * DEFAULT_BALL_RADIUS * DEFAULT_BALL_RADIUS


func _ready() -> void:
	if not _init_openfairway_instances():
		return
	initialize_ball()


func _new_openfairway(openfairway_class: StringName):
	var class_key := String(openfairway_class)
	var fallback_script_path: String = OPENFAIRWAY_CLASS_PATHS.get(class_key, "")
	if fallback_script_path != "":
		var script_resource: Script = load(fallback_script_path) as Script
		if script_resource != null:
			var instance = script_resource.new()
			if instance != null:
				return instance

	if fallback_script_path == "" and ClassDB.class_exists(openfairway_class) and ClassDB.can_instantiate(openfairway_class):
		var classdb_instance = ClassDB.instantiate(openfairway_class)
		if classdb_instance != null:
			return classdb_instance

	if not _openfairway_error_reported.has(class_key):
		_openfairway_error_reported[class_key] = true
		if not OS.has_feature("C#"):
			push_error("OpenFairway class '%s' is unavailable because this runtime has no C# support. Launch the project with the Godot .NET editor/runtime." % class_key)
		elif fallback_script_path != "":
			push_error("OpenFairway class '%s' could not be instantiated from '%s'. Build OpenShotGolf.csproj and restart the Godot .NET editor/runtime." % [class_key, fallback_script_path])
		else:
			push_error("OpenFairway class '%s' is unavailable. Build OpenShotGolf.csproj and restart the Godot .NET editor/runtime." % class_key)
	return null


func _has_openfairway_property(target: Object, property_name: StringName) -> bool:
	if target == null:
		return false
	for property_info in target.get_property_list():
		if StringName(property_info.get("name", "")) == property_name:
			return true
	return false


func _get_openfairway_property(target: Object, snake_name: StringName, pascal_name: StringName, default_value = null):
	if _has_openfairway_property(target, snake_name):
		return target.get(snake_name)
	if _has_openfairway_property(target, pascal_name):
		return target.get(pascal_name)
	return default_value


func _set_openfairway_property(target: Object, snake_name: StringName, pascal_name: StringName, value) -> bool:
	if _has_openfairway_property(target, snake_name):
		target.set(snake_name, value)
		return true
	if _has_openfairway_property(target, pascal_name):
		target.set(pascal_name, value)
		return true
	return false


func _call_openfairway_method(target: Object, snake_name: StringName, pascal_name: StringName, args: Array = []):
	if target == null:
		return null
	if target.has_method(snake_name):
		return target.callv(snake_name, args)
	if target.has_method(pascal_name):
		return target.callv(pascal_name, args)
	return null


func _init_openfairway_instances() -> bool:
	if _physics == null:
		_physics = _new_openfairway(&"BallPhysics")
	if _aero == null:
		_aero = _new_openfairway(&"Aerodynamics")
	if _surface == null:
		_surface = _new_openfairway(&"Surface")
	if _shot_setup == null:
		_shot_setup = _new_openfairway(&"ShotSetup")
	if _physics == null or _aero == null or _surface == null:
		return false
	_ball_mass = float(_get_openfairway_property(_physics, &"ball_mass", &"BallMass", DEFAULT_BALL_MASS))
	_ball_radius = float(_get_openfairway_property(_physics, &"ball_radius", &"BallRadius", DEFAULT_BALL_RADIUS))
	_ball_moi = float(_get_openfairway_property(_physics, &"ball_moment_of_inertia", &"BallMomentOfInertia", DEFAULT_BALL_MOI))
	if _ball_mass <= 0.0:
		_ball_mass = DEFAULT_BALL_MASS
	if _ball_radius <= 0.0:
		_ball_radius = DEFAULT_BALL_RADIUS
	if _ball_moi <= 0.0:
		_ball_moi = DEFAULT_BALL_MOI
	return true


func initialize_ball() -> void:
	_connect_settings()
	_update_environment()
	set_surface(GlobalSettings.range_settings.surface_type.value)


func _connect_settings() -> void:
	var settings := GlobalSettings.range_settings
	var env_callable := Callable(self, "_on_environment_changed")

	if not settings.temperature.setting_changed.is_connected(env_callable):
		settings.temperature.setting_changed.connect(env_callable)
	if not settings.altitude.setting_changed.is_connected(env_callable):
		settings.altitude.setting_changed.connect(env_callable)
	if not settings.range_units.setting_changed.is_connected(env_callable):
		settings.range_units.setting_changed.connect(env_callable)
	_drag_scale = _drag_mult
	_lift_scale = _lift_mult
	_settings_connected = true


func _update_environment() -> void:
	if _aero == null:
		return
	var settings := GlobalSettings.range_settings
	var units: int = settings.range_units.value
	var density = _call_openfairway_method(
		_aero,
		&"get_air_density",
		&"GetAirDensity",
		[settings.altitude.value, settings.temperature.value, units]
	)
	var viscosity = _call_openfairway_method(
		_aero,
		&"get_dynamic_viscosity",
		&"GetDynamicViscosity",
		[settings.temperature.value, units]
	)
	if density == null or viscosity == null:
		_air_density = 1.225
		_air_viscosity = 0.0000181
		return
	_air_density = float(density)
	_air_viscosity = float(viscosity)


func _on_environment_changed(_value) -> void:
	_update_environment()


func _on_drag_scale_changed(_value) -> void:
	_drag_scale = _drag_mult


func _on_lift_scale_changed(_value) -> void:
	_lift_scale = _lift_mult


func set_surface(surface: int) -> void:
	surface_type = surface
	_apply_surface_params()


func _apply_surface_params() -> void:
	if _surface == null:
		return
	var params_variant = _call_openfairway_method(_surface, &"get_params", &"GetParams", [surface_type])
	var params: Dictionary = {}
	if typeof(params_variant) == TYPE_DICTIONARY:
		params = params_variant
	else:
		params = {"u_k": 0.30, "u_kr": 0.03, "nu_g": 0.0010, "theta_c": 0.25}
	_kinetic_friction = float(params.get("u_k", 0.30)) * _kinetic_mult
	_rolling_friction = float(params.get("u_kr", 0.03)) * _rolling_mult
	_grass_viscosity = float(params.get("nu_g", 0.0010)) * _grass_mult
	_critical_angle = float(params.get("theta_c", 0.25)) * _critical_mult


func get_downrange_yards() -> float:
	var delta: Vector3 = position - shot_start_pos
	var meters: float = delta.dot(shot_direction)
	return meters * 1.09361


func _physics_process(delta: float) -> void:
	if not _init_openfairway_instances():
		return
	if state == PhysicsEnums.BallState.Rest:
		return

	var was_on_ground := on_ground
	var prev_velocity := velocity

	var params = _create_physics_params()
	if params == null:
		return
	var total_force = _call_openfairway_method(_physics, &"calculate_forces", &"CalculateForces", [velocity, omega, was_on_ground, params])
	var total_torque = _call_openfairway_method(_physics, &"calculate_torques", &"CalculateTorques", [velocity, omega, was_on_ground, params])
	if total_force == null or total_torque == null:
		return

	velocity += (total_force / _ball_mass) * delta
	omega += (total_torque / _ball_moi) * delta

	if _check_out_of_bounds():
		return

	var collision := move_and_collide(velocity * delta)
	_handle_collision(collision, was_on_ground, prev_velocity)

	if velocity.length() < 0.1 and state != PhysicsEnums.BallState.Rest:
		_enter_rest_state()


func _create_physics_params():
	var params = _new_openfairway(&"PhysicsParams")
	if params == null:
		return null
	_set_openfairway_property(params, &"air_density", &"AirDensity", _air_density)
	_set_openfairway_property(params, &"air_viscosity", &"AirViscosity", _air_viscosity)
	_set_openfairway_property(params, &"drag_scale", &"DragScale", _drag_scale)
	_set_openfairway_property(params, &"lift_scale", &"LiftScale", _lift_scale)
	_set_openfairway_property(params, &"kinetic_friction", &"KineticFriction", _kinetic_friction)
	_set_openfairway_property(params, &"rolling_friction", &"RollingFriction", _rolling_friction)
	_set_openfairway_property(params, &"grass_viscosity", &"GrassViscosity", _grass_viscosity)
	_set_openfairway_property(params, &"critical_angle", &"CriticalAngle", _critical_angle)
	_set_openfairway_property(params, &"floor_normal", &"FloorNormal", floor_normal)
	_set_openfairway_property(params, &"rollout_impact_spin", &"RolloutImpactSpin", 0.0)
	return params


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
	if collision:
		var normal := collision.get_normal()

		if _is_ground_normal(normal):
			floor_normal = normal
			var is_landing := (state == PhysicsEnums.BallState.Flight) or prev_velocity.y < -0.5

			if is_landing:
				if state == PhysicsEnums.BallState.Flight:
					_print_impact_debug()

				var params = _create_physics_params()
				if params == null:
					return
				var bounce_result = _call_openfairway_method(_physics, &"calculate_bounce", &"CalculateBounce", [velocity, omega, normal, state, params])
				if bounce_result == null:
					return
				velocity = _get_openfairway_property(bounce_result, &"new_velocity", &"NewVelocity", velocity)
				omega = _get_openfairway_property(bounce_result, &"new_omega", &"NewOmega", omega)
				state = int(_get_openfairway_property(bounce_result, &"new_state", &"NewState", state))

				print("  Velocity after bounce: ", velocity, " (%.2f m/s)" % velocity.length())
				on_ground = false
			else:
				on_ground = true
				if velocity.y < 0:
					velocity.y = 0
		else:
			on_ground = false
			floor_normal = Vector3.UP
			velocity = velocity.bounce(normal) * 0.30
	else:
		if state != PhysicsEnums.BallState.Flight and was_on_ground and position.y < 0.02 and velocity.y <= 0.0:
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
	state = PhysicsEnums.BallState.Rest
	velocity = Vector3.ZERO
	omega = Vector3.ZERO
	rest.emit()


func reset() -> void:
	position = Vector3(0.0, START_HEIGHT, 0.0)
	velocity = Vector3.ZERO
	omega = Vector3.ZERO
	launch_spin_rpm = 0.0
	state = PhysicsEnums.BallState.Rest
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
	if not _init_openfairway_instances():
		push_error("Cannot hit shot: OpenFairway classes are not available yet.")
		return
	var speed_mph: float = float(data.get("Speed", 0.0))
	var speed_mps: float = speed_mph * 0.44704  # mph to m/s
	var vla_deg: float = float(data.get("VLA", 0.0))
	var hla_deg: float = float(data.get("HLA", 0.0))

	var spin_data: Dictionary = {}
	if _shot_setup != null:
		var parsed_spin = _call_openfairway_method(_shot_setup, &"parse_spin", &"ParseSpin", [data])
		if typeof(parsed_spin) == TYPE_DICTIONARY:
			spin_data = parsed_spin
	if spin_data.is_empty():
		spin_data = _parse_spin_data(data)
	var total_spin: float = spin_data.total
	var spin_axis: float = spin_data.axis

	state = PhysicsEnums.BallState.Flight
	on_ground = false
	position = Vector3(0.0, START_HEIGHT, 0.0)

	var launch_data: Dictionary = {}
	if _shot_setup != null:
		var launch_result = _call_openfairway_method(
			_shot_setup,
			&"build_launch_vectors",
			&"BuildLaunchVectors",
			[speed_mph, vla_deg, hla_deg, total_spin, spin_axis]
		)
		if typeof(launch_result) == TYPE_DICTIONARY:
			launch_data = launch_result

	if launch_data.is_empty():
		velocity = Vector3(speed_mps, 0, 0) \
			.rotated(Vector3.FORWARD, deg_to_rad(-vla_deg)) \
			.rotated(Vector3.UP, deg_to_rad(-hla_deg))
		var flat_velocity := Vector3(velocity.x, 0.0, velocity.z)
		shot_direction = flat_velocity.normalized() if flat_velocity.length() > 0.001 else Vector3.RIGHT
		omega = Vector3(0.0, 0.0, total_spin * 0.10472) \
			.rotated(Vector3.RIGHT, deg_to_rad(spin_axis))
	else:
		velocity = launch_data.get("velocity", Vector3.ZERO)
		omega = launch_data.get("omega", Vector3.ZERO)
		shot_direction = launch_data.get("shot_direction", Vector3.RIGHT)

	shot_start_pos = position
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
	print("Pro V1 Ball")
	print("Speed: %.2f mph (%.2f m/s)" % [data.get("Speed", 0.0), speed_mps])
	print("VLA: %.2f deg, HLA: %.2f deg" % [vla, hla])
	print("Spin: %.0f rpm, Axis: %.2f deg" % [spin, axis])
	print("drag_cf: %.2f, lift_cf: %.2f" % [_drag_scale, _lift_scale])
	print("Air density: %.4f kg/m^3" % _air_density)
	print("Dynamic viscosity: %.11f" % _air_viscosity)

	var Re_initial = _air_density * speed_mps * _ball_radius * 2.0 / _air_viscosity
	var spin_ratio = (spin * 0.10472) * _ball_radius / speed_mps if speed_mps > 0.1 else 0.0
	var cl_result = _call_openfairway_method(_aero, &"get_cl", &"GetCl", [Re_initial, spin_ratio])
	var Cl_initial = float(cl_result) if cl_result != null else 0.0
	print("Reynolds number: %.0f" % Re_initial)
	print("Spin ratio: %.3f" % spin_ratio)
	print("Cl (before scale): %.3f, after: %.3f" % [Cl_initial, Cl_initial * _lift_scale])
	print("Initial velocity: ", velocity)
	print("Initial omega: ", omega, " (%.0f rpm)" % (omega.length() / 0.10472))
	print("Shot direction: ", shot_direction)
	print("===================")


func set_env(_value) -> void:
	_update_environment()
