extends GdUnitTestSuite

const MANA_POTION := preload("res://scenes/world/mana_potion.tscn")
const MANA_ITEM := preload("res://resources/items/mana_potion.tres")

var arena: TestArena


func before_test() -> void:
	RunState.reset()
	arena = TestArena.new(self)


func _potion_at(spot: Vector3) -> Potion:
	var potion := MANA_POTION.instantiate() as Potion
	potion.position = spot
	arena.root.add_child(potion)
	return potion


func test_the_mage_picks_up_a_mana_potion() -> void:
	var mage := arena.spawn(TestArena.MAGE, Vector3(0, 0, 3)) as Adventurer
	_potion_at(Vector3(0, 0, 3))
	await arena.wait_physics(3)

	assert_int(mage.inventory.count_of(MANA_ITEM)).is_equal(1)


func test_who_does_not_use_mana_leaves_it_on_the_ground() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 3)) as Adventurer
	var potion := _potion_at(Vector3(0, 0, 3))
	await arena.wait_physics(3)

	assert_int(knight.inventory.count_of(MANA_ITEM)).is_equal(0)
	assert_bool(potion.model.visible).is_true()


func test_drinking_it_brings_mana_back() -> void:
	var mage := arena.spawn(TestArena.MAGE, Vector3.ZERO) as Adventurer
	await arena.wait_physics(2)
	mage.inventory.add(MANA_ITEM)
	mage.mana.spend(60.0)
	var before := mage.mana.current

	assert_bool(mage.use_item()).is_true()

	assert_float(mage.mana.current).is_equal_approx(before + MANA_ITEM.mana_amount, 0.01)
	assert_int(mage.inventory.count_of(MANA_ITEM)).is_equal(0)


func test_with_full_mana_it_is_not_wasted() -> void:
	var mage := arena.spawn(TestArena.MAGE, Vector3.ZERO) as Adventurer
	await arena.wait_physics(2)
	mage.inventory.add(MANA_ITEM)

	assert_bool(mage.use_item()).is_false()
	assert_int(mage.inventory.count_of(MANA_ITEM)).is_equal(1)
