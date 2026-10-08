extends GdUnitTestSuite

const SKELETON := "res://scenes/characters/enemies/skeleton.tscn"

var arena: TestArena
var knight: Adventurer


func before_test() -> void:
	arena = TestArena.new(self)
	knight = arena.spawn(TestArena.KNIGHT, Vector3.ZERO) as Adventurer


func _wait_impact() -> void:
	await arena.wait_seconds(knight.attack.impact_delay + 0.1)


func test_hits_the_enemy_in_front() -> void:
	var skeleton := arena.spawn(SKELETON, Vector3(0, 0, 1.3)) as Enemy
	await arena.wait_physics(3)

	knight.attack.try_attack(knight)
	await _wait_impact()

	assert_float(skeleton.health).is_equal(skeleton.max_health - knight.attack.damage)


func test_misses_the_enemy_behind() -> void:
	var skeleton := arena.spawn(SKELETON, Vector3(0, 0, -1.3)) as Enemy
	await arena.wait_physics(3)

	knight.attack.try_attack(knight)
	await _wait_impact()

	assert_float(skeleton.health).is_equal(skeleton.max_health)


func test_second_attack_waits_for_the_cooldown() -> void:
	await arena.wait_physics(3)

	assert_bool(knight.attack.try_attack(knight)).is_true()
	assert_bool(knight.attack.try_attack(knight)).is_false()


func test_knight_stands_still_while_swinging() -> void:
	await arena.wait_physics(3)
	knight.attack.try_attack(knight)

	await arena.send_action("move_forward")
	await arena.wait_seconds(0.2)
	await arena.send_action("move_forward", false)

	assert_float(Vector2(knight.velocity.x, knight.velocity.z).length()).is_less(0.1)


func test_attack_turns_to_where_the_camera_looks() -> void:
	knight.camera_pivot.rotation.y = deg_to_rad(90.0)
	await arena.wait_physics(3)

	knight.attack_toward_camera()

	var facing := knight.model.global_basis.z.normalized()
	assert_float(facing.dot(-knight.camera_pivot.global_basis.z)).is_equal_approx(1.0, 0.01)


func test_enemy_falls_after_enough_hits_and_disappears() -> void:
	var skeleton := arena.spawn(SKELETON, Vector3(0, 0, 1.3)) as Enemy
	await arena.wait_physics(3)

	for i in skeleton.max_health:
		skeleton.take_damage(1.0)
	assert_bool(skeleton.is_dead).is_true()

	await arena.wait_seconds(skeleton.corpse_time + 0.2)
	assert_bool(is_instance_valid(skeleton)).is_false()
