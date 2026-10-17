extends GdUnitTestSuite

const SCENE := TestArena.ROGUE

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


func test_shows_two_handed_crossbow_only() -> void:
	var rogue := arena.spawn(SCENE, Vector3.ZERO)

	assert_array(checks.visible_weapons(rogue)).is_equal(["2H_Crossbow"])


func test_bolt_reaches_long_range() -> void:
	var rogue := arena.spawn(SCENE, Vector3.ZERO) as Adventurer
	var far := arena.spawn(TestArena.SKELETON, Vector3(0, 0, 22))
	await arena.wait_physics(3)

	rogue.attack.try_attack(rogue)
	await arena.wait_seconds(1.3)

	assert_float(far.health).is_equal(4.0)


func test_bolt_stops_at_first_enemy() -> void:
	var rogue := arena.spawn(SCENE, Vector3.ZERO) as Adventurer
	var first := arena.spawn(TestArena.SKELETON, Vector3(0, 0, 6))
	var second := arena.spawn(TestArena.SKELETON, Vector3(0, 0, 10))
	await arena.wait_physics(3)

	rogue.attack.try_attack(rogue)
	await arena.wait_seconds(1.0)

	assert_float(first.health).is_equal(4.0)
	assert_float(second.health).is_equal(5.0)


func test_shoots_more_often_than_the_mage() -> void:
	var rogue := arena.spawn(SCENE, Vector3.ZERO) as Adventurer
	var mage := arena.spawn(TestArena.MAGE, Vector3(5, 0, 0)) as Adventurer

	assert_float(rogue.attack.effective_cooldown(rogue)).is_less(mage.attack.effective_cooldown(mage))
