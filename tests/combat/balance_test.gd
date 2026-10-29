extends GdUnitTestSuite

# os numeros combinados no ajuste de equilibrio; mudar algum deles deve ser de proposito

const NECROMANCER := preload("res://resources/enemies/necromancer.tres")
const MAGIC_BOLT := preload("res://scenes/combat/magic_bolt.tscn")
const CROSSBOW_BOLT := preload("res://scenes/combat/crossbow_bolt.tscn")
const SHORT_WAIT := 0.2

var arena: TestArena


func before_test() -> void:
	RunState.reset()
	arena = TestArena.new(self)


func _range_of(scene: PackedScene) -> float:
	var projectile := auto_free(scene.instantiate()) as Projectile
	return projectile.max_distance


func test_the_necromancer_attacks_from_fourteen_meters() -> void:
	assert_float(NECROMANCER.attack_range).is_equal(14.0)


func test_the_mage_reaches_six_ninety_one_and_the_rogue_a_bit_less() -> void:
	assert_float(_range_of(MAGIC_BOLT)).is_equal_approx(6.91, 0.001)
	assert_float(_range_of(CROSSBOW_BOLT)).is_less(_range_of(MAGIC_BOLT))


func test_the_players_ranged_attacks_are_outranged_by_the_necromancer() -> void:
	assert_float(_range_of(MAGIC_BOLT)).is_less(NECROMANCER.attack_range)


func test_the_barbarian_charged_spin_costs_half_the_stamina() -> void:
	var barbarian := arena.spawn(TestArena.BARBARIAN, Vector3.ZERO) as Adventurer

	assert_float(barbarian.heavy_cost).is_equal_approx(barbarian.stamina.maximum * 0.5, 0.001)


func test_the_rogue_moves_a_fifth_faster_than_the_knight() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO) as Adventurer
	var rogue := arena.spawn(TestArena.ROGUE, Vector3(3, 0, 0)) as Adventurer

	assert_float(rogue.walk_speed).is_equal_approx(knight.walk_speed * 1.2, 0.001)
	assert_float(rogue.run_speed).is_equal_approx(knight.run_speed * 1.2, 0.001)


func test_common_skeletons_strike_more_often_than_before() -> void:
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3.ZERO)

	assert_float(skeleton.attack.cooldown).is_equal_approx(1.35, 0.001)


func test_emptied_stamina_starts_coming_back_without_the_pause() -> void:
	for scene in [TestArena.BARBARIAN, TestArena.MAGE, TestArena.ROGUE]:
		var adventurer := arena.spawn(scene, Vector3(randf_range(-6, 6), 0, 6)) as Adventurer
		await arena.wait_physics(2)

		adventurer.stamina.spend(adventurer.stamina.maximum)
		await arena.wait_seconds(SHORT_WAIT)

		assert_float(SHORT_WAIT).is_less(adventurer.stamina_regen_delay)
		assert_float(adventurer.stamina.current).override_failure_message(scene).is_greater(0.0)


func test_emptied_mana_starts_coming_back_without_the_pause() -> void:
	var mage := arena.spawn(TestArena.MAGE, Vector3.ZERO) as Adventurer
	await arena.wait_physics(2)

	mage.mana.spend(mage.mana.maximum)
	await arena.wait_seconds(SHORT_WAIT)

	assert_float(mage.mana.current).is_greater(0.0)


func test_the_knight_still_waits_the_pause_after_emptying() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO) as Adventurer
	await arena.wait_physics(2)

	knight.stamina.spend(knight.stamina.maximum)
	await arena.wait_seconds(SHORT_WAIT)

	assert_float(knight.stamina.current).is_equal(0.0)


func test_spending_without_emptying_still_waits_the_pause() -> void:
	var barbarian := arena.spawn(TestArena.BARBARIAN, Vector3.ZERO) as Adventurer
	await arena.wait_physics(2)

	barbarian.stamina.spend(barbarian.heavy_cost)
	var left := barbarian.stamina.current
	await arena.wait_seconds(SHORT_WAIT)

	assert_float(barbarian.stamina.current).is_equal(left)
