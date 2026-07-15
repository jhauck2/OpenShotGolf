extends HBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$ResetSpinBox.step = 0.5
	$ResetSpinBox.value = GlobalSettingsManager.range_settings.ball_reset_timer.value
	$ResetSpinBox.min_value = GlobalSettingsManager.range_settings.ball_reset_timer.min_value
	$ResetSpinBox.max_value = GlobalSettingsManager.range_settings.ball_reset_timer.max_value


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_reset_spin_box_value_changed(value: float) -> void:
	GlobalSettingsManager.range_settings.ball_reset_timer.set_value(value)
	pass
