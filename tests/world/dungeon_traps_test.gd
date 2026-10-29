extends GdUnitTestSuite

const PENDULUM := preload("res://scenes/world/pendulum_trap.tscn")
const DARTS := preload("res://scenes/world/dart_trap.tscn")
const BARREL_TRAP := preload("res://scenes/world/barrel_trap.tscn")
const STAIRS := preload("res://scenes/world/stone_stairs.tscn")

var arena: TestArena


func before_test() -> void:
	RunState.reset()
	arena = TestArena.new(self)


func _place(scene: PackedScene, spot: Vector3) -> Node3D:
	var node := scene.instantiate() as Node3D
	node.position = spot
	arena.root.add_child(node)
	return node


func test_the_pendulum_blade_cuts_whoever_is_in_its_way() -> void:
	var pendulum := _place(PENDULUM, Vector3(0, 0, 6)) as TrapCycle
	pendulum.animation_player.pause()
	var knight := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 6))
	await arena.wait_physics(4)

	(pendulum.get_node("Pivot") as Node3D).rotation = Vector3.ZERO
	await arena.wait_physics(4)

	assert_float(knight.health).is_equal(knight.get_max_health() - 3.0)
	assert_str(knight.damage_log.death_cause()).is_equal("Lâmina pendular")


func test_at_the_end_of_its_swing_the_blade_leaves_the_middle_free() -> void:
	var pendulum := _place(PENDULUM, Vector3(0, 0, 6)) as TrapCycle
	pendulum.animation_player.pause()
	var knight := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 6))
	await arena.wait_physics(4)

	(pendulum.get_node("Pivot/Blade") as TrapHurtbox).strike()

	assert_float(knight.health).is_equal(knight.get_max_health())


func test_stepping_on_the_plate_fires_darts_from_the_wall() -> void:
	var trap := _place(DARTS, Vector3(0, 0, 6)) as DartTrap
	var knight := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 6))

	await arena.wait_seconds(0.6)

	assert_float(knight.health).is_less(knight.get_max_health())
	assert_str(knight.damage_log.death_cause()).is_equal("Dardos")
	assert_bool(trap.is_armed).is_true()


func test_the_plate_needs_to_reload() -> void:
	_place(DARTS, Vector3(0, 0, 6))
	var knight := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 6))
	await arena.wait_seconds(0.6)
	var after_first := knight.health

	knight.global_position = Vector3(0, 0, 0)
	await arena.wait_physics(3)
	knight.global_position = Vector3(0, 0, 6)
	await arena.wait_seconds(0.4)

	assert_float(knight.health).is_equal(after_first)


func test_darts_hit_undead_lured_onto_the_plate() -> void:
	_place(DARTS, Vector3(0, 0, 6))
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3(0, 0, 6))

	await arena.wait_seconds(0.6)

	assert_float(skeleton.health).is_less(skeleton.get_max_health())


func test_an_adventurer_walks_up_the_stone_stairs() -> void:
	_place(STAIRS, Vector3(0, 0, 2))
	var knight := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 0))
	await arena.wait_physics(3)
	Settings.input_device = Settings.InputDevice.GAMEPAD
	Input.action_press("move_forward")

	await arena.wait_seconds(2.5)
	Input.action_release("move_forward")
	Settings.input_device = Settings.InputDevice.AUTOMATIC

	assert_float(knight.global_position.y).is_greater(1.5)


func test_the_barrel_rolls_down_the_stairs_and_runs_over_whoever_is_below() -> void:
	_place(STAIRS, Vector3(0, 0, 2))
	var trap := _place(BARREL_TRAP, Vector3(0, 2, 10)) as BarrelTrap
	var knight := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 0.5))
	await arena.wait_physics(3)

	var barrel := trap.release()
	await arena.wait_seconds(3.0)

	assert_float(barrel.global_position.z).is_less(4.0)
	assert_float(knight.health).is_less(knight.get_max_health())
	assert_str(knight.damage_log.death_cause()).is_equal("Barril rolando")


func test_stepping_on_the_stairs_releases_the_barrel() -> void:
	_place(STAIRS, Vector3(0, 0, 2))
	var trap := _place(BARREL_TRAP, Vector3(0, 2, 10))
	await arena.wait_physics(2)

	arena.spawn(TestArena.KNIGHT, Vector3(0, 1.2, 6))
	await arena.wait_physics(6)

	assert_int(arena.root.find_children("*", "RollingBarrel", true, false).size()).is_equal(1)
	assert_object(trap).is_not_null()
