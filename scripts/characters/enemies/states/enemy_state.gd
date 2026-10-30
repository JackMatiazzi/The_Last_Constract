class_name EnemyState
extends Node
## o nome do no e o usado em brain.change_state()

var brain: EnemyBrain
var enemy: Enemy


func enter() -> void:
	pass


func exit() -> void:
	pass


func think(_delta: float) -> void:
	pass


func _has_live_target() -> bool:
	var target := enemy.perception.target
	return target != null and not target.is_dead and enemy.perception.is_aware()
