class_name RangedAttack
extends Attack

@export var projectile_scene: PackedScene
## camadas que o projetil acerta
@export_flags_3d_physics var target_layers := 4

@onready var muzzle: Marker3D = $Muzzle


func _perform(attacker: Character, total_damage: float, heavy: bool) -> void:
	var direction := (attacker.get_aim_point() - muzzle.global_position).normalized()
	if attacker.is_broadcasting():
		_net_fire.rpc(attacker.get_path(), muzzle.global_position, direction, total_damage, heavy)
	_fire(attacker, muzzle.global_position, direction, total_damage, heavy)


func _fire(attacker: Character, origin: Vector3, direction: Vector3, total_damage: float, heavy: bool) -> void:
	var projectile := projectile_scene.instantiate() as Projectile
	attacker.get_parent().add_child(projectile)
	projectile.launch(attacker, origin, direction, total_damage, target_layers)
	projectile.breaks_props = heavy


# o projetil voa em todas as maquinas, mas so o do atirador causa dano
@rpc("any_peer", "reliable")
func _net_fire(attacker_path: NodePath, origin: Vector3, direction: Vector3, total_damage: float, heavy: bool) -> void:
	var attacker := get_node_or_null(attacker_path) as Character
	if attacker == null or multiplayer.get_remote_sender_id() != attacker.get_multiplayer_authority():
		return
	if not (origin.is_finite() and direction.is_finite()) or direction.length() < 0.001 or not Character.is_valid_remote_amount(total_damage):
		return
	_fire(attacker, origin, direction.normalized(), total_damage, heavy)
