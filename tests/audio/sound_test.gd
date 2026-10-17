extends GdUnitTestSuite

var arena: TestArena


func before_test() -> void:
	arena = TestArena.new(self)


func after_test() -> void:
	Input.action_release("move_forward")


func _plays_within(sound: AudioStreamPlayer3D, seconds: float) -> bool:
	for i in ceili(seconds * Engine.physics_ticks_per_second):
		if sound.playing:
			return true
		await arena.wait_physics(1)
	return sound.playing


func test_walking_plays_footsteps() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO) as Adventurer
	await arena.wait_physics(5)

	await arena.send_action("move_forward")

	assert_bool(await _plays_within(knight.footstep_sound, 1.5)).is_true()


func test_standing_still_makes_no_footsteps() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO) as Adventurer

	assert_bool(await _plays_within(knight.footstep_sound, 1.0)).is_false()


func test_getting_hit_plays_hurt_sound() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO) as Adventurer
	await arena.wait_physics(3)

	knight.take_damage(1.0)

	assert_bool(knight.hurt_sound.playing).is_true()


func test_skeleton_falls_apart_with_bones_sound() -> void:
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3.ZERO) as Enemy
	await arena.wait_physics(3)

	skeleton.take_damage(99.0)

	assert_bool(skeleton.death_sound.playing).is_true()


func test_attack_swings_at_impact() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO) as Adventurer
	await arena.wait_physics(3)

	knight.attack.try_attack(knight)
	assert_bool(knight.attack.sound.playing).is_false()

	assert_bool(await _plays_within(knight.attack.sound, knight.attack.impact_delay + 0.1)).is_true()


func test_sounds_are_positioned_on_the_character() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3(5, 0, 3)) as Adventurer
	await arena.wait_physics(3)

	for sound in [knight.footstep_sound, knight.hurt_sound, knight.death_sound, knight.attack.sound]:
		assert_float(sound.global_position.distance_to(knight.global_position)).is_less(2.0)
		assert_str(sound.bus).is_equal("SFX")
