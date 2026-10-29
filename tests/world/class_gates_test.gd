extends GdUnitTestSuite

const LEVER := preload("res://scenes/world/lever.tscn")
const NOTE := preload("res://scenes/world/readable_note.tscn")
const GATE := preload("res://scenes/world/iron_gate.tscn")
const BRIDGE := preload("res://scenes/world/drawbridge.tscn")
const PIT := preload("res://scenes/world/spike_pit.tscn")
const CRACKED := preload("res://scenes/world/cracked_wall.tscn")
const VOLLEY := preload("res://scenes/world/arrow_volley_trap.tscn")
const BOLT := preload("res://scenes/combat/crossbow_bolt.tscn")
const MAGIC := preload("res://scenes/combat/magic_bolt.tscn")
const GRATES_LAYER := 8

var arena: TestArena


func before_test() -> void:
	RunState.reset()
	arena = TestArena.new(self)


func _place(scene: PackedScene, spot: Vector3, yaw := 0.0) -> Node3D:
	var node := scene.instantiate() as Node3D
	node.position = spot
	node.rotation.y = deg_to_rad(yaw)
	arena.root.add_child(node)
	return node


func _shoot(scene: PackedScene, shooter: Character, from: Vector3, to: Vector3) -> void:
	var shot := scene.instantiate() as Projectile
	arena.root.add_child(shot)
	shot.launch(shooter, from, (to - from).normalized(), 1.0, 4)


func test_pulling_a_lever_opens_its_gate_once() -> void:
	var gate := _place(GATE, Vector3(0, 0, -4)) as Gate
	var lever := _place(LEVER, Vector3(2, 0, 0)) as Lever
	lever.targets = [gate]
	arena.spawn(TestArena.KNIGHT, Vector3(2, 0, 1.5))
	await arena.wait_physics(4)

	lever._request_use.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)
	lever._request_use.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)

	assert_bool(lever.is_pulled).is_true()
	assert_bool(gate.is_open).is_true()
	assert_int(gate.activations).is_equal(1)
	assert_bool(lever.can_interact()).is_false()


func test_a_lever_ignores_whoever_is_far_away() -> void:
	var gate := _place(GATE, Vector3(0, 0, -4)) as Gate
	var lever := _place(LEVER, Vector3(2, 0, 0)) as Lever
	lever.targets = [gate]
	arena.spawn(TestArena.KNIGHT, Vector3(2, 0, 12))
	await arena.wait_physics(4)

	lever._request_use.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)

	assert_bool(gate.is_open).is_false()


func test_a_gate_with_two_seals_waits_for_both() -> void:
	var gate := _place(GATE, Vector3(0, 0, -4)) as Gate
	gate.required = 2

	gate.activate()
	assert_bool(gate.is_open).is_false()
	gate.activate()

	assert_bool(gate.is_open).is_true()


func test_an_open_gate_lets_the_group_through() -> void:
	var gate := _place(GATE, Vector3(0, 0, -3)) as Gate
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO, 180)
	await arena.wait_physics(3)
	gate.activate()
	await arena.wait_seconds(2.8)

	await arena.send_action("move_forward")
	await arena.wait_seconds(1.5)
	await arena.send_action("move_forward", false)

	assert_float(knight.global_position.z).is_less(-4.0)


func test_reading_a_note_shows_its_page_only_here() -> void:
	var note := _place(NOTE, Vector3(0, 0, 1)) as ReadableNote
	note.text = "Somos cinco."
	note.page.text = note.text
	arena.spawn(TestArena.MAGE, Vector3.ZERO)
	await arena.wait_physics(4)

	note._interact()

	assert_bool(note.page.visible).is_true()
	assert_str(note.page.text).is_equal("Somos cinco.")


func test_walking_away_closes_the_note() -> void:
	var note := _place(NOTE, Vector3(0, 0, 1)) as ReadableNote
	var mage := arena.spawn(TestArena.MAGE, Vector3.ZERO)
	await arena.wait_physics(4)
	note._interact()

	mage.global_position = Vector3(0, 0, 12)
	await arena.wait_physics(4)

	assert_bool(note.page.visible).is_false()


func test_the_grate_holds_bodies_but_lets_aim_and_shots_through() -> void:
	var gate := _place(GATE, Vector3(0, 0, -3)) as Gate
	(gate.get_node("Grade") as CollisionObject3D).collision_layer = GRATES_LAYER
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO, 180)
	var rogue := arena.spawn(TestArena.ROGUE, Vector3(1.5, 0, 0), 180)
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3(1.5, 0, -7))
	await arena.wait_physics(3)

	await arena.send_action("move_forward")
	await arena.wait_seconds(1.5)
	await arena.send_action("move_forward", false)
	_shoot(BOLT, rogue, Vector3(1.5, 1.2, -0.8), Vector3(1.5, 1.0, -7))
	await arena.wait_seconds(0.6)

	assert_float(knight.global_position.z).is_greater(-3.0)
	assert_float(skeleton.health).is_less(skeleton.get_max_health())


func test_a_crossbow_bolt_cuts_the_rope_and_lowers_the_bridge() -> void:
	var bridge := _place(BRIDGE, Vector3(0, 0, -8), 180) as Gate
	var pit := _place(PIT, Vector3(0, 0, -6)) as TrapCycle
	var rope := bridge.get_node("Corda") as Rope
	rope.targets.append(pit)
	var rogue := arena.spawn(TestArena.ROGUE, Vector3.ZERO, 180)
	await arena.wait_physics(3)

	_shoot(BOLT, rogue, Vector3(0, 1.5, -1), rope.global_position)
	await arena.wait_seconds(0.8)

	assert_bool(rope.is_cut).is_true()
	assert_bool(bridge.is_open).is_true()
	assert_bool(pit.is_armed).is_false()


func test_a_magic_bolt_does_not_cut_the_rope() -> void:
	var bridge := _place(BRIDGE, Vector3(0, 0, -8), 180) as Gate
	var rope := bridge.get_node("Corda") as Rope
	var mage := arena.spawn(TestArena.MAGE, Vector3.ZERO, 180)
	await arena.wait_physics(3)

	_shoot(MAGIC, mage, Vector3(0, 1.5, -1), rope.global_position)
	await arena.wait_seconds(1.2)

	assert_bool(rope.is_cut).is_false()
	assert_bool(bridge.is_open).is_false()


func test_the_raised_bridge_blocks_the_way() -> void:
	_place(BRIDGE, Vector3(0, 0, -3), 180)
	var knight := arena.spawn(TestArena.KNIGHT, Vector3.ZERO, 180)
	await arena.wait_physics(3)

	await arena.send_action("move_forward")
	await arena.wait_seconds(1.5)
	await arena.send_action("move_forward", false)

	assert_float(knight.global_position.z).is_greater(-3.0)


func test_the_spike_pit_keeps_cutting_until_disarmed() -> void:
	var pit := _place(PIT, Vector3(0, 0, 0)) as TrapCycle
	var knight := arena.spawn(TestArena.KNIGHT, Vector3(0, 0.1, 0))
	await arena.wait_seconds(1.4)
	var after_two := knight.health
	assert_float(after_two).is_less_equal(knight.get_max_health() - 2.0)

	pit.activate()
	await arena.wait_seconds(1.4)

	assert_float(knight.health).is_equal(after_two)
	assert_str(knight.damage_log.death_cause()).is_equal("Fosso de lâminas")


func test_only_the_barbarian_heavy_spin_breaks_a_cracked_wall() -> void:
	var wall := _place(CRACKED, Vector3(0, 0, -1.6)) as CrackedWall
	var knight := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 0), 180)
	await arena.wait_physics(3)
	knight.attack.try_attack(knight, true)
	await arena.wait_seconds(1.5)
	assert_bool(wall.is_broken).is_false()
	knight.queue_free()

	var barbarian := arena.spawn(TestArena.BARBARIAN, Vector3(0, 0, 0), 180)
	await arena.wait_physics(3)
	barbarian.attack.try_attack(barbarian, true)
	await arena.wait_seconds(1.5)

	assert_bool(wall.is_broken).is_true()
	assert_int(wall.collision_layer).is_equal(0)


func test_a_quick_spin_does_not_break_the_wall() -> void:
	var wall := _place(CRACKED, Vector3(0, 0, -1.6)) as CrackedWall
	var barbarian := arena.spawn(TestArena.BARBARIAN, Vector3(0, 0, 0), 180)
	await arena.wait_physics(3)

	barbarian.attack.try_attack(barbarian)
	await arena.wait_seconds(1.2)

	assert_bool(wall.is_broken).is_false()


# as placas do corredor ficam a 10, 14 e 18 m da parede das seteiras; aqui, em z 0, 4 e 8
func test_stepping_on_a_corridor_plate_clicks_and_then_fires() -> void:
	_place(VOLLEY, Vector3(0, 0, -10))
	var mage := arena.spawn(TestArena.MAGE, Vector3(0, 0, 4), 180)

	await arena.wait_seconds(0.3)
	assert_float(mage.health).is_equal(mage.get_max_health())
	await arena.wait_seconds(1.0)

	assert_float(mage.health).is_less(mage.get_max_health())
	assert_str(mage.damage_log.death_cause()).is_equal("Dardos")


func test_the_arrow_corridor_stays_quiet_until_someone_steps_on_a_plate() -> void:
	_place(VOLLEY, Vector3(0, 0, -10))
	var mage := arena.spawn(TestArena.MAGE, Vector3(0, 0, -4), 180)

	await arena.wait_seconds(2.0)

	assert_float(mage.health).is_equal(mage.get_max_health())


func test_the_knight_shield_holds_the_arrows_after_the_click() -> void:
	_place(VOLLEY, Vector3(0, 0, -10))
	var knight := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 4), 180) as Adventurer
	await arena.wait_physics(3)
	knight.use_secondary()

	await arena.wait_seconds(1.5)

	assert_float(knight.health).is_equal(knight.get_max_health())
	assert_float(knight.stamina.current).is_less(knight.stamina.maximum)


func test_a_lever_disarms_the_arrow_corridor() -> void:
	var volley := _place(VOLLEY, Vector3(0, 0, -10)) as DartTrap
	volley.activate()
	var mage := arena.spawn(TestArena.MAGE, Vector3(0, 0, 4), 180)

	await arena.wait_seconds(1.5)

	assert_float(mage.health).is_equal(mage.get_max_health())


func test_a_lever_pulled_after_the_click_stops_the_arrows() -> void:
	var volley := _place(VOLLEY, Vector3(0, 0, -10)) as DartTrap
	var mage := arena.spawn(TestArena.MAGE, Vector3(0, 0, 4), 180)
	await arena.wait_seconds(0.2)

	volley.activate()
	await arena.wait_seconds(1.2)

	assert_float(mage.health).is_equal(mage.get_max_health())


func test_pressing_e_twice_opens_and_closes_the_note() -> void:
	var note := _place(NOTE, Vector3(0, 0, 1)) as ReadableNote
	arena.spawn(TestArena.MAGE, Vector3.ZERO)
	await arena.wait_physics(4)

	await arena.send_action("interact")
	await arena.send_action("interact", false)
	var opened := note.page.visible
	await arena.send_action("interact")
	await arena.send_action("interact", false)

	assert_bool(opened).is_true()
	assert_bool(note.page.visible).is_false()


func test_standing_by_a_lever_means_e_pulls_instead_of_drinking() -> void:
	var lever := _place(LEVER, Vector3(0, 0, 1)) as Lever
	var mage := arena.spawn(TestArena.MAGE, Vector3.ZERO) as Adventurer
	await arena.wait_physics(4)
	assert_int(mage.interactables_in_reach).is_equal(1)

	lever._request_use.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)

	assert_int(mage.interactables_in_reach).is_equal(0)
	assert_bool(lever.prompt.visible).is_false()
