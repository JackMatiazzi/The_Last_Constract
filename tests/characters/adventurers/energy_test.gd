extends GdUnitTestSuite

var arena: TestArena
var knight: Adventurer
var skeleton: Character
var _device_before: int


func before_test() -> void:
	RunState.reset()
	_device_before = Settings.input_device
	# no modo controle o personagem aceita o ataque sem capturar o mouse
	Settings.set_value(&"input_device", Settings.InputDevice.GAMEPAD)
	arena = TestArena.new(self)
	knight = arena.spawn(TestArena.KNIGHT, Vector3.ZERO) as Adventurer
	skeleton = arena.spawn(TestArena.SKELETON, Vector3(0, 0, 1.2))
	await arena.wait_physics(3)


func after_test() -> void:
	for action in ["attack", "move_forward", "run"]:
		Input.action_release(action)
	Settings.set_value(&"input_device", _device_before)


func _tap_attack() -> void:
	await arena.send_action("attack")
	await arena.send_action("attack", false)


func test_a_quick_click_is_a_quick_attack_and_spends_its_cost() -> void:
	await _tap_attack()

	assert_bool(knight.is_busy).is_true()
	assert_str(knight.animation_player.current_animation).is_equal(knight.attack.animations[0])
	assert_float(knight.stamina.current).is_equal_approx(knight.stamina.maximum - knight.quick_cost, 0.5)


func test_holding_the_button_becomes_a_heavy_attack() -> void:
	await arena.send_action("attack")
	await arena.wait_seconds(Adventurer.HEAVY_HOLD_TIME + 0.1)

	assert_str(knight.animation_player.current_animation).is_equal(knight.attack.heavy_animation)
	assert_float(knight.stamina.current).is_equal_approx(knight.stamina.maximum - knight.heavy_cost, 0.5)


func test_heavy_attack_hits_harder_than_quick() -> void:
	knight.heavy_attack()
	await arena.wait_seconds(knight.attack.heavy_impact_delay + 0.1)

	assert_float(skeleton.health).is_equal_approx(5.0 - knight.attack.damage * knight.attack.heavy_damage_multiplier, 0.01)


func test_without_the_full_cost_the_attack_does_not_happen() -> void:
	knight.stamina.current = knight.quick_cost * 0.9
	var signals := monitor_signals(knight, false)

	assert_bool(knight.attack_toward_camera()).is_false()
	await arena.wait_seconds(knight.attack.impact_delay + 0.1)

	assert_bool(knight.is_busy).is_false()
	assert_float(skeleton.health).is_equal(5.0)
	assert_float(knight.stamina.current).is_greater(0.0)
	await assert_signal(signals).is_emitted("energy_short", [knight.stamina])


func test_a_click_without_stamina_does_not_fire_once_the_bar_refills() -> void:
	knight.stamina.current = knight.quick_cost * 0.9

	knight.request_attack()
	knight.stamina.current = knight.stamina.maximum
	await arena.wait_seconds(Adventurer.ATTACK_BUFFER + 0.1)

	assert_bool(knight.is_busy).is_false()
	assert_float(knight.stamina.current).is_equal(knight.stamina.maximum)


func test_exactly_the_cost_is_enough_for_a_full_attack() -> void:
	knight.stamina.current = knight.quick_cost

	assert_bool(knight.attack_toward_camera()).is_true()
	await arena.wait_seconds(knight.attack.impact_delay + 0.1)

	assert_float(skeleton.health).is_equal_approx(5.0 - knight.attack.damage, 0.01)
	assert_float(knight.stamina.current).is_equal_approx(0.0, 0.01)


func test_a_heavy_attack_needs_the_heavy_cost() -> void:
	knight.stamina.current = knight.heavy_cost - 1.0

	assert_bool(knight.heavy_attack()).is_false()
	assert_bool(knight.is_busy).is_false()


func test_energy_refills_after_a_pause() -> void:
	knight.attack_toward_camera()
	var spent := knight.stamina.current
	await arena.wait_seconds(knight.stamina_regen_delay * 0.5)
	assert_float(knight.stamina.current).is_equal(spent)

	await arena.wait_seconds(knight.stamina_regen_delay + 0.5)
	assert_float(knight.stamina.current).is_greater(spent)


func test_enemies_attack_without_energy() -> void:
	assert_bool(skeleton.attack.try_attack(skeleton)).is_true()


func test_hud_shows_stamina_for_everyone_and_mana_also_for_the_mage() -> void:
	var hud: Hud = auto_free(preload("res://scenes/ui/hud.tscn").instantiate())
	arena.root.add_child(hud)

	hud.bind(knight)
	assert_bool(hud.stamina_bar.visible).is_true()
	assert_bool(hud.mana_bar.visible).is_false()

	var other: Hud = auto_free(preload("res://scenes/ui/hud.tscn").instantiate())
	arena.root.add_child(other)
	other.bind(arena.spawn(TestArena.MAGE, Vector3(4, 0, 0)))
	assert_bool(other.mana_bar.visible).is_true()
	assert_bool(other.stamina_bar.visible).is_true()


func test_running_spends_stamina_and_tires_down_to_a_walk() -> void:
	var runner := arena.spawn(TestArena.KNIGHT, Vector3(-6, 0, 0), 180.0) as Adventurer
	await arena.wait_physics(2)
	await arena.send_action("move_forward")
	await arena.send_action("run")
	await arena.wait_seconds(0.1)
	# so depois de comecar a correr: antes disso a estamina ainda regenera
	runner.stamina.current = runner.run_cost * 0.5
	await arena.wait_seconds(0.2)
	assert_float(runner.stamina.current).is_less(runner.run_cost * 0.5)

	await arena.wait_seconds(0.8)
	assert_float(runner.stamina.current).is_equal(0.0)
	assert_float(Vector2(runner.velocity.x, runner.velocity.z).length()).is_equal_approx(runner.walk_speed, 0.3)


func test_tired_adventurer_runs_again_only_after_refilling() -> void:
	var runner := arena.spawn(TestArena.KNIGHT, Vector3(-6, 0, 0), 180.0) as Adventurer
	await arena.wait_physics(2)
	await arena.send_action("move_forward")
	await arena.send_action("run")
	await arena.wait_seconds(0.1)
	runner.stamina.current = 1.0
	await arena.wait_seconds(0.4)
	assert_bool(runner.wants_to_run()).is_false()

	runner.stamina.current = runner.stamina.maximum * Adventurer.RUN_RECOVER_FRACTION
	await arena.wait_physics(2)
	assert_bool(runner.wants_to_run()).is_true()


func test_mage_running_spends_stamina_and_spells_spend_mana() -> void:
	var mage := arena.spawn(TestArena.MAGE, Vector3(6, 0, 0), 180.0) as Adventurer
	await arena.wait_physics(2)
	await arena.send_action("move_forward")
	await arena.send_action("run")
	await arena.wait_seconds(0.5)

	assert_float(Vector2(mage.velocity.x, mage.velocity.z).length()).is_greater(mage.walk_speed + 0.5)
	assert_float(mage.stamina.current).is_less(mage.stamina.maximum)
	assert_float(mage.mana.current).is_equal(mage.mana.maximum)

	Input.action_release("move_forward")
	Input.action_release("run")
	var stamina_before := mage.stamina.current
	mage.attack_toward_camera()
	assert_float(mage.mana.current).is_equal_approx(mage.mana.maximum - mage.quick_cost, 0.01)
	assert_float(mage.stamina.current).is_greater_equal(stamina_before)


func test_mage_mana_refills_faster_and_stamina_slower_than_the_base() -> void:
	var mage := arena.spawn(TestArena.MAGE, Vector3(6, 0, 0)) as Adventurer
	await arena.wait_physics(2)

	assert_float(mage.mana.regen_per_second).is_equal(Adventurer.BASE_REGEN * mage.mana_regen_multiplier)
	assert_float(mage.mana.regen_per_second).is_greater(knight.stamina.regen_per_second)
	assert_float(mage.stamina.regen_per_second).is_less(knight.stamina.regen_per_second)


func test_holding_the_shield_drains_stamina() -> void:
	knight.use_secondary()
	await arena.wait_seconds(0.5)

	assert_float(knight.stamina.current).is_less(knight.stamina.maximum)
	assert_bool(knight.is_blocking).is_true()


func test_a_blocked_hit_costs_stamina() -> void:
	knight.use_secondary()
	await arena.wait_physics(2)
	var before := knight.stamina.current

	knight.take_damage(1.0, skeleton)

	assert_float(knight.health).is_equal(knight.max_health)
	assert_float(knight.stamina.current).is_equal_approx(before - knight.block_hit_cost, 0.5)


func test_without_stamina_the_guard_breaks_and_the_hit_lands() -> void:
	knight.use_secondary()
	await arena.wait_physics(2)
	knight.stamina.current = knight.block_hit_cost * 0.5

	knight.take_damage(1.0, skeleton)

	assert_bool(knight.is_blocking).is_false()
	assert_float(knight.health).is_equal(knight.max_health - 1.0)


func test_a_locked_adventurer_ignores_movement_and_attacks() -> void:
	var walker := arena.spawn(TestArena.KNIGHT, Vector3(-6, 0, 0), 180.0) as Adventurer
	await arena.wait_physics(2)
	walker.input_locked = true

	await arena.send_action("move_forward")
	walker._unhandled_input(_action_event("attack"))
	await arena.wait_physics(10)

	assert_float(Vector2(walker.velocity.x, walker.velocity.z).length()).is_less(0.1)
	assert_float(walker.heavy_progress()).is_equal(0.0)


func _action_event(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event
