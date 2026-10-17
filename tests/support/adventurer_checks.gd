class_name AdventurerChecks
extends RefCounted

const ADVENTURER_LAYER := 2

var suite: GdUnitTestSuite
var arena: TestArena


func _init(test_suite: GdUnitTestSuite, test_arena: TestArena) -> void:
	suite = test_suite
	arena = test_arena


func visible_weapons(character: Character) -> Array[String]:
	var names: Array[String] = []
	for slot in character.find_children("handslot_*", "BoneAttachment3D", true, false):
		for weapon in slot.get_children():
			if (weapon as Node3D).visible:
				names.append(String(weapon.name))
	names.sort()
	return names


func check_spawns_ready_to_play(scene_path: String) -> void:
	var adventurer := arena.spawn(scene_path, Vector3.ZERO) as Adventurer
	await arena.wait_physics(3)

	suite.assert_float(adventurer.health).is_equal(10.0)
	suite.assert_int(adventurer.collision_layer).is_equal(ADVENTURER_LAYER)
	suite.assert_object(adventurer.attack).is_not_null()
	suite.assert_bool(adventurer.is_on_floor()).is_true()
	suite.assert_str(adventurer.animation_player.current_animation).is_equal(Character.ANIM_IDLE)


func check_walks(scene_path: String) -> void:
	var adventurer := arena.spawn(scene_path, Vector3.ZERO) as Adventurer
	await arena.wait_physics(3)

	await arena.send_action("move_forward")
	await arena.wait_seconds(0.4)
	Input.action_release("move_forward")

	var speed := Vector2(adventurer.velocity.x, adventurer.velocity.z).length()
	suite.assert_float(speed).is_equal_approx(adventurer.walk_speed, 0.01)
	suite.assert_str(adventurer.animation_player.current_animation).is_equal(Character.ANIM_WALK)


func check_attack_cycle(scene_path: String) -> void:
	var adventurer := arena.spawn(scene_path, Vector3.ZERO) as Adventurer
	await arena.wait_physics(3)
	var attack := adventurer.attack

	suite.assert_bool(attack.try_attack(adventurer)).is_true()
	suite.assert_bool(Array(attack.animations).has(adventurer.animation_player.current_animation)).is_true()
	suite.assert_bool(attack.try_attack(adventurer)).is_false()

	await arena.send_action("move_forward")
	await arena.wait_seconds(attack.impact_delay + attack.recovery + 0.05)
	Input.action_release("move_forward")
	suite.assert_bool(adventurer.is_busy).is_false()

	await arena.wait_seconds(attack.effective_cooldown(adventurer))
	suite.assert_bool(attack.can_attack(adventurer)).is_true()


func check_dies(scene_path: String) -> void:
	var adventurer := arena.spawn(scene_path, Vector3.ZERO) as Adventurer
	await arena.wait_physics(3)

	adventurer.take_damage(99.0)
	await arena.wait_physics(3)

	suite.assert_bool(adventurer.is_dead).is_true()
	suite.assert_str(adventurer.animation_player.current_animation).is_equal(Character.ANIM_DEATH)
	suite.assert_bool(adventurer.collision_shape.disabled).is_true()
	suite.assert_bool(adventurer.attack.try_attack(adventurer)).is_false()
