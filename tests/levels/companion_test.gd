extends GdUnitTestSuite

const LEVEL := preload("res://scenes/levels/calabouco_escondido_level.tscn")
const MAX_TALKS := 40

var level: Node3D
var player: Adventurer
var swordsman: FriendlyUndead
var _friendly_fire_before: bool


func before_test() -> void:
	RunState.reset()
	RunState.adventurer = load("res://resources/adventurers/rogue.tres")
	_friendly_fire_before = Net.friendly_fire
	level = auto_free(LEVEL.instantiate())
	add_child(level)
	swordsman = level.get_node("EspadachimPerdido") as FriendlyUndead
	for i in 6:
		await get_tree().physics_frame
	player = (level.get_node("GameSession") as GameSession).player
	for enemy: Enemy in level.find_children("*", "Enemy", true, false):
		enemy.ai_enabled = false


func after_test() -> void:
	Net.friendly_fire = _friendly_fire_before
	RunState.adventurer = null
	RunState.reset()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _teleport(body: Node3D, spot: Vector3) -> void:
	body.global_position = spot
	body.reset_physics_interpolation()
	for i in 4:
		await get_tree().physics_frame


func _talk() -> String:
	swordsman._request_talk.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)
	return swordsman.speech.text


func _talk_until_invited() -> void:
	await _teleport(player, swordsman.global_position + Vector3(2, 0.1, 0))
	for i in MAX_TALKS:
		if swordsman.awaiting_answer:
			return
		_talk()


func _answer(accepted: bool) -> void:
	swordsman._request_answer.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, accepted)


func _join() -> void:
	await _talk_until_invited()
	_answer(true)
	swordsman.companion._next_wander = INF


func _hitbox_mask() -> int:
	return (swordsman.attack.get_node("Hitbox") as Area3D).collision_mask


func test_he_asks_to_join_only_after_his_first_round_of_lines() -> void:
	await _teleport(player, swordsman.global_position + Vector3(2, 0.1, 0))
	_talk()
	_talk()
	assert_bool(swordsman.awaiting_answer).is_false()

	await _talk_until_invited()

	assert_bool(swordsman.awaiting_answer).is_true()
	assert_str(swordsman.speech.text).is_equal(swordsman.for_group(swordsman.invite_line))
	assert_str(swordsman.prompt.text).contains("Aceitar")
	assert_str(swordsman.prompt.text).contains("Recusar")


func test_accepting_makes_him_follow_whoever_said_yes() -> void:
	await _join()

	assert_bool(swordsman.is_companion).is_true()
	assert_object(swordsman.companion.leader).is_same(player)
	assert_str(swordsman.speech.text).is_equal(swordsman.for_group(swordsman.accept_line))
	assert_str(swordsman.prompt.text).contains("Conversar")


func test_declining_waits_for_the_next_floor() -> void:
	await _talk_until_invited()

	_answer(false)
	for i in MAX_TALKS:
		_talk()

	assert_bool(swordsman.is_companion).is_false()
	assert_bool(swordsman.awaiting_answer).is_false()
	assert_str(swordsman.speech.text).is_not_equal(swordsman.for_group(swordsman.invite_line))


func test_after_declining_he_asks_again_on_the_next_floor() -> void:
	await _talk_until_invited()
	_answer(false)
	await _teleport(player, swordsman.floor_triggers[0].global_position)

	await _talk_until_invited()

	assert_bool(swordsman.awaiting_answer).is_true()


func test_in_the_group_he_follows_the_leader() -> void:
	await _join()
	var spot := swordsman.global_position + Vector3(-9, 0, 0)
	await _teleport(player, spot + Vector3.UP * 0.1)
	var start := swordsman.global_position.distance_to(player.global_position)

	await get_tree().create_timer(3.0).timeout

	assert_float(start).is_greater(8.0)
	assert_float(swordsman.global_position.distance_to(player.global_position)).is_less(swordsman.companion.follow_distance + 1.0)


func test_in_the_group_he_cuts_the_undead() -> void:
	await _join()
	var patrol := level.get_node("PatrulhaDoSalao") as Node3D
	var skeleton := patrol.find_children("*", "Enemy", true, false)[0] as Enemy
	await _teleport(player, skeleton.global_position + Vector3(2, 0.1, 0))
	await _teleport(swordsman, skeleton.global_position + Vector3(-3, 0.1, 0))

	await get_tree().create_timer(4.0).timeout

	assert_float(skeleton.health).is_less(skeleton.get_max_health())


func test_with_friendly_fire_his_blades_can_hit_the_group() -> void:
	Net.friendly_fire = true

	await _join()

	assert_int(_hitbox_mask() & FriendlyUndead.UNDEAD_LAYER).is_equal(FriendlyUndead.UNDEAD_LAYER)
	assert_int(_hitbox_mask() & FriendlyUndead.ADVENTURERS_LAYER).is_equal(FriendlyUndead.ADVENTURERS_LAYER)


func test_without_friendly_fire_his_blades_only_find_the_undead() -> void:
	Net.friendly_fire = false

	await _join()

	assert_int(_hitbox_mask()).is_equal(FriendlyUndead.UNDEAD_LAYER)


func test_now_and_then_he_gets_lost_until_someone_finds_him() -> void:
	await _join()

	swordsman.companion._get_lost()
	var lost := swordsman.companion.is_lost
	_talk()

	assert_bool(lost).is_true()
	assert_bool(swordsman.companion.is_lost).is_false()
	assert_str(swordsman.speech.text).is_equal(swordsman.for_group(swordsman.companion.found_line))


func test_lost_he_stops_and_waits_until_the_leader_comes() -> void:
	await _join()
	swordsman.companion._get_lost()
	swordsman.companion._lost_until = 0.0
	await _teleport(player, swordsman.global_position + Vector3(-9, 0.1, 0))

	swordsman.companion.tick(0.1)
	var waiting := swordsman.speech.text
	await _teleport(player, swordsman.global_position + Vector3(2, 0.1, 0))
	swordsman.companion.tick(0.1)

	assert_str(waiting).is_equal(swordsman.for_group(swordsman.companion.wait_line))
	assert_bool(swordsman.companion.is_lost).is_false()


func test_now_and_then_he_gets_lost_by_himself() -> void:
	await _join()
	swordsman.companion._next_wander = 0.0

	swordsman.companion.tick(0.1)

	assert_bool(swordsman.companion.is_lost).is_true()


func test_he_ignores_undead_behind_a_wall() -> void:
	await _join()
	var patrol := level.get_node("PatrulhaDaCripta") as Node3D
	var skeleton := patrol.find_children("*", "Enemy", true, false)[0] as Enemy
	swordsman.global_position = skeleton.global_position + Vector3(0, 4, 0)
	swordsman.reset_physics_interpolation()
	await get_tree().physics_frame

	assert_object(swordsman.companion._nearest_enemy()).is_null()


func test_he_does_not_wake_sleeping_undead() -> void:
	await _join()
	var sleepers := level.get_node("AdormecidosDoOssuario") as Node3D
	var sleeper := sleepers.find_children("*", "Enemy", true, false)[0] as Enemy
	await _teleport(swordsman, sleeper.global_position + Vector3(2, 0.1, 0))

	assert_str(sleeper.brain.current_state_name).is_equal("Dormant")
	assert_object(swordsman.companion._nearest_enemy()).is_null()


func test_he_wanders_far_when_he_gets_lost() -> void:
	await _join()

	swordsman.companion._get_lost()

	assert_float(swordsman.companion.goal.distance_to(swordsman.global_position)).is_greater(6.0)


func test_traps_he_sets_off_never_hurt_him() -> void:
	await _join()
	var darts := level.get_node("Navigation/Calabouco/Armadilhas/Dardos")

	swordsman.take_damage(2.0, darts)

	assert_float(swordsman.health).is_equal(swordsman.get_max_health())
	assert_str(swordsman.speech.text).is_equal(swordsman.for_group(swordsman.trap_line))


func test_a_hit_from_the_group_hurts_his_feelings() -> void:
	await _join()

	swordsman.take_damage(1.0, player)

	assert_float(swordsman.health).is_equal(swordsman.get_max_health() - 1.0)
	assert_str(swordsman.speech.text).is_equal(swordsman.for_group(swordsman.ally_hurt_line))
	assert_bool(swordsman.is_companion).is_true()


func test_beaten_down_he_leaves_the_group_and_fights() -> void:
	Net.friendly_fire = true
	await _join()

	swordsman.take_damage(swordsman.health - 3.0, player)

	assert_int(swordsman.style).is_equal(1)
	assert_bool(swordsman.is_companion).is_false()
	assert_int(_hitbox_mask()).is_equal(FriendlyUndead.ADVENTURERS_LAYER)


func test_in_the_group_he_walks_down_with_the_leader() -> void:
	await _join()
	var trigger := swordsman.floor_triggers[0]
	await _teleport(swordsman, trigger.global_position + Vector3(1.5, 0.1, 0))

	await _teleport(player, trigger.global_position)

	assert_int(swordsman.floor_index).is_equal(1)
	assert_float(swordsman.global_position.distance_to(swordsman.spots[1].global_position)).is_greater(5.0)


func test_lost_far_away_he_shows_up_first_on_the_next_floor() -> void:
	await _join()
	var trigger := swordsman.floor_triggers[0]

	await _teleport(player, trigger.global_position)

	assert_float((swordsman.global_position - swordsman.spots[1].global_position).slide(Vector3.UP).length()).is_less(0.5)
	assert_str(swordsman.speech.text).is_equal(swordsman.for_group(swordsman.ahead_line))


func test_in_the_group_he_still_counts_for_the_contract() -> void:
	await _join()

	assert_bool(swordsman.is_in_group(UndeadCensus.GROUP)).is_true()
