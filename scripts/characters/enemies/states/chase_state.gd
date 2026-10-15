extends EnemyState


func think(_delta: float) -> void:
	var perception := enemy.perception
	if perception.target == null or perception.target.is_dead:
		brain.change_state("Idle")
		return
	if not perception.is_aware():
		brain.change_state("Investigate")
		return
	var distance := perception.distance_to_target() if perception.can_see else INF
	if distance <= enemy.profile.attack_range:
		brain.change_state("Attack")
		return
	var destination := perception.last_known_position
	var far := enemy.global_position.distance_to(destination) > enemy.profile.chase_run_distance
	brain.move_to(destination, far)
	brain.clear_look()


func exit() -> void:
	brain.stop_moving()
