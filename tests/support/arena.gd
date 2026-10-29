class_name TestArena
extends RefCounted

const ARENA := preload("res://tests/support/combat_arena.tscn")
const KNIGHT := "res://scenes/characters/adventurers/knight.tscn"
const BARBARIAN := "res://scenes/characters/adventurers/barbarian.tscn"
const MAGE := "res://scenes/characters/adventurers/mage.tscn"
const ROGUE := "res://scenes/characters/adventurers/rogue.tscn"
const SKELETON := "res://scenes/characters/enemies/skeleton_minion.tscn"

var root: Node3D


# tecla que outra suite deixou apertada (o espaco das cutscenes e tambem correr) nao vaza para esta;
# a ordem das suites muda de uma maquina para outra
func _init(suite: GdUnitTestSuite) -> void:
	for action in InputMap.get_actions():
		Input.action_release(action)
	root = suite.auto_free(ARENA.instantiate())
	suite.add_child(root)


# posicao antes do add_child: colado em outro corpo, a fisica empurra para fora
func spawn(scene_path: String, position: Vector3, yaw := 0.0) -> Character:
	var character := (load(scene_path) as PackedScene).instantiate() as Character
	character.position = position
	if character is Enemy:
		(character as Enemy).ai_enabled = false
	root.add_child(character)
	character.model.rotation.y = deg_to_rad(yaw)
	if character is Adventurer:
		(character as Adventurer).camera_pivot.rotation.y = deg_to_rad(yaw) + PI
		(character as Adventurer).spring_arm.rotation.x = 0.0
	return character


func add_wall(position: Vector3, size: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = size
	wall.add_child(shape)
	wall.position = position
	root.get_node("Navigation").add_child(wall)
	return wall


func bake_navigation() -> void:
	var region := root.get_node("Navigation") as NavigationRegion3D
	region.bake_navigation_mesh(false)
	await wait_physics(3)


func send_action(action: String, pressed := true) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)
	await root.get_tree().process_frame
	await root.get_tree().physics_frame


func send_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await root.get_tree().process_frame


func wait_physics(frames: int) -> void:
	for i in frames:
		await root.get_tree().physics_frame


func wait_seconds(seconds: float) -> void:
	await wait_physics(ceili(seconds * Engine.physics_ticks_per_second))
