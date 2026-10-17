extends EnemyState

var _searching_for := 0.0


func enter() -> void:
	_searching_for = 0.0
	brain.move_to(enemy.perception.last_known_position)


func think(delta: float) -> void:
	if enemy.perception.can_see:
		brain.change_state("Chase")
		return
	if not brain.has_arrived():
		return
	brain.stop_moving()
	_searching_for += delta
	if _searching_for >= enemy.profile.search_time:
		brain.change_state("Idle")


func exit() -> void:
	brain.stop_moving()
