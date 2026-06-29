extends PanelContainer
@export var label: String = "Label"
@export var data: String = "---"
@export var units: String = "units"
signal drag_started
signal drag_ended(panel: Control)
var dragging := false
var drag_offset := Vector2.ZERO

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_label(label)
	set_data(data)
	set_units(units)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func set_label(l: String) -> void:
	label = l
	$VBoxContainer/Label.text = l
	

func set_data(value: String) -> void:
	data = value
	$VBoxContainer/Data.text = value
	

func set_units(u: String) -> void:
	units = u
	$VBoxContainer/Units.text = units
	
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				emit_signal("drag_started")
				dragging = true
				drag_offset = get_global_mouse_position() - global_position
			else:
				emit_signal("drag_ended", self)
				dragging = false
	elif event is InputEventMouseMotion and dragging:
		global_position = get_global_mouse_position() - drag_offset
