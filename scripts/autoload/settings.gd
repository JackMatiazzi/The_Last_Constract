extends Node

signal input_device_changed

enum InputDevice { KEYBOARD_MOUSE, GAMEPAD, AUTOMATIC }

const PATH := "user://settings.cfg"
# tremida do mouse na mesa nao tira do modo controle
const MOUSE_SWITCH_DISTANCE := 4.0
const SECTION := "settings"
const GAMEPLAY_ACTIONS := ["move_forward", "move_back", "move_left", "move_right", "attack", "secondary",
		"run", "look_left", "look_right", "look_up", "look_down", "interact", "decline", "scoreboard",
		"next_ability", "next_item"]

var master_volume := 1.0
var music_volume := 0.8
var sfx_volume := 1.0
var fullscreen := false
var vsync := true
var mouse_sensitivity := 1.0
var invert_y := false
var input_device := InputDevice.AUTOMATIC
var stick_sensitivity := 1.0
var player_name := "Aventureiro"

var _applied_device := -1
var _last_used_gamepad := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	_apply()


func set_value(key: StringName, value: Variant) -> void:
	set(key, value)
	_apply()
	_save()


func _apply() -> void:
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	if input_device != _applied_device:
		_applied_device = input_device
		_apply_input_device()
		input_device_changed.emit()


func uses_gamepad() -> bool:
	if input_device == InputDevice.AUTOMATIC:
		return _last_used_gamepad
	return input_device == InputDevice.GAMEPAD


func _input(event: InputEvent) -> void:
	if input_device != InputDevice.AUTOMATIC:
		return
	var gamepad: bool = _is_gamepad_event(event) and (event is InputEventJoypadButton or absf(event.axis_value) > 0.5)
	var moved_mouse: bool = event is InputEventMouseMotion and event.screen_relative.length() > MOUSE_SWITCH_DISTANCE
	var keyboard_mouse: bool = event is InputEventKey or event is InputEventMouseButton or moved_mouse
	if (gamepad and not _last_used_gamepad) or (keyboard_mouse and _last_used_gamepad):
		_last_used_gamepad = gamepad
		input_device_changed.emit()


# le do project.godot porque o InputMap ja esta filtrado e perderia o outro dispositivo
func _apply_input_device() -> void:
	for action: String in GAMEPLAY_ACTIONS:
		InputMap.action_erase_events(action)
		for event: InputEvent in ProjectSettings.get_setting("input/" + action)["events"]:
			if input_device == InputDevice.AUTOMATIC or _is_gamepad_event(event) == uses_gamepad():
				InputMap.action_add_event(action, event)


static func _is_gamepad_event(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


func _set_bus_volume(bus: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index != -1:
		AudioServer.set_bus_volume_db(index, linear_to_db(linear))


func _keys() -> PackedStringArray:
	return ["master_volume", "music_volume", "sfx_volume", "fullscreen", "vsync", "mouse_sensitivity", "invert_y", "input_device", "stick_sensitivity", "player_name"]


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	for key in _keys():
		set(key, config.get_value(SECTION, key, get(key)))


func _save() -> void:
	var config := ConfigFile.new()
	for key in _keys():
		config.set_value(SECTION, key, get(key))
	var error := config.save(PATH)
	if error != OK:
		push_error("Nao foi possivel salvar as configuracoes: %s" % error_string(error))
