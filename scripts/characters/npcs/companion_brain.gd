class_name CompanionBrain
extends Node
## o que o espadachim faz depois de entrar no grupo: segue quem o chamou, bate no morto-vivo mais perto e,
## de vez em quando, jura que o caminho e por outro lado e some ate alguem ir buscar. Anda sem desviar de
## placa nenhuma, entao dispara armadilha em cima do grupo. Roda so no host; o resto das maquinas so ve ele
## andar

const REPATH_TIME := 0.4
const CORNER_REACH := 0.6
const FOUND_DISTANCE := 6.0
const WRONG_WAY_TRIES := 6
const WORLD_LAYER := 1
# inimigo em outro andar fica a pelo menos isso de diferenca de altura
const SAME_FLOOR_HEIGHT := 2.5

## Para a esta distancia do lider.
@export var follow_distance := 2.5
## Ataca o morto-vivo mais perto ate esta distancia dele.
@export var help_range := 10.0
## Menor tempo ate ele se perder de novo.
@export var wander_every_min := 45.0
## Maior tempo ate ele se perder de novo.
@export var wander_every_max := 75.0
## Quanto tempo anda para o lado errado antes de parar e esperar.
@export var lost_walk_time := 8.0
## Quao longe tenta ir quando se perde.
@export var lost_distance := 18.0
## Ditas em rodizio quando ele sai para o lado errado.
@export var lost_lines := PackedStringArray()
## Dita quando para e espera alguem achar.
@export var wait_line := ""
## Dita quando o acham ou falam com ele.
@export var found_line := ""

var leader: Adventurer
var is_lost := false
var goal := Vector3.ZERO
var _stop_at := 0.0
var _npc: FriendlyUndead
var _path := PackedVector3Array()
var _path_index := 0
var _sight := PhysicsRayQueryParameters3D.new()
var _repath_left := 0.0
var _next_wander := 0.0
var _lost_until := 0.0
var _waiting := false
var _lost_index := 0


func _ready() -> void:
	_npc = get_parent() as FriendlyUndead
	assert(_npc, "CompanionBrain: tem de ser filho de um FriendlyUndead")
	_sight.collision_mask = WORLD_LAYER


func start(new_leader: Adventurer) -> void:
	leader = new_leader
	is_lost = false
	_schedule_wander()


func stop() -> void:
	leader = null
	is_lost = false
	_path.clear()


func tick(delta: float) -> void:
	if leader == null or not is_instance_valid(leader) or leader.is_dead:
		leader = _nearest_player()
		if leader == null:
			return
	if is_lost:
		_wander_tick()
	elif _now() >= _next_wander:
		_get_lost()
	else:
		_escort()
	_repath_left -= delta
	if _repath_left <= 0.0:
		_repath_left = REPATH_TIME
		_path = NavigationServer3D.map_get_path(_npc.get_world_3d().navigation_map, _npc.global_position, goal, true)
		# o primeiro ponto e onde ele ja esta
		_path_index = 1


# canto alcancado fica para tras: nunca volta para um ponto do caminho que ja passou
func move_direction() -> Vector3:
	if leader == null or _npc.global_position.distance_to(goal) <= _stop_at:
		return Vector3.ZERO
	while _path_index < _path.size():
		var to := (_path[_path_index] - _npc.global_position).slide(Vector3.UP)
		if to.length() > CORNER_REACH:
			return to.normalized()
		_path_index += 1
	return (goal - _npc.global_position).slide(Vector3.UP).normalized()


func far_from_leader(distance: float) -> bool:
	return leader != null and _npc.global_position.distance_to(leader.global_position) > distance


## conversar com ele quando esta perdido tambem conta como achar
func found(quiet := false) -> void:
	if is_lost:
		is_lost = false
		_waiting = false
		_schedule_wander()
		if not quiet:
			_npc.speak(found_line)


func _escort() -> void:
	var enemy := _nearest_enemy()
	if enemy == null:
		goal = leader.global_position
		_stop_at = follow_distance
		return
	goal = enemy.global_position
	_stop_at = _npc.strike_range * 0.8
	if enemy.global_position.distance_to(_npc.global_position) <= _npc.strike_range:
		_npc.strike(enemy)


func _get_lost() -> void:
	is_lost = true
	_waiting = false
	_lost_until = _now() + lost_walk_time
	goal = _farthest_wrong_way()
	_stop_at = 0.8
	if not lost_lines.is_empty():
		_npc.speak(lost_lines[_lost_index % lost_lines.size()])
		_lost_index += 1


func _wander_tick() -> void:
	if leader.global_position.distance_to(_npc.global_position) <= FOUND_DISTANCE and _now() >= _lost_until:
		found()
		return
	if _now() >= _lost_until and not _waiting:
		_waiting = true
		goal = _npc.global_position
		_npc.speak(wait_line)


# parede para um lado so deixa ele ir para o outro: das direcoes sorteadas, a que leva mais longe
func _farthest_wrong_way() -> Vector3:
	var map := _npc.get_world_3d().navigation_map
	var best := _npc.global_position
	var start := randf() * TAU
	for i in WRONG_WAY_TRIES:
		var away := Vector3.FORWARD.rotated(Vector3.UP, start + TAU * i / WRONG_WAY_TRIES) * lost_distance
		var spot := NavigationServer3D.map_get_closest_point(map, _npc.global_position + away)
		if spot.distance_to(_npc.global_position) > best.distance_to(_npc.global_position):
			best = spot
	return best


func _schedule_wander() -> void:
	_next_wander = _now() + randf_range(wander_every_min, wander_every_max)


# so briga com quem ja esta acordado, no mesmo andar e a vista: nao acorda patrulha nem atravessa parede
func _nearest_enemy() -> Character:
	var nearest: Character = null
	var nearest_distance := help_range
	for enemy: Enemy in _npc.get_tree().get_nodes_in_group(UndeadCensus.GROUP).filter(func(node: Node) -> bool: return node is Enemy):
		var distance := enemy.global_position.distance_to(_npc.global_position)
		if enemy.is_dead or distance >= nearest_distance or enemy.brain.current_state_name == "Dormant":
			continue
		if absf(enemy.global_position.y - _npc.global_position.y) > SAME_FLOOR_HEIGHT or not _can_see(enemy):
			continue
		nearest = enemy
		nearest_distance = distance
	return nearest


func _can_see(enemy: Enemy) -> bool:
	_sight.from = _npc.global_position + Vector3.UP
	_sight.to = enemy.global_position + Vector3.UP
	return _npc.get_world_3d().direct_space_state.intersect_ray(_sight).is_empty()


func _nearest_player() -> Adventurer:
	var nearest: Adventurer = null
	var nearest_distance := INF
	for player: Adventurer in _npc.get_tree().get_nodes_in_group("players"):
		var distance := player.global_position.distance_to(_npc.global_position)
		if not player.is_dead and distance < nearest_distance:
			nearest = player
			nearest_distance = distance
	return nearest


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
