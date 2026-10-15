class_name Character
extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal died
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

@export var max_health := 10.0
@export var walk_speed := 4.0
@export var run_speed := 7.5
@export var acceleration := 45.0
@export var deceleration := 55.0
@export var turn_speed := 18.0
@export var jump_velocity := 7.0
@export var fall_gravity_multiplier := 1.8
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.12
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

var _action_time := 0.0
var _action_cancel_after := INF
var _action_move_factor := 0.0
var _holding_pose := false
var _coyote_left := 0.0
var _jump_buffer_left := 0.0
var _stride := 0.0

@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	assert(model and animation_player, "%s: aponte model e animation_player no Inspector" % name)
	active_buffs.assign(RunState.buffs)
	health = get_max_health()
	health_changed.emit(health, get_max_health())
	animation_player.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if is_busy:
		_action_time += delta
	_apply_gravity(delta)
	_try_buffered_jump(delta)

	var wish := _get_move_direction()
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


func request_jump() -> void:
	_jump_buffer_left = jump_buffer_time


func can_act() -> bool:
	return not is_dead and (not is_busy or is_action_cancelable())


func is_action_cancelable() -> bool:
	return is_busy and _action_time >= _action_cancel_after


func take_damage(amount: float, source: Node3D = null) -> void:
	if is_dead:
		return
	if source and _blocks(source):
		_play(block_sound)
		blocked.emit()
		return
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, get_max_health())
	if health == 0.0:
		die()
		return
	_play(hurt_sound)
	if _can_flinch():
		play_action(ANIM_HIT, 1.0, 0.0, HIT_RECOVERY)


func heal(amount: float) -> void:
	if is_dead:
		return
	health = minf(health + amount, get_max_health())
	health_changed.emit(health, get_max_health())


func die() -> void:
	is_dead = true
	collision_shape.set_deferred("disabled", true)
	animation_player.speed_scale = 1.0
	animation_player.play(ANIM_DEATH, ANIM_BLEND)
	_play(death_sound)
	died.emit()


func play_action(animation: String, speed := 1.0, move_factor := 0.0, cancel_after := INF) -> void:
	_begin_action(move_factor, cancel_after, false)
	animation_player.speed_scale = speed
	animation_player.play(animation, ANIM_BLEND)
	animation_player.seek(0.0, true)


# marca antes de tocar: animacao de pose dura zero e encerraria a acao na hora
func hold_pose(animation: String) -> void:
	_begin_action(0.0, INF, true)
	animation_player.speed_scale = 1.0
	animation_player.play(animation, ANIM_BLEND)


func is_making_noise() -> bool:
	var speed := Vector2(velocity.x, velocity.z).length()
	return speed > walk_speed + 0.5 or (is_busy and not _holding_pose)


func is_facing(point: Vector3, tolerance_degrees: float) -> bool:
	var forward := model.global_basis.z.slide(Vector3.UP)
	var to_point := (point - global_position).slide(Vector3.UP)
	return to_point.length() < 0.01 or rad_to_deg(forward.angle_to(to_point)) <= tolerance_degrees


func get_stat_bonus(stat: StatModifier.Stat) -> float:
	var total := 0.0
	for buff in active_buffs:
		for modifier in buff.modifiers:
			if modifier.stat == stat:
				total += modifier.amount
	return total


func get_max_health() -> float:
	return maxf(max_health + get_stat_bonus(StatModifier.Stat.MAX_HEALTH), 1.0)


func get_aim_point() -> Vector3:
	return global_position + Vector3.UP + model.global_basis.z.normalized() * 30.0


func get_max_speed() -> float:
	var base := run_speed if _wants_to_run() else walk_speed
	return base * maxf(1.0 + get_stat_bonus(StatModifier.Stat.SPEED), MIN_STAT_FACTOR)


func _get_move_direction() -> Vector3:
	return Vector3.ZERO


func _wants_to_run() -> bool:
	return false


func _can_flinch() -> bool:
	return true


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
	is_busy = false
	_holding_pose = false
	action_id += 1


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		_coyote_left = coyote_time
		return
	_coyote_left -= delta
	var multiplier := fall_gravity_multiplier if velocity.y < 0.0 else 1.0
	velocity.y -= gravity * multiplier * delta


func _try_buffered_jump(delta: float) -> void:
	if _jump_buffer_left <= 0.0:
		return
	_jump_buffer_left -= delta
	if _coyote_left > 0.0 and can_act():
		if is_busy:
			_end_action()
		velocity.y = jump_velocity
		_jump_buffer_left = 0.0
		_coyote_left = 0.0


func _count_steps(delta: float) -> void:
	if not is_on_floor():
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


func _update_animation(direction: Vector3) -> void:
	if is_busy:
		return
	var animation := ANIM_IDLE
	var speed_scale := 1.0
	if not is_on_floor():
		animation = ANIM_AIR
	elif direction != Vector3.ZERO:
		animation = ANIM_RUN if _wants_to_run() else ANIM_WALK
		# a passada acompanha a velocidade real para o pe nao deslizar na arrancada
		speed_scale = clampf(Vector2(velocity.x, velocity.z).length() / get_max_speed(), 0.5, 1.2)
	animation_player.speed_scale = speed_scale
	if animation_player.current_animation != animation:
		animation_player.play(animation, ANIM_BLEND)


func _on_animation_finished(_animation: StringName) -> void:
	if is_busy and not _holding_pose:
		_end_action()
