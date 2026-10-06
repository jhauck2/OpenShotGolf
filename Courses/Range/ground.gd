extends Node3D

var x_extent := 40 # forward direction
var z_extent := 40 # Sideways direction

var chunk_size: float = 4.0
var chunk: Resource = preload("res://assets/grass/grass_chunk.tscn")
var chunk_array: Array[Array] = []

var retile_timer: float = 0.0
const RETILE_TIME: float = 0.1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var camera_pos: Vector3 = get_viewport().get_camera_3d().global_position

	var tile_x_offset: float = float(int(camera_pos.x) - (int(camera_pos.x)%4))
	var tile_z_offset: float = float(int(camera_pos.z) - (int(camera_pos.z)%4))
	for x: int in range(x_extent):
		var temp_array: Array[Node3D] = []
		for z:int in range(z_extent):
			var chunk_instance: Node3D = chunk.instantiate()
			@warning_ignore("integer_division")
			chunk_instance.position = Vector3(tile_x_offset+(x-x_extent/4)*chunk_size,0.0, 
				tile_z_offset+(z-z_extent/2)*chunk_size)
			add_child(chunk_instance)
			temp_array.append(chunk_instance)
			
		chunk_array.append(temp_array.duplicate())



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	retile_timer += delta
	if retile_timer >= RETILE_TIME:
		retile()
		retile_timer = 0.0

func retile() -> void:
	var camera_pos: Vector3 = get_viewport().get_camera_3d().global_position

	var tile_x_offset: float = float(int(camera_pos.x + camera_pos.y) - (int(camera_pos.x + camera_pos.y)%4))
	var tile_z_offset: float = float(int(camera_pos.z) - (int(camera_pos.z)%4))
	for x: int in range(x_extent):
		for z:int in range(z_extent):
			var chunk_instance: Node3D = chunk_array[x][z]
			@warning_ignore("integer_division")
			chunk_instance.position = Vector3(tile_x_offset+(x-x_extent/2)*chunk_size,0.0, 
				tile_z_offset+(z-z_extent/2)*chunk_size)
