extends GdUnitTestSuite

const LEVEL := preload("res://scenes/levels/calabouco_escondido_level.tscn")
const MAP_BOUNDS := AABB(Vector3(4, -9, 0), Vector3(90, 14, 124))

var level: Node3D
var session: GameSession
var _device_before: int


func before_test() -> void:
	RunState.reset()
	RunState.adventurer = load("res://resources/adventurers/rogue.tres")
	_device_before = Settings.input_device
	Settings.input_device = Settings.InputDevice.GAMEPAD
	level = auto_free(LEVEL.instantiate())
	add_child(level)
	session = level.get_node("GameSession") as GameSession
	for i in 6:
		await get_tree().physics_frame


func after_test() -> void:
	Input.action_release("move_forward")
	Input.action_release("run")
	Settings.input_device = _device_before
	RunState.adventurer = null
	RunState.reset()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _map() -> Node3D:
	return level.get_node("Navigation/Calabouco")


func test_uses_the_dungeon_pieces() -> void:
	var expected := {"Chao": "dungeon_ground", "Paredes": "dungeon_structure", "Objetos": "dungeon_props"}
	for grid_name in expected:
		var grid := _map().get_node(grid_name) as GridMap
		assert_str(grid.mesh_library.resource_path).override_failure_message(grid_name).contains(expected[grid_name])
		assert_int(grid.get_used_cells().size()).override_failure_message(grid_name).is_greater(0)


func test_props_placed_in_it_can_break() -> void:
	assert_object(_map().get_node("Objetos")).is_instanceof(BreakableProps)


func test_is_dark_without_sky_and_with_fog() -> void:
	var environment := (level.get_node("Ambiente") as WorldEnvironment).environment

	assert_int(environment.background_mode).is_equal(Environment.BG_COLOR)
	assert_float(environment.background_color.v).is_less(0.05)
	assert_float(environment.ambient_light_energy).is_less(0.5)
	assert_bool(environment.fog_enabled).is_true()
	assert_bool(environment.volumetric_fog_enabled).is_true()


func test_torches_are_the_light_and_they_flicker() -> void:
	var torches := _map().get_node("Tochas").get_children()

	assert_int(torches.size()).is_greater(5)
	for torch in torches:
		assert_object(torch.get_node("Flame")).is_instanceof(OmniLight3D)
		assert_bool((torch.get_node("AnimationPlayer") as AnimationPlayer).is_playing()).is_true()


func test_the_spike_traps_do_not_rise_together() -> void:
	var offsets := {}
	for trap in _map().get_node("Armadilhas").find_children("Espinhos*", "", false, false):
		offsets[(trap as TrapCycle).cycle_offset] = true

	assert_int(offsets.size()).is_greater(1)


func test_the_treasure_chest_holds_a_mana_potion() -> void:
	var chest := _map().get_node("Interativos/BauDoTesouro") as Chest

	assert_str(chest.loot_scene.resource_path).is_equal("res://scenes/world/mana_potion.tscn")


func test_has_mana_potions_to_find() -> void:
	var mana_potions := _map().find_children("PocaoMana*", "", true, false)

	assert_int(mana_potions.size()).is_greater(0)


func test_the_skeletons_have_a_navigation_mesh() -> void:
	var navigation := level.get_node("Navigation") as NavigationRegion3D

	assert_int(navigation.navigation_mesh.get_polygon_count()).is_greater(0)


func test_the_adventurer_starts_standing_inside() -> void:
	await get_tree().physics_frame
	for i in 10:
		await get_tree().physics_frame

	assert_bool(session.player.is_on_floor()).is_true()
	assert_bool(MAP_BOUNDS.has_point(session.player.global_position)).is_true()


func test_running_into_every_direction_never_leaves_the_dungeon() -> void:
	var player := session.player
	for yaw in [0.0, PI * 0.5, PI, PI * 1.5]:
		player.camera_pivot.rotation.y = yaw
		Input.action_press("move_forward")
		Input.action_press("run")
		for i in ceili(2.5 * Engine.physics_ticks_per_second):
			await get_tree().physics_frame
		Input.action_release("move_forward")
		Input.action_release("run")

		assert_bool(MAP_BOUNDS.has_point(player.global_position)).override_failure_message("saiu correndo para %s em %s" % [yaw, player.global_position]).is_true()


func test_has_every_kind_of_trap() -> void:
	var traps := _map().get_node("Armadilhas")

	for prefix in ["Espinhos", "Lamina", "Dardos", "BarrilRolante"]:
		assert_int(traps.find_children(prefix + "*", "", false, false).size()).override_failure_message(prefix).is_greater(0)


func test_the_easter_eggs_are_hidden_in_it() -> void:
	var secrets := _map().get_node("Segredos")

	assert_object(level.get_node_or_null("EspadachimPerdido")).is_not_null()
	assert_object(level.get_node_or_null("Mimico")).is_not_null()
	assert_object(secrets.get_node_or_null("JogadoresDeDados")).is_not_null()


# chao com sulcos e pedrinhas prendia o personagem: toda peca de chao tem colisao de caixa lisa
func test_every_floor_piece_has_a_flat_collision() -> void:
	var library := (_map().get_node("Chao") as GridMap).mesh_library
	for id in library.get_item_list():
		var shapes := library.get_item_shapes(id)
		assert_object(shapes[0]).override_failure_message(library.get_item_name(id)).is_instanceof(BoxShape3D)


func test_standing_on_a_rocky_tile_does_not_lift_the_adventurer() -> void:
	var floor := _map().get_node("Chao") as GridMap
	var rocky := floor.mesh_library.find_item_by_name("floor_tile_large_rocks")
	var cell: Vector3i = floor.get_used_cells_by_item(rocky)[0]
	var spot := floor.to_global(floor.map_to_local(cell))
	session.player.global_position = spot + Vector3.UP * 0.6
	session.player.reset_physics_interpolation()

	for i in 30:
		await get_tree().physics_frame

	assert_float(session.player.global_position.y - spot.y).is_less(0.15)


func _mechanism(path: String) -> Node:
	return _map().get_node("Mecanismos/" + path)


func test_the_library_grate_holds_bodies_but_lets_the_mage_portal_through() -> void:
	var grate := _mechanism("PortaoBiblioteca/Grade") as CollisionObject3D
	var lever := _mechanism("AlavancaBiblioteca") as Lever

	assert_int(grate.collision_layer).is_equal(8)
	assert_int(session.player.collision_mask & 8).is_equal(8)
	assert_int(PortalSpell.WORLD_LAYER & 8).is_equal(0)
	assert_array(lever.targets).contains([_mechanism("PortaoBiblioteca")])


func test_the_descent_needs_both_seals() -> void:
	var gate := _mechanism("PortaoDosSelos") as Gate

	(_mechanism("SeloOeste") as Lever)._net_pull()
	assert_bool(gate.is_open).is_false()
	(_mechanism("SeloLeste") as Lever)._net_pull()

	assert_int(gate.required).is_equal(2)
	assert_bool(gate.is_open).is_true()


func test_the_arsenal_lever_disarms_the_arrow_corridor() -> void:
	var volley := _mechanism("CorredorDeFlechas") as DartTrap

	(_mechanism("AlavancaArsenal") as Lever)._net_pull()

	assert_bool(volley.is_armed).is_false()


func test_the_arrows_cross_the_whole_corridor_in_the_map() -> void:
	var plate := _mechanism("CorredorDeFlechas/Placas/Placa1") as Node3D
	session.player.global_position = plate.global_position + Vector3.UP * 0.2
	session.player.reset_physics_interpolation()

	await get_tree().create_timer(1.5).timeout

	assert_float(session.player.health).is_less(session.player.get_max_health())
	assert_str(session.player.damage_log.death_cause()).is_equal("Dardos")


func test_cutting_the_rope_lowers_the_bridge_over_the_middle_blades() -> void:
	var rope := _mechanism("PonteDoAbismo/Corda") as Rope

	rope._net_cut()

	assert_bool((_mechanism("PonteDoAbismo") as Gate).is_open).is_true()
	assert_bool((_mechanism("FossoDeLaminas2") as TrapCycle).is_armed).is_false()
	assert_bool((_mechanism("FossoDeLaminas1") as TrapCycle).is_armed).is_true()


func test_the_cellar_and_the_secret_room_hide_behind_cracked_walls() -> void:
	assert_object(_mechanism("ParedeDaAdega")).is_instanceof(CrackedWall)
	assert_object(_mechanism("ParedeDaSalaSecreta")).is_instanceof(CrackedWall)


func test_the_lantern_company_left_its_story_behind() -> void:
	var story := _map().get_node("Historia")

	assert_int(story.find_children("*", "ReadableNote", false, false).size()).is_greater_equal(10)
	for who in ["RestosDaMaga", "RestosDoCavaleiro", "RestosDoBarbaro", "RestosDaLadina"]:
		assert_object(story.get_node_or_null(who)).override_failure_message(who).is_not_null()
	for note: ReadableNote in story.find_children("*", "ReadableNote", false, false):
		assert_str(note.text).override_failure_message(note.name).is_not_empty()


# com tudo aberto, quem persegue chega a todos os grupos; as travas de classe so guardam atalhos e segredos
func test_every_undead_group_can_be_reached_from_the_entrance() -> void:
	var map := (level.get_node("Navigation") as NavigationRegion3D).get_navigation_map()
	var start: Vector3 = _map().get_node("PlayerSpots/Player1").global_position
	for group in ["AdormecidosDoOssuario", "PatrulhaDoSalao", "PatrulhaDaCripta", "GuardasDaCapela", "Patrulha", "Guardas"]:
		var target := (level.get_node(group) as Node3D).global_position
		var path := NavigationServer3D.map_get_path(map, start, target, true)

		assert_float(path[path.size() - 1].distance_to(target)).override_failure_message(group).is_less(2.5)


# ele conta na clausula, entao nunca fica numa sala que so uma classe abre
func test_the_swordsman_never_waits_behind_a_class_gate() -> void:
	var gated_rooms := [AABB(Vector3(42, -9, 94), Vector3(12, 6, 12)), AABB(Vector3(42, -1, 34), Vector3(12, 4, 12)),
			AABB(Vector3(10, -1, 14), Vector3(4, 4, 8))]
	for spot: Marker3D in _map().get_node("PontosDoEspadachim").find_children("*", "Marker3D", false, false):
		for room: AABB in gated_rooms:
			assert_bool(room.has_point(spot.global_position)).override_failure_message(spot.name).is_false()
