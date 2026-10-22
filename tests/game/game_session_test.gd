extends GdUnitTestSuite

const GAMEPLAY := preload("res://scenes/test/movement_test.tscn")


func after_test() -> void:
	RunState.adventurer = null
	RunState.reset()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _start_game_with(path: String) -> Node:
	RunState.adventurer = load(path)
	var game: Node = auto_free(GAMEPLAY.instantiate())
	add_child(game)
	await await_idle_frame()
	return game


func test_spawns_the_chosen_adventurer_at_the_spawn_point() -> void:
	var game := await _start_game_with("res://resources/adventurers/mage.tres")
	var session: GameSession = game.get_node("GameSession")

	assert_str(session.player.scene_file_path).is_equal("res://scenes/characters/adventurers/mage.tscn")
	var spawn: Vector3 = game.get_node("PlayerSpawn").global_position
	assert_float(session.player.global_position.distance_to(spawn)).is_less(0.5)


func test_hud_follows_the_spawned_adventurer() -> void:
	var game := await _start_game_with("res://resources/adventurers/rogue.tres")
	var session: GameSession = game.get_node("GameSession")
	var hud: Hud = game.get_node("Hud")

	session.player.take_damage(2.0)

	assert_str(hud.health_label.text).is_equal("8 / 10")


func test_without_a_choice_the_first_adventurer_is_used() -> void:
	RunState.adventurer = null

	assert_str(RunState.current_adventurer().title).is_equal("Knight")


func _press_pause(session: GameSession) -> void:
	var press := InputEventAction.new()
	press.action = &"pause"
	press.pressed = true
	session._unhandled_input(press)


func test_the_pause_menu_takes_control_away_until_it_closes() -> void:
	var game := await _start_game_with("res://resources/adventurers/knight.tres")
	var session: GameSession = game.get_node("GameSession")

	_press_pause(session)
	assert_bool(session.player.input_locked).is_true()

	get_tree().paused = false
	session.pause_menu.resumed.emit()
	assert_bool(session.player.input_locked).is_false()


func test_solo_is_a_party_of_one() -> void:
	var game := await _start_game_with("res://resources/adventurers/knight.tres")
	var session: GameSession = game.get_node("GameSession")

	assert_array(session._peers_in_match()).contains_exactly([multiplayer.get_unique_id()])
	assert_array(session.players).contains_exactly([session.player])


func test_pausing_drops_the_shield_and_what_was_being_held() -> void:
	var game := await _start_game_with("res://resources/adventurers/knight.tres")
	var session: GameSession = game.get_node("GameSession")
	var knight := session.player
	knight.use_secondary()
	await await_idle_frame()
	assert_bool(knight.is_blocking).is_true()

	_press_pause(session)

	assert_bool(knight.is_blocking).is_false()
	assert_float(knight.drink_progress()).is_equal(0.0)
	get_tree().paused = false


func test_only_blessings_from_the_buff_folder_are_loaded() -> void:
	var blessing := RunState.BUFF_DIR + "/lamina_afiada.tres"

	assert_object(GameSession.buff_at(blessing)).is_not_null()
	assert_object(GameSession.buff_at("res://scenes/ui/hud.tscn")).is_null()
	assert_object(GameSession.buff_at("user://lamina_afiada.tres")).is_null()
	assert_object(GameSession.buff_at(RunState.BUFF_DIR + "/../items/health_potion.tres")).is_null()
	assert_object(GameSession.buff_at("")).is_null()
