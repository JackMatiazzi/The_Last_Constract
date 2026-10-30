extends GdUnitTestSuite

const EXECUTION := preload("res://scenes/cutscenes/execution.tscn")
const BARBARIAN_MODEL := "res://scenes/characters/adventurers/models/barbarian_model.tscn"

var cutscene: AdventurerCutscene


func before_test() -> void:
	RunState.adventurer = load("res://resources/adventurers/barbarian.tres")
	cutscene = auto_free(EXECUTION.instantiate())
	cutscene.next_scene = ""
	add_child(cutscene)
	await await_idle_frame()


# solta o espaco, que tambem e a tecla de correr
func after_test() -> void:
	RunState.adventurer = null
	var release := InputEventKey.new()
	release.physical_keycode = KEY_SPACE
	Input.parse_input_event(release)


func _animation() -> Animation:
	return cutscene.timeline.get_animation("execution")


func _key_time(path: String) -> float:
	var animation := _animation()
	return animation.track_get_key_time(animation.find_track(NodePath(path), Animation.TYPE_VALUE), 0)


func _impact_key() -> Dictionary:
	var animation := _animation()
	var track := animation.find_track(NodePath("."), Animation.TYPE_METHOD)
	return {"time": animation.track_get_key_time(track, 0), "args": animation.method_track_get_params(track, 0)}


func _jump_to(time: float) -> void:
	cutscene.timeline.advance(time - cutscene.timeline.current_animation_position)
	await await_idle_frame()


func test_the_chosen_adventurer_leaves_and_is_condemned() -> void:
	assert_str(cutscene.actors[0].scene_file_path).is_equal(BARBARIAN_MODEL)
	assert_str(cutscene.actors[1].scene_file_path).is_equal(BARBARIAN_MODEL)


func test_executioner_holds_the_axe() -> void:
	var axe := cutscene.get_node("PublicSquare/Scaffold/Executioner").find_child("Axe", true, false) as Node3D

	assert_object(axe).is_not_null()
	assert_bool(axe.is_visible_in_tree()).is_true()


func test_opens_on_the_road_with_the_adventurer_walking_away() -> void:
	var camera := get_viewport().get_camera_3d()
	var start := cutscene.actors[0].global_position.distance_to(camera.global_position)

	await _jump_to(_key_time("SquareCamera:current") - 0.1)

	assert_str(camera.name).is_equal("RoadCamera")
	assert_float(cutscene.actors[0].global_position.distance_to(camera.global_position)).is_greater(start + 3.0)
	assert_str((cutscene.actors[0].get_node("AnimationPlayer") as AnimationPlayer).current_animation).is_equal(Character.ANIM_WALK)


func test_cuts_to_the_public_square() -> void:
	await _jump_to(_key_time("SquareCamera:current") + 0.1)

	assert_str(get_viewport().get_camera_3d().name).is_equal("SquareCamera")


func test_condemned_falls_and_the_crowd_cheers_when_the_axe_lands() -> void:
	var impact := _impact_key()
	await _jump_to(impact["time"] + 1.2)

	var condemned_player := cutscene.actors[1].get_node("AnimationPlayer") as AnimationPlayer
	var villager_player := cutscene.get_node("Crowd/Villager").get_node("AnimationPlayer") as AnimationPlayer
	assert_str(condemned_player.assigned_animation).is_equal(impact["args"][1])
	assert_str(get_viewport().get_camera_3d().name).is_equal("CloseCamera")
	assert_str(villager_player.assigned_animation).is_equal("Cheer")


func test_condemned_falls_from_the_kneeling_pose_without_standing_up() -> void:
	var impact := _impact_key()

	assert_int(impact["args"][0]).is_equal(1)
	assert_str(impact["args"][1]).ends_with("_Pose")
	assert_float(impact["args"][2]).is_greater(0.0)


func test_returns_to_the_main_menu() -> void:
	assert_str(auto_free(EXECUTION.instantiate()).next_scene).is_equal("res://scenes/ui/main_menu.tscn")


func test_finishes_on_its_own() -> void:
	var signals := monitor_signals(cutscene, false)

	await _jump_to(_animation().length + 0.1)

	await assert_signal(signals).wait_until(500).is_emitted("finished")


func test_any_key_skips_to_the_end() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.pressed = true

	Input.parse_input_event(event)

	await assert_signal(cutscene).wait_until(500).is_emitted("finished")
