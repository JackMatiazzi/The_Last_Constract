class_name MeleeAttack
extends Attack
## a hitbox atravessa parede, entao cada alvo precisa de linha livre ate o atacante

const WORLD_LAYER := 1
const CHEST_HEIGHT := 1.0
## alcance do golpe pesado contra barris e caixotes, a partir do centro da hitbox
const BREAK_RADIUS := 1.4

var _wall_query := PhysicsRayQueryParameters3D.new()

@onready var hitbox: Area3D = $Hitbox


func _ready() -> void:
	_wall_query.collision_mask = WORLD_LAYER


func _perform(attacker: Character, total_damage: float, heavy: bool) -> void:
	for body in hitbox.get_overlapping_bodies():
		if body is Character and body != attacker and _has_clear_line(attacker, body):
			body.take_damage(total_damage, attacker)
	for area in hitbox.get_overlapping_areas():
		if area is HealthPotion:
			area.shatter()
	if heavy:
		get_tree().call_group(BreakableProps.GROUP, "break_near", _strike_center(), BREAK_RADIUS)


func _has_clear_line(attacker: Character, target: Character) -> bool:
	_wall_query.from = attacker.global_position + Vector3.UP * CHEST_HEIGHT
	_wall_query.to = target.global_position + Vector3.UP * CHEST_HEIGHT
	return get_world_3d().direct_space_state.intersect_ray(_wall_query).is_empty()


# a origem da hitbox fica no atacante; quem esta deslocada para frente e a forma de colisao
func _strike_center() -> Vector3:
	for child in hitbox.get_children():
		if child is CollisionShape3D:
			return child.global_position
	return hitbox.global_position
