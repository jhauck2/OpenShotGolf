extends VBoxContainer

signal inject(data)

@export var default_payload_path := "res://assets/data/drive_test_shot.json"

@onready var payload_option: OptionButton = $PayloadOption

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_populate_payloads()
	_apply_payload(default_payload_path)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _populate_payloads() -> void:
	if not payload_option:
		return
	payload_option.clear()
	var payloads := {
		"Approach": "res://assets/data/approach_test_shot.json",
		"Driver": "res://assets/data/drive_test_shot.json",
		"Wood Low Flight": "res://assets/data/wood_low_test_shot.json",
		"Wedge": "res://assets/data/wedge_test_shot.json",
		"Bump & Run": "res://assets/data/bump_test_shot.json",
	}
	var selected := 0
	var idx := 0
	for label in payloads.keys():
		var path: String = payloads[label]
		payload_option.add_item(label)
		payload_option.set_item_metadata(idx, path)
		if path == default_payload_path:
			selected = idx
		idx += 1
	payload_option.select(selected)


func _apply_payload(_payload_path: String) -> void:
	var file := FileAccess.open(_payload_path, FileAccess.READ)
	if file:
		var json_text := file.get_as_text()
		var json := JSON.new()
		if json.parse(json_text) == OK:
			var parsed = json.data
			if parsed.has("BallData"):
				var data = parsed["BallData"].duplicate()
				$SpeedSpinBox.value = float(data["Speed"])
				$SpinAxisSpinBox.value = float(data["SpinAxis"])
				$TotalSpinSpinBox.value = float(data["TotalSpin"])
				$HLASpinBox.value = float(data["HLA"])
				$VLASpinBox.value = float(data["VLA"])
				

func _on_button_pressed() -> void:
	# Inject the spinboxes values within the shot data
	var data := {}
	data["Speed"] = $SpeedSpinBox.value
	data["SpinAxis"] = $SpinAxisSpinBox.value
	data["TotalSpin"] = $TotalSpinSpinBox.value
	data["HLA"] = $HLASpinBox.value
	data["VLA"] = $VLASpinBox.value
	
	print("Local shot injection payload: ", JSON.stringify(data))
	
	emit_signal("inject", data)


func _on_payload_option_item_selected(index: int) -> void:
	var metadata = payload_option.get_item_metadata(index)
	if typeof(metadata) == TYPE_STRING:
		_apply_payload(metadata)
