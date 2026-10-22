extends GdUnitTestSuite

const OBJECTS := preload("res://scenes/maps/village/objects.tscn")

var arena: TestArena
var props: BreakableProps
var barrel_cell: Vector3i
var knight: Adventurer


func before_test() -> void:
	RunState.reset()
	arena = TestArena.new(self)
	props = OBJECTS.instantiate() as BreakableProps
	arena.root.add_child(props)
	for cell in props.get_used_cells():
		if props.mesh_library.get_item_name(props.get_cell_item(cell)) == "barrel_large":
			barrel_cell = cell
			break
	var spot := props.to_global(props.map_to_local(barrel_cell))
	knight = arena.spawn(TestArena.KNIGHT, Vector3(spot.x, 0, spot.z - 1.6)) as Adventurer
	await arena.wait_physics(3)


func test_a_quick_hit_does_not_break_a_barrel() -> void:
	knight.attack.try_attack(knight)
	await arena.wait_seconds(knight.attack.impact_delay + 0.1)

	assert_int(props.get_cell_item(barrel_cell)).is_not_equal(GridMap.INVALID_CELL_ITEM)


func test_a_heavy_hit_breaks_the_barrel_and_leaves_debris() -> void:
	knight.heavy_attack()
	await arena.wait_seconds(knight.attack.heavy_impact_delay + 0.1)

	assert_int(props.get_cell_item(barrel_cell)).is_equal(GridMap.INVALID_CELL_ITEM)
	assert_int(arena.root.find_children("PropDebris*", "", true, false).size()).is_greater(0)


func test_wagons_and_fences_hold() -> void:
	var sturdy := props.get_used_cells().filter(func(cell: Vector3i) -> bool:
		var item_name := props.mesh_library.get_item_name(props.get_cell_item(cell))
		return item_name.begins_with("Prop_Wagon") or item_name.begins_with("Prop_WoodenFence"))
	for cell: Vector3i in sturdy:
		props.break_near(props.to_global(props.map_to_local(cell)), 0.5)

	for cell: Vector3i in sturdy:
		assert_int(props.get_cell_item(cell)).is_not_equal(GridMap.INVALID_CELL_ITEM)
