extends VBoxContainer

signal inject(data)

@export var default_payload_path := "res://assets/data/drive_test_shot.json"

@onready var payload_option: OptionButton = $PayloadOption

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_populate_payloads()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _populate_payloads() -> void:
	if not payload_option:
		return
	payload_option.clear()
	var payloads := {
		"Drive test shot": "res://assets/data/drive_test_shot.json",
		"Wedge test shot": "res://assets/data/wedge_test_shot.json",
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


func _on_button_pressed() -> void:
	# Collect data from boxes and send to be hit. If empty, fall back to default JSON payload.
	var data := {}
	var loaded := false
	if default_payload_path != "":
		var file := FileAccess.open(default_payload_path, FileAccess.READ)
		if file:
			var json_text := file.get_as_text()
			var json := JSON.new()
			if json.parse(json_text) == OK:
				var parsed = json.data
				if parsed.has("BallData"):
					data = parsed["BallData"].duplicate()
					loaded = true
	
	# Override with UI entries when provided
	if $SpeedText.text.strip_edges() != "":
		data["Speed"] = float($SpeedText.text)
	if $SpinAxisText.text.strip_edges() != "":
		data["SpinAxis"] = float($SpinAxisText.text)
	if $TotalSpinText.text.strip_edges() != "":
		data["TotalSpin"] = float($TotalSpinText.text)
	if $HLAText.text.strip_edges() != "":
		data["HLA"] = float($HLAText.text)
	if $VLAText.text.strip_edges() != "":
		data["VLA"] = float($VLAText.text)
	if has_node("BackSpinText"):
		var back_node = $BackSpinText
		if back_node.text.strip_edges() != "":
			data["BackSpin"] = float(back_node.text)
	if has_node("SideSpinText"):
		var side_node = $SideSpinText
		if side_node.text.strip_edges() != "":
			data["SideSpin"] = float(side_node.text)
	
	if data.is_empty():
		print("Shot injector: no data provided and default payload missing; using zeros")
	
	if loaded:
		print("Shot injector: loaded default payload from ", default_payload_path)
	print("Local shot injection payload: ", JSON.stringify(data))
	
	emit_signal("inject", data)


func _on_payload_option_item_selected(index: int) -> void:
	var metadata = payload_option.get_item_metadata(index)
	if typeof(metadata) == TYPE_STRING:
		default_payload_path = metadata
