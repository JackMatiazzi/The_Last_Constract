class_name Character
extends CharacterBody3D

signal died

const ANIM_IDLE := "Idle"
const ANIM_WALK := "Walking_A"
const ANIM_RUN := "Running_A"
const ANIM_AIR := "Jump_Idle"
const ANIM_HIT := "Hit_A"
const ANIM_DEATH := "Death_A"
const ANIM_BLEND := 0.2

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

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var health: float
var is_dead := false
var is_busy := false

var _coyote_left := 0.0
var _jump_buffer_left := 0.0

@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	health = max_health
	animation_player.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_apply_gravity(delta)
	_try_jump(delta)

	# durante um golpe ou uma reacao o personagem fica parado
	var direction := Vector3.ZERO if is_busy else _get_move_direction()
	var target := direction * get_max_speed()
	var rate := acceleration if direction != Vector3.ZERO else deceleration
	var horizontal := Vector2(velocity.x, velocity.z).move_toward(Vector2(target.x, target.z), rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	if direction != Vector3.ZERO:
		_face(direction, delta)

	move_and_slide()
	_update_animation(direction)


func take_damage(amount: float) -> void:
	if is_dead:
		return
	health = maxf(health - amount, 0.0)
	if health == 0.0:
		die()
	else:
		play_action(ANIM_HIT)


func die() -> void:
	is_dead = true
	collision_shape.set_deferred("disabled", true)
	animation_player.speed_scale = 1.0
	animation_player.play(ANIM_DEATH, ANIM_BLEND)
	died.emit()


func play_action(animation: String, speed := 1.0) -> void:
	is_busy = true
	animation_player.speed_scale = speed
	animation_player.play(animation, ANIM_BLEND)
	animation_player.seek(0.0, true)


func request_jump() -> void:
	_jump_buffer_left = jump_buffer_time


func get_max_speed() -> float:
	return run_speed if _wants_to_run() else walk_speed


func _get_move_direction() -> Vector3:
	return Vector3.ZERO


func _wants_to_run() -> bool:
	return false


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		_coyote_left = coyote_time
		return
	_coyote_left -= delta
	var multiplier := fall_gravity_multiplier if velocity.y < 0.0 else 1.0
	velocity.y -= gravity * multiplier * delta


# pula se apertou ha pouco (buffer) e saiu do chao ha pouco (coyote)
func _try_jump(delta: float) -> void:
	if _jump_buffer_left <= 0.0:
		return
	_jump_buffer_left -= delta
	if _coyote_left > 0.0:
		velocity.y = jump_velocity
		_jump_buffer_left = 0.0
		_coyote_left = 0.0


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
		speed_scale = clampf(Vector2(velocity.x, velocity.z).length() / get_max_speed(), 0.5, 1.2)
	animation_player.speed_scale = speed_scale
	if animation_player.current_animation != animation:
		animation_player.play(animation, ANIM_BLEND)


func _on_animation_finished(_animation: StringName) -> void:
	is_busy = false
