extends GdUnitTestSuite

const NECROMANCER := "res://scenes/characters/enemies/necromancer.tscn"
const LEVEL := preload("res://scenes/levels/village_level.tscn")
const PATROL := preload("res://scenes/characters/enemies/groups/patrol.tscn")

var arena: TestArena


func before_test() -> void:
	RunState.reset()


func after_test() -> void:
	RunState.adventurer = null
	RunState.reset()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _hunting_necromancer(player: Character, summon_interval := 99.0) -> Enemy:
	var boss := (load(NECROMANCER) as PackedScene).instantiate() as Enemy
	boss.position = Vector3.ZERO
	(boss.get_node("Summoner") as Summoner).interval = summon_interval
	arena.root.add_child(boss)
	await arena.wait_physics(3)
	boss.take_damage(0.1, player)
	return boss


func _minions() -> Array[Node]:
	return arena.root.find_children("*", "", true, false).filter(func(n: Node) -> bool:
		return n.scene_file_path == TestArena.SKELETON)


func test_necromancer_is_a_tough_caster() -> void:
	arena = TestArena.new(self)
	var boss := arena.spawn(NECROMANCER, Vector3.ZERO)

	assert_float(boss.get_max_health()).is_equal(30.0)
	assert_object(boss.attack).is_instanceof(RangedAttack)
	assert_int((boss.attack as RangedAttack).target_layers).is_equal(2)


func test_necromancer_shoots_the_player_from_a_distance() -> void:
	arena = TestArena.new(self)
	await arena.bake_navigation()
	var player := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 8))
	await _hunting_necromancer(player)

	await arena.wait_seconds(3.5)

	assert_float(player.health).is_less(player.get_max_health())


func test_summons_undead_but_never_more_than_the_limit() -> void:
	arena = TestArena.new(self)
	await arena.bake_navigation()
	var player := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 9))
	var boss := await _hunting_necromancer(player, 0.8)
	var summoner := boss.get_node("Summoner") as Summoner

	await arena.wait_seconds(2.5)
	assert_int(_minions().size()).is_greater_equal(summoner.per_cast)

	await arena.wait_seconds(5.0)
	assert_int(_minions().filter(func(m: Enemy) -> bool: return not m.is_dead).size()).is_less_equal(summoner.max_alive)


func test_summoned_undead_collapse_with_the_necromancer() -> void:
	arena = TestArena.new(self)
	await arena.bake_navigation()
	var player := arena.spawn(TestArena.KNIGHT, Vector3(0, 0, 9))
	var boss := await _hunting_necromancer(player, 0.5)
	await arena.wait_seconds(2.0)
	assert_int(_minions().size()).is_greater(0)

	boss.take_damage(99.0)

	for minion: Enemy in _minions():
		assert_bool(minion.is_dead).is_true()


func _level_with_patrols(count: int) -> Node3D:
	RunState.adventurer = load("res://resources/adventurers/knight.tres")
	var level := auto_free(LEVEL.instantiate()) as Node3D
	var encounters := level.get_node("Encounters") as EncounterSpawner
	encounters.group_scenes = [PATROL]
	encounters.group_count = count
	add_child(level)
	await await_idle_frame()
	return level


func test_clearing_every_group_summons_the_necromancer_on_the_square() -> void:
	var level := await _level_with_patrols(2)
	var session := level.get_node("GameSession") as GameSession
	var hud := level.get_node("Hud") as Hud
	assert_str(hud.objective_label.text).is_equal("Grupos restantes: 2")

	for group: EnemyGroup in level.get_node("Encounters").find_children("*", "EnemyGroup", false, false):
		for member in group.members():
			member.take_damage(99.0)
	await await_idle_frame()

	assert_object(session.boss).is_not_null()
	var spot := (level.get_node("Encounters") as EncounterSpawner).boss_spot.global_position
	assert_float(session.boss.global_position.distance_to(spot)).is_less(0.5)
	assert_bool(hud.boss_panel.visible).is_true()


func test_defeating_the_necromancer_wins_the_contract() -> void:
	var level := await _level_with_patrols(1)
	var session := level.get_node("GameSession") as GameSession
	var victory := level.get_node("VictoryScreen") as VictoryScreen
	for member in (level.get_node("Encounters").find_children("*", "EnemyGroup", false, false)[0] as EnemyGroup).members():
		member.take_damage(99.0)
	await await_idle_frame()

	session.boss.take_damage(99.0)
	assert_bool(victory.visible).is_false()
	await await_millis(int((GameSession.VICTORY_DELAY + 0.3) * 1000))

	assert_bool(victory.visible).is_true()
	assert_str(victory.summary_label.text).contains("tentativa 1")
