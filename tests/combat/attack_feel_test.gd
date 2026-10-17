extends GdUnitTestSuite

var arena: TestArena
var knight: Adventurer


func before_test() -> void:
	RunState.reset()
	arena = TestArena.new(self)
	knight = arena.spawn(TestArena.KNIGHT, Vector3.ZERO)
	await arena.wait_physics(5)


func after_test() -> void:
	for action in ["move_forward", "attack"]:
		Input.action_release(action)


func _horizontal_speed() -> float:
	return Vector2(knight.velocity.x, knight.velocity.z).length()


func test_can_move_slowly_while_attacking() -> void:
	knight.attack.try_attack(knight)
	await arena.send_action("move_forward")
	await arena.wait_seconds(0.2)

	assert_bool(knight.is_busy).is_true()
	assert_float(_horizontal_speed()).is_equal_approx(knight.walk_speed * knight.attack.move_factor, 0.05)


func test_moving_after_impact_cancels_attack_recovery() -> void:
	knight.attack.try_attack(knight)
	await arena.send_action("move_forward")
	await arena.wait_seconds(knight.attack.impact_delay + knight.attack.recovery + 0.05)

	assert_bool(knight.is_busy).is_false()
	assert_str(knight.animation_player.current_animation).is_equal(Character.ANIM_WALK)


func test_standing_still_lets_attack_animation_finish() -> void:
	knight.attack.try_attack(knight)
	await arena.wait_seconds(knight.attack.impact_delay + knight.attack.recovery + 0.05)

	assert_bool(knight.is_busy).is_true()


func test_knight_combo_cycles_three_swings() -> void:
	var played: Array[String] = []
	for i in 3:
		assert_bool(knight.attack.try_attack(knight)).is_true()
		played.append(knight.animation_player.current_animation)
		await arena.wait_seconds(knight.attack.effective_cooldown(knight) + 0.02)

	assert_array(played).is_equal(Array(knight.attack.animations))


func test_combo_restarts_after_a_pause() -> void:
	knight.attack.try_attack(knight)
	await arena.wait_seconds(knight.attack.effective_cooldown(knight) + knight.attack.combo_window + 0.2)

	knight.attack.try_attack(knight)

	assert_str(knight.animation_player.current_animation).is_equal(knight.attack.animations[0])


func test_early_click_is_buffered_until_cooldown_ends() -> void:
	knight.request_attack()
	var cooldown: float = knight.attack.effective_cooldown(knight)
	await arena.wait_seconds(cooldown - 0.1)

	knight.request_attack()
	await arena.wait_seconds(0.2)

	assert_str(knight.animation_player.current_animation).is_equal(knight.attack.animations[1])


func test_click_too_early_is_not_buffered() -> void:
	knight.request_attack()
	await arena.wait_seconds(0.1)

	knight.request_attack()
	await arena.wait_seconds(knight.attack.effective_cooldown(knight))

	assert_str(knight.animation_player.current_animation).is_not_equal(knight.attack.animations[1])


func test_hit_during_wind_up_cancels_the_strike() -> void:
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3(0, 0, 1.2))
	await arena.wait_physics(3)
	knight.attack.try_attack(knight)
	await arena.wait_seconds(knight.attack.impact_delay * 0.5)

	knight.take_damage(1.0)
	await arena.wait_seconds(knight.attack.impact_delay)

	assert_float(skeleton.health).is_equal(5.0)


func test_strike_after_impact_still_counts_if_hit_later() -> void:
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3(0, 0, 1.2))
	await arena.wait_physics(3)
	knight.attack.try_attack(knight)
	await arena.wait_seconds(knight.attack.impact_delay + 0.05)

	knight.take_damage(1.0)

	assert_float(skeleton.health).is_equal(4.0)
