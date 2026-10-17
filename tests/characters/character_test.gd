extends GdUnitTestSuite

var arena: TestArena


func before_test() -> void:
	RunState.reset()
	arena = TestArena.new(self)


func after_test() -> void:
	RunState.reset()


func test_adventurer_and_skeleton_spawn_with_their_max_health() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO)
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3(4, 0, 0))

	assert_float(knight.health).is_equal(10.0)
	assert_float(skeleton.health).is_equal(5.0)


func test_take_damage_reduces_health_and_emits_signal() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO)
	var signals := monitor_signals(knight, false)

	knight.take_damage(3.0)

	assert_float(knight.health).is_equal(7.0)
	await assert_signal(signals).is_emitted("health_changed", [7.0, 10.0])


func test_damage_plays_hit_reaction_and_locks_movement() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO)

	knight.take_damage(1.0)

	assert_bool(knight.is_busy).is_true()
	assert_str(knight.animation_player.current_animation).is_equal(Character.ANIM_HIT)


func test_dies_at_zero_health() -> void:
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3.ZERO)
	var signals := monitor_signals(skeleton, false)

	skeleton.take_damage(5.0)

	assert_bool(skeleton.is_dead).is_true()
	await assert_signal(signals).is_emitted("died")


func test_ignores_damage_after_death() -> void:
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3.ZERO)
	skeleton.take_damage(5.0)
	var signals := monitor_signals(skeleton, false)

	skeleton.take_damage(5.0)

	assert_float(skeleton.health).is_equal(0.0)
	await assert_signal(signals).wait_until(200).is_not_emitted("died")
	await assert_signal(signals).wait_until(200).is_not_emitted("health_changed")


func test_death_disables_body_collision() -> void:
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3.ZERO)

	skeleton.die()
	await arena.wait_physics(2)

	assert_bool(skeleton.collision_shape.disabled).is_true()


func test_run_buffs_apply_to_adventurers_and_enemies() -> void:
	RunState.buffs.append(load("res://resources/buffs/couraca.tres"))
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO)
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3(4, 0, 0))

	assert_float(knight.get_max_health()).is_equal(13.0)
	assert_float(skeleton.get_max_health()).is_equal(8.0)
	assert_float(skeleton.health).is_equal(8.0)


func test_max_health_never_drops_below_one() -> void:
	var fury: Buff = load("res://resources/buffs/furia_cega.tres")
	RunState.buffs.append_array([fury, fury, fury])
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3.ZERO)

	assert_float(skeleton.get_max_health()).is_equal(1.0)


func test_speed_buff_raises_max_speed() -> void:
	RunState.buffs.append(load("res://resources/buffs/passos_leves.tres"))
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO)

	assert_float(knight.get_max_speed()).is_equal_approx(knight.walk_speed * 1.2, 0.001)


func test_speed_penalty_never_goes_below_floor() -> void:
	var slow := Buff.new()
	var modifier := StatModifier.new()
	modifier.stat = StatModifier.Stat.SPEED
	modifier.amount = -5.0
	slow.modifiers = [modifier]
	RunState.buffs.append(slow)
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO)

	assert_float(knight.get_max_speed()).is_equal_approx(knight.walk_speed * Character.MIN_STAT_FACTOR, 0.001)
