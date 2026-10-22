extends GdUnitTestSuite

const HEALTH_POTION := preload("res://resources/items/health_potion.tres")

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
	Input.action_release("interact")
	Settings.set_value(&"input_device", _device_before)


func _mana_potion() -> QuickItem:
	var item := QuickItem.new()
	item.title = "Poção de mana"
	item.mana_amount = 30.0
	return item


func test_holding_interact_drinks_the_selected_potion() -> void:
	knight.inventory.add(HEALTH_POTION)
	knight.take_damage(5.0)

	await arena.send_action("interact")
	await arena.wait_seconds(Adventurer.DRINK_HOLD_TIME + 0.15)

	assert_float(knight.health).is_equal(5.0 + HEALTH_POTION.heal_amount)
	assert_object(knight.inventory.selected()).is_null()


func test_a_quick_tap_on_interact_does_not_drink() -> void:
	knight.inventory.add(HEALTH_POTION)
	knight.take_damage(5.0)

	await arena.send_action("interact")
	await arena.send_action("interact", false)
	await arena.wait_seconds(Adventurer.DRINK_HOLD_TIME + 0.15)

	assert_float(knight.health).is_equal(5.0)
	assert_int(knight.inventory.count_of(HEALTH_POTION)).is_equal(1)


func test_a_potion_is_not_wasted_at_full_health() -> void:
	knight.inventory.add(HEALTH_POTION)

	assert_bool(knight.use_item()).is_false()
	assert_int(knight.inventory.count_of(HEALTH_POTION)).is_equal(1)


func test_carrying_is_limited_per_item() -> void:
	for i in HEALTH_POTION.max_carried:
		assert_bool(knight.inventory.add(HEALTH_POTION)).is_true()

	assert_bool(knight.inventory.add(HEALTH_POTION)).is_false()


func test_wheel_down_cycles_the_quick_items() -> void:
	var mana_potion := _mana_potion()
	knight.inventory.add(HEALTH_POTION)
	knight.inventory.add(mana_potion)
	assert_object(knight.inventory.selected()).is_same(HEALTH_POTION)

	await arena.send_action("next_item")
	assert_object(knight.inventory.selected()).is_same(mana_potion)

	await arena.send_action("next_item")
	assert_object(knight.inventory.selected()).is_same(HEALTH_POTION)


func test_mana_potion_restores_the_mage_mana() -> void:
	var mage := arena.spawn(TestArena.MAGE, Vector3(4, 0, 0)) as Adventurer
	await arena.wait_physics(2)
	var mana_potion := _mana_potion()
	mage.inventory.add(mana_potion)
	mage.mana.spend(50.0)

	assert_bool(mage.use_item()).is_true()
	assert_float(mage.mana.current).is_equal_approx(80.0, 0.01)


func test_wheel_up_cycles_the_abilities() -> void:
	var second := knight.attack.duplicate() as Attack
	knight.attack.get_parent().add_child(second)
	knight.abilities.append(second)
	var first := knight.attack

	await arena.send_action("next_ability")
	assert_object(knight.attack).is_same(second)

	await arena.send_action("next_ability")
	assert_object(knight.attack).is_same(first)


func test_hud_cross_shows_ability_secondary_and_quick_item() -> void:
	var hud: Hud = auto_free(preload("res://scenes/ui/hud.tscn").instantiate())
	arena.root.add_child(hud)
	hud.bind(knight)

	assert_object(hud.ability_icon.texture).is_same(knight.attack.icon)
	assert_str(hud.ability_cost.text).is_equal("15%")
	assert_str(hud.ability_name.text).is_equal("Espada\nestamina")
	assert_bool(hud.get_node("%SecondarySlot").visible).is_true()
	assert_object(hud.secondary_icon.texture).is_same(knight.block.icon)
	assert_object(hud.item_icon.texture).is_null()
	assert_str(hud.item_hint.text).is_equal("Sem itens")

	knight.inventory.add(HEALTH_POTION)
	assert_object(hud.item_icon.texture).is_same(HEALTH_POTION.icon)
	assert_str(hud.item_count.text).is_equal("×1")
	assert_str(hud.item_hint.text).is_equal("Poção de vida\nsegure X")


func test_every_ability_and_item_has_an_icon() -> void:
	for scene_path in [TestArena.KNIGHT, TestArena.BARBARIAN, TestArena.MAGE, TestArena.ROGUE]:
		var adventurer := arena.spawn(scene_path, Vector3(8, 0, 0)) as Adventurer
		for ability in adventurer.abilities:
			assert_object(ability.icon).is_not_null()
		adventurer.queue_free()
	assert_object(HEALTH_POTION.icon).is_not_null()


func test_near_a_fallen_ally_with_a_potion_the_revive_prompt_appears() -> void:
	var ally := arena.spawn(TestArena.MAGE, Vector3(1.5, 0, 0)) as Adventurer
	await arena.wait_physics(2)
	ally.take_damage(99.0)
	await arena.wait_physics(2)
	assert_str(ally.revive_hint.text).is_equal("Sem poção para reviver")

	knight.inventory.add(HEALTH_POTION)
	await arena.wait_physics(2)
	assert_bool(ally.revive_hint.visible).is_true()
	assert_str(ally.revive_hint.text).contains("Reviver")

	await arena.send_action("interact")
	assert_bool(ally.is_dead).is_false()
	assert_bool(ally.revive_hint.visible).is_false()
	assert_int(knight.inventory.count_of(HEALTH_POTION)).is_equal(0)


func test_near_a_fallen_ally_without_a_potion_the_hint_says_so() -> void:
	var ally := arena.spawn(TestArena.MAGE, Vector3(1.5, 0, 0)) as Adventurer
	await arena.wait_physics(2)
	ally.take_damage(99.0)
	await arena.wait_physics(2)

	assert_bool(ally.revive_hint.visible).is_true()
	assert_str(ally.revive_hint.text).is_equal("Sem poção para reviver")
	await arena.send_action("interact")
	assert_bool(ally.is_dead).is_true()


func test_reviving_an_ally_that_already_got_up_keeps_the_potion() -> void:
	var ally := arena.spawn(TestArena.MAGE, Vector3(1.5, 0, 0)) as Adventurer
	await arena.wait_physics(2)
	ally.take_damage(99.0)
	knight.inventory.add(HEALTH_POTION)
	await arena.wait_physics(2)
	ally.revive(5.0)

	knight.revive_ally()

	assert_int(knight.inventory.count_of(HEALTH_POTION)).is_equal(1)


func test_spending_an_earlier_item_keeps_the_selection() -> void:
	var mana_potion := _mana_potion()
	knight.inventory.add(HEALTH_POTION)
	knight.inventory.add(mana_potion)
	knight.inventory.select_next()
	assert_object(knight.inventory.selected()).is_same(mana_potion)

	knight.take_damage(5.0)
	knight.inventory.take(HEALTH_POTION)

	assert_object(knight.inventory.selected()).is_same(mana_potion)


func test_binding_the_hud_twice_does_not_double_the_signals() -> void:
	var hud: Hud = auto_free(preload("res://scenes/ui/hud.tscn").instantiate())
	arena.root.add_child(hud)
	hud.bind(knight)
	var connections := knight.inventory.changed.get_connections().size()

	hud.bind(knight)

	assert_int(knight.inventory.changed.get_connections().size()).is_equal(connections)


func test_holding_interact_fills_the_drink_progress() -> void:
	knight.inventory.add(HEALTH_POTION)
	knight.take_damage(5.0)

	await arena.send_action("interact")
	await arena.wait_seconds(Adventurer.DRINK_HOLD_TIME * 0.5)

	assert_float(knight.drink_progress()).is_between(0.2, 0.9)


func test_near_something_to_interact_holding_e_does_not_drink() -> void:
	knight.inventory.add(HEALTH_POTION)
	knight.take_damage(5.0)
	knight.interactables_in_reach = 1

	await arena.send_action("interact")
	await arena.wait_seconds(Adventurer.DRINK_HOLD_TIME + 0.15)

	assert_int(knight.inventory.count_of(HEALTH_POTION)).is_equal(1)
