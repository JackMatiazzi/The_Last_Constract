class_name Attack
extends Node3D

const HEAVY_FALLBACK_SLOWDOWN := 0.7

@export var title := ""
@export var icon: Texture2D
## custo proprio da habilidade (rapido e pesado); negativo = usa o custo do aventureiro
@export var cost_override := -1.0
@export var damage := 1.0
## tempo minimo entre dois golpes
@export var cooldown := 0.8
## uma por golpe do combo, em ordem
@export var animations: PackedStringArray = ["1H_Melee_Attack_Chop"]
## depois da recarga, tempo para o golpe seguinte continuar o combo
@export var combo_window := 0.6
@export var animation_speed := 1.0
## do inicio do golpe ate o acerto
@export var impact_delay := 0.4
## depois do acerto, tempo ate andar cancelar a animacao
@export var recovery := 0.12
## fracao da velocidade enquanto golpeia
@export var move_factor := 0.3
@export var sound: AudioStreamPlayer3D

## segurar o botao: golpe mais lento e mais forte; vazio usa a animacao do combo mais devagar
@export_group("Pesado")
@export var heavy_animation := ""
## 0 usa a velocidade do rapido, mais devagar
@export var heavy_animation_speed := 0.0
## 0 usa o tempo do rapido, mais devagar
@export var heavy_impact_delay := 0.0
## dano do pesado em relacao ao rapido
@export var heavy_damage_multiplier := 2.0
## recarga do pesado em relacao ao rapido
@export var heavy_cooldown_multiplier := 1.5

var _ready_at := 0.0
var _combo_index := -1


func can_attack(attacker: Character) -> bool:
	return attacker.can_act() and _now() >= _ready_at


func effective_cooldown(attacker: Character) -> float:
	var factor := 1.0 + attacker.get_stat_bonus(StatModifier.Stat.ATTACK_COOLDOWN)
	return cooldown * maxf(factor, Character.MIN_STAT_FACTOR)


func try_attack(attacker: Character, heavy := false) -> bool:
	if not can_attack(attacker):
		return false
	var continues_combo := not heavy and _now() - _ready_at <= combo_window
	_combo_index = (_combo_index + 1) % animations.size() if continues_combo else 0
	_ready_at = _now() + effective_cooldown(attacker) * (heavy_cooldown_multiplier if heavy else 1.0)
	var animation := animations[_combo_index]
	var speed := animation_speed
	var delay := impact_delay
	if heavy:
		animation = heavy_animation if not heavy_animation.is_empty() else animation
		speed = heavy_animation_speed if heavy_animation_speed > 0.0 else animation_speed * HEAVY_FALLBACK_SLOWDOWN
		delay = heavy_impact_delay if heavy_impact_delay > 0.0 else impact_delay / HEAVY_FALLBACK_SLOWDOWN
	attacker.play_action(animation, speed, move_factor, delay + recovery)
	_impact_after_delay(attacker, attacker.action_id, _damage_for(attacker, heavy), delay, heavy)
	return true


func _damage_for(attacker: Character, heavy: bool) -> float:
	var total := maxf(damage + attacker.get_stat_bonus(StatModifier.Stat.DAMAGE), 0.0)
	return total * heavy_damage_multiplier if heavy else total


func _impact_after_delay(attacker: Character, action: int, total_damage: float, delay: float, heavy: bool) -> void:
	await get_tree().create_timer(delay).timeout
	# action_id diferente: o atacante apanhou (ou fez outra acao) antes do impacto
	if is_instance_valid(attacker) and not attacker.is_dead and attacker.action_id == action:
		if sound:
			sound.play()
		_perform(attacker, total_damage, heavy)


func _perform(_attacker: Character, _total_damage: float, _heavy: bool) -> void:
	pass


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
