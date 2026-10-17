class_name Adventurer
extends Character

const DOUBLE_TAP_WINDOW := 0.3
const ATTACK_BUFFER := 0.2
const PITCH_MIN := deg_to_rad(-60.0)
const PITCH_MAX := deg_to_rad(30.0)
const CAMERA_HEIGHT := 1.5
const BASE_MOUSE_SENSITIVITY := 0.003
const BASE_STICK_SPEED := 2.8
const MOVE_DEADZONE := 0.1
const AIM_RANGE := 40.0
const AIM_LAYERS := 1 | 4

@export var camera_follow_speed := 14.0
@export var push_force := 120.0
@export var secondary_attack: Attack
@export var block: BlockAbility

var is_blocking := false

var _is_running := false
var _double_tap_left := 0.0
var _attack_buffer_left := 0.0
var _aim_query := PhysicsRayQueryParameters3D.new()

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D


func _ready() -> void:
	super()
	add_to_group("players")
	_aim_query.collision_mask = AIM_LAYERS
	camera_pivot.global_position = global_position + Vector3.UP * CAMERA_HEIGHT


# a camera e top_level e segue a posicao interpolada, senao treme entre os passos de fisica
func _process(delta: float) -> void:
	var target := get_global_transform_interpolated().origin + Vector3.UP * CAMERA_HEIGHT
	camera_pivot.global_position = camera_pivot.global_position.lerp(target, minf(camera_follow_speed * delta, 1.0))
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look != Vector2.ZERO and not is_dead and _has_control():
		_rotate_camera(look * BASE_STICK_SPEED * Settings.stick_sensitivity * delta)


func _physics_process(delta: float) -> void:
	super(delta)
	_push_bodies(delta)
	if is_blocking:
		_keep_blocking()
	_double_tap_left -= delta
	_attack_buffer_left -= delta
	if _is_running and _read_move_input().length() < MOVE_DEADZONE:
		_is_running = false
	var holding := _has_control() and Input.is_action_pressed("attack")
	if (holding or _attack_buffer_left > 0.0) and attack_toward_camera():
		_attack_buffer_left = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	var has_control := _has_control()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not Settings.uses_gamepad():
		_rotate_camera(event.relative * BASE_MOUSE_SENSITIVITY * Settings.mouse_sensitivity)
	elif event.is_action_pressed("attack") and has_control:
		request_attack()
	elif event.is_action_pressed("secondary") and has_control and not is_blocking:
		use_secondary()
	elif event.is_action_released("secondary"):
		release_secondary()
	elif event.is_action_pressed("move_forward") and not event.is_echo():
		_is_running = _double_tap_left > 0.0
		_double_tap_left = DOUBLE_TAP_WINDOW
	elif event.is_action_released("move_forward"):
		_is_running = false
	elif event.is_action_pressed("run"):
		_is_running = true
	elif event.is_action_pressed("jump"):
		request_jump()


func _push_bodies(delta: float) -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var body := collision.get_collider() as RigidBody3D
		if body:
			var direction := -collision.get_normal().slide(Vector3.UP).normalized()
			body.apply_central_impulse(direction * push_force * delta)


func _has_control() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or Settings.uses_gamepad()


func request_attack() -> void:
	if not attack_toward_camera():
		_attack_buffer_left = ATTACK_BUFFER


func attack_toward_camera() -> bool:
	return _attack_toward_camera(attack)


func use_secondary() -> void:
	if block:
		_start_blocking()
	elif secondary_attack:
		_attack_toward_camera(secondary_attack)


func release_secondary() -> void:
	if is_blocking:
		is_blocking = false
		_end_action()


func _attack_toward_camera(chosen: Attack) -> bool:
	if not chosen or is_blocking or not chosen.can_attack(self):
		return false
	_face_camera()
	return chosen.try_attack(self)


func _start_blocking() -> void:
	if not can_act():
		return
	_face_camera()
	play_action(block.animation, 1.0, block.move_factor)
	is_blocking = true


# apanhar por tras derruba a guarda: a reacao de dano substitui a acao
func _keep_blocking() -> void:
	if animation_player.current_animation != block.animation:
		is_blocking = false
		return
	_face_camera()


func _face_camera() -> void:
	var forward := -camera_pivot.global_basis.z
	model.rotation.y = atan2(forward.x, forward.z) - global_rotation.y


func _blocks(source: Node3D) -> bool:
	return is_blocking and block.covers(self, source)


# o raio comeca depois do personagem para nao bater em algo entre a camera e ele
func get_aim_point() -> Vector3:
	var center := get_viewport().get_visible_rect().size / 2.0
	var origin := camera.project_ray_origin(center)
	var direction := camera.project_ray_normal(center)
	var behind_player := origin.distance_to(camera_pivot.global_position)
	_aim_query.from = origin + direction * behind_player
	_aim_query.to = origin + direction * AIM_RANGE
	var hit := get_world_3d().direct_space_state.intersect_ray(_aim_query)
	return hit.position if hit else _aim_query.to


func _get_move_direction() -> Vector3:
	var input := _read_move_input()
	return camera_pivot.global_basis * Vector3(input.x, 0.0, input.y)


func _read_move_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func _wants_to_run() -> bool:
	return _is_running


func _rotate_camera(amount: Vector2) -> void:
	var vertical := -amount.y if Settings.invert_y else amount.y
	camera_pivot.rotation.y -= amount.x
	spring_arm.rotation.x = clampf(spring_arm.rotation.x - vertical, PITCH_MIN, PITCH_MAX)
