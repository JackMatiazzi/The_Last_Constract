extends GdUnitTestSuite

const PORTAL := preload("res://scenes/world/portal.tscn")

var arena: TestArena
var mage: Adventurer


func before_test() -> void:
	RunState.reset()
	arena = TestArena.new(self)
	mage = arena.spawn(TestArena.MAGE, Vector3.ZERO) as Adventurer
	await arena.wait_physics(3)


func after_test() -> void:
	Input.action_release("move_forward")


func _portals() -> Array[Node]:
	return arena.root.find_children("*", "Portal", true, false)


func _select_portal_spell() -> void:
	mage.next_ability()


func test_the_mage_switches_to_the_portal_spell() -> void:
	_select_portal_spell()

	assert_object(mage.attack).is_instanceof(PortalSpell)
	assert_str(mage.attack.title).is_equal("Portal")


func test_two_casts_open_a_linked_pair_on_the_ground() -> void:
	_select_portal_spell()

	assert_bool(mage.attack_toward_camera()).is_true()
	await arena.wait_seconds(mage.attack.impact_delay + mage.attack.cooldown)
	assert_bool(mage.attack_toward_camera()).is_true()
	await arena.wait_seconds(mage.attack.impact_delay + 0.1)

	var portals := _portals()
	assert_int(portals.size()).is_equal(2)
	assert_bool((portals[0] as Portal).is_linked()).is_true()
	assert_float((portals[0] as Portal).global_position.y).is_equal_approx(0.0, 0.6)


func test_each_portal_costs_its_own_mana() -> void:
	_select_portal_spell()

	mage.attack_toward_camera()

	assert_float(mage.mana.current).is_equal_approx(mage.mana.maximum - mage.attack.cost_override, 0.01)


func test_a_third_cast_closes_the_old_pair() -> void:
	_select_portal_spell()
	for i in 3:
		mage.attack_toward_camera()
		await arena.wait_seconds(mage.attack.impact_delay + mage.attack.cooldown)

	var alive := _portals().filter(func(portal: Node) -> bool: return not portal.is_queued_for_deletion())
	assert_int(alive.size()).is_equal(1)
	assert_bool((alive[0] as Portal).is_linked()).is_false()


func test_walking_into_a_portal_comes_out_of_the_other() -> void:
	var entry := PORTAL.instantiate() as Portal
	var exit := PORTAL.instantiate() as Portal
	arena.root.add_child(entry)
	arena.root.add_child(exit)
	entry.global_position = Vector3(0, 0, 3)
	exit.global_position = Vector3(12, 0, 0)
	entry.link = exit
	exit.link = entry
	await arena.wait_physics(2)

	mage.global_position = Vector3(0, 0, 3)
	await arena.wait_physics(3)

	assert_float(mage.global_position.distance_to(exit.global_position)).is_less(2.0)


func test_skeletons_do_not_travel() -> void:
	var entry := PORTAL.instantiate() as Portal
	var exit := PORTAL.instantiate() as Portal
	arena.root.add_child(entry)
	arena.root.add_child(exit)
	entry.global_position = Vector3(-6, 0, 0)
	exit.global_position = Vector3(12, 0, 0)
	entry.link = exit
	exit.link = entry
	var skeleton := arena.spawn(TestArena.SKELETON, Vector3(-6, 0, 0))
	await arena.wait_physics(4)

	assert_float(skeleton.global_position.distance_to(Vector3(-6, 0, 0))).is_less(1.0)


func test_coming_out_does_not_send_you_straight_back() -> void:
	var entry := PORTAL.instantiate() as Portal
	var exit := PORTAL.instantiate() as Portal
	arena.root.add_child(entry)
	arena.root.add_child(exit)
	entry.global_position = Vector3(0, 0, 3)
	exit.global_position = Vector3(12, 0, 0)
	entry.link = exit
	exit.link = entry
	await arena.wait_physics(2)

	mage.global_position = Vector3(0, 0, 3)
	await arena.wait_physics(3)
	mage.global_position = exit.global_position
	await arena.wait_physics(3)

	assert_float(mage.global_position.distance_to(exit.global_position)).is_less(2.0)


func test_a_wall_in_front_of_the_exit_lands_you_on_the_portal() -> void:
	var exit := PORTAL.instantiate() as Portal
	arena.root.add_child(exit)
	exit.global_position = Vector3(-10, 0, -10)
	arena.add_wall(Vector3(-10, 1, -10.9), Vector3(4, 2, 0.3))
	exit.look_at(Vector3(-10, 0, -12))
	await arena.wait_physics(2)

	assert_float(exit.exit_point().distance_to(exit.global_position)).is_less(0.5)


func test_a_linked_portal_shows_the_other_side() -> void:
	var entry := PORTAL.instantiate() as Portal
	var exit := PORTAL.instantiate() as Portal
	arena.root.add_child(entry)
	arena.root.add_child(exit)
	entry.global_position = Vector3(0, 0, -4)
	exit.global_position = Vector3(12, 0, 0)
	await arena.wait_physics(2)
	assert_int(entry.view.render_target_update_mode).is_equal(SubViewport.UPDATE_DISABLED)

	entry.link = exit
	exit.link = entry
	await arena.wait_physics(2)

	var eye := entry.get_viewport().get_camera_3d()
	assert_int(entry.view.render_target_update_mode).is_equal(SubViewport.UPDATE_ALWAYS)
	assert_float(entry.view_camera.global_position.distance_to(exit.global_position)) \
		.is_equal_approx(eye.global_position.distance_to(entry.global_position), 0.05)
