extends GdUnitTestSuite

const CHARACTER_SELECT := preload("res://scenes/ui/character_select.tscn")

var screen: CharacterSelect


func before_test() -> void:
	screen = auto_free(CHARACTER_SELECT.instantiate())
	add_child(screen)
	await await_idle_frame()


# espera as animacoes acabarem: no CI os quadros atrasam e o tempo de relogio nao basta
func _choose(index: int) -> void:
	screen.picker.select(index)
	var limit := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < limit:
		await await_idle_frame()
		if not get_tree().get_processed_tweens().any(func(tween: Tween) -> bool: return tween.is_running()):
			return


func test_shows_one_model_per_adventurer() -> void:
	assert_int(screen.models.size()).is_equal(RunState.ADVENTURERS.size())


func test_chosen_adventurer_steps_forward() -> void:
	await _choose(2)

	for i in screen.models.size():
		if i != 2:
			assert_float(screen.models[2].position.z).is_greater(screen.models[i].position.z)


func test_ring_marks_the_chosen_adventurer() -> void:
	await _choose(3)

	assert_float(screen.ring.position.x).is_equal_approx(screen.models[3].position.x, 0.01)


func test_only_the_chosen_name_is_highlighted() -> void:
	await _choose(1)

	for i in screen.name_tags.size():
		var highlighted := screen.name_tags[i].modulate.a > 0.9
		assert_bool(highlighted).is_equal(i == 1)
