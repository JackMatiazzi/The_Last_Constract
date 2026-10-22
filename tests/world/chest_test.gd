extends GdUnitTestSuite

const CHEST := preload("res://scenes/world/chest.tscn")
const POTION := preload("res://scenes/world/health_potion.tscn")
const HEALTH_POTION := preload("res://resources/items/health_potion.tres")

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


# quem esta perto ja pega a pocao: conta a do chao e a do inventario
func _dropped_for(adventurer: Adventurer) -> int:
	var on_ground := _potions().filter(func(potion: HealthPotion) -> bool: return potion.model.visible).size()
	return on_ground + adventurer.inventory.count_of(HEALTH_POTION)


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
	var knight := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 7.5)) as Adventurer
	await arena.wait_physics(3)

	await arena.send_action("interact")
	await arena.wait_seconds(0.7)

	assert_bool(chest.is_open).is_true()
	assert_int(_dropped_for(knight)).is_equal(1)


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
	var knight := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 7.5)) as Adventurer
	await arena.wait_physics(3)

	await arena.send_action("interact")
	await arena.wait_seconds(0.7)
	await arena.send_action("interact")
	await arena.wait_seconds(0.7)

	assert_bool(chest.is_open).is_true()
	assert_int(_dropped_for(knight)).is_equal(1)


func _potion_at(position: Vector3) -> HealthPotion:
	var potion := POTION.instantiate() as HealthPotion
	potion.position = position
	arena.root.add_child(potion)
	return potion


func test_touching_a_potion_stores_it_instead_of_healing() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 3)) as Adventurer
	knight.take_damage(5.0)
	var potion := _potion_at(Vector3(0, 0, 3))
	await arena.wait_physics(3)

	assert_float(knight.health).is_equal(5.0)
	assert_int(knight.inventory.count_of(potion.item)).is_equal(1)
	await arena.wait_seconds(1.5)
	assert_bool(is_instance_valid(potion)).is_false()


func test_a_full_inventory_leaves_the_potion_on_the_ground() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 3)) as Adventurer
	var item := HEALTH_POTION
	for i in item.max_carried:
		knight.inventory.add(item)
	var potion := _potion_at(Vector3(0, 0, 3))
	await arena.wait_physics(3)

	assert_bool(potion.model.visible).is_true()
	assert_int(knight.inventory.count_of(item)).is_equal(item.max_carried)


func test_a_sword_hit_breaks_a_potion_on_the_ground() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, -6)) as Adventurer
	var potion := _potion_at(Vector3(0, 0, -4.8))
	for i in HEALTH_POTION.max_carried:
		knight.inventory.add(HEALTH_POTION)
	await arena.wait_physics(3)

	knight.attack.try_attack(knight)
	await arena.wait_seconds(knight.attack.impact_delay + 0.1)

	assert_bool(potion.model.visible).is_false()
	assert_int(knight.inventory.count_of(HEALTH_POTION)).is_equal(HEALTH_POTION.max_carried)


func test_a_bolt_breaks_a_potion_on_the_ground() -> void:
	var rogue := arena.spawn(TestArena.ROGUE, Vector3(6, 0, -6)) as Adventurer
	var potion := _potion_at(Vector3(6, 0, -2))
	await arena.wait_physics(3)

	rogue.attack_toward_camera()
	await arena.wait_seconds(rogue.attack.impact_delay + 0.5)

	assert_bool(not is_instance_valid(potion) or not potion.model.visible).is_true()


func test_standing_by_a_closed_chest_counts_as_something_to_interact() -> void:
	_chest_at(Vector3(0, 0, 5))
	var knight := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 7.5)) as Adventurer
	await arena.wait_physics(3)
	assert_int(knight.interactables_in_reach).is_equal(1)

	await arena.send_action("interact")
	await arena.wait_seconds(0.2)
	assert_int(knight.interactables_in_reach).is_equal(0)


func test_an_open_request_from_someone_far_away_is_ignored() -> void:
	var chest := _chest_at(Vector3(0, 0, 5))
	arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 14))
	await arena.wait_physics(3)

	chest._request_open.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)

	assert_bool(chest.is_open).is_false()


func test_two_adventurers_on_the_same_potion_get_only_one() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3(-0.4, 0, 3)) as Adventurer
	var rogue := arena.spawn(TestArena.ROGUE, Vector3(0.4, 0, 3)) as Adventurer
	_potion_at(Vector3(0, 0, 3))
	await arena.wait_physics(3)

	var carried := knight.inventory.count_of(HEALTH_POTION) + rogue.inventory.count_of(HEALTH_POTION)
	assert_int(carried).is_equal(1)


func test_a_full_adventurer_takes_the_waiting_potion_after_drinking_one() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 3)) as Adventurer
	for i in HEALTH_POTION.max_carried:
		knight.inventory.add(HEALTH_POTION)
	knight.take_damage(5.0)
	var potion := _potion_at(Vector3(0, 0, 3))
	await arena.wait_physics(3)
	assert_bool(potion.model.visible).is_true()

	knight.use_item()
	await arena.wait_physics(2)

	assert_bool(potion.model.visible).is_false()
	assert_int(knight.inventory.count_of(HEALTH_POTION)).is_equal(HEALTH_POTION.max_carried)
