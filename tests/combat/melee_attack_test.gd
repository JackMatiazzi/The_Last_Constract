extends GdUnitTestSuite

var arena: TestArena


func before_test() -> void:
	RunState.reset()
	arena = TestArena.new(self)


func after_test() -> void:
	RunState.reset()


func test_knight_hits_enemy_in_front() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO)
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3(0, 0, 1.2))
	await arena.wait_physics(5)

	assert_bool(knight.attack.try_attack(knight)).is_true()
	await arena.wait_seconds(0.6)

	assert_float(skeleton.health).is_equal(4.0)


func test_knight_misses_enemy_behind() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO)
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3(0, 0, -1.2))
	await arena.wait_physics(5)

	knight.attack.try_attack(knight)
	await arena.wait_seconds(0.6)

	assert_float(skeleton.health).is_equal(5.0)


func test_wall_between_blocks_the_hit() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO)
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3(0, 0, 1.4))
	arena.add_wall(Vector3(0, 1.5, 0.7), Vector3(3, 3, 0.15))
	await arena.wait_physics(5)

	knight.attack.try_attack(knight)
	await arena.wait_seconds(knight.attack.impact_delay + 0.1)

	assert_float(skeleton.health).is_equal(5.0)


func test_knight_does_not_hit_other_adventurers() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO)
	var ally := arena.spawn(TestArena.ROGUE, Vector3(0, 0, 1.2))
	await arena.wait_physics(5)

	knight.attack.try_attack(knight)
	await arena.wait_seconds(0.6)

	assert_float(ally.health).is_equal(10.0)


func test_second_attack_inside_cooldown_is_refused() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO)
	await arena.wait_physics(5)

	assert_bool(knight.attack.try_attack(knight)).is_true()
	assert_bool(knight.attack.can_attack(knight)).is_false()
	assert_bool(knight.attack.try_attack(knight)).is_false()


func test_dead_attacker_cannot_attack() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO)
	await arena.wait_physics(5)
	knight.take_damage(99.0)

	assert_bool(knight.attack.try_attack(knight)).is_false()


func test_damage_buff_adds_to_hit() -> void:
	RunState.buffs.append(load("res://resources/buffs/lamina_afiada.tres"))
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO)
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3(0, 0, 1.2))
	await arena.wait_physics(5)

	knight.attack.try_attack(knight)
	await arena.wait_seconds(0.6)

	assert_float(skeleton.health).is_equal(3.0)


func test_cooldown_buff_shortens_recharge() -> void:
	var plain := arena.spawn(TestArena.KNIGHT, Vector3.ZERO)
	await arena.wait_physics(2)
	var plain_cooldown: float = plain.attack.effective_cooldown(plain)
	RunState.buffs.append(load("res://resources/buffs/frenesi.tres"))
	var frenzied := arena.spawn(TestArena.KNIGHT, Vector3(5, 0, 0))
	await arena.wait_physics(2)

	assert_float(frenzied.attack.effective_cooldown(frenzied)).is_equal_approx(plain_cooldown * 0.75, 0.001)
