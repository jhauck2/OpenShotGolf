extends Node3D

enum FollowMode {
	NONE = 0,
	OBJECT = 1
}

var followDistance : Vector3 = Vector3(-5.0, 1.5, 0)
var lookAtOffset : Vector3 = Vector3(0.0, 1.0, 0.0)
var speed : float = 0.0
const MAX_SPEED : float = 40.0

var mode : FollowMode = FollowMode.NONE
var followObject : Node3D = null


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Print error on mode/object mismatch
	if bool(mode) != (followObject == null):
		print("Follow mode does not match object")
	if followObject:
		position = followObject.position + followDistance
		look_at(followObject.position)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if followObject != null:
		# Move toward object, capped at max speed
		speed += (followObject.position + followDistance).length()/delta*0.2
		speed = min(speed, MAX_SPEED)
		position = position.move_toward(followObject.position + followDistance, speed*delta)
		look_at(followObject.position + lookAtOffset)

func setMode(followMode : FollowMode) -> void:
	mode = followMode
	if mode == FollowMode.NONE:
		followObject = null
	
func follow(object: Node3D) -> void:
	#if object != null:
		#position = followObject.position + followDistance
		#look_at(followObject.position)
		
	followObject = object
