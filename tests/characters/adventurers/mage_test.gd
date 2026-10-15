extends GdUnitTestSuite

const SCENE := TestArena.MAGE

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


func test_shows_staff_only() -> void:
	var mage := arena.spawn(SCENE, Vector3.ZERO)

	assert_array(checks.visible_weapons(mage)).is_equal(["2H_Staff"])


func test_bolt_pierces_three_enemies_in_line() -> void:
	var mage := arena.spawn(SCENE, Vector3.ZERO) as Adventurer
	var line: Array[Character] = []
	for distance in [4.0, 7.0, 10.0]:
		line.append(arena.spawn(TestArena.SKELETON, Vector3(0, 0, distance)))
	await arena.wait_physics(3)

	mage.attack.try_attack(mage)
	await arena.wait_seconds(1.6)

	for skeleton in line:
		assert_float(skeleton.health).is_equal(4.0)


func test_bolt_does_not_reach_beyond_its_range() -> void:
	var mage := arena.spawn(SCENE, Vector3.ZERO) as Adventurer
	var far := arena.spawn(TestArena.SKELETON, Vector3(0, 0, 21))
	await arena.wait_physics(3)

	mage.attack.try_attack(mage)
	await arena.wait_seconds(2.2)

	assert_float(far.health).is_equal(5.0)


func test_bolt_leaves_from_in_front_of_the_mage() -> void:
	var mage := arena.spawn(SCENE, Vector3.ZERO) as Adventurer
	await arena.wait_physics(3)

	mage.attack.try_attack(mage)
	await arena.wait_seconds(mage.attack.impact_delay + 0.03)

	var bolts := arena.root.find_children("*", "Projectile", true, false)
	assert_int(bolts.size()).is_equal(1)
	var bolt := bolts[0] as Projectile
	assert_float(bolt.global_position.z).is_greater(0.4)
	assert_float(bolt.global_position.y).is_between(0.8, 1.8)
