extends GdUnitTestSuite

const SCENE := TestArena.BARBARIAN

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


func test_shows_two_one_handed_axes() -> void:
	var barbarian := arena.spawn(SCENE, Vector3.ZERO)

	assert_array(checks.visible_weapons(barbarian)).is_equal(["1H_Axe", "1H_Axe_Offhand"])


func test_spin_hits_four_enemies_around_at_once() -> void:
	var barbarian := arena.spawn(SCENE, Vector3.ZERO) as Adventurer
	var around: Array[Character] = []
	for offset in [Vector3(0, 0, 1.3), Vector3(0, 0, -1.3), Vector3(1.3, 0, 0), Vector3(-1.3, 0, 0)]:
		around.append(arena.spawn(TestArena.SKELETON, offset))
	await arena.wait_physics(3)

	barbarian.attack.try_attack(barbarian)
	await arena.wait_seconds(barbarian.attack.impact_delay + 0.1)

	for skeleton in around:
		assert_float(skeleton.health).is_equal(4.0)


func test_spin_does_not_reach_far_enemies() -> void:
	var barbarian := arena.spawn(SCENE, Vector3.ZERO) as Adventurer
	var far := arena.spawn(TestArena.SKELETON, Vector3(0, 0, 3.0))
	await arena.wait_physics(3)

	barbarian.attack.try_attack(barbarian)
	await arena.wait_seconds(barbarian.attack.impact_delay + 0.1)

	assert_float(far.health).is_equal(5.0)


func test_spin_plays_faster_than_the_original_animation() -> void:
	var barbarian := arena.spawn(SCENE, Vector3.ZERO) as Adventurer

	assert_float(barbarian.attack.animation_speed).is_greater(1.0)
	assert_array(Array(barbarian.attack.animations)).is_equal(["2H_Melee_Attack_Spin"])
