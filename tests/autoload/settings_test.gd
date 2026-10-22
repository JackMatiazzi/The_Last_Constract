extends GdUnitTestSuite

# devolve as preferencias reais do jogador no fim de cada teste

const KEYS := ["master_volume", "music_volume", "sfx_volume", "fullscreen", "vsync", "mouse_sensitivity", "invert_y", "input_device", "stick_sensitivity"]

var _backup := {}


func before_test() -> void:
	for key in KEYS:
		_backup[key] = Settings.get(key)


func after_test() -> void:
	for key in _backup:
		Settings.set_value(key, _backup[key])


func test_set_value_saves_to_disk() -> void:
	Settings.set_value(&"mouse_sensitivity", 2.5)

	var config := ConfigFile.new()
	assert_int(config.load(Settings.PATH)).is_equal(OK)
	assert_float(config.get_value(Settings.SECTION, "mouse_sensitivity")).is_equal(2.5)


func test_saved_values_come_back_on_next_start() -> void:
	Settings.set_value(&"invert_y", true)

	var next_start: Node = auto_free(load("res://scripts/autoload/settings.gd").new())
	add_child(next_start)

	assert_bool(next_start.invert_y).is_true()


func test_volume_is_applied_to_audio_bus() -> void:
	Settings.set_value(&"music_volume", 0.5)

	var bus := AudioServer.get_bus_index("Music")
	assert_float(AudioServer.get_bus_volume_db(bus)).is_equal_approx(linear_to_db(0.5), 0.01)


func _has_gamepad_event(action: String) -> bool:
	return InputMap.action_get_events(action).any(func(event: InputEvent) -> bool:
		return event is InputEventJoypadButton or event is InputEventJoypadMotion)


func _has_keyboard_or_mouse_event(action: String) -> bool:
	return InputMap.action_get_events(action).any(func(event: InputEvent) -> bool:
		return event is InputEventKey or event is InputEventMouseButton)


func test_gamepad_mode_keeps_only_gamepad_bindings_on_gameplay_actions() -> void:
	Settings.set_value(&"input_device", Settings.InputDevice.GAMEPAD)

	for action in ["move_forward", "run", "attack", "secondary"]:
		assert_bool(_has_gamepad_event(action)).override_failure_message(action).is_true()
		assert_bool(_has_keyboard_or_mouse_event(action)).override_failure_message(action).is_false()


func test_keyboard_mode_gets_its_bindings_back() -> void:
	Settings.set_value(&"input_device", Settings.InputDevice.GAMEPAD)
	Settings.set_value(&"input_device", Settings.InputDevice.KEYBOARD_MOUSE)

	for action in ["move_forward", "run", "attack", "secondary"]:
		assert_bool(_has_keyboard_or_mouse_event(action)).override_failure_message(action).is_true()
		assert_bool(_has_gamepad_event(action)).override_failure_message(action).is_false()


func test_menus_accept_both_devices_in_any_mode() -> void:
	Settings.set_value(&"input_device", Settings.InputDevice.KEYBOARD_MOUSE)

	assert_bool(_has_gamepad_event("pause")).is_true()
	assert_bool(_has_keyboard_or_mouse_event("pause")).is_true()


func test_announces_device_change() -> void:
	Settings.set_value(&"input_device", Settings.InputDevice.KEYBOARD_MOUSE)
	var signals := monitor_signals(Settings, false)

	Settings.set_value(&"input_device", Settings.InputDevice.GAMEPAD)

	await assert_signal(signals).is_emitted("input_device_changed")


func test_automatic_mode_keeps_both_bindings() -> void:
	Settings.set_value(&"input_device", Settings.InputDevice.AUTOMATIC)

	assert_bool(_has_gamepad_event("attack")).is_true()
	assert_bool(_has_keyboard_or_mouse_event("attack")).is_true()


func test_automatic_mode_follows_the_last_device_used() -> void:
	Settings.set_value(&"input_device", Settings.InputDevice.AUTOMATIC)
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true

	Input.parse_input_event(button)
	await await_idle_frame()
	assert_bool(Settings.uses_gamepad()).is_true()

	Input.parse_input_event(key)
	await await_idle_frame()
	assert_bool(Settings.uses_gamepad()).is_false()

	button.pressed = false
	Input.parse_input_event(button)
	key.pressed = false
	Input.parse_input_event(key)


func test_automatic_mode_ignores_a_shaky_mouse() -> void:
	Settings.set_value(&"input_device", Settings.InputDevice.AUTOMATIC)
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	var jitter := InputEventMouseMotion.new()
	jitter.relative = Vector2(1, 1)
	jitter.screen_relative = Vector2(1, 1)

	Input.parse_input_event(stick)
	Input.parse_input_event(jitter)
	await await_idle_frame()

	assert_bool(Settings.uses_gamepad()).is_true()
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
