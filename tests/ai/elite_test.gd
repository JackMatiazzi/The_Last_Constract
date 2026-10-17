extends GdUnitTestSuite

const ELITE := "res://scenes/characters/enemies/skeleton_elite.tscn"

var arena: TestArena


func before_test() -> void:
	RunState.reset()
	arena = TestArena.new(self)


func _group_at(positions: Array[Vector3], origin := Vector3.ZERO) -> EnemyGroup:
	var group := EnemyGroup.new()
	group.position = origin
	group.elite_scene = load(ELITE)
	group.merge_delay = 0.3
	group.gather_time = 0.3
	for position in positions:
		var skeleton := (load(TestArena.SKELETON) as PackedScene).instantiate() as Enemy
		skeleton.position = position
		skeleton.ai_enabled = false
		group.add_child(skeleton)
	arena.root.add_child(group)
	return group


func _kill_all(group: EnemyGroup) -> void:
	for member in group.members():
		member.take_damage(99.0)


func _elites() -> Array[Node]:
	return arena.root.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n.scene_file_path == ELITE)


func test_elite_rises_at_the_group_spot_not_where_bodies_fell() -> void:
	var origin := Vector3(4, 0, 2)
	var group := _group_at([Vector3(-2, 0, 0), Vector3(2, 0, 0), Vector3(0, 0, 3)], origin)
	await arena.wait_physics(3)

	_kill_all(group)
	await arena.wait_seconds(0.3 + 0.3 + 0.3)

	var elites := _elites()
	assert_int(elites.size()).is_equal(1)
	assert_float(Vector2(elites[0].global_position.x - origin.x, elites[0].global_position.z - origin.z).length()).is_less(0.3)


func test_a_body_that_fell_far_away_is_not_dragged_to_the_elite() -> void:
	var group := _group_at([Vector3(-1, 0, 0), Vector3(1, 0, 0)])
	var straggler: Enemy = group.members()[1]
	await arena.wait_physics(3)
	straggler.global_position = Vector3(group.gather_radius + 10.0, 0, 0)
	var fallen_at := straggler.global_position

	_kill_all(group)
	await arena.wait_seconds(0.3 + 0.3 + 0.3)

	assert_int(_elites().size()).is_equal(1)
	assert_bool(is_instance_valid(straggler)).is_true()
	assert_float(straggler.global_position.distance_to(fallen_at)).is_less(0.5)


func test_editor_warns_when_a_member_is_placed_too_far() -> void:
	var group := _group_at([Vector3(-1, 0, 0), Vector3(30, 0, 0)])

	var warnings := group._get_configuration_warnings()

	assert_int(warnings.size()).is_equal(1)
	assert_str(warnings[0]).contains(String(group.members()[1].name))


func test_editor_is_quiet_for_a_well_built_group() -> void:
	var group := _group_at([Vector3(-1, 0, 0), Vector3(1, 0, 0)])

	assert_array(Array(group._get_configuration_warnings())).is_empty()


func test_partial_losses_raise_nothing() -> void:
	var group := _group_at([Vector3(-2, 0, 0), Vector3(2, 0, 0)])
	await arena.wait_physics(3)

	group.members()[0].take_damage(99.0)
	await arena.wait_seconds(1.2)

	assert_int(_elites().size()).is_equal(0)


func test_fallen_bodies_are_absorbed_into_the_elite() -> void:
	var group := _group_at([Vector3(-2, 0, 0), Vector3(2, 0, 0)])
	var fallen := group.members()
	await arena.wait_physics(3)

	_kill_all(group)
	await arena.wait_seconds(0.3 + 0.3 + 0.3)

	for body in fallen:
		assert_bool(is_instance_valid(body)).is_false()


func test_elite_is_stronger_than_a_minion() -> void:
	var minion := arena.spawn(TestArena.SKELETON, Vector3.ZERO)
	var elite := arena.spawn(ELITE, Vector3(5, 0, 0))

	assert_float(elite.get_max_health()).is_greater(minion.get_max_health())
	assert_float(elite.attack.damage).is_greater(minion.attack.damage)
	assert_float(elite.model.scale.y).is_greater(minion.model.scale.y)


func test_elite_rises_and_hunts_the_player() -> void:
	await arena.bake_navigation()
	var player := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, -10))
	var group := _group_at([Vector3(-1, 0, 0), Vector3(1, 0, 0)])
	await arena.wait_physics(3)

	_kill_all(group)
	await arena.wait_seconds(0.3 + 0.3 + 0.2)
	var elite := _elites()[0] as Enemy
	assert_str(elite.brain.current_state_name).is_equal("Awaken")

	await arena.wait_seconds(3.0)

	assert_array(["Chase", "Attack"]).contains([elite.brain.current_state_name])
	assert_float(elite.global_position.distance_to(player.global_position)).is_less(9.0)


func test_group_announces_the_elite_once() -> void:
	var group := _group_at([Vector3(-1, 0, 0), Vector3(1, 0, 0)])
	await arena.wait_physics(3)
	var signals := monitor_signals(group, false)

	_kill_all(group)

	await assert_signal(signals).wait_until(2000).is_emitted("elite_formed", [any()])
	assert_int(_elites().size()).is_equal(1)


func test_group_without_elite_just_leaves_its_bodies() -> void:
	var group := _group_at([Vector3(-1, 0, 0), Vector3(1, 0, 0)])
	group.elite_scene = null
	await arena.wait_physics(3)

	_kill_all(group)
	await arena.wait_seconds(0.3 + 0.3 + 0.3)

	assert_int(_elites().size()).is_equal(0)
	assert_int(group.members().size()).is_equal(2)


func test_group_without_elite_is_cleared_when_all_fall() -> void:
	var group := _group_at([Vector3(-1, 0, 0), Vector3(1, 0, 0)])
	group.elite_scene = null
	await arena.wait_physics(3)
	var signals := monitor_signals(group, false)

	_kill_all(group)

	await assert_signal(signals).wait_until(500).is_emitted("cleared")


func test_group_with_elite_is_cleared_only_when_the_elite_falls() -> void:
	var group := _group_at([Vector3(-1, 0, 0), Vector3(1, 0, 0)])
	await arena.wait_physics(3)
	var signals := monitor_signals(group, false)

	_kill_all(group)
	await arena.wait_seconds(0.3 + 0.3 + 0.3)
	await assert_signal(signals).wait_until(200).is_not_emitted("cleared")

	(_elites()[0] as Enemy).take_damage(99.0)

	await assert_signal(signals).wait_until(500).is_emitted("cleared")
