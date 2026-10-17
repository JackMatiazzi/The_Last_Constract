extends GdUnitTestSuite

var hint: DeviceHint
var _device_before: int


func before_test() -> void:
	_device_before = Settings.input_device
	Settings.set_value(&"input_device", Settings.InputDevice.KEYBOARD_MOUSE)
	hint = auto_free(DeviceHint.new())
	hint.keyboard_text = "Esc"
	hint.gamepad_text = "Start"
	add_child(hint)


func after_test() -> void:
	Settings.set_value(&"input_device", _device_before)


func test_shows_the_keyboard_text_by_default() -> void:
	assert_str(hint.text).is_equal("Esc")


func test_switches_when_the_player_picks_the_gamepad() -> void:
	Settings.set_value(&"input_device", Settings.InputDevice.GAMEPAD)

	assert_str(hint.text).is_equal("Start")
