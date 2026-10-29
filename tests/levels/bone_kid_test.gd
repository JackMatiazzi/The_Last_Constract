extends GdUnitTestSuite

const LEVEL := preload("res://scenes/levels/calabouco_escondido_level.tscn")

var level: Node3D
var player: Adventurer
var kid: BoneKid


func _start_as(adventurer: String) -> void:
	RunState.reset()
	RunState.adventurer = load("res://resources/adventurers/%s.tres" % adventurer)
	level = auto_free(LEVEL.instantiate())
	add_child(level)
	kid = level.get_node("Esqueletinho") as BoneKid
	for i in 6:
		await get_tree().physics_frame
	player = (level.get_node("GameSession") as GameSession).player
	for enemy: Enemy in level.find_children("*", "Enemy", true, false):
		enemy.ai_enabled = false


func after_test() -> void:
	RunState.adventurer = null
	RunState.reset()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _walk_up_to_him() -> void:
	player.global_position = kid.global_position + Vector3(1.5, 0.1, 0)
	player.reset_physics_interpolation()
	for i in 4:
		await get_tree().physics_frame


func _roar() -> void:
	kid._request_roar.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)


func test_only_the_barbarian_roars() -> void:
	await _start_as("barbarian")

	assert_bool(player.roars).is_true()
	for other in ["knight", "mage", "rogue"]:
		var scene := (load("res://resources/adventurers/%s.tres" % other) as AdventurerInfo).scene
		var adventurer := auto_free(scene.instantiate()) as Adventurer
		assert_bool(adventurer.roars).override_failure_message(other).is_false()


func test_the_barbarian_sees_that_he_can_roar() -> void:
	await _start_as("barbarian")

	await _walk_up_to_him()

	assert_bool(kid.prompt.visible).is_true()
	assert_str(kid.prompt.text).contains("Urrar")


func test_anyone_else_gets_no_roar_option() -> void:
	await _start_as("rogue")

	await _walk_up_to_him()

	assert_bool(kid.prompt.visible).is_false()


func test_he_keeps_asking_for_the_roar() -> void:
	await _start_as("rogue")
	await _walk_up_to_him()

	await get_tree().create_timer(0.5).timeout

	assert_bool(kid.speech.visible).is_true()
	assert_str(kid.speech.text.to_lower()).contains("urro")


func test_he_follows_whoever_comes_close() -> void:
	await _start_as("rogue")
	player.global_position = kid.global_position + Vector3(6, 0.1, 0)
	player.reset_physics_interpolation()
	var start := kid.global_position.distance_to(player.global_position)

	await get_tree().create_timer(1.5).timeout

	assert_float(kid.global_position.distance_to(player.global_position)).is_less(start - 1.0)


# de longe o bastante para o presente nao ser pego na hora
func test_the_first_roar_brings_a_gift_and_the_cellar_hint() -> void:
	await _start_as("barbarian")
	player.global_position = kid.global_position + Vector3(3.2, 0.1, 0)
	player.reset_physics_interpolation()
	await get_tree().physics_frame

	_roar()
	await get_tree().create_timer(BoneKid.TUMBLE_TIME + 0.3).timeout
	var cheer := kid.speech.text
	await get_tree().create_timer(BoneKid.LINE_TIME).timeout

	assert_int(kid.roars_heard).is_equal(1)
	assert_str(cheer).is_equal(kid.again_line)
	assert_str(kid.speech.text).is_equal(kid.hint_line)
	assert_object(level.find_child("PresenteDoEsqueletinho", true, false)).is_not_null()


func test_another_roar_gives_no_second_gift() -> void:
	await _start_as("barbarian")
	player.global_position = kid.global_position + Vector3(3.2, 0.1, 0)
	player.reset_physics_interpolation()
	await get_tree().physics_frame
	_roar()
	await get_tree().create_timer(BoneKid.TUMBLE_TIME * 2.0 + 0.2).timeout

	_roar()
	await get_tree().physics_frame

	assert_int(kid.roars_heard).is_equal(2)
	assert_int(level.find_children("PresenteDoEsqueletinho*", "", true, false).size()).is_equal(1)


func test_no_one_else_can_ask_for_the_roar() -> void:
	await _start_as("rogue")
	await _walk_up_to_him()

	_roar()

	assert_int(kid.roars_heard).is_equal(0)


func test_a_roar_from_far_away_does_not_count() -> void:
	await _start_as("barbarian")
	player.global_position = kid.global_position + Vector3(10, 0.1, 0)
	player.reset_physics_interpolation()
	await get_tree().physics_frame

	_roar()

	assert_int(kid.roars_heard).is_equal(0)


func test_hitting_him_only_makes_him_fall_apart() -> void:
	await _start_as("knight")

	kid.take_damage(99.0, player)
	await get_tree().create_timer(BoneKid.TUMBLE_TIME + 0.3).timeout

	assert_bool(kid.is_dead).is_false()
	assert_float(kid.health).is_equal(kid.get_max_health())
	assert_str(kid.speech.text).is_equal(kid.hurt_line)


func test_he_is_too_small_for_the_contract() -> void:
	await _start_as("knight")

	assert_bool(kid.is_in_group(UndeadCensus.GROUP)).is_false()


func _ignore_him(times: int) -> void:
	for i in times:
		kid._pester(BoneKid.PESTER_TIME)


func test_a_barbarian_who_keeps_denying_the_roar_makes_him_sulk() -> void:
	await _start_as("barbarian")
	await _walk_up_to_him()
	var census := level.get_node("Contagem") as UndeadCensus
	var standing := census.remaining()

	_ignore_him(kid.denial_limit + 1)

	assert_bool(kid.is_sulking).is_true()
	assert_int(census.remaining()).is_equal(standing + 1)
	assert_str(kid.speech.text).is_equal(kid.sulk_line)


func test_a_sulking_kid_can_fall_like_any_undead() -> void:
	await _start_as("barbarian")
	await _walk_up_to_him()
	_ignore_him(kid.denial_limit + 1)

	kid.take_damage(99.0, player)

	assert_bool(kid.is_dead).is_true()


func test_a_late_roar_makes_up_with_him_and_still_brings_the_gift() -> void:
	await _start_as("barbarian")
	player.global_position = kid.global_position + Vector3(3.2, 0.1, 0)
	player.reset_physics_interpolation()
	await get_tree().physics_frame
	_ignore_him(kid.denial_limit + 1)

	_roar()
	await get_tree().physics_frame

	assert_bool(kid.is_sulking).is_false()
	assert_bool(kid.is_in_group(UndeadCensus.GROUP)).is_false()
	assert_bool(kid.gift_given).is_true()
	assert_object(level.find_child("PresenteDoEsqueletinho", true, false)).is_not_null()


func test_a_fallen_kid_hides_the_roar_option() -> void:
	await _start_as("barbarian")
	await _walk_up_to_him()
	_ignore_him(kid.denial_limit + 1)

	kid.take_damage(99.0, player)

	assert_bool(kid.prompt.visible).is_false()


func test_without_a_barbarian_there_is_no_roar_to_deny() -> void:
	await _start_as("rogue")
	await _walk_up_to_him()

	_ignore_him(kid.denial_limit * 3)

	assert_bool(kid.is_sulking).is_false()
	assert_bool(kid.is_in_group(UndeadCensus.GROUP)).is_false()
