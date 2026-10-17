extends GdUnitTestSuite

# os grupos nascem girados; o giro do pai nao pode entortar o modelo

const MINION := "res://scenes/characters/enemies/skeleton_minion.tscn"

var arena: TestArena


func before_test() -> void:
	RunState.reset()
	arena = TestArena.new(self)


func _skeleton_in_group_turned_by(yaw: float, player: Adventurer) -> Enemy:
	var group := Node3D.new()
	group.rotation.y = yaw
	var skeleton := (load(MINION) as PackedScene).instantiate() as Enemy
	group.add_child(skeleton)
	arena.root.add_child(group)
	await arena.wait_physics(3)
	skeleton.take_damage(0.1, player)
	return skeleton


func test_walks_facing_where_it_goes_inside_a_turned_group() -> void:
	await arena.bake_navigation()
	var player := arena.spawn(TestArena.MAGE, Vector3(0, 0, 9)) as Adventurer
	var skeleton := await _skeleton_in_group_turned_by(2.4, player)
	var sideways := 0
	var moving := 0

	for frame in 90:
		await arena.wait_physics(1)
		var velocity := Vector3(skeleton.velocity.x, 0, skeleton.velocity.z)
		if velocity.length() > 0.4:
			moving += 1
			if velocity.normalized().dot(skeleton.model.global_basis.z.normalized()) < 0.7:
				sideways += 1

	assert_int(moving).is_greater(30)
	assert_int(sideways).is_less(10)


func test_attacks_the_player_it_reaches_inside_a_turned_group() -> void:
	await arena.bake_navigation()
	var player := arena.spawn(TestArena.MAGE, Vector3(0, 0, 3)) as Adventurer
	await _skeleton_in_group_turned_by(2.4, player)

	await arena.wait_seconds(3.0)

	assert_float(player.health).is_less(player.get_max_health())
