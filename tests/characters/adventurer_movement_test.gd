extends GdUnitTestSuite

var arena: TestArena
var knight: Adventurer


func before_test() -> void:
	RunState.reset()
	arena = TestArena.new(self)
	knight = arena.spawn(TestArena.KNIGHT, Vector3.ZERO)
	await arena.wait_physics(5)


func after_test() -> void:
	for action in ["move_forward", "move_back", "run", "attack"]:
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


func test_attack_turns_to_where_the_camera_looks() -> void:
	knight.camera_pivot.rotation.y = deg_to_rad(90.0)

	knight.attack_toward_camera()

	var facing := Vector3(sin(knight.model.rotation.y), 0, cos(knight.model.rotation.y))
	var camera_forward := -knight.camera_pivot.global_basis.z
	assert_float(facing.dot(camera_forward)).is_equal_approx(1.0, 0.001)


func test_hit_reaction_can_be_cancelled_by_moving() -> void:
	knight.take_damage(1.0)
	await arena.send_action("move_forward")
	await arena.wait_seconds(Character.HIT_RECOVERY + 0.1)

	assert_bool(knight.is_busy).is_false()
	assert_float(_horizontal_speed()).is_greater(0.0)


func test_holding_space_runs() -> void:
	await arena.send_action("move_forward")
	await arena.send_action("run")
	await arena.wait_seconds(0.6)

	assert_float(_horizontal_speed()).is_equal_approx(knight.run_speed, 0.01)
	assert_str(knight.animation_player.current_animation).is_equal(Character.ANIM_RUN)


func test_letting_go_of_space_goes_back_to_walking() -> void:
	await arena.send_action("move_forward")
	await arena.send_action("run")
	await arena.wait_seconds(0.4)

	await arena.send_action("run", false)
	await arena.wait_seconds(0.4)

	assert_float(_horizontal_speed()).is_equal_approx(knight.walk_speed, 0.01)


func test_space_does_not_jump() -> void:
	await arena.send_key(KEY_SPACE)
	await arena.wait_physics(10)

	assert_bool(knight.is_on_floor()).is_true()
	assert_float(knight.velocity.y).is_less_equal(0.0)


func test_walking_off_a_ledge_falls_and_lands() -> void:
	knight.global_position.y = 1.5
	await arena.wait_physics(5)
	assert_bool(knight.is_on_floor()).is_false()

	await arena.wait_seconds(1.0)

	assert_bool(knight.is_on_floor()).is_true()
