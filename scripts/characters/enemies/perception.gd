class_name Perception
extends Node3D

const WORLD_LAYER := 1
const EYE_HEIGHT := 1.4
const CHEST_HEIGHT := 1.0

var enemy: Enemy
var target: Character
var can_see := false
var last_known_position := Vector3.ZERO
var time_since_aware := INF
# desligada deitado: so proximidade, barulho e dano acordam
var sight_enabled := true

var _sight_query := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	enemy = get_parent() as Enemy
	_sight_query.collision_mask = WORLD_LAYER


func sense(delta: float) -> void:
	acquire_target()
	time_since_aware += delta
	can_see = sight_enabled and target != null and _sees(target)
	if can_see or (target != null and (_hears(target) or _feels_close(target))):
		_mark_aware()


func is_aware() -> bool:
	return time_since_aware <= enemy.profile.memory_time


func distance_to_target() -> float:
	if target == null:
		return INF
	return (target.global_position - enemy.global_position).slide(Vector3.UP).length()


func force_awareness(new_target: Character) -> void:
	target = new_target
	_mark_aware()


func _mark_aware() -> void:
	last_known_position = target.global_position
	time_since_aware = 0.0


func acquire_target() -> void:
	if target == null or not is_instance_valid(target) or target.is_dead:
		target = _nearest_living_player()


func _nearest_living_player() -> Character:
	var nearest: Character = null
	var nearest_distance := INF
	for player: Character in get_tree().get_nodes_in_group("players"):
		var distance := player.global_position.distance_squared_to(enemy.global_position)
		if not player.is_dead and distance < nearest_distance:
			nearest = player
			nearest_distance = distance
	return nearest


func _sees(candidate: Character) -> bool:
	var to_target := (candidate.global_position - enemy.global_position).slide(Vector3.UP)
	var distance := to_target.length()
	if distance > enemy.profile.sight_range:
		return false
	var forward := enemy.model.global_basis.z.slide(Vector3.UP)
	if distance > 0.01 and rad_to_deg(forward.angle_to(to_target)) > enemy.profile.sight_angle * 0.5:
		return false
	return _has_clear_line(candidate)


func _feels_close(candidate: Character) -> bool:
	return distance_to_target() <= enemy.profile.proximity_range and _has_clear_line(candidate)


func _has_clear_line(candidate: Character) -> bool:
	_sight_query.from = enemy.global_position + Vector3.UP * EYE_HEIGHT
	_sight_query.to = candidate.global_position + Vector3.UP * CHEST_HEIGHT
	return get_world_3d().direct_space_state.intersect_ray(_sight_query).is_empty()


func _hears(candidate: Character) -> bool:
	var distance := distance_to_target()
	return distance <= enemy.profile.hearing_range and candidate.is_making_noise()

