# Physics calculations for golf ball motion
class_name BallPhysics
extends Node

const GRASS_VISCOSITY : float = 0.035

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

static var gravityAccel : Vector3 = Vector3(0.0, -Aerodynamics.EARTH_GRAVITY, 0.0)


static func CalculateForces(ball: GolfBall, onGround: bool, floorNorm: Vector3 = Vector3.ZERO) -> Vector3:
	if onGround:
		# When on ground, normal force cancels gravity vertically
		# while gravity still contibutes along the local slope tangent
		return CalculateGroundForces(ball, floorNorm) + gravityAccel*ball.MASS
	else:
		return gravityAccel*ball.MASS + CalculateAirForces(ball)
		

static func CalculateTorques(ball: GolfBall, onGround: bool) ->Vector3:
	if onGround:
		return CalculateGroundTorques(ball)
	else:
		# Viscous Torque
		return -8.0*PI*Aerodynamics.viscosity*pow(ball.RADIUS,3)*ball.omega


## Calculates ground friction and drag forces
static func CalculateGroundForces(ball: GolfBall, floorNorm: Vector3) -> Vector3:
	var grassDrag : Vector3 = ball.velocity * (-6.0*PI*ball.RADIUS*GRASS_VISCOSITY)
	var friction : Vector3 = CalculateFrictionForce(ball, floorNorm)
	var normal : Vector3 = -floorNorm*floorNorm.dot(gravityAccel)*ball.MASS
	return grassDrag + friction + normal
	
	
static func CalculateFrictionForce(ball: GolfBall, floorNorm: Vector3) -> Vector3:
	var contactVel : Vector3 = ball.velocity + ball.omega.cross(floorNorm*ball.RADIUS)
	var tangentVel : Vector3 = contactVel - floorNorm*contactVel.dot(floorNorm)
	var tangentSpeed : float = tangentVel.length()
	if tangentSpeed < 0.01:
		return Vector3.ZERO
	if tangentSpeed < TANGET_VEL_THRESHOLD: # rolling without slipping
		var ballTanVel : Vector3 = ball.velocity - floorNorm*ball.velocity.dot(floorNorm)
		if ballTanVel.length() < 0.01: return Vector3.ZERO
		
		var frictionDir : Vector3 = ballTanVel.normalized()
		
		return frictionDir*ROLLING_FRICTION*ball.MASS*gravityAccel.dot(floorNorm)
	else: # rolling with slipping
		var speed : float = ball.velocity.length()
		var friction : float
		var spinFrictionMultiplier : float = 1.0 # TODO: look into this
		if speed < FRICTION_BLEND_SPEED: # Blend between kinetic and static friction constants
			var blendFactor : float = speed/FRICTION_BLEND_SPEED
			friction = lerpf(ROLLING_FRICTION, KINETIC_FRICTION, blendFactor*blendFactor)
		else: # true rolling with slipping
			friction = KINETIC_FRICTION
			
		var effectiveFriction : float = friction*spinFrictionMultiplier
		return tangentVel.normalized()*effectiveFriction*ball.MASS*gravityAccel.dot(floorNorm)

static func CalculateAirForces(ball: GolfBall) -> Vector3:
	# Calculate reynolds number and spin ration
	var speed : float = ball.velocity.length()
	var re : float = Aerodynamics.GetRe(speed, ball.RADIUS)
	var spin : float = ball.omega.length()*ball.RADIUS/speed
	
	# Drag force
	var drag : Vector3 = - 0.5*Aerodynamics.GetCd(re, spin)*Aerodynamics.density*ball.A*ball.velocity*speed
	
	
	# Magnus force
	var magnus : Vector3 = Vector3.ZERO
	if ball.omega.length() > 0.1:
		magnus = 0.5*Aerodynamics.GetCl(re, spin)*Aerodynamics.density*ball.A*ball.omega.cross(ball.velocity)*speed/ball.omega.length()
	
	return drag + magnus

static func CalculateGroundTorques(ball: GolfBall) -> Vector3:
	var grassTorque : Vector3 = -8.0*PI*GRASS_VISCOSITY*pow(ball.RADIUS, 3)*ball.omega
	
	return grassTorque
