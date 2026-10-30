extends GdUnitTestSuite

const INTRO := preload("res://scenes/cutscenes/mission_intro.tscn")
const GAMEPLAY := "res://scenes/levels/village_level.tscn"

var cutscene: AdventurerCutscene


func before_test() -> void:
	RunState.adventurer = load("res://resources/adventurers/mage.tres")
	cutscene = auto_free(INTRO.instantiate())
	cutscene.next_scene = ""
	add_child(cutscene)
	await await_idle_frame()


# solta o espaco, que tambem e a tecla de correr
func after_test() -> void:
	RunState.adventurer = null
	var release := InputEventKey.new()
	release.physical_keycode = KEY_SPACE
	Input.parse_input_event(release)


func _cut_time() -> float:
	var animation := cutscene.timeline.get_animation("intro")
	return animation.track_get_key_time(animation.find_track(^"EntranceCamera:current", Animation.TYPE_VALUE), 0)


# pausada, a cutscene nao anda sozinha no quadro seguinte
func _jump_to(time: float) -> void:
	cutscene.timeline.play()
	cutscene.timeline.advance(time - cutscene.timeline.current_animation_position)
	cutscene.timeline.pause()
	await await_idle_frame()


func test_the_chosen_adventurer_walks_to_the_mission() -> void:
	var traveler := cutscene.actors[0]

	assert_str(traveler.scene_file_path).is_equal("res://scenes/characters/adventurers/models/mage_model.tscn")
	assert_str((traveler.get_node("AnimationPlayer") as AnimationPlayer).current_animation).is_equal(Character.ANIM_WALK)


func test_approaches_the_village_then_cuts_to_its_entrance() -> void:
	var traveler := cutscene.actors[0]
	var village := Vector3.ZERO
	var start := traveler.global_position.distance_to(village)

	await _jump_to(_cut_time() - 0.1)
	assert_str(get_viewport().get_camera_3d().name).is_equal("ApproachCamera")
	assert_float(traveler.global_position.distance_to(village)).is_less(start - 8.0)

	await _jump_to(_cut_time() + 0.1)
	assert_str(get_viewport().get_camera_3d().name).is_equal("EntranceCamera")


func test_leads_into_the_gameplay() -> void:
	var fresh: AdventurerCutscene = auto_free(INTRO.instantiate())

	assert_str(fresh.next_scene).is_equal(GAMEPLAY)
	assert_bool(ResourceLoader.exists(fresh.next_scene)).is_true()


func test_finishes_on_its_own() -> void:
	var signals := monitor_signals(cutscene, false)

	await _jump_to(cutscene.timeline.get_animation("intro").length + 0.1)

	await assert_signal(signals).wait_until(500).is_emitted("finished")


func test_any_key_skips_to_the_mission() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.pressed = true

	Input.parse_input_event(event)

	await assert_signal(cutscene).wait_until(500).is_emitted("finished")
