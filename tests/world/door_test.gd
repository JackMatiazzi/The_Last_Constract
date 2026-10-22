extends GdUnitTestSuite

# a porta das casas da vila tem vao de 2,3 m; o pulo leva a cabeca acima disso

const STRUCTURE := preload("res://resources/mesh_libraries/village_structure.res")
const DOOR_ITEM := "Wall_UnevenBrick_Door_Round"
const DOOR_Z := 3.0

var arena: TestArena
var rogue: Adventurer
var _device_before: int


func before_test() -> void:
	RunState.reset()
	arena = TestArena.new(self)
	_device_before = Settings.input_device
	Settings.input_device = Settings.InputDevice.GAMEPAD
	_add_door()
	rogue = arena.spawn(TestArena.ROGUE, Vector3.ZERO) as Adventurer
	await arena.wait_physics(3)


func after_test() -> void:
	Input.action_release("move_forward")
	Settings.input_device = _device_before


func _add_door() -> void:
	var door := StaticBody3D.new()
	var shapes := STRUCTURE.get_item_shapes(STRUCTURE.find_item_by_name(DOOR_ITEM))
	for i in range(0, shapes.size(), 2):
		var shape := CollisionShape3D.new()
		shape.shape = shapes[i]
		shape.transform = shapes[i + 1]
		door.add_child(shape)
	door.position = Vector3(0, 0, DOOR_Z)
	arena.root.add_child(door)


func _walk_until(z: float) -> void:
	Input.action_press("move_forward")
	while rogue.global_position.z < z:
		await arena.wait_physics(1)


func test_walking_goes_through_the_door() -> void:
	await _walk_until(DOOR_Z - 1.0)
	await arena.wait_seconds(1.0)

	assert_float(rogue.global_position.z).is_greater(DOOR_Z + 1.0)


func test_jumping_before_the_door_does_not_stick_to_the_wall_above_it() -> void:
	await _walk_until(DOOR_Z - 1.8)
	rogue.request_jump()
	await arena.wait_seconds(1.2)

	assert_float(rogue.global_position.z).is_greater(DOOR_Z + 0.5)


# o caixote bate nos pes: o pulo nao e cortado e chega a altura de sempre
func test_jumping_against_a_crate_keeps_the_full_jump() -> void:
	arena.add_wall(Vector3(4, 0.5, 1.0), Vector3(1, 1, 1))
	rogue.global_position = Vector3(4, 0, 0)
	await arena.wait_physics(3)
	Input.action_press("move_forward")
	rogue.request_jump()
	var highest := 0.0
	for i in 50:
		await arena.wait_physics(1)
		highest = maxf(highest, rogue.global_position.y)

	assert_float(highest).is_greater(2.0)
