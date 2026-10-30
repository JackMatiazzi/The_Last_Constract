class_name Character
extends CharacterBody3D
## Classe base para todas as entidades combatentes no mundo 3D (Aventureiros e Inimigos).
## Gerencia vida, movimento, aplicação de dano/cura, sistema de ações e animações,
## efeitos sonoros de passos/impacto, acúmulo de buffs e sincronização de rede em tempo real.
signal health_changed(current: float, maximum: float)
signal died
signal revived
signal blocked

const ANIM_IDLE := "Idle"
const ANIM_WALK := "Walking_A"
const ANIM_RUN := "Running_A"
const ANIM_AIR := "Jump_Idle"
const ANIM_HIT := "Hit_A"
const ANIM_DEATH := "Death_A"
const ANIM_BLEND := 0.2
const HIT_RECOVERY := 0.3
const MIN_STAT_FACTOR := 0.2
# em rede so quem tem autoridade simula; as outras maquinas seguem o estado enviado
const NET_SEND_INTERVAL := 0.05
const NET_FOLLOW_SPEED := 15.0
# pulo maior que isso (portal, reviver longe) aparece de uma vez, sem deslizar pelo mapa
const NET_SNAP_DISTANCE := 4.0
# teto para dano e cura vindos de outra maquina: o golpe mais forte do jogo (pesado do mago com
# bencaos) fica perto de 10, e a vida de reviver e metade da vida maxima
const MAX_REMOTE_AMOUNT := 20.0
# a seta vai ate 24 m e o atirador ainda anda enquanto ela voa
const REMOTE_HIT_REACH := 35.0
# o reviver chega pela rede com a posicao um pouco atrasada
const REMOTE_REACH_SLACK := 1.5

@export var max_health := 10.0
@export var walk_speed := 4.0
@export var run_speed := 7.5
@export var acceleration := 45.0
@export var deceleration := 55.0
@export var turn_speed := 18.0
@export var fall_gravity_multiplier := 1.8
@export var model: Node3D
@export var animation_player: AnimationPlayer
@export var attack: Attack

@export_group("Sons")
@export var footstep_sound: AudioStreamPlayer3D
@export var hurt_sound: AudioStreamPlayer3D
@export var death_sound: AudioStreamPlayer3D
@export var block_sound: AudioStreamPlayer3D
@export var step_length := 1.7

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var health: float
var is_dead := false
var is_busy := false
# muda a cada acao; o golpe compara para saber se foi interrompido
var action_id := 0
var active_buffs: Array[Buff] = []
var damage_log := DamageLog.new()
# o host conta cada queda uma vez so, mesmo que o relato chegue repetido
var fall_counted := false

var _action_time := 0.0
var _action_cancel_after := INF
var _action_move_factor := 0.0
var _holding_pose := false
var _stride := 0.0
var _net_send_left := 0.0
var _net_position := Vector3.ZERO
var _net_yaw := 0.0
var _net_on_floor := true

@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	assert(model and animation_player, "%s: aponte model e animation_player no Inspector" % name)
	active_buffs.assign(RunState.buffs)
	health = get_max_health()
	health_changed.emit(health, get_max_health())
	animation_player.animation_finished.connect(_on_animation_finished)
	_net_position = global_position
	_net_yaw = model.rotation.y


func _physics_process(delta: float) -> void:
	# Máquinas sem autoridade multiplayer apenas interpolam a posição/animação recebidas pela rede
	if not is_multiplayer_authority():
		_follow_network(delta)
		return
	if is_dead:
		return
	if is_busy:
		_action_time += delta
	_apply_gravity(delta)

	var wish := _get_move_direction()
	# Cancela a ação atual caso o jogador tente se mover após o tempo de cancelamento
	if is_busy and wish != Vector3.ZERO and is_action_cancelable():
		_end_action()
	var direction := wish * (_action_move_factor if is_busy else 1.0)
	var target := direction * get_max_speed()
	var rate := acceleration if direction != Vector3.ZERO else deceleration
	var horizontal := Vector2(velocity.x, velocity.z).move_toward(Vector2(target.x, target.z), rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	if direction != Vector3.ZERO and not is_busy:
		_face(direction, delta)

	move_and_slide()
	_update_animation(direction)
	_count_steps(delta)
	_send_network_state(delta)

## Retorna true se a entidade não estiver morta e puder iniciar uma nova ação.
func can_act() -> bool:
	return not is_dead and (not is_busy or is_action_cancelable())

## Retorna true se a ação atual já ultrapassou a janela mínima para poder ser cancelada.
func is_action_cancelable() -> bool:
	return is_busy and _action_time >= _action_cancel_after

## Aplica dano ao personagem. Trata envio por RPC se a chamada vier de um cliente sem autoridade.
func take_damage(amount: float, source: Node3D = null) -> void:
	if is_dead:
		return
	# Se a máquina atual não tem autoridade sobre o personagem, envia pedido para o dono do nó
	if not is_multiplayer_authority():
		_request_damage.rpc_id(get_multiplayer_authority(), amount, source.get_path() if source else NodePath())
		return
	# Verifica se o ataque foi bloqueado pela frente ou por habilidade de defesa
	if source and _blocks(source):
		_play(block_sound)
		blocked.emit()
		return
	_note_attacker(source, minf(amount, health))
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, get_max_health())
	_share_health()
	if health == 0.0:
		die()
		return
	_play(hurt_sound)
	if _can_flinch():
		play_action(ANIM_HIT, 1.0, 0.0, HIT_RECOVERY)

## Restaura pontos de vida do personagem até o limite máximo permitido.
func heal(amount: float) -> void:
	if is_dead:
		return
	if not is_multiplayer_authority():
		return
	var restored := minf(amount, get_max_health() - health)
	if restored > 0.0:
		damage_log.note_heal(restored)
	health = minf(health + amount, get_max_health())
	health_changed.emit(health, get_max_health())
	_share_health()

## Inicia o processo de morte da entidade e notifica os clientes e o RunState.
func die() -> void:
	if is_broadcasting():
		_net_die.rpc()
	_die_locally()
	if is_multiplayer_authority():
		RunState.record_death(self)

## Retorna o nome formatado da entidade para relatórios de combate.
func get_display_name() -> String:
	return name

## Registra o atacante e a causa da morte no relatório individual de danos (DamageLog).
func _note_attacker(source: Node3D, amount: float) -> void:
	var attacker := source as Character
	if attacker == null or attacker == self:
		damage_log.note_hit(DamageLog.UNKNOWN_CAUSE, amount)
		return
	var attacker_name := attacker.get_display_name()
	var is_player := attacker is Adventurer
	var cause := "Fogo amigo de %s" % attacker_name if is_player and self is Adventurer else attacker_name
	damage_log.note_hit(cause, amount, attacker_name, attacker.get_multiplayer_authority() if is_player else 0)

## Retorna a recapitulação formatada de quem causou dano antes da morte.
func damage_recap() -> String:
	return damage_log.recap(get_max_health(), is_dead)

## Executa as alterações de física, colisão e animação necessárias na máquina local ao morrer.
func _die_locally() -> void:
	is_dead = true
	collision_shape.set_deferred("disabled", true)
	animation_player.speed_scale = 1.0
	animation_player.play(ANIM_DEATH, ANIM_BLEND)
	_play(death_sound)
	died.emit()

## Restaura a entidade da morte atribuindo a vida informada.
func revive(amount: float) -> void:
	if not is_dead:
		return
	if not is_multiplayer_authority():
		_request_revive.rpc_id(get_multiplayer_authority(), amount)
		return
	if is_broadcasting():
		_net_revive.rpc(amount)
	_revive_locally(amount)

## Restaura as colisões e a animação inicial do personagem re-erguido.
func _revive_locally(amount: float) -> void:
	damage_log.clear()
	fall_counted = false
	is_dead = false
	collision_shape.set_deferred("disabled", false)
	health = clampf(amount, 1.0, get_max_health())
	health_changed.emit(health, get_max_health())
	_end_action_locally()
	animation_player.play(ANIM_IDLE, ANIM_BLEND)
	revived.emit()

## Executa uma animação de ação (ataque, dor, etc) com controle de velocidade, velocidade de passos e cancelamento.
func play_action(animation: String, speed := 1.0, move_factor := 0.0, cancel_after := INF) -> void:
	if is_broadcasting():
		_net_play_action.rpc(animation, speed, move_factor, cancel_after)
	_play_action_locally(animation, speed, move_factor, cancel_after)


func _play_action_locally(animation: String, speed: float, move_factor: float, cancel_after: float) -> void:
	_begin_action(move_factor, cancel_after, false)
	animation_player.speed_scale = speed
	animation_player.play(animation, ANIM_BLEND)
	animation_player.seek(0.0, true)

## Trava o personagem em uma pose específica mantendo o estado ocupado.
func hold_pose(animation: String) -> void:
	if is_broadcasting():
		_net_hold_pose.rpc(animation)
	_hold_pose_locally(animation)


# marca antes de tocar: animacao de pose dura zero e encerraria a acao na hora
func _hold_pose_locally(animation: String) -> void:
	_begin_action(0.0, INF, true)
	animation_player.speed_scale = 1.0
	animation_player.play(animation, ANIM_BLEND)

## Retorna se o personagem está se movendo em alta velocidade ou executando uma ação ruidosa.
func is_making_noise() -> bool:
	var speed := Vector2(velocity.x, velocity.z).length()
	return speed > walk_speed + 0.5 or (is_busy and not _holding_pose)

## Retorna true se o modelo 3D estiver virado na direção do ponto com a tolerância informada.
func is_facing(point: Vector3, tolerance_degrees: float) -> bool:
	var forward := model.global_basis.z.slide(Vector3.UP)
	var to_point := (point - global_position).slide(Vector3.UP)
	return to_point.length() < 0.01 or rad_to_deg(forward.angle_to(to_point)) <= tolerance_degrees

## Calcula a soma total dos bônus de um determinado atributo fornecidos pelos buffs ativos.
func get_stat_bonus(stat: StatModifier.Stat) -> float:
	var total := 0.0
	for buff in active_buffs:
		for modifier in buff.modifiers:
			if modifier.stat == stat:
				total += modifier.amount
	return total

## Retorna a vida máxima calculada já com os modificadores dos buffs aplicados.
func get_max_health() -> float:
	return maxf(max_health + get_stat_bonus(StatModifier.Stat.MAX_HEALTH), 1.0)

## Retorna o ponto no mundo 3D para onde a mira/frente do personagem aponta.
func get_aim_point() -> Vector3:
	return global_position + Vector3.UP + model.global_basis.z.normalized() * 30.0

## Retorna a velocidade máxima de movimento considerando corrida, caminhada e os buffs de velocidade.
func get_max_speed() -> float:
	var base := run_speed if wants_to_run() else walk_speed
	return base * maxf(1.0 + get_stat_bonus(StatModifier.Stat.SPEED), MIN_STAT_FACTOR)

## Método virtual a ser sobrescrito por subclasses para determinar a intenção de movimento.
func _get_move_direction() -> Vector3:
	return Vector3.ZERO

## Método virtual a ser sobrescrito para indicar intenção de corrida.
func wants_to_run() -> bool:
	return false

## Método virtual a ser sobrescrito para indicar se o personagem reage com flinch a ataques.
func _can_flinch() -> bool:
	return true

## Método virtual a ser sobrescrito para verificar mecânicas de defesa/escudo.
func _blocks(_source: Node3D) -> bool:
	return false


func _begin_action(move_factor: float, cancel_after: float, holding: bool) -> void:
	is_busy = true
	_holding_pose = holding
	action_id += 1
	_action_time = 0.0
	_action_cancel_after = cancel_after
	_action_move_factor = move_factor


func _end_action() -> void:
	if is_broadcasting():
		_net_end_action.rpc()
	_end_action_locally()


func _end_action_locally() -> void:
	is_busy = false
	_holding_pose = false
	action_id += 1


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * fall_gravity_multiplier * delta

## Contabiliza a distância percorrida e toca o som de passos a cada intervalo configurado.
func _count_steps(delta: float) -> void:
	if not is_grounded():
		return
	_stride += Vector2(velocity.x, velocity.z).length() * delta
	if _stride >= step_length:
		_stride = 0.0
		_play(footstep_sound)


func _play(sound: AudioStreamPlayer3D) -> void:
	if sound:
		sound.play()


# gira so o modelo; girar o corpo arrastaria a camera junto
# desconta o giro do corpo, que pode vir de um pai girado (grupo de inimigos)
func _face(direction: Vector3, delta: float) -> void:
	var target_yaw := atan2(direction.x, direction.z) - global_rotation.y
	model.rotation.y = lerp_angle(model.rotation.y, target_yaw, turn_speed * delta)

## Gerencia as transições básicas das animações de caminhada, corrida, salto e repouso.
func _update_animation(direction: Vector3) -> void:
	if is_busy:
		return
	if not is_grounded():
		play_locomotion(ANIM_AIR)
	elif direction != Vector3.ZERO:
		play_locomotion(ANIM_RUN if is_running_now() else ANIM_WALK, stride_speed_scale())
	else:
		play_locomotion(ANIM_IDLE)


func play_locomotion(animation: String, speed_scale := 1.0) -> void:
	animation_player.speed_scale = speed_scale
	if animation_player.current_animation != animation:
		animation_player.play(animation, ANIM_BLEND)


# a passada acompanha a velocidade real para o pe nao deslizar na arrancada
func stride_speed_scale() -> float:
	return clampf(Vector2(velocity.x, velocity.z).length() / get_max_speed(), 0.5, 1.2)


func _on_animation_finished(_animation: StringName) -> void:
	if is_busy and not _holding_pose:
		_end_action()

## Retorna true se a entidade estiver tocando o chão (localmente ou via confirmação de rede).
func is_grounded() -> bool:
	return is_on_floor() if is_multiplayer_authority() else _net_on_floor

## Retorna true se a entidade estiver atualmente se movendo em ritmo de corrida.
func is_running_now() -> bool:
	if is_multiplayer_authority():
		return wants_to_run()
	return Vector2(velocity.x, velocity.z).length() > walk_speed + 0.5

## Retorna true se este nó deve propagar chamadas RPC de rede no momento.
func is_broadcasting() -> bool:
	return Net.is_online() and not Net.waiting_for_peers and is_multiplayer_authority() and is_inside_tree()

## Envia os dados de transform e movimento física para as outras máquinas na rede.
func _send_network_state(delta: float) -> void:
	if not Net.is_online() or Net.waiting_for_peers:
		return
	_net_send_left -= delta
	if _net_send_left > 0.0:
		return
	_net_send_left = NET_SEND_INTERVAL
	_net_state.rpc(global_position, model.rotation.y, velocity, is_on_floor())


# o corpo morto fica onde caiu; o sumico do cadaver roda em cada maquina
func _follow_network(delta: float) -> void:
	if is_dead:
		return
	var weight := minf(NET_FOLLOW_SPEED * delta, 1.0)
	global_position = global_position.lerp(_net_position, weight)
	model.rotation.y = lerp_angle(model.rotation.y, _net_yaw, weight)
	var direction := Vector3(velocity.x, 0.0, velocity.z)
	_update_animation(direction if direction.length() > 0.1 else Vector3.ZERO)
	_count_steps(delta)

## RPC de física não confiável (unreliable_ordered) com os dados de posição e rotação.
@rpc("authority", "unreliable_ordered")
func _net_state(position_now: Vector3, yaw: float, velocity_now: Vector3, on_floor: bool) -> void:
	if not (position_now.is_finite() and is_finite(yaw) and velocity_now.is_finite()):
		return
	_net_position = position_now
	if global_position.distance_to(position_now) > NET_SNAP_DISTANCE:
		global_position = position_now
		reset_physics_interpolation()
	_net_yaw = yaw
	velocity = velocity_now
	_net_on_floor = on_floor

## Valida se o valor numérico vindo pela rede é válido e está dentro do intervalo seguro.
static func is_valid_remote_amount(amount: float) -> bool:
	return is_finite(amount) and amount >= 0.0 and amount <= MAX_REMOTE_AMOUNT


# so quem controla o atacante pode dizer que ele acertou, e de uma distancia que um ataque alcanca;
# golpe sem atacante so vem do host
func accepts_hit_from(sender: int, source: Node3D) -> bool:
	var attacker := source as Character
	if attacker == null:
		return sender == MultiplayerPeer.TARGET_PEER_SERVER
	if attacker.get_multiplayer_authority() != sender or attacker.global_position.distance_to(global_position) > REMOTE_HIT_REACH:
		return false
	return Net.friendly_fire or not (attacker is Adventurer and self is Adventurer)

## Valida se a solicitação remota de reviver é feita por um jogador próximo.
func accepts_revive_from(sender: int) -> bool:
	return is_dead and Adventurer.peer_can_reach(get_tree(), sender, global_position, Adventurer.REVIVE_RANGE + REMOTE_REACH_SLACK)

## RPC recebido para processar solicitação de dano enviada por outra máquina.
@rpc("any_peer", "reliable")
func _request_damage(amount: float, source_path: NodePath) -> void:
	var source := get_node_or_null(source_path) as Node3D if not source_path.is_empty() else null
	if is_valid_remote_amount(amount) and accepts_hit_from(multiplayer.get_remote_sender_id(), source):
		take_damage(amount, source)

## RPC recebido para processar solicitação de reviver enviada por um aliado.
@rpc("any_peer", "reliable")
func _request_revive(amount: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if is_valid_remote_amount(amount) and accepts_revive_from(sender):
		revive(amount)
		_net_revive_confirmed.rpc_id(sender)


# so agora quem reviveu gasta a pocao
@rpc("authority", "reliable")
func _net_revive_confirmed() -> void:
	var reviver := Adventurer.of_peer(get_tree(), multiplayer.get_unique_id())
	if reviver:
		reviver.spend_revive_item()


func _share_health() -> void:
	if is_broadcasting():
		_net_health.rpc(health)


@rpc("authority", "reliable")
func _net_health(value: float) -> void:
	if value < health:
		_play(hurt_sound)
	health = value
	health_changed.emit(health, get_max_health())


@rpc("authority", "reliable")
func _net_die() -> void:
	if not is_dead:
		_die_locally()


@rpc("authority", "reliable")
func _net_revive(amount: float) -> void:
	_revive_locally(amount)


@rpc("authority", "reliable")
func _net_play_action(animation: String, speed: float, move_factor: float, cancel_after: float) -> void:
	_play_action_locally(animation, speed, move_factor, cancel_after)


@rpc("authority", "reliable")
func _net_hold_pose(animation: String) -> void:
	_hold_pose_locally(animation)


@rpc("authority", "reliable")
func _net_end_action() -> void:
	_end_action_locally()
