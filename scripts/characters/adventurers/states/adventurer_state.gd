class_name AdventurerState
extends Node

# o nome do no e o usado em machine.change_state()

var machine: AdventurerStateMachine
var adventurer: Adventurer


func enter() -> void:
	pass


func exit() -> void:
	pass


func next_state(direction: Vector3) -> String:
	return machine.locomotion_state(direction)


# sem animacao propria: quem toca e a acao em curso (golpe, reacao, guarda)
func play(_direction: Vector3) -> void:
	pass


func accepts_input() -> bool:
	return true
