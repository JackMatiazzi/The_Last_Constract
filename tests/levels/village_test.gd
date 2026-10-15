extends GdUnitTestSuite

const VILLAGE := preload("res://scenes/levels/village.tscn")

var level: Node3D


func before_test() -> void:
	level = auto_free(VILLAGE.instantiate()) as Node3D
	add_child(level)


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_knight_starts_on_the_ground_with_the_camera() -> void:
	for i in 60:
		await get_tree().physics_frame

	var knight := level.get_node("Knight") as Adventurer
	assert_bool(knight.is_on_floor()).is_true()
	assert_bool(knight.camera.current).is_true()


func test_skeletons_stand_on_the_village_floor() -> void:
	for i in 60:
		await get_tree().physics_frame

	for skeleton: Enemy in level.get_node("Skeletons").get_children():
		assert_bool(skeleton.is_on_floor()).override_failure_message("%s nao esta no chao" % skeleton.name).is_true()


func test_night_ambience_plays_on_the_music_bus() -> void:
	await get_tree().process_frame

	var ambience := level.get_node("Ambience") as AudioStreamPlayer
	assert_bool(ambience.playing).is_true()
	assert_str(ambience.bus).is_equal("Music")


func test_audio_buses_exist() -> void:
	assert_int(AudioServer.get_bus_index("SFX")).is_not_equal(-1)
	assert_int(AudioServer.get_bus_index("Music")).is_not_equal(-1)


func test_village_walls_keep_the_player_inside() -> void:
	var knight := level.get_node("Knight") as Adventurer
	await get_tree().physics_frame

	knight.global_position = Vector3(0, 0.2, 23.5)
	knight.velocity = Vector3(0, 0, 30)
	for i in 30:
		await get_tree().physics_frame

	assert_float(knight.global_position.z).is_less(24.0)
