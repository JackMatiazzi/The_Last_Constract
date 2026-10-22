class_name AdventurerStateMachine
extends Node

# roda dentro de _update_animation do aventureiro: estado e animacao mudam no mesmo quadro

const MAX_CHAINED_TRANSITIONS := 4

var adventurer: Adventurer
var current_state: AdventurerState
var current_state_name := ""

var _states := {}


func _ready() -> void:
	adventurer = get_parent() as Adventurer
	for child in get_children():
		if child is AdventurerState:
			child.machine = self
			child.adventurer = adventurer
			_states[String(child.name)] = child
	change_state("Idle")


func change_state(state_name: String) -> void:
	if state_name == current_state_name:
		return
	if current_state:
		current_state.exit()
	current_state = _states[state_name]
	current_state_name = state_name
	current_state.enter()


# um estado pode levar a outro que tambem quer trocar (Block solto vira Action do golpe)
func step(direction: Vector3) -> void:
	for i in MAX_CHAINED_TRANSITIONS:
		var next := current_state.next_state(direction)
		if next == current_state_name:
			break
		change_state(next)
	current_state.play(direction)


func locomotion_state(direction: Vector3) -> String:
	if adventurer.is_busy:
		return "Action"
	if not adventurer.is_grounded():
		return "Air"
	if direction == Vector3.ZERO:
		return "Idle"
	return "Run" if adventurer.is_running_now() else "Walk"
