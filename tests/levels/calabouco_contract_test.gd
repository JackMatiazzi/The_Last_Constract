extends GdUnitTestSuite

const LEVEL := preload("res://scenes/levels/calabouco_escondido_level.tscn")

var level: Node3D
var session: GameSession
var player: Adventurer
var swordsman: FriendlyUndead
var mimic: Mimic


class FakeSession extends GameSession:
	var fulfilled: Variant = null

	func end_contract(was_fulfilled: bool) -> void:
		fulfilled = was_fulfilled


func before_test() -> void:
	RunState.reset()
	RunState.adventurer = load("res://resources/adventurers/rogue.tres")
	level = auto_free(LEVEL.instantiate())
	add_child(level)
	session = level.get_node("GameSession") as GameSession
	swordsman = level.get_node("EspadachimPerdido") as FriendlyUndead
	mimic = level.get_node("Mimico") as Mimic
	for i in 6:
		await get_tree().physics_frame
	player = session.player
	for enemy: Enemy in level.find_children("*", "Enemy", true, false):
		enemy.ai_enabled = false


func after_test() -> void:
	RunState.adventurer = null
	RunState.reset()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _teleport(spot: Vector3) -> void:
	player.global_position = spot
	player.reset_physics_interpolation()
	for i in 4:
		await get_tree().physics_frame


# o espadachim no escuro so se assusta com o primeiro golpe
func _kill_every_undead() -> void:
	_startle_swordsman()
	for undead: Character in get_tree().get_nodes_in_group(UndeadCensus.GROUP):
		undead.take_damage(1000.0)
	await get_tree().physics_frame


# tira do escuro e pula a folga do susto, para o proximo golpe ja contar
func _startle_swordsman() -> void:
	if swordsman.in_the_dark:
		swordsman.take_damage(1.0, player)
	swordsman._startled_until = 0.0


func _talk() -> String:
	swordsman._request_talk.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)
	return swordsman.speech.text


func test_the_swordsman_waits_in_the_dark_with_the_lantern_off() -> void:
	assert_bool(swordsman.in_the_dark).is_true()
	assert_bool(swordsman.lantern.visible).is_false()


func test_the_first_shot_in_the_dark_only_startles_him() -> void:
	swordsman.take_damage(4.0, player)

	assert_float(swordsman.health).is_equal(swordsman.get_max_health())
	assert_bool(swordsman.in_the_dark).is_false()
	assert_bool(swordsman.lantern.visible).is_true()
	assert_str(swordsman.speech.text).contains("Uepa")


func test_the_rest_of_the_combo_does_not_cut_his_startle() -> void:
	swordsman.take_damage(4.0, player)

	swordsman.take_damage(2.0, player)

	assert_float(swordsman.health).is_equal(swordsman.get_max_health())
	assert_str(swordsman.speech.text).contains("Uepa")


func test_after_coming_out_he_takes_the_hits_and_complains() -> void:
	_startle_swordsman()

	swordsman.take_damage(2.0, player)

	assert_float(swordsman.health).is_equal(swordsman.get_max_health() - 2.0)
	assert_bool(Array(swordsman.hurt_lines).map(swordsman.for_group).has(swordsman.speech.text)).is_true()


func test_with_his_health_high_he_does_not_strike_back() -> void:
	await _teleport(swordsman.global_position + Vector3(1.5, 0.1, 0))
	_startle_swordsman()
	swordsman.take_damage(2.0, player)

	await get_tree().create_timer(2.0).timeout

	assert_int(swordsman.style).is_equal(0)
	assert_float(player.health).is_equal(player.get_max_health())


func _wound_swordsman_to(target_health: float) -> void:
	_startle_swordsman()
	var factor := swordsman.fighting_damage_factor if swordsman.style > 0 else 1.0
	swordsman.take_damage((swordsman.health - target_health) / factor, player)


func test_with_low_health_he_draws_one_sword() -> void:
	_wound_swordsman_to(3.0)

	assert_int(swordsman.style).is_equal(1)
	assert_object(swordsman.attack).is_same(swordsman.style_attacks[0])
	assert_bool(swordsman.drawn_blades[0].visible).is_true()
	assert_bool(swordsman.sheathed_blades[0].visible).is_false()
	assert_bool(swordsman.drawn_blades[1].visible).is_false()
	assert_str(swordsman.speech.text).is_equal(swordsman.for_group(swordsman.style_lines[0]))


func test_each_new_drop_draws_another_sword_up_to_three() -> void:
	_wound_swordsman_to(3.0)
	_wound_swordsman_to(2.0)
	assert_int(swordsman.style).is_equal(2)

	_wound_swordsman_to(1.0)

	assert_int(swordsman.style).is_equal(3)
	assert_object(swordsman.attack).is_same(swordsman.style_attacks[2])
	for blade in swordsman.drawn_blades:
		assert_bool(blade.visible).is_true()
	for blade in swordsman.sheathed_blades:
		assert_bool(blade.visible).is_false()
	assert_str(swordsman.speech.text).contains("Santoryuu")


func test_a_blow_that_skips_styles_draws_every_sword_at_once() -> void:
	_wound_swordsman_to(1.0)

	assert_int(swordsman.style).is_equal(3)
	assert_bool(swordsman.drawn_blades[1].visible).is_true()


func test_once_fighting_he_feels_only_a_quarter_of_each_blow() -> void:
	_wound_swordsman_to(3.0)

	swordsman.take_damage(2.0, player)

	assert_float(swordsman.health).is_equal_approx(2.5, 0.001)


func test_once_fighting_he_chases_and_cuts() -> void:
	await _teleport(swordsman.global_position + Vector3(-3, 0.1, 0))
	_wound_swordsman_to(3.0)

	await get_tree().create_timer(3.0).timeout

	assert_float(player.health).is_less(player.get_max_health())
	assert_str(player.damage_log.death_cause()).is_equal("Espadachim perdido")


func test_once_fighting_he_stops_talking_and_following_the_group() -> void:
	await _teleport(swordsman.global_position + Vector3(2, 0.1, 0))
	_wound_swordsman_to(3.0)
	var line := swordsman.speech.text

	swordsman._request_talk.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)
	swordsman._on_floor_reached(player, 1)

	assert_str(swordsman.speech.text).is_equal(line)
	assert_int(swordsman.floor_index).is_equal(0)


func test_the_first_talk_is_him_introducing_himself() -> void:
	await _teleport(swordsman.global_position + Vector3(2, 0.1, 0))

	var first := _talk()
	var second := _talk()

	assert_str(first).is_equal(swordsman.for_group(swordsman.introduction))
	assert_str(first).contains("Mayoi Michio")
	assert_str(second).is_equal(swordsman.for_group(swordsman.floor_lines[0][0]))
	assert_bool(swordsman.lantern.visible).is_true()


func test_before_he_introduces_himself_he_is_only_the_lost_swordsman() -> void:
	assert_str(swordsman.get_display_name()).is_equal("Espadachim perdido")


func test_after_he_introduces_himself_his_name_shows_in_the_damage_recap() -> void:
	await _teleport(swordsman.global_position + Vector3(-3, 0.1, 0))
	_talk()
	_talk()
	_wound_swordsman_to(3.0)

	await get_tree().create_timer(3.0).timeout

	assert_str(swordsman.get_display_name()).is_equal("Mayoi Michio")
	assert_str(player.damage_log.death_cause()).is_equal("Mayoi Michio")


func test_the_introduction_comes_first_on_any_floor() -> void:
	await _teleport(swordsman.floor_triggers[0].global_position)
	await _teleport(swordsman.global_position + Vector3(2, 0.1, 0))

	assert_str(_talk()).is_equal(swordsman.for_group(swordsman.introduction))
	assert_str(_talk()).is_equal(swordsman.for_group(swordsman.floor_lines[1][0]))


func test_standing_close_shows_that_he_can_talk() -> void:
	await _teleport(swordsman.global_position + Vector3(2, 0.1, 0))

	assert_bool(swordsman.prompt.visible).is_true()
	assert_str(swordsman.prompt.text).contains("Conversar")


func test_a_line_stays_until_the_next_one() -> void:
	await _teleport(swordsman.global_position + Vector3(2, 0.1, 0))
	_talk()
	_talk()

	await get_tree().create_timer(5.0).timeout

	assert_bool(swordsman.speech.visible).is_true()


func test_he_comments_on_the_seals_the_group_has_pulled() -> void:
	await _teleport(swordsman.global_position + Vector3(2, 0.1, 0))
	_talk()
	_talk()
	(level.get_node("Navigation/Calabouco/Mecanismos/SeloOeste") as Lever)._net_pull()

	var line := _talk()

	assert_str(line).contains("Um selo já foi")


func test_opening_a_companion_room_brings_back_a_memory() -> void:
	await _teleport(swordsman.global_position + Vector3(2, 0.1, 0))
	_talk()
	_talk()
	(level.get_node("Navigation/Calabouco/Mecanismos/PortaoBiblioteca") as Gate).activate()

	var line := _talk()

	assert_str(line).contains("Maelis")


func test_counting_the_undead_left_puts_the_number_in_the_line() -> void:
	var topic := DialogueTopic.new()
	topic.watch = NodePath("../Contagem")
	topic.property = &"remaining"
	topic.lines = PackedStringArray(["Faltam {valor}."])
	swordsman.topics = [topic]
	await _teleport(swordsman.global_position + Vector3(2, 0.1, 0))
	_talk()
	_talk()

	var line := _talk()

	assert_str(line).is_equal("Faltam %d." % (level.get_node("Contagem") as UndeadCensus).remaining())


func test_a_topic_is_told_once_then_the_floor_lines_come_back() -> void:
	var topic := DialogueTopic.new()
	topic.watch = NodePath("../Contagem")
	topic.property = &"remaining"
	topic.lines = PackedStringArray(["Uma vez só."])
	swordsman.topics = [topic]
	await _teleport(swordsman.global_position + Vector3(2, 0.1, 0))
	_talk()
	_talk()

	var told := _talk()
	var after := _talk()

	assert_str(told).is_equal("Uma vez só.")
	assert_str(after).is_equal(swordsman.for_group(swordsman.floor_lines[0][1]))


func test_a_topic_whose_moment_has_not_come_stays_quiet() -> void:
	var topic := DialogueTopic.new()
	topic.watch = NodePath("../Mimico")
	topic.property = &"is_dead"
	topic.lines = PackedStringArray(["O baú morreu."])
	swordsman.topics = [topic]
	await _teleport(swordsman.global_position + Vector3(2, 0.1, 0))
	_talk()
	_talk()

	assert_str(_talk()).is_not_equal("O baú morreu.")
	mimic.take_damage(1000.0, player)
	assert_str(_talk()).is_equal("O baú morreu.")


func test_alone_he_talks_to_you_not_to_a_group() -> void:
	assert_str(swordsman.for_group("{Você parece forte|Vocês parecem fortes}.")).is_equal("Você parece forte.")
	assert_str(swordsman.for_group("Foi bom {te conhecer|conhecer vocês}.")).is_equal("Foi bom te conhecer.")


func test_with_a_group_he_talks_to_everyone() -> void:
	var ally := Node.new()
	add_child(ally)
	ally.add_to_group("players")

	var line := swordsman.for_group("{Você parece forte|Vocês parecem fortes}.")
	ally.free()

	assert_str(line).is_equal("Vocês parecem fortes.")


func test_no_line_of_his_talks_to_a_group_without_a_choice() -> void:
	var lines := PackedStringArray([swordsman.introduction, swordsman.death_line, swordsman.startle_line])
	lines.append_array(swordsman.hurt_lines)
	lines.append_array(swordsman.style_lines)
	for floor in swordsman.floor_lines:
		lines.append_array(floor)
	for topic: DialogueTopic in swordsman.topics:
		lines.append_array(topic.lines)
	for line in lines:
		assert_bool(RegEx.create_from_string("[Vv]ocês").search(swordsman.for_group(line)) == null).override_failure_message(line).is_true()


func test_he_does_not_talk_to_whoever_is_far_away() -> void:
	swordsman._request_talk.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)

	assert_bool(swordsman.speech.visible).is_false()


func test_he_shows_up_lost_on_each_floor_the_group_reaches() -> void:
	var trigger := swordsman.floor_triggers[0]

	await _teleport(trigger.global_position)

	assert_int(swordsman.floor_index).is_equal(1)
	assert_float((swordsman.global_position - swordsman.spots[1].global_position).slide(Vector3.UP).length()).is_less(0.5)


func test_he_counts_as_an_undead_the_contract_asks_for() -> void:
	var census := level.get_node("Contagem") as UndeadCensus
	var standing := census.remaining()

	_startle_swordsman()
	swordsman.take_damage(1000.0, player)

	assert_bool(swordsman.is_in_group(UndeadCensus.GROUP)).is_true()
	assert_int(census.remaining()).is_equal(standing - 1)
	assert_str(swordsman.speech.text).is_equal(swordsman.for_group(swordsman.death_line))


func test_the_mimic_looks_like_a_chest_until_disturbed() -> void:
	assert_bool(mimic.is_awake).is_false()
	assert_bool(mimic.mouth.visible).is_false()
	assert_bool(mimic.is_in_group(UndeadCensus.GROUP)).is_false()


func test_opening_the_mimic_wakes_it() -> void:
	await _teleport(mimic.global_position + Vector3(0, 0.1, -2.5))

	mimic._request_open.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)

	assert_bool(mimic.is_awake).is_true()
	assert_bool(mimic.mouth.visible).is_true()


func test_hitting_the_mimic_also_wakes_it() -> void:
	mimic.take_damage(1.0, player)

	assert_bool(mimic.is_awake).is_true()


func test_the_awake_mimic_chases_and_bites() -> void:
	await _teleport(mimic.global_position + Vector3(0, 0.1, -5))
	mimic.take_damage(1.0, player)

	await get_tree().create_timer(3.0).timeout

	assert_float(player.health).is_less(player.get_max_health())
	assert_str(player.damage_log.death_cause()).is_equal("Mímico")


func test_the_mimic_does_not_wake_for_whoever_is_far_away() -> void:
	await _teleport(mimic.global_position + Vector3(0, 0.1, -8))

	mimic._request_open.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)

	assert_bool(mimic.is_awake).is_false()


func test_a_mimic_killed_in_its_sleep_cannot_be_opened() -> void:
	mimic.take_damage(1000.0, player)
	await _teleport(mimic.global_position + Vector3(0, 0.1, -2.5))

	mimic._request_open.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)

	assert_bool(mimic.mouth.visible).is_false()
	assert_bool(mimic.prompt.visible).is_false()


func test_the_defeated_mimic_drops_the_real_treasure() -> void:
	mimic.take_damage(1000.0, player)
	await get_tree().physics_frame

	assert_object(level.find_child("MimicoLoot", true, false)).is_not_null()


func test_the_hud_counts_the_undead_left() -> void:
	var census := level.get_node("Contagem") as UndeadCensus

	await get_tree().create_timer(0.6).timeout

	assert_str(level.get_node("Hud").objective_label.text).is_equal("Mortos-vivos restantes: %d" % census.remaining())
	assert_int(census.remaining()).is_greater(0)


func test_leaving_with_undead_standing_breaks_the_contract() -> void:
	var exit := level.get_node("Saida") as DungeonExit
	var fake: FakeSession = auto_free(FakeSession.new())
	exit.session = fake
	await _teleport(exit.global_position + Vector3(0, 0.2, 1))

	exit._request_use.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)

	assert_bool(fake.fulfilled).is_false()


func test_leaving_after_every_undead_falls_fulfills_the_contract() -> void:
	var exit := level.get_node("Saida") as DungeonExit
	var fake: FakeSession = auto_free(FakeSession.new())
	exit.session = fake
	await _teleport(exit.global_position + Vector3(0, 0.2, 1))
	await _kill_every_undead()

	exit._request_use.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)

	assert_bool(fake.fulfilled).is_true()


func test_the_contract_ends_only_once() -> void:
	session.end_contract(true)
	(level.get_node("VictoryScreen") as CanvasLayer).hide()

	session.end_contract(false)

	assert_bool((level.get_node("VictoryScreen") as CanvasLayer).visible).is_false()
	assert_int(RunState.attempt).is_equal(1)


func test_a_fulfilled_contract_opens_the_victory_screen() -> void:
	session.end_contract(true)

	assert_bool((level.get_node("VictoryScreen") as CanvasLayer).visible).is_true()


func test_the_exit_ignores_whoever_is_far_away() -> void:
	var exit := level.get_node("Saida") as DungeonExit
	var fake: FakeSession = auto_free(FakeSession.new())
	exit.session = fake
	await _teleport(exit.global_position + Vector3(0, 0.2, 10))
	await _kill_every_undead()

	exit._request_use.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)

	assert_that(fake.fulfilled).is_null()
