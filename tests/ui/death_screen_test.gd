extends GdUnitTestSuite

const DEATH_SCREEN := preload("res://scenes/ui/death_screen.tscn")

var arena: TestArena
var screen: DeathScreen


func before_test() -> void:
	RunState.reset()
	arena = TestArena.new(self)
	screen = DEATH_SCREEN.instantiate()
	arena.root.add_child(screen)


func after_test() -> void:
	RunState.reset()


# a sessao abre a votacao quando o grupo inteiro cai
func _kill_and_wait_for_screen() -> void:
	screen.open_vote(RunState.roll_choices(), true)
	await arena.wait_seconds(DeathScreen.SHOW_DELAY + 0.2)


func test_opens_only_after_death_animation() -> void:
	screen.open_vote(RunState.roll_choices(), true)
	await arena.wait_physics(2)
	assert_bool(screen.visible).is_false()

	await arena.wait_seconds(DeathScreen.SHOW_DELAY)

	assert_bool(screen.visible).is_true()
	assert_bool(screen.death_panel.visible).is_true()


func test_shows_attempt_and_accumulated_buffs() -> void:
	RunState.start_next_attempt(load("res://resources/buffs/couraca.tres"))

	await _kill_and_wait_for_screen()

	assert_str(screen.attempt_label.text).is_equal("Tentativa 2")
	assert_str(screen.active_buffs_label.text).contains("Couraça")


func test_give_up_asks_for_confirmation_and_can_cancel() -> void:
	await _kill_and_wait_for_screen()

	screen.get_node("%GiveUpButton").pressed.emit()
	assert_bool(screen.confirm_panel.visible).is_true()
	screen.get_node("%CancelGiveUpButton").pressed.emit()

	assert_bool(screen.death_panel.visible).is_true()


func test_confirmed_give_up_is_reported() -> void:
	await _kill_and_wait_for_screen()
	var signals := monitor_signals(screen, false)

	screen.get_node("%GiveUpButton").pressed.emit()
	screen.get_node("%ConfirmGiveUpButton").pressed.emit()

	await assert_signal(signals).is_emitted("gave_up")


func test_revive_offers_two_different_cards() -> void:
	await _kill_and_wait_for_screen()

	screen.get_node("%ReviveButton").pressed.emit()
	await arena.wait_physics(1)

	var cards := screen.cards.get_children()
	assert_int(cards.size()).is_equal(2)
	assert_object(cards[0].buff).is_not_same(cards[1].buff)


func test_key_1_chooses_first_card() -> void:
	await _kill_and_wait_for_screen()
	screen.get_node("%ReviveButton").pressed.emit()
	await arena.wait_physics(1)
	var first: Buff = screen.cards.get_child(0).buff
	var signals := monitor_signals(screen, false)

	await arena.send_key(KEY_1)

	await assert_signal(signals).is_emitted("revive_chosen", [first])


func test_clicking_a_card_chooses_it() -> void:
	await _kill_and_wait_for_screen()
	screen.get_node("%ReviveButton").pressed.emit()
	await arena.wait_physics(1)
	var second: BuffCard = screen.cards.get_child(1)
	var signals := monitor_signals(screen, false)

	second.pressed.emit()

	await assert_signal(signals).is_emitted("revive_chosen", [second.buff])


func test_only_the_host_can_give_up() -> void:
	screen.open_vote(RunState.roll_choices(), false)
	await arena.wait_seconds(DeathScreen.SHOW_DELAY + 0.2)

	assert_bool(screen.get_node("%GiveUpButton").visible).is_false()


func test_shows_the_damage_recap() -> void:
	screen.set_recap("Dano recebido: 14")
	await _kill_and_wait_for_screen()

	assert_bool(screen.get_node("%RecapLabel").visible).is_true()
	assert_str(screen.get_node("%RecapLabel").text).is_equal("Dano recebido: 14")
