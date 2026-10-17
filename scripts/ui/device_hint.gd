class_name DeviceHint
extends Label

@export_multiline var keyboard_text := ""
@export_multiline var gamepad_text := ""


func _ready() -> void:
	Settings.input_device_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	text = gamepad_text if Settings.uses_gamepad() else keyboard_text
