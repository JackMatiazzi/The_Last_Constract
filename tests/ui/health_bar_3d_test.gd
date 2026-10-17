extends GdUnitTestSuite

var arena: TestArena


func before_test() -> void:
	RunState.reset()
	arena = TestArena.new(self)


func _bar(character: Character) -> HealthBar3D:
	return character.get_node("HealthBar3D")


func _damage_numbers() -> Array[Node]:
	return arena.root.find_children("*", "DamageNumber", true, false)


func test_fill_drops_at_once_and_trail_catches_up_later() -> void:
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3.ZERO)
	var bar := _bar(skeleton)

	skeleton.take_damage(2.0)
	await arena.wait_physics(2)
	assert_float(bar.fill.value).is_equal(3.0)
	assert_float(bar.trail.value).is_equal(5.0)

	await arena.wait_seconds(HealthBar3D.TRAIL_DELAY + HealthBar3D.TRAIL_DURATION + 0.1)

	assert_float(bar.trail.value).is_equal_approx(3.0, 0.01)


func test_damage_spawns_number_with_amount() -> void:
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3.ZERO)

	skeleton.take_damage(2.0)

	var numbers := _damage_numbers()
	assert_int(numbers.size()).is_equal(1)
	assert_str((numbers[0] as Label3D).text).is_equal("-2")


func test_damage_number_disappears() -> void:
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3.ZERO)

	skeleton.take_damage(1.0)
	await arena.wait_seconds(DamageNumber.DURATION + 0.2)

	assert_int(_damage_numbers().size()).is_equal(0)


func test_bar_fades_out_after_death() -> void:
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3.ZERO)

	skeleton.take_damage(5.0)
	await arena.wait_seconds(1.4)

	assert_bool(_bar(skeleton).visible).is_false()


func test_player_bar_is_hidden_but_still_shows_damage_numbers() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO)

	knight.take_damage(1.0)

	assert_bool(_bar(knight).visible).is_false()
	assert_int(_damage_numbers().size()).is_equal(1)


func test_bar_colors_tell_sides_apart() -> void:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO)
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3(4, 0, 0))

	assert_bool(_bar(knight).fill_color.g > _bar(knight).fill_color.r).is_true()
	assert_bool(_bar(skeleton).fill_color.r > _bar(skeleton).fill_color.g).is_true()
