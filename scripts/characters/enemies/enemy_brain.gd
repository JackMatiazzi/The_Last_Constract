class_name EnemyBrain
extends Node

# pensa a cada think_interval, mas segue o caminho todo quadro para nao andar travado

const MAX_CHAINED_TRANSITIONS := 4

@export var think_interval := 0.15
@export var arrive_distance := 0.4

var enemy: Enemy
var current_state: EnemyState
var current_state_name := ""
var desired_direction := Vector3.ZERO
var wants_run := false
var look_point := Vector3.ZERO
var has_look_point := false

var _states := {}
var _think_accumulator := 0.0
var _move_target := Vector3.ZERO
var _has_move_target := false
var _chained_transitions := 0


func _ready() -> void:
	enemy = get_parent() as Enemy
	for child in get_children():
		if child is EnemyState:
			child.brain = self
			child.enemy = enemy
			_states[String(child.name)] = child


# o estado novo ja decide na hora, sem esperar o proximo think
func change_state(state_name: String) -> void:
	if current_state:
		current_state.exit()
	current_state = _states[state_name]
	current_state_name = state_name
	current_state.enter()
	if _chained_transitions < MAX_CHAINED_TRANSITIONS:
		_chained_transitions += 1
		current_state.think(0.0)
		_chained_transitions -= 1


func physics_step(delta: float) -> void:
	_think_accumulator += delta
	if _think_accumulator >= think_interval:
		enemy.perception.sense(_think_accumulator)
		current_state.think(_think_accumulator)
		_think_accumulator = 0.0
	_steer()


func move_to(point: Vector3, run := false) -> void:
	_move_target = point
	_has_move_target = true
	wants_run = run
	enemy.navigation_agent.target_position = point


func stop_moving() -> void:
	_has_move_target = false
	desired_direction = Vector3.ZERO
	wants_run = false


func look_at_point(point: Vector3) -> void:
	look_point = point
	has_look_point = true


func clear_look() -> void:
	has_look_point = false


func has_arrived() -> bool:
	return not _has_move_target or (_move_target - enemy.global_position).slide(Vector3.UP).length() <= arrive_distance


# sem navmesh o proximo ponto e a propria posicao, entao vai reto
func _steer() -> void:
	if not _has_move_target or has_arrived():
		desired_direction = Vector3.ZERO
		return
	var next := enemy.navigation_agent.get_next_path_position()
	var to_next := (next - enemy.global_position).slide(Vector3.UP)
	if to_next.length() < 0.05:
		to_next = (_move_target - enemy.global_position).slide(Vector3.UP)
	desired_direction = to_next.normalized()
