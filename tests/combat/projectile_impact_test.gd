extends GdUnitTestSuite

var arena: TestArena


func before_test() -> void:
	RunState.reset()
	arena = TestArena.new(self)


func _impacts() -> Array[Node]:
	return arena.root.find_children("*", "ProjectileImpact", true, false)


func _shoot_at_wall(scene_path: String) -> StaticBody3D:
	var shooter := arena.spawn(scene_path, Vector3.ZERO) as Adventurer
	var wall := arena.add_wall(Vector3(0, 1.5, 6), Vector3(8, 4, 0.4))
	await arena.wait_physics(5)
	shooter.attack_toward_camera()
	await arena.wait_seconds(1.0)
	return wall


func test_magic_bolt_leaves_a_mark_on_the_wall_surface() -> void:
	var wall := await _shoot_at_wall(TestArena.MAGE)

	var impacts := _impacts()
	assert_int(impacts.size()).is_equal(1)
	var mark := impacts[0] as ProjectileImpact
	assert_float(mark.global_position.z).is_equal_approx(wall.global_position.z - 0.2, 0.05)
	assert_float(mark.global_basis.y.dot(Vector3.FORWARD)).is_greater(0.9)


func test_crossbow_bolt_sticks_pointing_where_it_flew() -> void:
	await _shoot_at_wall(TestArena.ROGUE)

	var impacts := _impacts()
	assert_int(impacts.size()).is_equal(1)
	var arrow := impacts[0] as ProjectileImpact
	assert_float((-arrow.global_basis.z).normalized().dot(Vector3.BACK)).is_greater(0.9)


func test_wall_impact_disappears_after_its_lifetime() -> void:
	await _shoot_at_wall(TestArena.ROGUE)
	var arrow := _impacts()[0] as ProjectileImpact

	await arena.wait_seconds(arrow.lifetime + arrow.fade_time + 0.3)

	assert_int(_impacts().size()).is_equal(0)


func test_crossbow_bolt_sticks_in_the_enemy_it_hits() -> void:
	var rogue := arena.spawn(TestArena.ROGUE, Vector3.ZERO) as Adventurer
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3(0, 0, 5))
	await arena.wait_physics(5)

	rogue.attack_toward_camera()
	await arena.wait_seconds(0.8)

	var stuck := skeleton.find_children("*", "ProjectileImpact", true, false)
	assert_int(stuck.size()).is_equal(1)
	assert_float((stuck[0] as Node3D).global_position.distance_to(skeleton.global_position + Vector3.UP)).is_less(1.0)


func test_stuck_bolt_follows_the_enemy() -> void:
	var rogue := arena.spawn(TestArena.ROGUE, Vector3.ZERO) as Adventurer
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3(0, 0, 5))
	await arena.wait_physics(5)
	rogue.attack_toward_camera()
	await arena.wait_seconds(0.8)
	var arrow := skeleton.find_children("*", "ProjectileImpact", true, false)[0] as Node3D
	var offset := arrow.global_position - skeleton.global_position

	skeleton.global_position += Vector3(3, 0, 0)
	await arena.wait_physics(2)

	assert_vector(arrow.global_position - skeleton.global_position).is_equal_approx(offset, Vector3.ONE * 0.05)


func test_stuck_bolt_falls_with_the_body() -> void:
	var rogue := arena.spawn(TestArena.ROGUE, Vector3.ZERO) as Adventurer
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3(0, 0, 5))
	await arena.wait_physics(5)
	rogue.attack_toward_camera()
	await arena.wait_seconds(0.8)
	var arrow := skeleton.find_children("*", "ProjectileImpact", true, false)[0] as Node3D
	var height_alive := arrow.global_position.y

	skeleton.take_damage(99.0)
	await arena.wait_seconds(1.6)

	assert_float(arrow.global_position.y).is_less(height_alive - 0.3)


func test_magic_bolt_does_not_stick_in_enemies() -> void:
	var mage := arena.spawn(TestArena.MAGE, Vector3.ZERO) as Adventurer
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3(0, 0, 5))
	await arena.wait_physics(5)

	mage.attack_toward_camera()
	await arena.wait_seconds(0.9)

	assert_int(skeleton.find_children("*", "ProjectileImpact", true, false).size()).is_equal(0)
