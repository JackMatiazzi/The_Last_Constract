extends GdUnitTestSuite

const SHARP := "res://resources/buffs/lamina_afiada.tres"


func before_test() -> void:
	RunState.reset()


func after_test() -> void:
	RunState.reset()


func test_every_buff_resource_can_be_offered() -> void:
	var offered := {}
	for i in 200:
		for buff in RunState.roll_choices():
			offered[buff.title] = true

	assert_int(offered.size()).is_equal(DirAccess.get_files_at("res://resources/buffs").size())


func test_roll_offers_two_different_buffs() -> void:
	for i in 30:
		var choices := RunState.roll_choices()
		assert_int(choices.size()).is_equal(2)
		assert_object(choices[0]).is_not_same(choices[1])


func test_buff_at_max_stacks_is_never_offered() -> void:
	var sharp: Buff = load(SHARP)
	for i in sharp.max_stacks:
		RunState.start_next_attempt(sharp)

	for i in 50:
		assert_bool(RunState.roll_choices().has(sharp)).is_false()


func test_next_attempt_stores_buff_and_counts_attempt() -> void:
	var sharp: Buff = load(SHARP)

	RunState.start_next_attempt(sharp)

	assert_int(RunState.attempt).is_equal(2)
	assert_int(RunState.stacks_of(sharp)).is_equal(1)


func test_next_attempt_without_buff_still_counts() -> void:
	RunState.start_next_attempt(null)

	assert_int(RunState.attempt).is_equal(2)
	assert_array(RunState.buffs).is_empty()


func test_reset_clears_attempts_and_buffs() -> void:
	RunState.start_next_attempt(load(SHARP))

	RunState.reset()

	assert_int(RunState.attempt).is_equal(1)
	assert_array(RunState.buffs).is_empty()
