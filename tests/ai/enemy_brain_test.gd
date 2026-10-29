extends GdUnitTestSuite

var arena: TestArena


func before_test() -> void:
	RunState.reset()
	arena = TestArena.new(self)


func _spawn_skeleton(position: Vector3, dormant := false) -> Enemy:
	var skeleton := (load(TestArena.SKELETON) as PackedScene).instantiate() as Enemy
	skeleton.position = position
	skeleton.start_dormant = dormant
	arena.root.add_child(skeleton)
	return skeleton


func _distance(a: Node3D, b: Node3D) -> float:
	return Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()


func test_starts_idle_when_awake() -> void:
	var skeleton := _spawn_skeleton(Vector3.ZERO)
	await arena.wait_physics(3)

	assert_str(skeleton.brain.current_state_name).is_equal("Idle")


func test_reacts_after_reaction_time_not_instantly() -> void:
	await arena.bake_navigation()
	var skeleton := _spawn_skeleton(Vector3.ZERO)
	var player := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 8))
	await arena.wait_seconds(skeleton.profile.reaction_time * 0.5)
	assert_float(_distance(skeleton, player)).is_equal_approx(8.0, 0.05)

	await arena.wait_seconds(skeleton.profile.reaction_time + 0.6)

	assert_float(_distance(skeleton, player)).is_less(7.8)


func test_chases_player_it_sees() -> void:
	await arena.bake_navigation()
	var skeleton := _spawn_skeleton(Vector3.ZERO)
	var player := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 10))
	await arena.wait_seconds(1.5)

	assert_array(["Chase", "Attack"]).contains([skeleton.brain.current_state_name])
	assert_float(_distance(skeleton, player)).is_less(7.0)


func test_attacks_when_in_range_and_hurts_player_after_telegraph() -> void:
	await arena.bake_navigation()
	var skeleton := _spawn_skeleton(Vector3.ZERO)
	var player := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 1.4))
	await arena.wait_seconds(skeleton.profile.reaction_time + 0.2)
	assert_str(skeleton.brain.current_state_name).is_equal("Attack")
	assert_bool(skeleton.is_busy).is_true()
	assert_float(player.health).is_equal(10.0)

	await arena.wait_seconds(skeleton.attack.impact_delay + 0.1)

	assert_float(player.health).is_equal(9.0)


func test_enemy_attack_gives_time_to_react() -> void:
	var skeleton := _spawn_skeleton(Vector3.ZERO)

	assert_float(skeleton.attack.impact_delay).is_greater_equal(0.55)


func test_does_not_hit_other_skeletons() -> void:
	await arena.bake_navigation()
	var skeleton := _spawn_skeleton(Vector3.ZERO)
	var ally := _spawn_skeleton(Vector3(0, 0, 1.2))
	ally.ai_enabled = false
	var player := arena.spawn(TestArena.KNIGHT, Vector3(0.6, 0, 1.6))
	await arena.wait_seconds(2.5)

	assert_float(ally.health).is_equal(5.0)
	assert_float(player.health).is_less(10.0)


func test_dormant_skeleton_stays_down_until_player_comes_close() -> void:
	await arena.bake_navigation()
	var skeleton := _spawn_skeleton(Vector3.ZERO, true)
	var player := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 12))
	await arena.wait_seconds(1.0)
	assert_str(skeleton.brain.current_state_name).is_equal("Dormant")

	player.global_position = Vector3(0, 0, skeleton.profile.awaken_distance - 1.0)
	await arena.wait_seconds(0.5)
	assert_str(skeleton.brain.current_state_name).is_equal("Awaken")

	await arena.wait_seconds(2.6)
	assert_array(["Chase", "Attack"]).contains([skeleton.brain.current_state_name])


func test_dormant_skeleton_hides_health_bar_until_it_awakens() -> void:
	await arena.bake_navigation()
	var skeleton := _spawn_skeleton(Vector3.ZERO, true)
	var player := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 12))
	await arena.wait_seconds(0.5)
	assert_bool(skeleton.health_bar.visible).is_false()

	player.global_position = Vector3(0, 0, skeleton.profile.awaken_distance - 1.0)
	await arena.wait_seconds(0.5)

	assert_bool(skeleton.health_bar.visible).is_true()


func test_awake_skeleton_shows_health_bar_from_the_start() -> void:
	var skeleton := _spawn_skeleton(Vector3.ZERO)
	await arena.wait_physics(2)

	assert_bool(skeleton.health_bar.visible).is_true()


func test_lost_player_is_searched_at_last_known_position() -> void:
	await arena.bake_navigation()
	var skeleton := _spawn_skeleton(Vector3.ZERO)
	var player := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 9))
	await arena.wait_seconds(0.8)
	var last_seen := player.global_position
	player.global_position = Vector3(30, 0, -30)
	await arena.wait_seconds(0.5)

	assert_array(["Chase", "Investigate"]).contains([skeleton.brain.current_state_name])
	await arena.wait_seconds(3.5)
	assert_float(Vector2(skeleton.global_position.x - last_seen.x, skeleton.global_position.z - last_seen.z).length()).is_less(2.0)


func test_gives_up_and_returns_to_idle_after_searching() -> void:
	await arena.bake_navigation()
	var skeleton := _spawn_skeleton(Vector3.ZERO)
	var player := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 6))
	await arena.wait_seconds(0.6)
	player.global_position = Vector3(30, 0, -30)

	await arena.wait_seconds(skeleton.profile.memory_time + skeleton.profile.search_time + 3.0)

	assert_str(skeleton.brain.current_state_name).is_equal("Idle")


func _lose_player(skeleton: Enemy, player: Character) -> void:
	await arena.wait_seconds(0.8)
	player.global_position = Vector3(30, 0, -30)
	await arena.wait_seconds(skeleton.profile.memory_time + skeleton.profile.search_time + 3.0)


func _point_in_front_of(skeleton: Enemy, distance: float) -> Vector3:
	return skeleton.global_position + skeleton.model.global_basis.z.slide(Vector3.UP).normalized() * distance


func test_reengages_when_player_comes_back_into_view() -> void:
	await arena.bake_navigation()
	var skeleton := _spawn_skeleton(Vector3.ZERO)
	var player := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 6))
	await _lose_player(skeleton, player)
	assert_str(skeleton.brain.current_state_name).is_equal("Idle")

	player.global_position = _point_in_front_of(skeleton, 6.0)
	await arena.wait_seconds(1.0)

	assert_array(["Chase", "Attack"]).contains([skeleton.brain.current_state_name])


func test_reengages_when_player_walks_up_from_behind() -> void:
	await arena.bake_navigation()
	var skeleton := _spawn_skeleton(Vector3.ZERO)
	var player := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 6))
	await _lose_player(skeleton, player)

	player.global_position = _point_in_front_of(skeleton, -2.5)
	await arena.wait_seconds(1.0)

	assert_array(["Chase", "Attack"]).contains([skeleton.brain.current_state_name])


func test_awakened_skeleton_reengages_after_player_returns() -> void:
	await arena.bake_navigation()
	var skeleton := _spawn_skeleton(Vector3.ZERO, true)
	var player := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 5))
	await arena.wait_seconds(3.0)
	await _lose_player(skeleton, player)

	player.global_position = _point_in_front_of(skeleton, 5.0)
	await arena.wait_seconds(1.0)

	assert_array(["Chase", "Attack"]).contains([skeleton.brain.current_state_name])


func test_shot_from_behind_makes_skeleton_hunt_the_shooter() -> void:
	await arena.bake_navigation()
	var skeleton := _spawn_skeleton(Vector3.ZERO)
	var rogue := arena.spawn(TestArena.ROGUE, Vector3(0, 0, -5.5)) as Adventurer
	await arena.wait_seconds(0.5)
	assert_str(skeleton.brain.current_state_name).is_equal("Idle")

	rogue.attack.try_attack(rogue)
	await arena.wait_seconds(1.6)

	assert_float(skeleton.health).is_equal(4.0)
	assert_str(skeleton.brain.current_state_name).is_equal("Chase")


func test_hit_while_dormant_starts_rising_without_flinching() -> void:
	var skeleton := _spawn_skeleton(Vector3.ZERO, true)
	arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 15))
	await arena.wait_seconds(0.3)

	skeleton.take_damage(1.0)

	assert_float(skeleton.health).is_equal(4.0)
	assert_str(skeleton.brain.current_state_name).is_equal("Awaken")
	assert_str(skeleton.animation_player.current_animation).is_equal(AwakenState.ANIMATION)
	assert_bool(skeleton.health_bar.visible).is_true()


func test_hit_while_rising_does_not_interrupt_it() -> void:
	await arena.bake_navigation()
	var skeleton := _spawn_skeleton(Vector3.ZERO, true)
	var player := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 15))
	await arena.wait_seconds(0.3)
	player.global_position = Vector3(0, 0, 5)
	await arena.wait_seconds(0.8)
	assert_str(skeleton.brain.current_state_name).is_equal("Awaken")

	skeleton.take_damage(1.0)
	await arena.wait_physics(3)

	assert_float(skeleton.health).is_equal(4.0)
	assert_str(skeleton.animation_player.current_animation).is_equal(AwakenState.ANIMATION)
	await arena.wait_seconds(2.0)
	assert_array(["Chase", "Attack"]).contains([skeleton.brain.current_state_name])


func test_dying_while_rising_ends_in_death() -> void:
	var skeleton := _spawn_skeleton(Vector3.ZERO, true)
	arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 15))
	await arena.wait_seconds(0.3)

	skeleton.take_damage(1.0)
	skeleton.take_damage(10.0)
	await arena.wait_physics(3)

	assert_bool(skeleton.is_dead).is_true()
	assert_str(skeleton.brain.current_state_name).is_equal("Dead")
	assert_str(skeleton.animation_player.current_animation).is_equal(Character.ANIM_DEATH)


func test_walks_around_wall_to_reach_player() -> void:
	arena.add_wall(Vector3(0, 1, 3), Vector3(6, 3, 0.5))
	await arena.bake_navigation()
	var skeleton := _spawn_skeleton(Vector3.ZERO)
	var player := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 6))
	skeleton.perception.force_awareness(player)
	await arena.wait_seconds(5.0)

	assert_float(_distance(skeleton, player)).is_less(2.0)


func test_dead_skeleton_stops_thinking() -> void:
	await arena.bake_navigation()
	var skeleton := _spawn_skeleton(Vector3.ZERO)
	arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 6))
	await arena.wait_seconds(0.5)

	skeleton.take_damage(99.0)
	var position_at_death := skeleton.global_position
	await arena.wait_seconds(1.0)

	assert_str(skeleton.brain.current_state_name).is_equal("Dead")
	assert_float(skeleton.global_position.distance_to(position_at_death)).is_less(0.1)


func test_disabled_ai_stays_still() -> void:
	var skeleton := _spawn_skeleton(Vector3.ZERO)
	skeleton.ai_enabled = false
	arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 4))
	await arena.wait_seconds(1.0)

	assert_float(skeleton.global_position.distance_to(Vector3.ZERO)).is_less(0.05)
