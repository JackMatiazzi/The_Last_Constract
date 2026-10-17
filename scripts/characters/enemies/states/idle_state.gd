extends EnemyState

var _noticed_for := 0.0


func enter() -> void:
	brain.stop_moving()
	brain.clear_look()
	_noticed_for = 0.0


func think(delta: float) -> void:
	if not _has_live_target():
		_noticed_for = 0.0
		return
	_noticed_for += delta
	brain.look_at_point(enemy.perception.last_known_position)
	if _noticed_for >= enemy.profile.reaction_time:
		brain.change_state("Chase")
