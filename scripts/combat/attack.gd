class_name Attack
extends Node3D

@export var damage := 1.0
@export var cooldown := 0.8
@export var animations: PackedStringArray = ["1H_Melee_Attack_Chop"]
@export var combo_window := 0.6
@export var animation_speed := 1.0
@export var impact_delay := 0.4
@export var recovery := 0.12
@export var move_factor := 0.3
@export var sound: AudioStreamPlayer3D

var _ready_at := 0.0
var _combo_index := -1


func can_attack(attacker: Character) -> bool:
	return attacker.can_act() and _now() >= _ready_at


func effective_cooldown(attacker: Character) -> float:
	var factor := 1.0 + attacker.get_stat_bonus(StatModifier.Stat.ATTACK_COOLDOWN)
	return cooldown * maxf(factor, Character.MIN_STAT_FACTOR)


func try_attack(attacker: Character) -> bool:
	if not can_attack(attacker):
		return false
	var continues_combo := _now() - _ready_at <= combo_window
	_combo_index = (_combo_index + 1) % animations.size() if continues_combo else 0
	_ready_at = _now() + effective_cooldown(attacker)
	attacker.play_action(animations[_combo_index], animation_speed, move_factor, impact_delay + recovery)
	var total_damage := maxf(damage + attacker.get_stat_bonus(StatModifier.Stat.DAMAGE), 0.0)
	_impact_after_delay(attacker, attacker.action_id, total_damage)
	return true


func _impact_after_delay(attacker: Character, action: int, total_damage: float) -> void:
	await get_tree().create_timer(impact_delay).timeout
	# action_id diferente: o atacante apanhou (ou fez outra acao) antes do impacto
	if is_instance_valid(attacker) and not attacker.is_dead and attacker.action_id == action:
		if sound:
			sound.play()
		_perform(attacker, total_damage)


func _perform(_attacker: Character, _total_damage: float) -> void:
	pass


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
