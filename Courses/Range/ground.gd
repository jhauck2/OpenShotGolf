@tool 
extends Node3D

var x_extent := 50 # forward direction
var z_extent := 25 # Sideways direction

var chunk_size: float = 4.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	reload()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func reload() -> void:
	for child in get_children():
		child.queue_free()
		
	for x: int in range(-2, x_extent-2):
		for z: int in range(-z_extent/2, z_extent/2):
			var chunk: Node3D = preload("res://assets/grass/grass_chunk.tscn").instantiate()
			
			chunk.position = Vector3(chunk_size*x, 0.0, chunk_size*z)
			
			add_child(chunk)
