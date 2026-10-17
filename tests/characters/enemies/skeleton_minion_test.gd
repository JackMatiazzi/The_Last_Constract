extends GdUnitTestSuite

const SCENE := TestArena.SKELETON
const ENEMY_LAYER := 4

var arena: TestArena


func before_test() -> void:
	RunState.reset()
	arena = TestArena.new(self)


func test_spawns_as_enemy_with_five_health() -> void:
	var skeleton := arena.spawn(SCENE, Vector3.ZERO)
	await arena.wait_physics(3)

	assert_object(skeleton).is_instanceof(Enemy)
	assert_float(skeleton.health).is_equal(5.0)
	assert_int(skeleton.collision_layer).is_equal(ENEMY_LAYER)
	assert_bool(skeleton.is_on_floor()).is_true()


func test_holds_blade_on_right_hand_bone() -> void:
	var skeleton := arena.spawn(SCENE, Vector3.ZERO)
	await arena.wait_physics(3)

	var blade := skeleton.find_child("Skeleton_Blade", true, false) as Node3D
	var skeleton_3d := skeleton.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var hand := skeleton_3d.global_transform * skeleton_3d.get_bone_global_pose(skeleton_3d.find_bone("handslot.r"))
	assert_object(blade).is_not_null()
	assert_float(blade.global_position.distance_to(hand.origin)).is_less(0.01)


func test_shows_red_health_bar() -> void:
	var skeleton := arena.spawn(SCENE, Vector3.ZERO)
	var bar := skeleton.get_node("HealthBar3D") as HealthBar3D

	assert_bool(bar.visible).is_true()
	assert_bool(bar.fill_color.r > bar.fill_color.g).is_true()


func test_stays_still_without_ai() -> void:
	var skeleton := arena.spawn(SCENE, Vector3.ZERO)
	await arena.wait_seconds(0.5)

	assert_float(skeleton.global_position.distance_to(Vector3.ZERO)).is_less(0.05)


func test_reacts_to_hit_and_dies_on_fifth() -> void:
	var skeleton := arena.spawn(SCENE, Vector3.ZERO)

	skeleton.take_damage(1.0)
	assert_str(skeleton.animation_player.current_animation).is_equal(Character.ANIM_HIT)
	skeleton.take_damage(4.0)

	assert_bool(skeleton.is_dead).is_true()
	assert_str(skeleton.animation_player.current_animation).is_equal(Character.ANIM_DEATH)
