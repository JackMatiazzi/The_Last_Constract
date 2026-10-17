extends GdUnitTestSuite

const SCENE := TestArena.KNIGHT

var arena: TestArena
var checks: AdventurerChecks


func before_test() -> void:
	RunState.reset()
	arena = TestArena.new(self)
	checks = AdventurerChecks.new(self, arena)


func after_test() -> void:
	Input.action_release("move_forward")


func test_spawns_ready_to_play() -> void:
	await checks.check_spawns_ready_to_play(SCENE)


func test_walks() -> void:
	await checks.check_walks(SCENE)


func test_attack_cycle() -> void:
	await checks.check_attack_cycle(SCENE)


func test_dies() -> void:
	await checks.check_dies(SCENE)


func test_shows_sword_and_badge_shield_only() -> void:
	var knight := arena.spawn(SCENE, Vector3.ZERO)

	assert_array(checks.visible_weapons(knight)).is_equal(["1H_Sword", "Badge_Shield"])


func test_combo_has_three_different_swings() -> void:
	var knight := arena.spawn(SCENE, Vector3.ZERO) as Adventurer

	assert_int(knight.attack.animations.size()).is_equal(3)
	assert_int(Array(knight.attack.animations).filter(func(a): return knight.animation_player.has_animation(a)).size()).is_equal(3)


func test_hits_one_enemy_in_front_and_not_one_behind() -> void:
	var knight := arena.spawn(SCENE, Vector3.ZERO) as Adventurer
	var front := arena.spawn(TestArena.SKELETON, Vector3(0, 0, 1.2))
	var back := arena.spawn(TestArena.SKELETON, Vector3(0, 0, -1.2))
	await arena.wait_physics(3)

	knight.attack.try_attack(knight)
	await arena.wait_seconds(knight.attack.impact_delay + 0.1)

	assert_float(front.health).is_equal(4.0)
	assert_float(back.health).is_equal(5.0)


func test_full_combo_kills_skeleton_in_five_hits() -> void:
	var knight := arena.spawn(SCENE, Vector3.ZERO) as Adventurer
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3(0, 0, 1.2))
	await arena.wait_physics(3)

	var swings := 0
	while not skeleton.is_dead and swings < 10:
		if knight.attack.try_attack(knight):
			swings += 1
		await arena.wait_physics(1)
	await arena.wait_seconds(knight.attack.impact_delay + 0.1)

	assert_bool(skeleton.is_dead).is_true()
	assert_int(swings).is_equal(5)
