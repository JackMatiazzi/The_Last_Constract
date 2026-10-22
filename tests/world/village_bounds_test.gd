extends GdUnitTestSuite

# as casas da borda tem porta virada para fora da vila; as paredes invisiveis de Limites seguram
# quem sai por elas antes do fim do chao

const VILLAGE := preload("res://scenes/maps/village.tscn")
const DOOR_ITEM := "Wall_UnevenBrick_Door_Round"
const GROUND_EDGE := 24.0
const RUN_TIME := 3.0

var village: Node3D
var _device_before: int


func before_test() -> void:
	RunState.reset()
	_device_before = Settings.input_device
	Settings.input_device = Settings.InputDevice.GAMEPAD
	village = auto_free(VILLAGE.instantiate())
	add_child(village)
	for i in 6:
		await get_tree().physics_frame


func after_test() -> void:
	Input.action_release("move_forward")
	Input.action_release("run")
	Settings.input_device = _device_before


# portas cujo lado de fora, 3,5 m adiante, ja passa do fim do chao
func _edge_doors() -> Array[Transform3D]:
	var structure := village.get_node("Estrutura") as GridMap
	var item := structure.mesh_library.find_item_by_name(DOOR_ITEM)
	var found: Array[Transform3D] = []
	for cell in structure.get_used_cells_by_item(item):
		var door := structure.global_transform * Transform3D(structure.get_cell_item_basis(cell), structure.map_to_local(cell))
		for side in [1.0, -1.0]:
			var outward: Vector3 = door.basis.z.normalized() * side
			var ahead := door.origin + outward * 3.5
			if absf(ahead.x) > GROUND_EDGE or absf(ahead.z) > GROUND_EDGE:
				found.append(Transform3D(Basis.looking_at(outward), door.origin))
	return found


func test_the_village_has_doors_facing_the_edge() -> void:
	assert_int(_edge_doors().size()).is_greater(0)


func test_running_out_of_an_edge_door_stops_at_the_invisible_wall() -> void:
	for door in _edge_doors():
		var outward := -door.basis.z
		var rogue := (load("res://scenes/characters/adventurers/rogue.tscn") as PackedScene).instantiate() as Adventurer
		rogue.position = door.origin + outward * 1.0
		village.add_child(rogue)
		rogue.camera_pivot.rotation.y = atan2(outward.x, outward.z) + PI
		await get_tree().physics_frame
		Input.action_press("move_forward")
		Input.action_press("run")
		for i in ceili(RUN_TIME * Engine.physics_ticks_per_second):
			await get_tree().physics_frame
		Input.action_release("move_forward")
		Input.action_release("run")

		var spot := rogue.global_position
		assert_float(maxf(absf(spot.x), absf(spot.z))).override_failure_message("saiu pela porta em %s" % door.origin).is_less(GROUND_EDGE)
		assert_float(spot.y).override_failure_message("caiu pela porta em %s" % door.origin).is_greater(-0.5)
		rogue.queue_free()
		await get_tree().physics_frame
