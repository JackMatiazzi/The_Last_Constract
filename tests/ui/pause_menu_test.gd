extends GdUnitTestSuite

const PAUSE_MENU := preload("res://scenes/ui/pause_menu.tscn")

var arena: TestArena
var pause: PauseMenu


func before_test() -> void:
	arena = TestArena.new(self)
	pause = PAUSE_MENU.instantiate()
	arena.root.add_child(pause)
	await arena.wait_physics(1)


func after_test() -> void:
	get_tree().paused = false


func test_open_pauses_the_game() -> void:
	pause.open()

	assert_bool(get_tree().paused).is_true()
	assert_bool(pause.main_panel.visible).is_true()


func test_close_resumes_and_emits_resumed() -> void:
	var signals := monitor_signals(pause, false)
	pause.open()

	pause.close()

	assert_bool(get_tree().paused).is_false()
	await assert_signal(signals).is_emitted("resumed")


func test_esc_inside_settings_returns_to_pause_panel() -> void:
	pause.open()
	pause.get_node("%SettingsButton").pressed.emit()
	assert_bool(pause.settings_menu.visible).is_true()

	await arena.send_action("pause")

	assert_bool(pause.settings_menu.visible).is_false()
	assert_bool(pause.main_panel.visible).is_true()
	assert_bool(get_tree().paused).is_true()


func test_abandon_requires_confirmation() -> void:
	pause.open()

	pause.get_node("%AbandonButton").pressed.emit()

	assert_bool(pause.confirm_panel.visible).is_true()
	assert_bool(pause.visible).is_true()
	assert_bool(get_tree().paused).is_true()


func test_esc_on_confirmation_cancels_abandon() -> void:
	pause.open()
	pause.get_node("%AbandonButton").pressed.emit()

	await arena.send_action("pause")

	assert_bool(pause.main_panel.visible).is_true()
	assert_bool(get_tree().paused).is_true()


func test_confirming_abandon_unpauses_and_emits() -> void:
	var signals := monitor_signals(pause, false)
	pause.open()
	pause.get_node("%AbandonButton").pressed.emit()

	pause.get_node("%ConfirmAbandonButton").pressed.emit()

	assert_bool(get_tree().paused).is_false()
	await assert_signal(signals).is_emitted("abandon_confirmed")
