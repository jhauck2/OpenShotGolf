extends Node3D

@export var label_text: int = 150
@export var pole_height := 3.0

@export var flag_color := Color.GREEN_YELLOW
@export var pole_color := Color.WHITE

@onready var pole := $PoleMesh
@onready var flag := $FlagMesh


func _ready():
	_apply_height()
	_apply_color()

func _apply_height():
	var mesh := pole.mesh as CylinderMesh
	mesh.height = pole_height
	pole.position.y = pole_height / 2.0


func _apply_color():
	set_pole_color(pole_color)
	set_flag_color(flag_color)
	
func set_pole_color(c: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	pole.material_override = mat

func set_flag_color(c: Color) -> void:
	var mat : ShaderMaterial = flag.get_active_material(0)

	if mat:
		var unique_mat = mat.duplicate() as ShaderMaterial
		flag.set_surface_override_material(0, unique_mat)
		
		unique_mat.set_shader_parameter("flag_color", c)



func _process(_delta):
	pass
