extends GdUnitTestSuite

var _roster_before: Dictionary


func before_test() -> void:
	_roster_before = Net.roster.duplicate()


func after_test() -> void:
	Net.roster = _roster_before


func test_names_are_trimmed_and_cut() -> void:
	assert_str(Net.clean_name("  Jackson  ")).is_equal("Jackson")
	assert_int(Net.clean_name("a".repeat(40)).length()).is_equal(Net.MAX_NAME_LENGTH)


func test_empty_names_fall_back_to_a_default() -> void:
	assert_str(Net.clean_name("   ")).is_equal("Aventureiro")


func test_control_characters_are_removed_from_names() -> void:
	assert_str(Net.clean_name("And\nré\t")).is_equal("André")


func test_an_adventurer_chosen_by_someone_else_is_taken() -> void:
	Net.roster = {1: 0, 2: 1}

	assert_bool(Net.is_taken(1)).is_true()
	assert_bool(Net.is_taken(0)).is_false()
	assert_bool(Net.is_taken(2)).is_false()


func test_the_match_starts_only_when_everyone_chose() -> void:
	Net.roster = {1: 0, 2: Net.NO_CHOICE}
	assert_bool(Net.can_start()).is_false()

	Net.roster = {1: 0, 2: 3}
	assert_bool(Net.can_start()).is_true()


func test_only_listed_peers_count_as_players() -> void:
	Net.roster = {1: 0, 2: 1}

	assert_bool(Net.is_player(2)).is_true()
	assert_bool(Net.is_player(99)).is_false()


func test_shareable_addresses_skip_loopback_ipv6_and_virtual_adapters() -> void:
	for entry in Net.shareable_addresses():
		assert_bool(entry.address.begins_with("127.")).is_false()
		assert_int(entry.address.count(".")).is_equal(3)
		assert_bool(entry.label.to_lower().contains("virtualbox")).is_false()


func test_invisible_and_direction_characters_are_removed_from_names() -> void:
	var raw := "An%sd%sr%se%s" % [char(0x202E), char(0x200B), char(0x7F), char(0x85)]

	assert_str(Net.clean_name(raw)).is_equal("Andre")


func test_after_the_match_starts_nobody_changes_adventurer() -> void:
	Net.roster = {1: 0}
	Net.in_match = true

	Net._request_choice(2)

	assert_dict(Net.roster).is_equal({1: 0})
	Net.in_match = false


func test_names_made_only_of_blank_lookalikes_fall_back_to_the_default() -> void:
	var blank := "%s%s%s" % [char(0x3164), char(0x2800), char(0xAD)]

	assert_str(Net.clean_name(blank)).is_equal("Aventureiro")
	assert_str(Net.clean_name("Ana%s" % char(0xE0041))).is_equal("Ana")
