extends GdUnitTestSuite

var arena: TestArena


func before_test() -> void:
	RunState.reset()
	arena = TestArena.new(self)


func after_test() -> void:
	RunState.reset()


func test_projectile_does_not_hit_its_shooter_or_allies() -> void:
	var rogue := arena.spawn(TestArena.ROGUE, Vector3.ZERO)
	var ally := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 4))
	await arena.wait_physics(5)

	rogue.attack.try_attack(rogue)
	await arena.wait_seconds(1.2)

	assert_float(rogue.health).is_equal(10.0)
	assert_float(ally.health).is_equal(10.0)


func test_projectile_is_freed_after_max_distance() -> void:
	var rogue := arena.spawn(TestArena.ROGUE, Vector3.ZERO)
	await arena.wait_physics(5)

	rogue.attack.try_attack(rogue)
	await arena.wait_seconds(rogue.attack.impact_delay + 0.05)
	assert_int(arena.root.find_children("*", "Projectile", true, false).size()).is_equal(1)
	await arena.wait_seconds(1.0)

	assert_int(arena.root.find_children("*", "Projectile", true, false).size()).is_equal(0)


func test_wall_blocks_projectile() -> void:
	var rogue := arena.spawn(TestArena.ROGUE, Vector3.ZERO)
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3(0, 0, 8))
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(4, 4, 0.4)
	wall.add_child(shape)
	arena.root.add_child(wall)
	wall.global_position = Vector3(0, 1, 4)
	await arena.wait_physics(5)

	rogue.attack.try_attack(rogue)
	await arena.wait_seconds(1.2)

	assert_float(skeleton.health).is_equal(5.0)
