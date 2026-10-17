extends GdUnitTestSuite

var arena: TestArena


func before_test() -> void:
	RunState.reset()
	arena = TestArena.new(self)


func after_test() -> void:
	Input.action_release("move_forward")


func _horizontal_speed(character: Character) -> float:
	return Vector2(character.velocity.x, character.velocity.z).length()


func test_knight_blocks_hits_from_the_front() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO) as Adventurer
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3(0, 0, 1.2))
	await arena.wait_physics(3)
	knight.use_secondary()
	var signals := monitor_signals(knight, false)

	knight.take_damage(1.0, skeleton)

	assert_float(knight.health).is_equal(10.0)
	await assert_signal(signals).is_emitted("blocked")


func test_knight_does_not_block_hits_from_behind() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO) as Adventurer
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3(0, 0, -1.2))
	await arena.wait_physics(3)
	knight.use_secondary()

	knight.take_damage(1.0, skeleton)

	assert_float(knight.health).is_equal(9.0)


func test_skeleton_strike_is_stopped_by_the_shield() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO) as Adventurer
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3(0, 0, 1.3), 180.0)
	await arena.wait_physics(3)
	knight.use_secondary()

	skeleton.attack.try_attack(skeleton)
	await arena.wait_seconds(skeleton.attack.impact_delay + 0.1)

	assert_float(knight.health).is_equal(10.0)


func test_knight_moves_slowly_while_blocking() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO) as Adventurer
	await arena.wait_physics(3)
	knight.use_secondary()

	await arena.send_action("move_forward")
	await arena.wait_seconds(0.5)

	assert_float(_horizontal_speed(knight)).is_equal_approx(knight.walk_speed * knight.block.move_factor, 0.05)


func test_knight_cannot_attack_while_blocking() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO) as Adventurer
	await arena.wait_physics(3)
	knight.use_secondary()

	assert_bool(knight.attack_toward_camera()).is_false()


func test_releasing_lowers_the_shield() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO) as Adventurer
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3(0, 0, 1.2))
	await arena.wait_physics(3)
	knight.use_secondary()

	knight.release_secondary()
	knight.take_damage(1.0, skeleton)

	assert_bool(knight.is_blocking).is_false()
	assert_float(knight.health).is_equal(9.0)


func test_blocked_hit_shows_feedback() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO) as Adventurer
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3(0, 0, 1.2))
	await arena.wait_physics(3)
	knight.use_secondary()

	knight.take_damage(1.0, skeleton)

	var numbers := arena.root.find_children("*", "DamageNumber", true, false)
	assert_int(numbers.size()).is_equal(1)
	assert_str((numbers[0] as Label3D).text).is_equal("Bloqueado")


func test_barbarian_holds_two_axes() -> void:
	var barbarian := arena.spawn(TestArena.BARBARIAN, Vector3.ZERO)

	assert_array(AdventurerChecks.new(self, arena).visible_weapons(barbarian)).is_equal(["1H_Axe", "1H_Axe_Offhand"])


func test_barbarian_offhand_axe_hits_only_in_front() -> void:
	var barbarian := arena.spawn(TestArena.BARBARIAN, Vector3.ZERO) as Adventurer
	var front := arena.spawn(TestArena.SKELETON, Vector3(0, 0, 1.2))
	var back := arena.spawn(TestArena.SKELETON, Vector3(0, 0, -1.2))
	await arena.wait_physics(3)

	barbarian.use_secondary()
	await arena.wait_seconds(barbarian.secondary_attack.impact_delay + 0.1)

	assert_float(front.health).is_equal(4.0)
	assert_float(back.health).is_equal(5.0)


func test_barbarian_offhand_axe_is_quicker_than_the_spin() -> void:
	var barbarian := arena.spawn(TestArena.BARBARIAN, Vector3.ZERO) as Adventurer

	assert_float(barbarian.secondary_attack.effective_cooldown(barbarian)).is_less(barbarian.attack.effective_cooldown(barbarian))


func test_mage_has_no_secondary() -> void:
	var mage := arena.spawn(TestArena.MAGE, Vector3.ZERO) as Adventurer
	await arena.wait_physics(3)

	mage.use_secondary()

	assert_bool(mage.is_busy).is_false()
