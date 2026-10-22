extends GdUnitTestSuite

# pedidos que chegam de outra maquina: so valem de quem controla o personagem e esta perto.
# Chamados direto, fora de uma rpc, o remetente e 0 (ninguem)

const HOST := 1
const STRANGER := 7

var arena: TestArena
var knight: Adventurer
var mage: Adventurer
var skeleton: Character


func before_test() -> void:
	RunState.reset()
	arena = TestArena.new(self)
	knight = arena.spawn(TestArena.KNIGHT, Vector3.ZERO) as Adventurer
	mage = arena.spawn(TestArena.MAGE, Vector3(1.5, 0, 0)) as Adventurer
	skeleton = arena.spawn(TestArena.SKELETON, Vector3(-4, 0, 0))
	await arena.wait_physics(2)


func after_test() -> void:
	Net.friendly_fire = true
	RunState.reset()


func test_remote_amounts_must_be_finite_and_in_range() -> void:
	assert_bool(Character.is_valid_remote_amount(3.0)).is_true()
	assert_bool(Character.is_valid_remote_amount(-1.0)).is_false()
	assert_bool(Character.is_valid_remote_amount(Character.MAX_REMOTE_AMOUNT + 1.0)).is_false()
	assert_bool(Character.is_valid_remote_amount(NAN)).is_false()
	assert_bool(Character.is_valid_remote_amount(INF)).is_false()


func test_only_who_controls_the_attacker_can_report_its_hit() -> void:
	assert_bool(skeleton.accepts_hit_from(HOST, knight)).is_true()
	assert_bool(skeleton.accepts_hit_from(STRANGER, knight)).is_false()


func test_a_hit_from_farther_than_any_attack_reaches_is_refused() -> void:
	knight.global_position = Vector3(Character.REMOTE_HIT_REACH + 5.0, 0, 0)

	assert_bool(skeleton.accepts_hit_from(HOST, knight)).is_false()


func test_remote_damage_is_capped_near_the_strongest_hit_of_the_game() -> void:
	assert_bool(Character.is_valid_remote_amount(15.0)).is_true()
	assert_bool(Character.is_valid_remote_amount(999.0)).is_false()


func test_a_hit_without_attacker_only_comes_from_the_host() -> void:
	assert_bool(knight.accepts_hit_from(HOST, null)).is_true()
	assert_bool(knight.accepts_hit_from(STRANGER, null)).is_false()


func test_with_friendly_fire_off_allies_cannot_report_hits_on_each_other() -> void:
	Net.friendly_fire = false

	assert_bool(mage.accepts_hit_from(HOST, knight)).is_false()
	assert_bool(skeleton.accepts_hit_from(HOST, knight)).is_true()


func test_a_damage_request_outside_the_network_does_nothing() -> void:
	skeleton._request_damage(5.0, skeleton.get_path_to(knight))

	assert_float(skeleton.health).is_equal(skeleton.get_max_health())


func test_revive_needs_a_living_ally_close_by() -> void:
	mage.take_damage(99.0)
	await arena.wait_physics(2)

	assert_bool(mage.accepts_revive_from(HOST)).is_true()
	assert_bool(mage.accepts_revive_from(STRANGER)).is_false()

	knight.global_position = Vector3(12, 0, 0)
	assert_bool(mage.accepts_revive_from(HOST)).is_false()


func test_revive_is_refused_for_someone_standing() -> void:
	assert_bool(mage.accepts_revive_from(HOST)).is_false()


func test_a_revive_request_outside_the_network_does_nothing() -> void:
	mage.take_damage(99.0)
	await arena.wait_physics(2)

	mage._request_revive(5.0)

	assert_bool(mage.is_dead).is_true()


func test_a_shot_still_counts_after_the_shooter_falls() -> void:
	knight.take_damage(99.0)
	await arena.wait_physics(2)
	var tree := arena.root.get_tree()

	assert_bool(Adventurer.peer_can_reach(tree, HOST, knight.global_position, 1.0)).is_false()
	assert_bool(Adventurer.peer_can_reach(tree, HOST, knight.global_position, 1.0, false)).is_true()


func test_each_player_is_found_by_peer() -> void:
	assert_object(Adventurer.of_peer(arena.root.get_tree(), STRANGER)).is_null()
	assert_bool(Adventurer.peer_can_reach(arena.root.get_tree(), HOST, knight.global_position, 1.0)).is_true()
	assert_bool(Adventurer.peer_can_reach(arena.root.get_tree(), STRANGER, knight.global_position, 1.0)).is_false()


func test_a_shot_announced_outside_the_network_is_not_fired() -> void:
	var bolt := mage.attack as RangedAttack
	var before := arena.root.find_children("*", "Projectile", true, false).size()

	bolt._net_fire(bolt.get_path_to(mage), mage.global_position, Vector3.FORWARD, 1.0, false)

	assert_int(arena.root.find_children("*", "Projectile", true, false).size()).is_equal(before)


func test_a_portal_announced_outside_the_network_is_not_opened() -> void:
	var spell := mage.abilities[1] as PortalSpell

	spell._net_open(spell.get_path_to(mage), Vector3(0, 0, 4), Vector3.FORWARD)

	assert_int(arena.root.find_children("*", "Portal", true, false).size()).is_equal(0)


func test_the_reviver_spends_the_potion_only_when_the_revive_happens() -> void:
	knight.inventory.add(load("res://resources/items/health_potion.tres"))
	mage.take_damage(99.0)
	await arena.wait_physics(2)
	mage.revive(5.0)

	knight.revive_ally()

	assert_int(knight.inventory.count_of(load("res://resources/items/health_potion.tres"))).is_equal(1)
