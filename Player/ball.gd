extends CharacterBody3D

var omega := Vector3.ZERO
var on_ground := false
var floor_norm := Vector3(0.0, 1.0, 0.0)
var temperature: float = GlobalSettings.range_settings.temperature.value # Using global settings

var mass = 0.04592623
var radius = 0.021335
var A = PI*radius*radius # Cross-sectional area
var I = 0.4*mass*radius*radius # Moment of inertia
var u_k = 0.15 # kinetic friction; surface-driven
var u_kr = 0.05 # rolling friction; surface-driven
var theta_c = 0.30 # critical bounce angle in radians (~17°); surface-driven

var airDensity = Coefficients.get_air_density(0.0, temperature)
var dynamicAirViscosity = Coefficients.get_dynamic_air_viscosity(temperature)
# Spin decay time constant (seconds) - tuned to match GSPro behavior
# Note: With fixed Cl model (1.1*S + 0.05), tau = 3.0 gives correct spin decay
var spin_decay_tau = 3.0
var nu_g = 0.0005 # Grass drag viscosity; surface-driven
var drag_cf: float # Drag correction factor (set from GlobalSettings)
var lift_cf: float # Lift correction factor (set from GlobalSettings)
var surface_type: int = Enums.Surface.FAIRWAY

var state : Enums.BallState = Enums.BallState.REST
var debug_frame_count := 0

# --- NEW: shot reference for measuring downrange distance correctly ---
var shot_start_pos := Vector3.ZERO
var shot_dir := Vector3(0.0, 0.0, 1.0) # normalized horizontal-ish direction

# --- Store launch spin for bounce calculations (spin decays during flight) ---
var launch_spin_rpm := 0.0

signal rest

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GlobalSettings.range_settings.range_units.setting_changed.connect(set_env)
	GlobalSettings.range_settings.temperature.setting_changed.connect(set_env)
	GlobalSettings.range_settings.altitude.setting_changed.connect(set_env)
	GlobalSettings.range_settings.drag_scale.setting_changed.connect(_on_drag_scale_changed)
	GlobalSettings.range_settings.lift_scale.setting_changed.connect(_on_lift_scale_changed)
	drag_cf = GlobalSettings.range_settings.drag_scale.value
	lift_cf = GlobalSettings.range_settings.lift_scale.value
	set_env(null) # Sync air properties to current settings on startup
	_apply_surface(surface_type)


func _is_ground_normal(n: Vector3) -> bool:
	# Collision normals from Godot are always normalized, so n.y == n.dot(Vector3.UP)
	return n.y > 0.7


# --- NEW: compute downrange distance along shot_dir (GSPro-like) ---
func get_downrange_yards() -> float:
	var delta: Vector3 = position - shot_start_pos
	# measure along initial shot direction, ignore sign mistakes by allowing negative if it happens
	var meters: float = delta.dot(shot_dir)
	return meters * 1.09361


func _physics_process(delta: float) -> void:
	# Track previous state for bounce detection
	var was_on_ground := on_ground
	var prev_velocity := velocity

	var F_g := Vector3(0.0, -9.81*mass, 0) # force of gravity
	var F_m := Vector3.ZERO # Magnus force
	var F_d := Vector3.ZERO # Drag force
	var F_f := Vector3.ZERO # Frictional force
	var F_gd := Vector3.ZERO # Drag force from grass

	var T_d := Vector3.ZERO # Viscous torque
	var T_f := Vector3.ZERO # Frictional torque
	var T_g := Vector3.ZERO # Grass drag torque

	# Use ground state from PREVIOUS frame for force calculations
	if was_on_ground:
		# Force of viscous drag from grass
		F_gd = velocity*(-6*PI*radius*nu_g)
		F_gd.y = 0.0

		# Contact point velocity: v_contact = v_center + omega × r_contact
		# where r_contact = -floor_norm * radius (from center to ground contact)
		var v_contact : Vector3 = velocity + omega.cross(-floor_norm * radius)

		# FIX: friction should act in tangent plane only (remove normal component)
		var v_tan: Vector3 = v_contact - floor_norm * v_contact.dot(floor_norm)

		if v_tan.length() < 0.05: # rolling without slipping
			var v_flat: Vector3 = velocity - floor_norm * velocity.dot(floor_norm)
			var friction_dir = v_flat.normalized() if v_flat.length() > 0.01 else Vector3.ZERO
			F_f = friction_dir * (-u_kr * mass * 9.81)  # Use rolling friction
		else: # ball slipping - kinetic friction
			var slip_dir = v_tan.normalized()
			F_f = slip_dir * (-u_k * mass * 9.81)  # Use kinetic friction

		# Friction torque (applies in both rolling and slipping cases)
		if F_f.length() > 0.001:
			T_f = (-floor_norm * radius).cross(F_f)

		# Viscous Torque
		T_g = -6.0*PI*nu_g*radius*omega
	else: # ball in air
		var speed := velocity.length()
		var spin := 0.0
		if speed > 0.5:
			spin = omega.length()*radius/speed

		var Re : float = airDensity*speed*radius*2.0/dynamicAirViscosity

		# Magnus, drag, and coefficients
		var Cl = Coefficients.get_Cl(Re, spin)*lift_cf
		var Cd = Coefficients.get_Cd(Re)*drag_cf
		# Magnus force
		var om_x_vel = omega.cross(velocity)
		var omega_len = omega.length()
		if omega_len > 0.1:
			F_m = 0.5*Cl*airDensity*A*om_x_vel*velocity.length()/omega.length()
		# Spin decay torque (empirical exponential decay model)
		# T = -I * omega / tau gives exponential decay with time constant tau
		T_d = -I * omega / spin_decay_tau
		# Drag force
		F_d = -0.5*Cd*airDensity*A*velocity*speed

	# Total force
	var F : Vector3 = F_g + F_d + F_m + F_f + F_gd

	# Total torque
	var T : Vector3 = T_d + T_f + T_g

	velocity = velocity + F/mass*delta
	omega = omega + T/I*delta

	# Safety check: prevent ball from going too far out of bounds
	if abs(position.x) > 1000.0 or abs(position.z) > 1000.0:
		print("WARNING: Ball went out of bounds at position: ", position)
		velocity = Vector3.ZERO
		omega = Vector3.ZERO
		state = Enums.BallState.REST
		emit_signal("rest")
		return

	# Safety check: prevent ball from falling through ground
	if position.y < -0.5:
		print("WARNING: Ball fell through ground at position: ", position, " - resetting to y=0.0")
		position.y = 0.0
		velocity = Vector3.ZERO
		omega = Vector3.ZERO
		state = Enums.BallState.REST
		emit_signal("rest")
		return

	# Move and detect collision
	var collision = move_and_collide(velocity * delta)

	if collision:
		var normal = collision.get_normal()

		if _is_ground_normal(normal):
			floor_norm = normal

			# Bounce if: first impact (FLIGHT) OR subsequent airborne landing
			var is_landing = (state == Enums.BallState.FLIGHT) or prev_velocity.y < -0.5

			if is_landing:
				if state == Enums.BallState.FLIGHT:
					# Keep for debugging later. 
					print("FIRST IMPACT at pos: ", position, ", downrange: %.2f yds" % get_downrange_yards())
					print("  Velocity at impact: ", velocity, " (%.2f m/s)" % velocity.length())
					print("  Spin at impact: ", omega, " (%.0f rpm)" % (omega.length()/0.10472))
					print("  Normal: ", normal)
				velocity = bounce(velocity, normal)
				print("  Velocity after bounce: ", velocity, " (%.2f m/s)" % velocity.length())
				on_ground = false
			else:
				# On ground, not bouncing
				on_ground = true
				if velocity.y < 0:
					velocity.y = 0
		else:
			# Non-ground collision (wall, etc.) - damped reflection
			on_ground = false
			floor_norm = Vector3(0.0, 1.0, 0.0)
			velocity = velocity.bounce(normal) * 0.30
	else:
		# No collision - check rolling continuity for non-flight states
		if state != Enums.BallState.FLIGHT and was_on_ground and position.y < 0.02 and velocity.y <= 0.0:
			on_ground = true
		else:
			on_ground = false
			floor_norm = Vector3(0.0, 1.0, 0.0)

	# Rest detection
	if velocity.length() < 0.1 and state != Enums.BallState.REST:
		state = Enums.BallState.REST
		velocity = Vector3.ZERO
		emit_signal("rest")


func bounce(vel, normal) -> Vector3:
	if state == Enums.BallState.FLIGHT:
		state = Enums.BallState.ROLLOUT

	# component of velocity parallel to floor normal
	var vel_norm : Vector3 = vel.project(normal)
	var speed_norm : float = vel_norm.length()
	# component of velocity orthogonal to normal
	var vel_orth : Vector3 = vel - vel_norm
	var speed_orth : float = vel_orth.length()
	# component of angular velocity parallel to normal
	var omg_norm : Vector3 = omega.project(normal)
	# component of angular velocity orthogonal to normal
	var omg_orth : Vector3 = omega - omg_norm

	var speed : float = vel.length()
	var theta_1 : float = vel.angle_to(normal)
	# theta_c is the critical angle (surface-dependent, set via _apply_surface)

	# final orthogonal speed
	# FIX: use signed normal spin component (length() loses sign)
	# Reduced tangential retention from 5/7 (0.714) to 0.25 to fix excessive roll
	# GSPro shows ~10-20 yards roll on driver, we were getting 38+ yards with 0.714
	# Further reduce tangential retention for high-spin shots (wedges should check up)
	var spin_n: float = omega.dot(normal) # signed

	# Use LAUNCH spin for bounce retention calculation, not current decayed spin
	# This ensures high-spin shots always check up, regardless of spin decay during flight
	# At 0 rpm launch: retention = 0.30, at 5000+ rpm launch: retention ≈ 0.06
	var spin_factor = clamp(1.0 - (launch_spin_rpm / 6000.0), 0.20, 1.0)
	var tangential_retention: float = 0.30 * spin_factor  # Heavily reduced for high-spin launches

	if state == Enums.BallState.FLIGHT:
		print("  Bounce calc: launch_spin=%.0f rpm, current_spin=%.0f rpm, spin_factor=%.3f, retention=%.3f" % [launch_spin_rpm, omega.length()/0.10472, spin_factor, tangential_retention])

	var v2_orth = tangential_retention*speed*sin(theta_1-theta_c) - 2.0*radius*abs(spin_n)/7.0

	# orthogonal restitution - handle negative v2_orth (high spin case)
	if speed_orth < 0.01 or v2_orth <= 0.0:
		vel_orth = Vector3.ZERO
	else:
		vel_orth = vel_orth.limit_length(v2_orth)

	# final orthogonal angular velocity
	var w2h : float = v2_orth / radius
	# orthogonal angular restitution - handle negative w2h
	if omg_orth.length() < 0.1 or w2h <= 0.0:
		omg_orth = Vector3.ZERO
	else:
		omg_orth = omg_orth.limit_length(w2h)

	# normal restitution (coefficient of restitution)
	# Reduced low-speed COR to prevent extended bouncing (ball appearing "stuck")
	var e : float = 0.0
	if speed_norm > 20.0:
		e = 0.12
	elif speed_norm < 3.0:
		e = 0.0  # Kill small bounces entirely
	else:
		# Reduced from 0.510 to 0.30 at low speeds
		e = 0.30 - 0.0150*speed_norm + 0.0003*speed_norm*speed_norm

	vel_norm = vel_norm*-e

	omega = omg_norm + omg_orth

	return vel_norm + vel_orth


func hit():
	var data : Dictionary = {
		"Speed": 100.0,
		"VLA": 22.0,
		"HLA": -3.1,
		"TotalSpin": 6000.0,
		"SpinAxis": 3.5,
		"Temp": 25.0,
		"Altitude": 0.0
	}

	state = Enums.BallState.FLIGHT
	on_ground = false
	position = Vector3(0.0, 0.05, 0.0)

	velocity = Vector3(data["Speed"]*0.44704, 0, 0).rotated(
					Vector3(0.0, 0.0, 1.0), data["VLA"]*PI/180.0).rotated(
						Vector3(0.0, 1.0, 0.0), -data["HLA"]*PI/180.0)

	# NEW: set shot start + direction for correct distance measurement
	shot_start_pos = position
	var v_flat: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	shot_dir = v_flat.normalized() if v_flat.length() > 0.001 else Vector3(0.0, 0.0, 1.0)

	omega = Vector3(0.0, 0.0, data["TotalSpin"]*0.10472).rotated(Vector3(1.0, 0.0, 0.0), data["SpinAxis"]*PI/180.0)
	launch_spin_rpm = data["TotalSpin"]


func hit_from_data(data : Dictionary):
	debug_frame_count = 0  # Reset diagnostic counter for new shot
	var speed_mps: float = (data.get("Speed", 0.0) as float)*0.44704
	var vla_deg: float = data.get("VLA", 0.0) as float
	var hla_deg: float = data.get("HLA", 0.0) as float
	var has_backspin := data.has("BackSpin")
	var has_sidespin := data.has("SideSpin")
	var has_total := data.has("TotalSpin")
	var has_axis := data.has("SpinAxis")
	var backspin: float = (data.get("BackSpin", 0.0) as float)
	var sidespin: float = (data.get("SideSpin", 0.0) as float)
	var total_spin: float = (data.get("TotalSpin", 0.0) as float)
	var spin_axis: float = (data.get("SpinAxis", 0.0) as float)

	if total_spin == 0.0 and (has_backspin or has_sidespin):
		total_spin = sqrt(backspin*backspin + sidespin*sidespin)
	if not has_axis and (has_backspin or has_sidespin):
		spin_axis = rad_to_deg(atan2(sidespin, backspin))
	if has_total and has_axis:
		if not has_backspin:
			backspin = total_spin * cos(deg_to_rad(spin_axis))
		if not has_sidespin:
			sidespin = total_spin * sin(deg_to_rad(spin_axis))

	state = Enums.BallState.FLIGHT
	on_ground = false
	position = Vector3(0.0, 0.05, 0.0)

	velocity = Vector3(speed_mps, 0, 0).rotated(
					Vector3(0.0, 0.0, 1.0), vla_deg*PI/180.0).rotated(
						Vector3(0.0, 1.0, 0.0), -hla_deg*PI/180.0)

	# NEW: set shot start + direction for correct distance measurement
	shot_start_pos = position
	var v_flat: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	shot_dir = v_flat.normalized() if v_flat.length() > 0.001 else Vector3(0.0, 0.0, 1.0)

	if total_spin == 0.0:
		omega = Vector3(sidespin*0.10472, 0.0, backspin*0.10472)
	else:
		omega = Vector3(0.0, 0.0, total_spin*0.10472).rotated(Vector3(1.0, 0.0, 0.0), spin_axis*PI/180)

	# Store launch spin for bounce calculations (spin decays during flight)
	launch_spin_rpm = total_spin

	# Leave these in. We'll revisit again--I am sure.
	print("=== SHOT DEBUG ===")
	print("Speed: %.2f mph (%.2f m/s)" % [data.get("Speed", 0.0), speed_mps])
	print("VLA: %.2f°, HLA: %.2f°" % [vla_deg, hla_deg])
	print("Spin: %.0f rpm, Axis: %.2f°" % [total_spin, spin_axis])
	print("drag_cf: %.2f, lift_cf: %.2f" % [drag_cf, lift_cf])
	print("Air density: %.4f kg/m³" % airDensity)
	print("Dynamic viscosity: %.11f kg/(m·s)" % dynamicAirViscosity)
	var Re_initial = airDensity * speed_mps * radius * 2.0 / dynamicAirViscosity
	var spin_ratio = (total_spin * 0.10472) * radius / speed_mps if speed_mps > 0.1 else 0.0
	var Cl_initial = Coefficients.get_Cl(Re_initial, spin_ratio)
	print("Reynolds number (initial): %.0f" % Re_initial)
	print("Spin ratio (initial): %.3f" % spin_ratio)
	print("Cl (initial, before lift_cf): %.3f, after: %.3f" % [Cl_initial, Cl_initial * lift_cf])
	print("Initial velocity: ", velocity)
	print("Initial omega: ", omega, " (%.0f rpm)" % (omega.length()/0.10472))
	print("Shot dir (flat): ", shot_dir)
	print("===================")


func set_env(_value):
	airDensity = Coefficients.get_air_density(GlobalSettings.range_settings.altitude.value,
		 GlobalSettings.range_settings.temperature.value)
	dynamicAirViscosity = Coefficients.get_dynamic_air_viscosity(GlobalSettings.range_settings.temperature.value)


func reset():
	position = Vector3(0.0, 0.1, 0.0)
	velocity = Vector3.ZERO
	omega = Vector3.ZERO
	launch_spin_rpm = 0.0
	state = Enums.BallState.REST
	on_ground = false


func _on_drag_scale_changed(_value):
	drag_cf = GlobalSettings.range_settings.drag_scale.value


func _on_lift_scale_changed(_value):
	lift_cf = GlobalSettings.range_settings.lift_scale.value


func set_surface(surface: int) -> void:
	surface_type = surface as Enums.Surface
	_apply_surface(surface_type)


func _apply_surface(surface: int) -> void:
	var params := SurfaceUtil.get_params(surface as Enums.Surface)
	u_k = params["u_k"]
	u_kr = params["u_kr"]
	nu_g = params["nu_g"]
	theta_c = params["theta_c"]
