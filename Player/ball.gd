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

# Ball properties
const MASS : float = 0.04592623 ## mass in kg
const RADIUS : float = 0.021335 ## radius in m
const A : float = PI*RADIUS*RADIUS ## cross-sectional area in m^2
const I : float = 0.4*MASS*RADIUS*RADIUS

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
	shape.set_radius(RADIUS)
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
	var total_force : Vector3 = BallPhysics.CalculateForces(self, was_on_ground, floor_normal)
	var total_torque : Vector3 = BallPhysics.CalculateTorques(self, was_on_ground, floor_normal)
	
	if total_force == null or total_torque == null:
		return

	# Update velocity and angular velocity
	velocity += (total_force / MASS) * delta
	omega += (total_torque / I) * delta

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
		rest.emit()

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
		else:
			# Wall collision - damped reflection
			on_ground = false
			floor_normal = Vector3.UP
			velocity = velocity.bounce(normal) * 0.30
	else:
		# No collision - only stay grounded if terrain is still directly beneath the ball.
		if state != PhysicsEnums.BallState.FLIGHT and was_on_ground:
			on_ground = true
			floor_normal = Vector3.UP
		else:
			on_ground = false
			floor_normal = Vector3.UP


func bounce(vel: Vector3, normal: Vector3) -> Vector3:
	if state == PhysicsEnums.BallState.FLIGHT:
		state = PhysicsEnums.BallState.ROLLOUT
		
	# Set up local axes vectors
	var local_y : Vector3 = normal.cross(vel).normalized()
	var local_x : Vector3 = local_y.cross(normal).normalized()
	var local_z : Vector3 = normal
	
	# Calculate impact angles
	var speed : float = vel.length()
	var theta_1 : float = normal.angle_to(-vel)
	var theta_c : float = 15.4 * speed * theta_1 / 18.6 / 44.4 # Eq 18 from reference
	
	# Handle high theta 1 "skimming" shots
	if theta_1 > 1.0: # ~ 60 degrees
		var normal_vel := vel.project(normal)*0.5
		var orth_vel := vel.slide(normal)*0.7
		
		omega *= 0.5
		return -normal_vel + orth_vel
	
	# Set up local impact axes vectors
	var local_x_i : Vector3 = local_x.rotated(local_y, theta_c)
	var local_z_i : Vector3 = local_z.rotated(local_y, theta_c)
	
	
	# normal restitution
	var vel1_iz : float = absf(vel.dot(-local_z_i))
	var e : float = 0.0
	if vel1_iz > 20.0:
		e = 0.12
	else:
		e = 0.510 - 0.0375*vel1_iz + 0.000903*vel1_iz*vel1_iz
	
	var vel2_iz : float = e*speed*cos(theta_1-theta_c)
	var vel2_ix : float = (5.0*speed*sin(theta_1-theta_c) - 2.0*RADIUS*omega.dot(-local_y))/7.0
	var vel2_iy : float = -2.0*RADIUS*omega.dot(local_x)/7.0
	
	# velocity 2 in impact frame
	var vel2_i : Vector3 = vel2_iz*local_z_i + vel2_ix*local_x_i + vel2_iy*local_y
	
	# backspin relative to impact direction
	var w_back : float = omega.dot(local_y)
	var w_side: float = omega.dot(local_x)
	var w_axial: float = omega.dot(local_z)
	var w2_back: float = absf(vel2_ix/RADIUS)
	var w2_side: float = absf(vel2_iy/RADIUS)
	
	omega = sign(w_back)*w2_back*local_y + sign(w_side)*w2_side*local_x + w_axial*local_z
	
	return vel2_i

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
