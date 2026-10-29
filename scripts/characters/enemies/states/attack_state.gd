extends EnemyState

## folga para nao ficar trocando entre Chase e Attack na borda do alcance
const RANGE_MARGIN := 0.5
const FACING_TOLERANCE := 30.0


func enter() -> void:
	brain.stop_moving()


func think(_delta: float) -> void:
	var perception := enemy.perception
	if perception.target == null or perception.target.is_dead:
		brain.change_state("Idle")
		return
	if perception.distance_to_target() > enemy.profile.attack_range + RANGE_MARGIN:
		brain.change_state("Chase")
		return
	var target_position := perception.target.global_position
	brain.look_at_point(target_position)
	if enemy.is_facing(target_position, FACING_TOLERANCE) and enemy.attack.can_attack(enemy):
		enemy.attack.try_attack(enemy)


func exit() -> void:
	brain.clear_look()
