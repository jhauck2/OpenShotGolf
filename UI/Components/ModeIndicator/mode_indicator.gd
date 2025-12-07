@tool
extends Control

signal pressed

var InfoItemScene := preload("res://UI/Components/ModeIndicator/ModeIndicatorItem/mode_indicator_item.tscn")
var BorderItemScene := preload("res://UI/Components/ModeIndicator/ModeIndicatorItem/border_item.tscn")

@onready var main_button: Button = %ModeButton
@onready var title_label: Label = %ModeLabel
@onready var sub_label: Label = %InfoLabel
@onready var icon_label: TextureRect = %ModeIcon
@onready var info_container := %InfoContainer

@export var info_items: Array[InfoItem] = []:
	set(value):
		info_items = value
		_rebuild_info_items()

func _ready() -> void:
	main_button.pressed.connect(_on_internal_pressed)
	title_label.text = title
	sub_label.text = subtitle
	icon_label.texture = icon

func _on_internal_pressed() -> void:
	emit_signal("pressed")

# ---------------------------
# PUBLIC API (Inspector-safe)
# ---------------------------

@export var title: String:
	set(value):
		title = value
		if title_label:
			title_label.text = value
	get:
		return title

@export var subtitle: String:
	set(value):
		subtitle = value
		if sub_label:
			sub_label.text = value
	get:
		return subtitle

@export var icon: Texture2D:
	set(value):
		icon = value
		if icon_label:
			icon_label.texture = value
	get:
		return icon
		
@export var icon_tint: Color = Color("3498DB"):
	set(value):
		icon_tint = value
		if icon_label:
			icon_label.modulate = value
	get:
		return icon_tint



# ---------------------------
# INFO CONTAINER API
# ---------------------------
func set_info_items(new_items: Array[InfoItem]):
	info_items.clear()
	info_items.append_array(new_items)
	_rebuild_info_items()


func _rebuild_info_items():
	if not info_container:
		return
		
	queue_free_children(info_container)

	for item: InfoItem in info_items:
		var inst = InfoItemScene.instantiate()
		var border = BorderItemScene.instantiate()
		info_container.add_child(inst)
		info_container.add_child(border)
		inst.set_info(item.title, item.value)
		

func queue_free_children(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()
