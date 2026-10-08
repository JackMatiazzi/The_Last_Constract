extends GdUnitTestSuite

var arena: TestArena
var knight: Adventurer


func before_test() -> void:
	arena = TestArena.new(self)
	knight = arena.spawn(TestArena.KNIGHT, Vector3.ZERO) as Adventurer
	await arena.wait_physics(5)


func after_test() -> void:
	for action in ["move_forward", "move_back", "jump"]:
		Input.action_release(action)


func _horizontal_speed() -> float:
	return Vector2(knight.velocity.x, knight.velocity.z).length()


func test_walks_at_walk_speed_with_walk_animation() -> void:
	await arena.send_action("move_forward")
	await arena.wait_seconds(0.5)

	assert_float(_horizontal_speed()).is_equal_approx(knight.walk_speed, 0.01)
	assert_str(knight.animation_player.current_animation).is_equal(Character.ANIM_WALK)


func test_reaches_walk_speed_quickly() -> void:
	await arena.send_action("move_forward")
	await arena.wait_seconds(0.15)

	assert_float(_horizontal_speed()).is_equal_approx(knight.walk_speed, 0.01)


func test_stops_quickly_when_released() -> void:
	await arena.send_action("move_forward")
	await arena.wait_seconds(0.4)
	await arena.send_action("move_forward", false)
	await arena.wait_seconds(0.12)

	assert_float(_horizontal_speed()).is_equal(0.0)


func test_double_tap_forward_runs() -> void:
	await arena.send_action("move_forward")
	await arena.send_action("move_forward", false)
	await arena.send_action("move_forward")
	await arena.wait_seconds(0.6)

	assert_float(_horizontal_speed()).is_equal_approx(knight.run_speed, 0.01)
	assert_str(knight.animation_player.current_animation).is_equal(Character.ANIM_RUN)


func test_slow_second_tap_does_not_run() -> void:
	await arena.send_action("move_forward")
	await arena.send_action("move_forward", false)
	await arena.wait_seconds(Adventurer.DOUBLE_TAP_WINDOW + 0.1)
	await arena.send_action("move_forward")
	await arena.wait_seconds(0.6)

	assert_float(_horizontal_speed()).is_equal_approx(knight.walk_speed, 0.01)


func test_releasing_forward_stops_running() -> void:
	await arena.send_action("move_forward")
	await arena.send_action("move_forward", false)
	await arena.send_action("move_forward")
	await arena.wait_seconds(0.3)
	await arena.send_action("move_forward", false)
	await arena.wait_seconds(0.5)

	assert_float(_horizontal_speed()).is_equal(0.0)
	assert_str(knight.animation_player.current_animation).is_equal(Character.ANIM_IDLE)


func test_jump_leaves_ground_and_lands() -> void:
	await arena.send_action("jump")
	await arena.wait_physics(5)
	assert_bool(knight.is_on_floor()).is_false()
	assert_str(knight.animation_player.current_animation).is_equal(Character.ANIM_AIR)

	await arena.wait_seconds(1.2)

	assert_bool(knight.is_on_floor()).is_true()


func test_jump_falls_faster_than_it_rises() -> void:
	await arena.send_action("jump")
	var frames_rising := 0
	var frames_falling := 0
	for i in 120:
		await arena.wait_physics(1)
		if knight.is_on_floor() and i > 3:
			break
		if knight.velocity.y > 0.0:
			frames_rising += 1
		else:
			frames_falling += 1

	assert_int(frames_falling).is_less(frames_rising)


func test_jump_pressed_just_before_landing_still_jumps() -> void:
	await arena.send_action("jump")
	await arena.send_action("jump", false)
	while knight.velocity.y > 0.0 or knight.global_position.y > 0.25:
		await arena.wait_physics(1)

	await arena.send_action("jump")
	await arena.wait_physics(10)

	assert_bool(knight.is_on_floor()).is_false()
	assert_float(knight.velocity.y).is_greater(0.0)


func test_jump_right_after_leaving_ground_is_forgiven() -> void:
	knight.global_position.y = 0.4
	await arena.wait_physics(2)
	assert_bool(knight.is_on_floor()).is_false()

	await arena.send_action("jump")
	await arena.wait_physics(2)

	assert_float(knight.velocity.y).is_greater(0.0)
