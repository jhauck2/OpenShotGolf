extends CharacterBody3D
class_name GolfBall

signal rest

const START_HEIGHT := 0.02
const COLLISION_SAFE_MARGIN := 0.0005
const BELOW_GROUND_RECOVERY_Y := -0.5
const FALLTHROUGH_FAILSAFE_Y := -5.0
const GROUND_SNAP_OFFSET := 0.001
const GROUND_RAYCAST_UP := 2.0
const GROUND_RAYCAST_DOWN := 8.0
const GROUND_PROBE_DISTANCE := 0.08
const MIN_GROUND_NORMAL := 0.7

var ball_model : PackedScene = preload("res://assets/models/balls/golf_ball.glb")

# Ball state variables
var state: int = PhysicsEnums.BallState.REST
var omega := Vector3.ZERO  # Angular velocity (rad/s)
var on_ground := false
var floor_normal := Vector3.UP

# Surface parameters
var surface_type: int = PhysicsEnums.SurfaceType.FAIRWAY

# Shot tracking
var shot_start_pos := Vector3.ZERO

var pause_physics : bool = false

func _ready() -> void:
	initialize_ball()
	reset()


func initialize_ball() -> void:
	# Create collision shape
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.set_radius(BPhysics.RADIUS)
	collision.set_shape(shape)
	add_child(collision)
	# Create model
	var mesh : Node = ball_model.instantiate()
	var mesh_scale := 0.05
	mesh.scale = Vector3(mesh_scale, mesh_scale, mesh_scale)
	add_child(mesh)


func _physics_process(delta: float) -> void:
	# pause physics when 'p' is pressed
	if (Input.is_action_just_pressed("pause")):
		pause_physics = not pause_physics
		
	if pause_physics or state == PhysicsEnums.BallState.REST:
		return

	var was_on_ground := on_ground
	var prev_velocity := velocity

	# Calculate forces and torques using BallPhysics
	var total_force : Vector3 = BPhysics.CalculateForces(velocity, omega, was_on_ground, floor_normal)
	var total_torque : Vector3 = BPhysics.CalculateTorques(velocity, omega, was_on_ground, floor_normal)
	
	if total_force == null or total_torque == null:
		return

	# Update velocity and angular velocity
	velocity += (total_force / BPhysics.MASS) * delta
	omega += (total_torque / BPhysics.I) * delta

	# Safety: catch NaN/infinity before it reaches the physics engine
	# Without this, ROUGH appears to error with FINITE bug. Do not remove until someone
	# better understands this. 
	if not velocity.is_finite() or not omega.is_finite():
		push_warning("BallPhysics: infinite velocity or omega detected, entering rest")
		reset()
		return
		
	# Move and handle collisions
	var vel_before_collision : Vector3 = velocity
	var collision := move_and_collide(velocity * delta, false, COLLISION_SAFE_MARGIN)
	_handle_collision(collision, was_on_ground, vel_before_collision)

	# Check for rest
	if velocity.length() < 0.1:
		velocity = Vector3.ZERO
		omega = Vector3.ZERO
		state = PhysicsEnums.BallState.REST

func _handle_collision(collision: KinematicCollision3D, was_on_ground: bool, prev_velocity: Vector3) -> void:
	if collision:
		var normal := collision.get_normal()

		if _is_ground_normal(normal): # regular floor collision
			floor_normal = normal
			var prev_normal_velocity := prev_velocity.dot(normal)
			var is_landing := (state == PhysicsEnums.BallState.FLIGHT) or prev_normal_velocity < -0.5

			if is_landing:
				velocity = bounce(prev_velocity, normal)
				if absf(velocity.dot(normal)) < 0.15:
					on_ground = true
				else:
					on_ground = false
			else:
				on_ground = true
				velocity -= normal*velocity.dot(normal)
		else:
			# Wall collision - damped reflection
			on_ground = false
			floor_normal = Vector3.UP
			velocity = velocity.bounce(normal) * 0.30
	else:
		# No collision - only stay grounded if terrain is still directly beneath the ball.
		var probe := _try_probe_ground()
		if state != PhysicsEnums.BallState.FLIGHT and was_on_ground and bool(probe.get("hit", false)):
			on_ground = true
			floor_normal = probe.get("normal", Vector3.UP)
		else:
			on_ground = false
			floor_normal = Vector3.UP


func bounce(vel: Vector3, normal: Vector3) -> Vector3:
	if state == PhysicsEnums.BallState.FLIGHT:
		state = PhysicsEnums.BallState.ROLLOUT
		
	# component of velocity parallel to floor normal
	var vel_norm : Vector3 = vel.project(normal)
	var speed_norm : float = vel_norm.length()
	# component of velocity orthoganal to normal
	var vel_orth : Vector3 = vel - vel_norm
	var speed_orth : float = vel_orth.length()
	#component of angular velocity parallel to normal
	var omg_norm : Vector3 = omega.project(normal)
	# component of angular velocity orthoganal to normal
	var omg_orth : Vector3 = omega - omg_norm
	
	var speed : float = velocity.length()
	var theta_1 : float = velocity.angle_to(normal)
	var theta_c : float = 15.4 * speed * theta_1 / 18.6 / 44.4 # Eq 18 from reference
	
	
	# final orthoganal angular velocity
	var w2h : float = 5*speed/(7.0*BPhysics.RADIUS)*sin(theta_1-theta_c) - 2.0*omg_orth.length()/7.0
	# orthoganal angular restitution
	if omg_orth.length() < 0.1:
		omg_orth = Vector3.ZERO
	else:
		omg_orth = omg_orth.limit_length(w2h)
		
	# normal restitution
	var v1_z_prime : float = speed_norm*cos(theta_c) - speed_orth*sin(theta_c)
	var e : float = 0.0
	if v1_z_prime > 20.0:
		e = 0.12
	else:
		e = 0.510 - 0.0375*v1_z_prime + 0.000903*v1_z_prime*v1_z_prime
	
	
	# final orthoganal speed
	# with reference to the rotated frame (theta c)
	var v2_orth: float = 5.0/7.0*speed*sin(theta_1-theta_c) - 2.0*BPhysics.RADIUS*omg_norm.length()/7.0
	# final speed parallel to norm rotated by theta_c
	var v2_normal : float = e*speed*cos(theta_1-theta_c)
	
	vel_norm = (v2_normal*cos(theta_c) + v2_orth*sin(theta_c))*normal
	var orth_normal : Vector3 = vel_orth.normalized()
	vel_orth = (-v2_normal*sin(theta_c) + v2_orth*cos(theta_c))*orth_normal
	
	omega = omg_norm + omg_orth
	
	return vel_norm + vel_orth

func _try_recover_to_ground() -> bool:
	var world := get_world_3d()

	var ray_start := global_position + Vector3.UP * GROUND_RAYCAST_UP
	var ray_end := global_position + Vector3.DOWN * GROUND_RAYCAST_DOWN
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [get_rid()]

	var ray_hit := world.direct_space_state.intersect_ray(query)
	if ray_hit.is_empty():
		return false

	var hit_position: Vector3 = ray_hit["position"]
	var hit_normal: Vector3 = ray_hit["normal"]
	if hit_normal.length_squared() < 0.000001:
		hit_normal = Vector3.UP
	else:
		hit_normal = hit_normal.normalized()

	global_position = hit_position + hit_normal * (BPhysics.RADIUS + GROUND_SNAP_OFFSET)
	floor_normal = hit_normal
	velocity = _remove_velocity_along_normal(velocity, hit_normal)
	on_ground = true

	if state == PhysicsEnums.BallState.FLIGHT:
		state = PhysicsEnums.BallState.ROLLOUT

	print("Recovered ball-to-ground at %s (normal: %s)" % [str(global_position), str(hit_normal)])
	return true


func _try_probe_ground() -> Dictionary:
	var world := get_world_3d()
	if world == null:
		return {"hit": false, "normal": Vector3.UP}

	var ray_start := global_position + Vector3.UP * 0.05
	var ray_end := global_position + Vector3.DOWN * (BPhysics.RADIUS + GROUND_PROBE_DISTANCE)
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [get_rid()]

	var ray_hit := world.direct_space_state.intersect_ray(query)
	if ray_hit.is_empty():
		return {"hit": false, "normal": Vector3.UP}

	var ground_normal: Vector3 = ray_hit["normal"]
	if ground_normal.length_squared() < 0.000001:
		ground_normal = Vector3.UP
	else:
		ground_normal = ground_normal.normalized()
	return {"hit": true, "normal": ground_normal}


func _is_ground_normal(normal: Vector3) -> bool:
	return normal.y > MIN_GROUND_NORMAL


func _remove_velocity_along_normal(source_velocity: Vector3, normal: Vector3) -> Vector3:
	var normal_component : Vector3= source_velocity.dot(normal)*normal
	return source_velocity - normal_component


func get_downrange_yards() -> float:
	var delta: Vector3 = position - shot_start_pos
	var meters: float = delta.dot(Vector3.RIGHT)
	return meters * 1.09361


func reset() -> void:
	position = Vector3(0.0, START_HEIGHT, 0.0)
	velocity = Vector3.ZERO
	omega = Vector3.ZERO
	state = PhysicsEnums.BallState.REST
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
	var speed_mph: float = float(data.get("Speed", 0.0))
	var speed_mps: float = speed_mph * 0.44704  # mph to m/s
	var vla_deg: float = float(data.get("VLA", 0.0))
	var hla_deg: float = float(data.get("HLA", 0.0))
	var rpm2rad_s : float = 0.10472
	var deg2rad : float = PI/180.0
	var vla_rad : float = vla_deg*deg2rad
	var hla_rad : float = hla_deg*deg2rad

	if data.has("TotalSpin") and data.has("SpinAxis"):
		omega = Vector3(0.0, 0.0, data["TotalSpin"]*rpm2rad_s).rotated(Vector3.RIGHT, data["SpinAxis"]*deg2rad)
	elif data.has("BackSpin") and data.has("SideSpin"):
		omega = Vector3(0.0, data["SideSpin"], data["BackSpin"])*rpm2rad_s
	else:
		push_error("Not enough spin information provided")
	
	velocity = Vector3(speed_mps, 0.0, 0.0).rotated(Vector3.BACK, vla_rad).rotated(Vector3.UP, -hla_rad)
	state = PhysicsEnums.BallState.FLIGHT
