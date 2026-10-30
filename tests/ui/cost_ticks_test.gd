extends GdUnitTestSuite

const HUD := preload("res://scenes/ui/hud.tscn")

var arena: TestArena


func before_test() -> void:
	RunState.reset()
	arena = TestArena.new(self)


func _hud_for(scene: String) -> Hud:
	var adventurer := arena.spawn(scene, Vector3.ZERO)
	var hud: Hud = HUD.instantiate()
	hud.player = adventurer
	arena.root.add_child(hud)
	return hud


func _expected(step: float) -> PackedFloat32Array:
	var positions := PackedFloat32Array()
	var at := step
	while at < 0.999:
		positions.append(at)
		at += step
	return positions


func test_the_stamina_bar_shows_one_block_per_attack() -> void:
	var hud := _hud_for(TestArena.KNIGHT)
	var knight := hud.player as Adventurer
	await arena.wait_physics(2)

	var step := knight.quick_cost / knight.stamina.maximum

	assert_array(hud.stamina_ticks.tick_positions()).is_equal(_expected(step))
	assert_int(hud.stamina_ticks.tick_positions().size()).is_equal(6)


func test_each_class_gets_blocks_of_its_own_cost() -> void:
	var hud := _hud_for(TestArena.BARBARIAN)
	await arena.wait_physics(2)

	assert_int(hud.stamina_ticks.tick_positions().size()).is_equal(4)


func test_the_mage_sees_the_blocks_on_the_mana_bar() -> void:
	var hud := _hud_for(TestArena.MAGE)
	var mage := hud.player as Adventurer
	await arena.wait_physics(2)

	assert_array(hud.mana_ticks.tick_positions()).is_equal(_expected(mage.quick_cost / mage.mana.maximum))
	assert_array(hud.stamina_ticks.tick_positions()).is_empty()


func test_switching_ability_redraws_the_blocks() -> void:
	var hud := _hud_for(TestArena.MAGE)
	var mage := hud.player as Adventurer
	await arena.wait_physics(2)

	mage.next_ability()

	var step := mage.cost_of(mage.attack) / mage.mana.maximum
	assert_array(hud.mana_ticks.tick_positions()).is_equal(_expected(step))


func test_no_cost_means_no_blocks() -> void:
	var ticks := CostTicks.new()
	add_child(auto_free(ticks))

	ticks.set_step(0.0)

	assert_array(ticks.tick_positions()).is_empty()
