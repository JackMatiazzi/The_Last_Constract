class_name Chaser
extends Character
## quem nao usa o cerebro dos mortos-vivos mas, quando entra na briga, persegue o aventureiro mais perto e
## golpeia ao alcancar. So o host decide

## Golpeia o alvo a esta distancia (para um pouco antes, a 80%).
@export var strike_range := 1.9
## Alvo mais longe que isso e trocado pelo aventureiro mais perto.
@export var chase_range := 30.0

var _target: Adventurer


func is_hunting() -> bool:
	return false


func _physics_process(delta: float) -> void:
	if is_multiplayer_authority() and is_hunting() and not is_dead:
		_hunt()
	super(delta)


func _hunt() -> void:
	if _target == null or _target.is_dead or _target.global_position.distance_to(global_position) > chase_range:
		_target = _nearest_player()
	if _target and _target.global_position.distance_to(global_position) <= strike_range:
		_look_toward(_target.global_position)
		attack.try_attack(self)


func _nearest_player() -> Adventurer:
	var nearest: Adventurer = null
	var nearest_distance := chase_range
	for player: Adventurer in get_tree().get_nodes_in_group("players"):
		var distance := player.global_position.distance_to(global_position)
		if not player.is_dead and distance < nearest_distance:
			nearest = player
			nearest_distance = distance
	return nearest


func _get_move_direction() -> Vector3:
	if not is_hunting() or _target == null or _target.global_position.distance_to(global_position) <= strike_range * 0.8:
		return Vector3.ZERO
	return (_target.global_position - global_position).slide(Vector3.UP).normalized()


func _look_toward(point: Vector3) -> void:
	var to := (point - global_position).slide(Vector3.UP)
	if to.length() > 0.01:
		model.rotation.y = atan2(to.x, to.z) - global_rotation.y
