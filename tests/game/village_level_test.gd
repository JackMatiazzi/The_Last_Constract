extends GdUnitTestSuite

const LEVEL := preload("res://scenes/levels/village_level.tscn")

var level: Node3D
var session: GameSession
var encounters: EncounterSpawner


func before_test() -> void:
	RunState.reset()
	RunState.adventurer = load("res://resources/adventurers/knight.tres")
	level = auto_free(LEVEL.instantiate())
	add_child(level)
	session = level.get_node("GameSession")
	encounters = level.get_node("Encounters")
	for i in 3:
		await await_idle_frame()


func after_test() -> void:
	RunState.adventurer = null
	RunState.reset()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _groups() -> Array[Node]:
	return encounters.get_children().filter(func(child: Node) -> bool: return child is EnemyGroup)


func test_player_starts_on_one_of_the_player_spots() -> void:
	var spots := encounters.player_spots.get_children()

	var nearest: float = spots.map(func(spot: Marker3D) -> float: return spot.global_position.distance_to(session.player.global_position)).min()

	assert_float(nearest).is_less(0.5)


func test_places_the_configured_number_of_groups_away_from_the_player() -> void:
	var groups := _groups()

	assert_int(groups.size()).is_equal(encounters.group_count)
	for group: EnemyGroup in groups:
		assert_float(group.global_position.distance_to(session.player.global_position)).is_greater_equal(encounters.min_distance_from_player)


func test_every_group_spot_can_walk_to_every_player_spot() -> void:
	var map := level.get_world_3d().navigation_map
	# o mapa de navegacao sincroniza em segundo plano
	var probe: Vector3 = encounters.player_spots.get_child(0).global_position
	for frame in 60:
		if NavigationServer3D.map_get_closest_point(map, probe).distance_to(probe) < 1.0:
			break
		await get_tree().physics_frame

	for group_spot: Marker3D in encounters.group_spots.get_children():
		for player_spot: Marker3D in encounters.player_spots.get_children():
			var path := NavigationServer3D.map_get_path(map, group_spot.global_position, player_spot.global_position, true)
			var reached := not path.is_empty() and path[-1].distance_to(player_spot.global_position) < 1.5
			assert_bool(reached).override_failure_message("%s nao chega em %s" % [group_spot.name, player_spot.name]).is_true()


func test_every_spot_stands_on_open_ground() -> void:
	var space := level.get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = 0.6
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1

	for spot: Marker3D in encounters.group_spots.get_children() + encounters.player_spots.get_children():
		query.transform = Transform3D(Basis(), spot.global_position + Vector3.UP * 1.0)
		assert_array(space.intersect_shape(query)).override_failure_message("%s dentro de algo" % spot.name).is_empty()
