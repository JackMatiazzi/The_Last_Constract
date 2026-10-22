class_name PortalSpell
extends Attack

# o primeiro uso abre a entrada onde a mira aponta, o segundo abre a saida;
# um par novo fecha o anterior

const MAX_DISTANCE := 15.0
const GROUND_PROBE := 4.0
const WORLD_LAYER := 1

@export var portal_scene: PackedScene

var _entry: Portal
var _pair: Array[Portal] = []
var _ground_query := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	_ground_query.collision_mask = WORLD_LAYER


func _perform(attacker: Character, _total_damage: float, _heavy: bool) -> void:
	var spot: Variant = _ground_spot(attacker)
	if spot == null:
		return
	var facing := ((spot as Vector3) - attacker.global_position).slide(Vector3.UP).normalized()
	if attacker.is_broadcasting():
		_net_open.rpc(attacker.get_path(), spot, facing)
	_open(attacker, spot, facing)


func _open(attacker: Character, spot: Vector3, facing: Vector3) -> void:
	var portal := portal_scene.instantiate() as Portal
	attacker.get_parent().add_child(portal)
	portal.global_position = spot
	if facing.length() > 0.01:
		portal.look_at(spot + facing)
	if _entry == null or not is_instance_valid(_entry):
		_close_pair()
		_entry = portal
	else:
		_entry.link = portal
		portal.link = _entry
		_entry = null
	_pair.append(portal)


func _close_pair() -> void:
	for portal in _pair:
		if is_instance_valid(portal):
			portal.queue_free()
	_pair.clear()


# a mira pode bater em parede ou no ar: desce de cima do ponto ate achar o chao
func _ground_spot(attacker: Character) -> Variant:
	var target := attacker.get_aim_point()
	var flat := (target - attacker.global_position).slide(Vector3.UP)
	if flat.length() > MAX_DISTANCE:
		target = attacker.global_position + flat.normalized() * MAX_DISTANCE
	_ground_query.from = target + Vector3.UP * GROUND_PROBE
	_ground_query.to = target + Vector3.DOWN * GROUND_PROBE * 2.0
	var hit := attacker.get_world_3d().direct_space_state.intersect_ray(_ground_query)
	return hit.position if hit else null


@rpc("any_peer", "reliable")
func _net_open(attacker_path: NodePath, spot: Vector3, facing: Vector3) -> void:
	var attacker := get_node_or_null(attacker_path) as Character
	if attacker == null or multiplayer.get_remote_sender_id() != attacker.get_multiplayer_authority():
		return
	if spot.is_finite() and facing.is_finite():
		_open(attacker, spot, facing)
