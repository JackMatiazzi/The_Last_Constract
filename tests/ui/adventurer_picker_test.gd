extends GdUnitTestSuite

const PICKER := preload("res://scenes/ui/adventurer_picker.tscn")

var picker: AdventurerPicker


func before_test() -> void:
	picker = auto_free(PICKER.instantiate())
	add_child(picker)
	await await_idle_frame()


func _press(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await await_idle_frame()


func test_shows_one_card_per_adventurer_in_roster_order() -> void:
	var titles: Array = picker.cards.get_children().map(func(card: Button) -> String: return card.text)

	assert_int(titles.size()).is_equal(RunState.ADVENTURERS.size())
	assert_str(titles[0]).contains("Knight")
	assert_str(titles[3]).contains("Rogue")


func test_starts_with_first_adventurer_selected() -> void:
	assert_str(picker.selected.title).is_equal("Knight")
	assert_str(picker.name_label.text).is_equal("Knight")


func test_clicking_a_card_shows_its_details() -> void:
	var signals := monitor_signals(picker, false)

	(picker.cards.get_child(2) as Button).pressed.emit()

	assert_str(picker.name_label.text).is_equal("Mage")
	assert_str(picker.attack_label.text).is_equal(picker.selected.attack_name)
	assert_str(picker.description_label.text).is_equal(picker.selected.description)
	await assert_signal(signals).is_emitted("selection_changed", [picker.selected])


func test_number_keys_select_directly() -> void:
	await _press(KEY_4)

	assert_str(picker.selected.title).is_equal("Rogue")


func test_arrow_keys_cycle_and_wrap() -> void:
	await _press(KEY_LEFT)
	assert_str(picker.selected.title).is_equal("Rogue")

	await _press(KEY_RIGHT)
	assert_str(picker.selected.title).is_equal("Knight")


func test_accept_confirms_selected_adventurer() -> void:
	(picker.cards.get_child(1) as Button).pressed.emit()
	var signals := monitor_signals(picker, false)

	picker.get_node("%AcceptButton").pressed.emit()

	await assert_signal(signals).is_emitted("confirmed", [picker.selected])
	assert_str(picker.selected.title).is_equal("Barbarian")


func test_back_button_asks_to_leave() -> void:
	var signals := monitor_signals(picker, false)

	picker.get_node("%BackButton").pressed.emit()

	await assert_signal(signals).is_emitted("back_requested")


func _joy_button(button: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
	await await_idle_frame()


func test_dpad_and_bumpers_cycle_adventurers() -> void:
	await _joy_button(JOY_BUTTON_DPAD_RIGHT)
	assert_int(picker.selected_index).is_equal(1)

	await _joy_button(JOY_BUTTON_RIGHT_SHOULDER)
	assert_int(picker.selected_index).is_equal(2)

	await _joy_button(JOY_BUTTON_LEFT_SHOULDER)
	assert_int(picker.selected_index).is_equal(1)


func test_holding_the_stick_moves_only_one_step() -> void:
	for value in [0.6, 0.8, 1.0, 1.0]:
		var event := InputEventJoypadMotion.new()
		event.axis = JOY_AXIS_LEFT_X
		event.axis_value = value
		Input.parse_input_event(event)
	await await_idle_frame()

	var release := InputEventJoypadMotion.new()
	release.axis = JOY_AXIS_LEFT_X
	Input.parse_input_event(release)
	await await_idle_frame()

	assert_int(picker.selected_index).is_equal(1)


func test_b_asks_to_leave() -> void:
	var signals := monitor_signals(picker, false)

	await _joy_button(JOY_BUTTON_B)

	await assert_signal(signals).is_emitted("back_requested")
