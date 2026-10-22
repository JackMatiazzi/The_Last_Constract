extends GdUnitTestSuite

var arena: TestArena
var knight: Adventurer


func before_test() -> void:
	RunState.reset()
	arena = TestArena.new(self)
	knight = arena.spawn(TestArena.KNIGHT, Vector3.ZERO) as Adventurer
	await arena.wait_physics(3)


func after_test() -> void:
	for action in ["move_forward", "run", "jump"]:
		Input.action_release(action)


func _state() -> String:
	return knight.state_machine.current_state_name


func _until_state(state_name: String, seconds := 1.0) -> bool:
	for i in ceili(seconds * Engine.physics_ticks_per_second):
		if _state() == state_name:
			return true
		await arena.wait_physics(1)
	return _state() == state_name


func test_starts_idle() -> void:
	assert_str(_state()).is_equal("Idle")


func test_walking_and_running_have_their_own_states() -> void:
	await arena.send_action("move_forward")
	assert_bool(await _until_state("Walk")).is_true()
	assert_str(knight.animation_player.current_animation).is_equal(Character.ANIM_WALK)

	await arena.send_action("run")
	assert_bool(await _until_state("Run")).is_true()
	assert_str(knight.animation_player.current_animation).is_equal(Character.ANIM_RUN)


func test_jumping_goes_through_air_and_lands_idle() -> void:
	await arena.send_action("jump")
	assert_bool(await _until_state("Air")).is_true()
	assert_str(knight.animation_player.current_animation).is_equal(Character.ANIM_AIR)

	assert_bool(await _until_state("Idle", 2.0)).is_true()


func test_attacking_is_an_action_and_returns_to_idle() -> void:
	knight.attack.try_attack(knight)
	await arena.wait_physics(1)
	assert_str(_state()).is_equal("Action")

	assert_bool(await _until_state("Idle", 3.0)).is_true()


func test_raising_the_shield_enters_block_and_releasing_leaves_it() -> void:
	knight.use_secondary()
	await arena.wait_physics(1)
	assert_str(_state()).is_equal("Block")
	assert_bool(knight.is_blocking).is_true()

	knight.release_secondary()
	await arena.wait_physics(1)
	assert_str(_state()).is_equal("Idle")
	assert_bool(knight.is_blocking).is_false()


func test_a_hit_from_behind_breaks_the_guard() -> void:
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3(0, 0, -1.2))
	await arena.wait_physics(2)
	knight.use_secondary()
	await arena.wait_physics(1)

	knight.take_damage(1.0, skeleton)
	await arena.wait_physics(1)

	assert_str(_state()).is_equal("Action")
	assert_bool(knight.is_blocking).is_false()


func test_dead_adventurer_ignores_input() -> void:
	knight.take_damage(99.0)
	assert_str(_state()).is_equal("Dead")

	await arena.send_action("jump")
	await arena.wait_physics(3)

	assert_float(knight.velocity.y).is_less_equal(0.0)
	assert_str(_state()).is_equal("Dead")
