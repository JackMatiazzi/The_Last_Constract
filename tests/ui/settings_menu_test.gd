extends GdUnitTestSuite

const MENU := preload("res://scenes/ui/settings_menu.tscn")

var menu: SettingsMenu
var _device_before: int


func before_test() -> void:
	_device_before = Settings.input_device
	menu = auto_free(MENU.instantiate())
	add_child(menu)
	menu.open()
	await await_idle_frame()


func after_test() -> void:
	Settings.set_value(&"input_device", _device_before)


func _joy_button(button: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
	await await_idle_frame()


func test_choosing_controle_switches_to_the_gamepad() -> void:
	var index := menu.device_option.get_item_index(Settings.InputDevice.GAMEPAD)
	menu.device_option.select(index)
	menu.device_option.item_selected.emit(index)

	assert_bool(Settings.uses_gamepad()).is_true()


func test_bumpers_switch_tabs() -> void:
	await _joy_button(JOY_BUTTON_RIGHT_SHOULDER)
	assert_int(menu.get_node("%Tabs").current_tab).is_equal(1)

	await _joy_button(JOY_BUTTON_LEFT_SHOULDER)
	await _joy_button(JOY_BUTTON_LEFT_SHOULDER)
	assert_int(menu.get_node("%Tabs").current_tab).is_equal(2)


func test_b_closes_the_menu() -> void:
	await _joy_button(JOY_BUTTON_B)

	assert_bool(menu.visible).is_false()
