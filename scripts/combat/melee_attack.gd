class_name MeleeAttack
extends Attack

# a hitbox atravessa parede, entao cada alvo precisa de linha livre ate o atacante

const WORLD_LAYER := 1
const CHEST_HEIGHT := 1.0

var _wall_query := PhysicsRayQueryParameters3D.new()

@onready var hitbox: Area3D = $Hitbox


func _ready() -> void:
	_wall_query.collision_mask = WORLD_LAYER


func _perform(attacker: Character, total_damage: float) -> void:
	for body in hitbox.get_overlapping_bodies():
		if body is Character and body != attacker and _has_clear_line(attacker, body):
			body.take_damage(total_damage, attacker)


func _has_clear_line(attacker: Character, target: Character) -> bool:
	_wall_query.from = attacker.global_position + Vector3.UP * CHEST_HEIGHT
	_wall_query.to = target.global_position + Vector3.UP * CHEST_HEIGHT
	return get_world_3d().direct_space_state.intersect_ray(_wall_query).is_empty()
