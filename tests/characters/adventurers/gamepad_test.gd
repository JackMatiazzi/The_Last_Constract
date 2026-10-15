extends GdUnitTestSuite

var arena: TestArena
var knight: Adventurer
var _device_before: int


func before_test() -> void:
	RunState.reset()
	_device_before = Settings.input_device
	Settings.set_value(&"input_device", Settings.InputDevice.GAMEPAD)
	arena = TestArena.new(self)
	knight = arena.spawn(TestArena.KNIGHT, Vector3.ZERO) as Adventurer
	await arena.wait_physics(3)


func after_test() -> void:
	for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_TRIGGER_RIGHT]:
		_axis(axis, 0.0)
	Settings.set_value(&"input_device", _device_before)


func _axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)


func _button(button: JoyButton, pressed := true) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)


# espera ate o efeito aparecer: num runner lento o numero de quadros ate o evento chegar varia
func _until(condition: Callable, seconds := 0.5) -> bool:
	for i in ceili(seconds * Engine.physics_ticks_per_second):
		if condition.call():
			return true
		await arena.wait_physics(1)
	return condition.call()


func test_right_stick_turns_the_camera() -> void:
	var yaw := knight.camera_pivot.rotation.y

	_axis(JOY_AXIS_RIGHT_X, 1.0)
	await arena.wait_seconds(0.3)

	assert_float(absf(knight.camera_pivot.rotation.y - yaw)).is_greater(0.4)


func test_left_stick_walks() -> void:
	_axis(JOY_AXIS_LEFT_Y, -1.0)
	await arena.wait_seconds(0.4)

	assert_float(Vector2(knight.velocity.x, knight.velocity.z).length()).is_equal_approx(knight.walk_speed, 0.3)


func test_clicking_the_left_stick_runs_until_the_stick_is_released() -> void:
	_axis(JOY_AXIS_LEFT_Y, -1.0)
	_button(JOY_BUTTON_LEFT_STICK)
	_button(JOY_BUTTON_LEFT_STICK, false)
	await arena.wait_seconds(0.6)
	assert_float(Vector2(knight.velocity.x, knight.velocity.z).length()).is_greater(knight.walk_speed + 0.5)

	_axis(JOY_AXIS_LEFT_Y, 0.0)
	await arena.wait_physics(2)
	_axis(JOY_AXIS_LEFT_Y, -1.0)
	await arena.wait_seconds(0.6)

	assert_float(Vector2(knight.velocity.x, knight.velocity.z).length()).is_equal_approx(knight.walk_speed, 0.3)


func test_right_trigger_attacks() -> void:
	_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)

	assert_bool(await _until(func() -> bool: return knight.is_busy)).is_true()


func test_a_jumps() -> void:
	_button(JOY_BUTTON_A)
	var jumped: bool = await _until(func() -> bool: return knight.velocity.y > 0.0)
	_button(JOY_BUTTON_A, false)

	assert_bool(jumped).is_true()


func test_keyboard_mode_ignores_the_gamepad() -> void:
	Settings.set_value(&"input_device", Settings.InputDevice.KEYBOARD_MOUSE)
	var yaw := knight.camera_pivot.rotation.y

	_axis(JOY_AXIS_RIGHT_X, 1.0)
	_axis(JOY_AXIS_LEFT_Y, -1.0)
	await arena.wait_seconds(0.3)

	assert_float(absf(angle_difference(knight.camera_pivot.rotation.y, yaw))).is_less(0.001)
	assert_float(Vector2(knight.velocity.x, knight.velocity.z).length()).is_less(0.05)
