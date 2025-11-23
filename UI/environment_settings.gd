extends VBoxContainer

signal inject_env(data)

func _on_button_pressed() -> void:
	# Collect data from boxes and send to be hit
	var data = {}
	
	data["Altitude"] = float($AltitudeText.text)
	data["Temp"] = float($TemperatureText.text)
	
	emit_signal("inject_env", data)
