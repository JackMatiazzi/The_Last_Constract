extends GdUnitTestSuite


func test_the_most_voted_blessing_wins() -> void:
	assert_array(GameSession.most_voted({1: 0, 2: 1, 3: 1})).contains_exactly([1])


func test_a_tie_returns_every_tied_choice() -> void:
	assert_array(GameSession.most_voted({1: 0, 2: 1})).contains_exactly_in_any_order([0, 1])


func test_a_lone_voter_decides_alone() -> void:
	assert_array(GameSession.most_voted({1: 1})).contains_exactly([1])


func test_no_blessing_left_is_a_valid_vote() -> void:
	assert_array(GameSession.most_voted({1: -1, 2: -1})).contains_exactly([-1])
