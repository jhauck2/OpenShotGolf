# Physics calculations for golf ball motion
extends Node

# physical properties
const MASS : float = 0.04592623 ## mass in kg
const RADIUS : float = 0.021335 ## radius in m
const A : float = PI*RADIUS*RADIUS ## cross-sectional area in m^2
const I : float = 0.4*MASS*RADIUS*RADIUS
const SPIN_DECAY_TAU : float = 5.0 ## spin decay time constant (s)

const GRASS_VISCOSITY : float = 0.0020

# Velocity Scaling
const CHIP_SPEED_THRESHOLD : float = 20.0
const PITCH_SPEED_THRESHOLD : float = 35.0
const CHIP_VEL_SCALE_MIN : float = 0.6
const CHIP_VEL_SCALE_MAX : float = 0.87

# Spin Thresholds
const LOW_SPIN_THRESHOLD : float = 1750.0

# Spin Friction Multipliers
const LOW_SPIN_MULT_MAX : float = 1.15
const MID_SPIN_MULT_MAX : float = 2.25
const HI_SPIN_MULT_MAX : float = 2.50
const HIGH_SPIN_RAMP_RANGE : float = 1000.0

# Friction Blending
const FRICTION_BLEND_SPEED : float = 15.0
const TANGET_VEL_THRESHOLD : float = 0.05
const ROLLING_FRICTION : float = 0.18
const KINETIC_FRICTION : float = 0.42

var gravityForce : Vector3 = Vector3(0.0, -Aero.EARTH_GRAVITY*MASS, 0.0)


func CalculateForces(vel: Vector3, omega: Vector3, onGround: bool, floorNorm: Vector3 = Vector3.ZERO) -> Vector3:
	if onGround:
		# When on ground, normal force cancels gravity vertically
		# while gravity still contibutes along the local slope tangent
		return CalculateGroundForces(vel, omega, floorNorm) + gravityForce
	else:
		return gravityForce + CalculateAirForces(vel, omega)
		

func CalculateTorques(vel: Vector3, omega: Vector3, onGround: bool, floorNorm: Vector3 = Vector3.ZERO) ->Vector3:
	if onGround:
		return CalculateGroundTorques(vel, omega, floorNorm)
	else:
		# Viscous Torque
		return -8.0*PI*Aero.viscosity*RADIUS*RADIUS*RADIUS*omega


## Calculates ground friction and drag forces
func CalculateGroundForces(vel: Vector3, omega: Vector3, floorNorm: Vector3) -> Vector3:
	var grassDrag : Vector3 = vel * (-6.0*PI*RADIUS*GRASS_VISCOSITY)
	var friction : Vector3 = CalculateFrictionForce(vel, omega, floorNorm)
	return grassDrag + friction
	
	
func CalculateFrictionForce(vel: Vector3, omega: Vector3, floorNorm: Vector3) -> Vector3:
	var contactVel : Vector3 = vel + omega.cross(floorNorm*RADIUS)
	var tangentVel : Vector3 = contactVel - floorNorm*contactVel.dot(floorNorm)
	var tangentSpeed : float = tangentVel.length()
	if tangentSpeed < 0.01:
		return Vector3.ZERO
	if tangentSpeed < TANGET_VEL_THRESHOLD: # rolling without slipping
		var ballTanVel : Vector3 = vel - floorNorm*vel.dot(floorNorm)
		if ballTanVel.length() < 0.01: return Vector3.ZERO
		
		var frictionDir : Vector3 = ballTanVel.normalized()
		
		return frictionDir*ROLLING_FRICTION*MASS*gravityForce.dot(floorNorm)
	else: # rolling with slipping
		var speed : float = vel.length()
		var friction : float
		var spinFrictionMultiplier : float = 1.0 # TODO: look into this
		if speed < FRICTION_BLEND_SPEED: # Blend between kinetic and static friction constants
			var blendFactor : float = speed/FRICTION_BLEND_SPEED
			friction = lerpf(ROLLING_FRICTION, KINETIC_FRICTION, blendFactor*blendFactor)
		else: # true rolling with slipping
			friction = KINETIC_FRICTION
			
		var effectiveFriction : float = friction*spinFrictionMultiplier
		return tangentVel.normalized()*effectiveFriction*MASS*gravityForce.dot(floorNorm)

func CalculateAirForces(vel: Vector3, omega: Vector3) -> Vector3:
	# Calculate reynolds number and spin ration
	var speed : float = vel.length()
	var re : float = Aero.GetRe(speed, RADIUS)
	var spin : float = omega.length()*RADIUS/speed
	
	# Drag force
	var drag : Vector3 = - 0.5*Aero.GetCd(re, spin)*Aero.density*A*vel*speed
	
	
	# Magnus force
	var magnus : Vector3 = Vector3.ZERO
	if omega.length() > 0.1:
		magnus = 0.5*Aero.GetCl(re, spin)*Aero.density*A*omega.cross(vel)*speed/omega.length()
	
	return drag + magnus

func CalculateGroundTorques(vel: Vector3, omega: Vector3, floorNorm: Vector3) -> Vector3:
	var grassTorque : Vector3 = -8.0*PI*GRASS_VISCOSITY*RADIUS*RADIUS*RADIUS*omega
	
	var frictionForce : Vector3 = CalculateFrictionForce(vel, omega, floorNorm)
	
	var frictionTorque : Vector3 = Vector3.ZERO
	if frictionForce.length() > 0.001:
		frictionTorque = -RADIUS*floorNorm.cross(frictionForce)
	
	return frictionTorque + grassTorque
