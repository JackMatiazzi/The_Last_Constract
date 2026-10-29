extends GdUnitTestSuite

var arena: TestArena
var victim: Adventurer
var ally: Adventurer
var skeleton: Character


func before_test() -> void:
	RunState.reset()
	arena = TestArena.new(self)
	victim = arena.spawn(TestArena.MAGE, Vector3.ZERO) as Adventurer
	ally = arena.spawn(TestArena.KNIGHT, Vector3(4, 0, 0)) as Adventurer
	skeleton = arena.spawn(TestArena.SKELETON, Vector3(-4, 0, 0))
	victim.set_display_name("Andre")
	ally.set_display_name("Jackson")
	await arena.wait_physics(2)


func after_test() -> void:
	RunState.reset()


func test_recap_tells_the_life_in_order_and_marks_the_final_blow() -> void:
	victim.take_damage(4.0, skeleton)
	victim.heal(4.0)
	victim.take_damage(4.0, skeleton)
	victim.take_damage(6.0, ally)

	assert_str(victim.damage_recap()).is_equal("\n".join([
		"Dano recebido: 14 (vida máxima 10, curou 4)",
		"Esqueleto: -4",
		"Cura: +4",
		"Esqueleto: -4",
		"Fogo amigo de Jackson: -6 (golpe final)",
	]))


func test_hits_in_a_row_from_the_same_source_become_one_line() -> void:
	victim.take_damage(2.0, skeleton)
	victim.take_damage(3.0, skeleton)

	assert_str(victim.damage_recap()).contains("Esqueleto: -5")


func test_a_hit_without_source_does_not_inherit_the_last_attacker() -> void:
	victim.take_damage(4.0, ally)
	victim.take_damage(99.0)

	assert_str(victim.damage_log.death_cause()).is_equal("Ferimentos")
	assert_str(RunState.stats_of(1).last_death).is_equal("Ferimentos")


func test_hurting_yourself_counts_as_wounds_not_your_own_name() -> void:
	victim.take_damage(99.0, victim)

	assert_str(victim.damage_log.death_cause()).is_equal("Ferimentos")


func test_friendly_fire_death_counts_on_the_scoreboard() -> void:
	victim.take_damage(99.0, ally)

	var line := RunState.stats_of(1)
	assert_int(line.deaths).is_equal(1)
	assert_str(line.last_death).is_equal("Fogo amigo de Jackson")


func test_killing_an_enemy_counts_for_the_player() -> void:
	skeleton.take_damage(99.0, ally)

	assert_int(RunState.stats_of(1).kills).is_equal(1)


func test_revive_starts_a_fresh_recap() -> void:
	victim.take_damage(99.0, skeleton)
	victim.revive(5.0)

	assert_str(victim.damage_recap()).starts_with("Dano recebido: 0")


# a queda de um cliente chega por relato; o mesmo relato repetido nao conta duas vezes
func test_a_reported_fall_counts_once() -> void:
	var roster_before := Net.roster.duplicate()
	Net.roster = {1: 0}
	victim._die_locally()

	RunState.count_reported_fall(1, "Esqueleto")
	RunState.count_reported_fall(1, "Esqueleto")

	assert_int(RunState.stats_of(1).deaths).is_equal(1)
	Net.roster = roster_before


func test_a_fall_report_from_someone_standing_is_ignored() -> void:
	var roster_before := Net.roster.duplicate()
	Net.roster = {1: 0}

	RunState.count_reported_fall(1, "Esqueleto")

	assert_int(RunState.stats_of(1).deaths).is_equal(0)
	Net.roster = roster_before
