extends GdUnitTestSuite

const TRAP := preload("res://scenes/world/spike_trap.tscn")

var arena: TestArena
var trap: TrapCycle
var spikes: TrapHurtbox


func before_test() -> void:
	RunState.reset()
	arena = TestArena.new(self)
	trap = TRAP.instantiate() as TrapCycle
	trap.position = Vector3(0, 0, 6)
	arena.root.add_child(trap)
	trap.animation_player.pause()
	spikes = trap.get_node("Reach") as TrapHurtbox
	await arena.wait_physics(2)


func _standing_on_trap(scene_path: String) -> Character:
	var victim := arena.spawn(scene_path, trap.position)
	await arena.wait_physics(4)
	return victim


func test_raised_spikes_hurt_an_adventurer_standing_on_them() -> void:
	var knight := await _standing_on_trap(TestArena.KNIGHT)

	spikes.strike()

	assert_float(knight.health).is_equal(knight.get_max_health() - spikes.damage)


func test_raised_spikes_hurt_undead_too() -> void:
	var skeleton := await _standing_on_trap(TestArena.SKELETON)

	spikes.strike()

	assert_float(skeleton.health).is_equal(skeleton.get_max_health() - spikes.damage)


func test_each_rise_hurts_once() -> void:
	var knight := await _standing_on_trap(TestArena.KNIGHT)

	spikes.strike()
	await arena.wait_physics(5)

	assert_float(knight.health).is_equal(knight.get_max_health() - spikes.damage)


func test_lowered_spikes_do_not_hurt_whoever_walks_in() -> void:
	var knight := await _standing_on_trap(TestArena.KNIGHT)

	assert_float(knight.health).is_equal(knight.get_max_health())


func test_stepping_on_raised_spikes_hurts() -> void:
	spikes.strike()
	var knight := await _standing_on_trap(TestArena.KNIGHT)

	assert_float(knight.health).is_equal(knight.get_max_health() - spikes.damage)


func test_the_shield_does_not_stop_spikes_from_below() -> void:
	var knight := await _standing_on_trap(TestArena.KNIGHT) as Adventurer
	knight.use_secondary()
	await arena.wait_physics(2)
	assert_bool(knight.is_blocking).is_true()

	spikes.strike()

	assert_float(knight.health).is_equal(knight.get_max_health() - spikes.damage)


func test_the_damage_recap_names_the_spikes() -> void:
	var knight := await _standing_on_trap(TestArena.KNIGHT)

	spikes.strike()

	assert_str(knight.damage_log.death_cause()).is_equal("Espinhos")


func test_the_cycle_raises_and_lowers_the_spikes_by_itself() -> void:
	var knight := await _standing_on_trap(TestArena.KNIGHT)
	trap.animation_player.play("ciclo")

	await arena.wait_seconds(trap.animation_player.current_animation_length + 0.2)

	assert_float(knight.health).is_less(knight.get_max_health())
	assert_bool(spikes.active).is_false()
