extends GdUnitTestSuite

var arena: TestArena


func before_test() -> void:
	RunState.reset()
	arena = TestArena.new(self)


func test_friendly_fire_reaches_every_ability_of_the_mage() -> void:
	var mage := arena.spawn(TestArena.MAGE, Vector3.ZERO) as Adventurer
	await arena.wait_physics(2)

	mage._allow_friendly_fire()

	for ability in mage.abilities:
		if ability is RangedAttack:
			assert_int(ability.target_layers & mage.collision_layer).is_not_zero()


func test_friendly_fire_reaches_the_knight_sword() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO) as Adventurer
	await arena.wait_physics(2)

	knight._allow_friendly_fire()

	var hitbox := knight.attack.get_node("Hitbox") as Area3D
	assert_int(hitbox.collision_mask & knight.collision_layer).is_not_zero()
