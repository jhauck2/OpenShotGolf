class_name PhysicsEnums
extends Object

enum BallState { REST, FLIGHT, ROLLOUT }
enum Units { METRIC, IMPERIAL }
enum SurfaceType { 
	FAIRWAY, # Fast rollout
	FAIRWAY_SOFT, # Medium rollout 
	ROUGH, # Slow rollout
	FIRM, # Hardpan / cart-path style
	GREEN # Putting green (spin check / possible spinback)
}
