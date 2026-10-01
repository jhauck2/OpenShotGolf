@tool
extends Node3D


@export var extent := 10:
	set(new_extent):
		extent = new_extent
		reload()
@export var chunk_size := 5.0


func _ready():
	reload()


func reload():
	for child in get_children():
		child.queue_free()
	
	for x in range(-extent / 2, extent):
		for y in range(-extent / 2, extent):
			var chunk = preload("res://grass_chunk.tscn").instantiate()
			
			chunk.position = Vector3(
				chunk_size * x,
				0.0,
				chunk_size * y
			)
			
			add_child(chunk)
