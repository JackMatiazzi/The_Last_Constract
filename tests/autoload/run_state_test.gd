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


func _report(victim_peer: int, killer_peer: int, helpers: Array) -> Dictionary:
	return {"victim_peer": victim_peer, "victim": "Esqueleto", "killer_peer": killer_peer, "killer": "Jackson", "cause": "Esqueleto", "helpers": helpers}


func test_a_kill_counts_for_the_killer_and_assists_for_the_helpers() -> void:
	RunState._apply_death(_report(0, 1, [2, 1, 3]))

	assert_int(RunState.stats_of(1).kills).is_equal(1)
	assert_int(RunState.stats_of(1).assists).is_equal(0)
	assert_int(RunState.stats_of(2).assists).is_equal(1)
	assert_int(RunState.stats_of(3).assists).is_equal(1)


func test_a_fallen_player_counts_a_death_with_its_cause() -> void:
	RunState._apply_death(_report(2, 0, []))

	assert_int(RunState.stats_of(2).deaths).is_equal(1)
	assert_str(RunState.stats_of(2).last_death).is_equal("Esqueleto")


func test_an_enemy_that_dies_to_nobody_counts_nothing() -> void:
	RunState._apply_death(_report(0, 0, []))

	assert_bool(RunState.stats.is_empty()).is_true()


func test_a_death_report_from_outside_the_match_is_ignored() -> void:
	RunState._report_death({"cause": "Esqueleto"})

	assert_bool(RunState.stats.is_empty()).is_true()
