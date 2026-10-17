extends GdUnitTestSuite

var arena: TestArena


func before_test() -> void:
	RunState.reset()
	arena = TestArena.new(self)


func _first_projectile() -> Projectile:
	var found := arena.root.find_children("*", "Projectile", true, false)
	return found[0] if not found.is_empty() else null


func test_aim_point_lands_on_what_the_crosshair_covers() -> void:
	var rogue := arena.spawn(TestArena.ROGUE, Vector3.ZERO) as Adventurer
	var wall := arena.add_wall(Vector3(0, 1.5, 10), Vector3(20, 6, 0.4))
	await arena.wait_physics(5)

	var aim := rogue.get_aim_point()

	assert_float(aim.z).is_equal_approx(wall.global_position.z - 0.2, 0.05)


func test_looking_up_shoots_upward() -> void:
	var rogue := arena.spawn(TestArena.ROGUE, Vector3.ZERO) as Adventurer
	await arena.wait_physics(5)
	rogue.spring_arm.rotation.x = deg_to_rad(25.0)
	await arena.wait_physics(2)

	rogue.attack_toward_camera()
	await arena.wait_seconds(rogue.attack.impact_delay + 0.05)
	var bolt := _first_projectile()
	var start_height := bolt.global_position.y
	await arena.wait_seconds(0.3)

	assert_float(bolt.global_position.y).is_greater(start_height + 1.0)


func test_bolt_hits_enemy_under_the_crosshair() -> void:
	var rogue := arena.spawn(TestArena.ROGUE, Vector3.ZERO) as Adventurer
	await arena.wait_physics(5)
	var center := rogue.get_viewport().get_visible_rect().size / 2.0
	var ray_origin := rogue.camera.project_ray_origin(center)
	var ray_line := rogue.camera.project_ray_normal(center).slide(Vector3.UP).normalized()
	var skeleton := arena.spawn(TestArena.SKELETON, ray_origin.slide(Vector3.UP) + ray_line * 9.0)
	await arena.wait_physics(3)

	rogue.attack_toward_camera()
	await arena.wait_seconds(1.2)

	assert_float(skeleton.health).is_equal(4.0)


func test_crosshair_shows_only_for_ranged_adventurers() -> void:
	var hud: Hud = auto_free(preload("res://scenes/ui/hud.tscn").instantiate())
	arena.root.add_child(hud)

	hud.bind(arena.spawn(TestArena.ROGUE, Vector3.ZERO))
	assert_bool(hud.crosshair.visible).is_true()

	hud.bind(arena.spawn(TestArena.KNIGHT, Vector3(4, 0, 0)))
	assert_bool(hud.crosshair.visible).is_false()
