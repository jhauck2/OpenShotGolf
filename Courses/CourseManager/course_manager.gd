extends Node3D

class Player:
	var name : String
	var total_score : int
	var scores : Array[int]
	var current_ball_location : Vector3
	
	func _init(_name: String):
		name = _name
		total_score = 0
		scores = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
		current_ball_location = Vector3.ZERO
	
var players : Array[Player]
var camera_rotation_speed : float = 10.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Handle camera and player rotation
	var camera_rotation = Input.get_axis("look_right", "look_left")
	$PhantomCamera3D.rotation.y += camera_rotation*delta

func start_course(course_folder_path : String, metadata : Dictionary, _players : Array) -> void:
	# Load the course
	var packed := load(course_folder_path+"/course.tscn") as PackedScene
	if packed == null:
		push_error("Could not load course: %s" % course_folder_path)
		return

	var course_scene := packed.instantiate()
	if course_scene == null:
		push_error("Could not instantiate scene: %s" % course_folder_path+"/course.tscn")
		return

	add_child(course_scene)
	
	# Add tee boxes and pins based on metadata
	
	# Add players
	for player_name in _players:
		var new_player = Player.new(player_name)
		players.append(new_player)
		
	# Start game at hole 1
	
	return
