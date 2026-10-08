class_name TestArena
extends RefCounted

const ARENA := preload("res://tests/support/test_arena.tscn")
const KNIGHT := "res://scenes/characters/adventurers/knight.tscn"

var root: Node3D


func _init(suite: GdUnitTestSuite) -> void:
	root = suite.auto_free(ARENA.instantiate())
	suite.add_child(root)


func spawn(scene_path: String, position: Vector3) -> Node3D:
	var node := (load(scene_path) as PackedScene).instantiate() as Node3D
	node.position = position
	root.add_child(node)
	return node


func send_action(action: String, pressed := true) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)
	await root.get_tree().process_frame
	await root.get_tree().physics_frame


func wait_physics(frames: int) -> void:
	for i in frames:
		await root.get_tree().physics_frame


func wait_seconds(seconds: float) -> void:
	await wait_physics(ceili(seconds * Engine.physics_ticks_per_second))
