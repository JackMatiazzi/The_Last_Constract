class_name MeleeAttack
extends Node3D

@export var damage := 1.0
@export var cooldown := 0.6
@export var animations := PackedStringArray(["1H_Melee_Attack_Chop"])
@export var animation_speed := 1.0
## Segundos entre o inicio da animacao e o momento em que o golpe acerta.
@export var impact_delay := 0.3
@export var hitbox: Area3D

var _ready_at := 0.0
var _next_animation := 0


func try_attack(attacker: Character) -> bool:
	if attacker.is_dead or attacker.is_busy or _now() < _ready_at:
		return false
	_ready_at = _now() + cooldown
	attacker.play_action(animations[_next_animation], animation_speed)
	_next_animation = (_next_animation + 1) % animations.size()
	_hit_after_delay(attacker)
	return true


func _hit_after_delay(attacker: Character) -> void:
	await get_tree().create_timer(impact_delay).timeout
	if not is_instance_valid(attacker) or attacker.is_dead:
		return
	for body in hitbox.get_overlapping_bodies():
		if body != attacker and body is Character:
			body.take_damage(damage)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
