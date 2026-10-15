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
