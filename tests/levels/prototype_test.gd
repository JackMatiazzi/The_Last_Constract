extends GdUnitTestSuite

const PROTOTYPE := preload("res://scenes/levels/prototype.tscn")


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_opens_with_a_playable_knight_on_the_ground() -> void:
	var level := auto_free(PROTOTYPE.instantiate()) as Node3D
	add_child(level)
	for i in 60:
		await get_tree().physics_frame

	var knight := level.get_node("Knight") as Adventurer
	assert_bool(knight.is_on_floor()).is_true()
	assert_bool(knight.camera.current).is_true()


func test_props_stay_on_the_map() -> void:
	var level := auto_free(PROTOTYPE.instantiate()) as Node3D
	add_child(level)
	for i in 120:
		await get_tree().physics_frame

	for prop: RigidBody3D in level.get_node("Props").get_children():
		assert_float(prop.global_position.y).override_failure_message("%s caiu do mapa" % prop.name).is_greater(-0.2)


func test_falling_off_the_map_returns_to_the_start() -> void:
	var level := auto_free(PROTOTYPE.instantiate()) as Node3D
	add_child(level)
	var knight := level.get_node("Knight") as Adventurer
	var start := knight.global_position
	await get_tree().physics_frame

	knight.global_position = Vector3(start.x, -20.0, start.z)
	await get_tree().physics_frame

	assert_float(knight.global_position.distance_to(start)).is_less(0.5)


func test_has_an_enemy_to_attack() -> void:
	var level := auto_free(PROTOTYPE.instantiate()) as Node3D
	add_child(level)
	await get_tree().physics_frame

	assert_object(level.get_node_or_null("Skeleton")).is_instanceof(Enemy)
