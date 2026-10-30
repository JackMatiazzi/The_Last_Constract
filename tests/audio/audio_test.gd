extends GdUnitTestSuite

var arena: TestArena


func before_test() -> void:
	RunState.reset()
	arena = TestArena.new(self)


func after_test() -> void:
	Input.action_release("move_forward")


func _played_during(sound: AudioStreamPlayer, seconds: float) -> bool:
	return await _played(func() -> bool: return sound.playing, seconds)


func _played_3d_during(sound: AudioStreamPlayer3D, seconds: float) -> bool:
	return await _played(func() -> bool: return sound.playing, seconds)


func _played(is_playing: Callable, seconds: float) -> bool:
	var frames := int(seconds * Engine.physics_ticks_per_second)
	for frame in frames:
		if is_playing.call():
			return true
		await arena.wait_physics(1)
	return is_playing.call()


func test_walking_plays_footsteps() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO) as Adventurer
	await arena.wait_physics(3)

	Input.action_press("move_forward")

	assert_bool(await _played_3d_during(knight.footstep_sound, 1.5)).is_true()


func test_standing_still_makes_no_footsteps() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO) as Adventurer

	assert_bool(await _played_3d_during(knight.footstep_sound, 1.0)).is_false()


func test_getting_hit_hurts_out_loud() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO) as Adventurer

	knight.take_damage(1.0)

	assert_bool(knight.hurt_sound.playing).is_true()


func test_skeleton_falls_apart_with_bones_sound() -> void:
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3.ZERO)

	skeleton.take_damage(99.0)

	assert_bool(skeleton.death_sound.playing).is_true()
	assert_bool(skeleton.hurt_sound.playing).is_false()


func test_blocked_hit_clangs_on_the_shield() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO) as Adventurer
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3(0, 0, 2))
	await arena.wait_physics(3)
	knight.use_secondary()

	knight.take_damage(1.0, skeleton)

	assert_bool(knight.block_sound.playing).is_true()


func test_attack_sound_plays_at_the_impact() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO) as Adventurer
	await arena.wait_physics(3)

	knight.attack.try_attack(knight)
	assert_bool(knight.attack.sound.playing).is_false()

	assert_bool(await _played_3d_during(knight.attack.sound, knight.attack.impact_delay + 0.2)).is_true()


func test_dormant_skeleton_creaks_when_it_rises() -> void:
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3.ZERO) as Enemy

	skeleton.brain.change_state("Awaken")

	assert_bool(skeleton.rise_sound.playing).is_true()


# espera a condicao, com limite de tempo
func _until(condition: Callable, seconds: float) -> bool:
	var limit := Time.get_ticks_msec() + roundi(seconds * 1000)
	while Time.get_ticks_msec() < limit:
		if condition.call():
			return true
		await await_idle_frame()
	return condition.call()


func test_music_cue_switches_the_track() -> void:
	var track := load("res://assets/audio/music/menu_medieval_fair.ogg") as AudioStream
	var cue := MusicCue.new()
	cue.track = track

	add_child(auto_free(cue))
	# com outra faixa tocando, a troca so acontece no meio do fade
	assert_bool(await _until(func() -> bool: return Music.stream == track, MusicPlayer.FADE_TIME + 3.0)).is_true()
	assert_bool(Music.playing).is_true()


func test_every_button_clicks() -> void:
	var button: Button = auto_free(Button.new())
	add_child(button)

	button.pressed.emit()

	assert_bool(UiSounds.click.playing).is_true()
