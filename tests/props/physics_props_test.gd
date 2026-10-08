extends GdUnitTestSuite

const CRATE := "res://scenes/props/crate.tscn"
const BIG_CRATE := "res://scenes/props/big_crate.tscn"
const BARREL := "res://scenes/props/barrel.tscn"

var arena: TestArena


func before_test() -> void:
	arena = TestArena.new(self)


func after_test() -> void:
	Input.action_release("move_forward")


func _walk_into(prop_path: String, seconds: float) -> float:
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO) as Adventurer
	var prop := arena.spawn(prop_path, Vector3(0, 0.05, -2.0)) as RigidBody3D
	await arena.wait_physics(10)
	var start := prop.global_position
	await arena.send_action("move_forward")
	await arena.wait_seconds(seconds)
	return Vector2(prop.global_position.x - start.x, prop.global_position.z - start.z).length()


func test_props_rest_on_the_floor() -> void:
	var crate := arena.spawn(CRATE, Vector3(0, 0.05, 0)) as RigidBody3D

	await arena.wait_seconds(1.0)

	assert_float(crate.global_position.y).is_equal_approx(0.0, 0.05)


func test_walking_into_a_crate_pushes_it() -> void:
	assert_float(await _walk_into(CRATE, 1.5)).is_greater(0.5)


func test_walking_into_a_barrel_pushes_it() -> void:
	assert_float(await _walk_into(BARREL, 1.5)).is_greater(0.5)


func test_a_heavy_crate_moves_less_than_a_light_one() -> void:
	var light := await _walk_into(CRATE, 1.5)
	arena.root.queue_free()
	arena = TestArena.new(self)
	var heavy := await _walk_into(BIG_CRATE, 1.5)

	assert_float(heavy).is_less(light)
