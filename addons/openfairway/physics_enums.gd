class_name PhysicsEnums
extends RefCounted

## GDScript mirror of C# PhysicsEnums nested enums.
## Integer values match the C# definitions so GDScript ↔ C# works seamlessly.

enum BallState { REST, FLIGHT, ROLLOUT }
enum Units { METRIC, IMPERIAL }
enum SurfaceType { 
	FAIRWAY, # Fast rollout
	FAIRWAY_SOFT, # Medium rollout 
	ROUGH, # Slow rollout
	FIRM # Green (fastest) rollout
}
