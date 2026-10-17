extends GdUnitTestSuite

const CHEST := preload("res://scenes/world/chest.tscn")
const POTION := preload("res://scenes/world/health_potion.tscn")

var arena: TestArena


func before_test() -> void:
	RunState.reset()
	arena = TestArena.new(self)


func _chest_at(position: Vector3) -> Chest:
	var chest := CHEST.instantiate() as Chest
	chest.position = position
	arena.root.add_child(chest)
	return chest


func _potions() -> Array[Node]:
	return arena.root.find_children("*", "HealthPotion", true, false)


func test_prompt_shows_only_when_the_player_is_close() -> void:
	var chest := _chest_at(Vector3(0, 0, 5))
	var knight := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 12))
	await arena.wait_physics(3)
	assert_bool(chest.prompt.visible).is_false()

	knight.global_position = Vector3(0, 0, 7.5)
	await arena.wait_physics(3)

	assert_bool(chest.prompt.visible).is_true()


func test_interact_near_the_chest_opens_it_and_drops_a_potion() -> void:
	var chest := _chest_at(Vector3(0, 0, 5))
	arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 7.5))
	await arena.wait_physics(3)

	await arena.send_action("interact")
	await arena.wait_seconds(0.7)

	assert_bool(chest.is_open).is_true()
	assert_int(_potions().size()).is_equal(1)


func test_interact_far_away_does_nothing() -> void:
	var chest := _chest_at(Vector3(0, 0, 5))
	arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 14))
	await arena.wait_physics(3)

	await arena.send_action("interact")
	await arena.wait_seconds(0.7)

	assert_bool(chest.is_open).is_false()
	assert_int(_potions().size()).is_equal(0)


func test_chest_opens_only_once() -> void:
	var chest := _chest_at(Vector3(0, 0, 5))
	arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 7.5))
	await arena.wait_physics(3)

	await arena.send_action("interact")
	await arena.wait_seconds(0.7)
	await arena.send_action("interact")
	await arena.wait_seconds(0.7)

	assert_int(_potions().size()).is_equal(1)


func test_potion_heals_a_wounded_adventurer_and_disappears() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 3))
	knight.take_damage(5.0)
	var potion := POTION.instantiate() as HealthPotion
	potion.position = Vector3(0, 0, 3)
	arena.root.add_child(potion)
	await arena.wait_physics(3)

	assert_float(knight.health).is_equal(5.0 + potion.heal_amount)
	await arena.wait_seconds(1.5)
	assert_bool(is_instance_valid(potion)).is_false()


func test_potion_never_heals_above_max_health() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 3))
	knight.take_damage(1.0)
	var potion := POTION.instantiate() as HealthPotion
	potion.position = Vector3(0, 0, 3)
	arena.root.add_child(potion)
	await arena.wait_physics(3)

	assert_float(knight.health).is_equal(knight.get_max_health())


func test_potion_waits_while_health_is_full() -> void:
	arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 3))
	var potion := POTION.instantiate() as HealthPotion
	potion.position = Vector3(0, 0, 3)
	arena.root.add_child(potion)
	await arena.wait_physics(3)

	assert_bool(is_instance_valid(potion) and potion.model.visible).is_true()


func test_potion_heals_when_the_player_standing_on_it_gets_hurt() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 3))
	var potion := POTION.instantiate() as HealthPotion
	potion.position = Vector3(0, 0, 3)
	arena.root.add_child(potion)
	await arena.wait_physics(3)

	knight.take_damage(4.0)
	await arena.wait_physics(1)

	assert_float(knight.health).is_equal(knight.get_max_health() - 4.0 + potion.heal_amount)
	assert_bool(potion.model.visible).is_false()
