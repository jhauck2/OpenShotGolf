extends VBoxContainer

signal inject(data)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_button_pressed() -> void:
	# Collect data from boxes and send to be hit
	var data = {}
	data["Speed"] = float($SpeedText.text)
	data["SpinAxis"] = float($SpinAxisText.text)
	data["TotalSpin"] = float($TotalSpinText.text)
	data["HLA"] = float($HLAText.text)
	data["VLA"] = float($VLAText.text)
	data["Altitude"] = float($AltitudeText.text)
	data["Temp"] = float($TemperatureText.text)
	
	emit_signal("inject", data)
