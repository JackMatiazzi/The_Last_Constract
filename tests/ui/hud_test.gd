extends GdUnitTestSuite

const HUD := preload("res://scenes/ui/hud.tscn")

var arena: TestArena


func before_test() -> void:
	RunState.reset()
	arena = TestArena.new(self)


func after_test() -> void:
	RunState.reset()


func _spawn_hud(player: Character) -> Hud:
	var hud: Hud = HUD.instantiate()
	hud.player = player
	arena.root.add_child(hud)
	return hud


func test_shows_attempt_and_full_health() -> void:
	var hud := _spawn_hud(arena.spawn(TestArena.KNIGHT, Vector3.ZERO))

	assert_str(hud.attempt_label.text).is_equal("Tentativa 1")
	assert_str(hud.health_label.text).is_equal("10 / 10")


func test_follows_damage() -> void:
	var player := arena.spawn(TestArena.KNIGHT, Vector3.ZERO)
	var hud := _spawn_hud(player)

	player.take_damage(3.0)

	assert_str(hud.health_label.text).is_equal("7 / 10")
	assert_float(hud.health_bar.value).is_equal(7.0)


func test_hides_buff_title_without_buffs() -> void:
	var hud := _spawn_hud(arena.spawn(TestArena.KNIGHT, Vector3.ZERO))

	assert_bool(hud.get_node("%BuffTitle").visible).is_false()
	assert_int(hud.buff_list.get_child_count()).is_equal(0)


func test_lists_buffs_once_with_stacks_and_effect() -> void:
	var sharp: Buff = load("res://resources/buffs/lamina_afiada.tres")
	RunState.start_next_attempt(sharp)
	RunState.start_next_attempt(sharp)
	var hud := _spawn_hud(arena.spawn(TestArena.KNIGHT, Vector3.ZERO))

	assert_str(hud.attempt_label.text).is_equal("Tentativa 3")
	assert_int(hud.buff_list.get_child_count()).is_equal(1)
	assert_str((hud.buff_list.get_child(0) as Label).text).is_equal("Lâmina Afiada ×2: +1 de dano")
