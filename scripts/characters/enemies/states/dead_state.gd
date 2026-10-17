extends EnemyState


func enter() -> void:
	brain.stop_moving()
	brain.clear_look()
