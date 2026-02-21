extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func start_course(course_folder_path : String, metadata : Dictionary, players : Array) -> void:
	# Load the course
	var packed := load(course_folder_path+"/course.tscn") as PackedScene
	if packed == null:
		push_error("Could not load course: %s" % course_folder_path)
		return

	var course_scene := packed.instantiate()
	if course_scene == null:
		push_error("Could not instantiate scene: %s" % course_folder_path+"/course.tscn")
		return
		
	# Set current camera
	#course_scene.get_node("Terrain3D").set_camera($PhantomCamera3D)

	add_child(course_scene)
	
	
	
	# Add tee boxes and pins based on metadata
	
	# Add players
	return
