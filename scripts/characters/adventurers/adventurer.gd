class_name Adventurer
extends Character

const DOUBLE_TAP_WINDOW := 0.3
const PITCH_MIN := deg_to_rad(-60.0)
const PITCH_MAX := deg_to_rad(30.0)
const CAMERA_HEIGHT := 1.5
const MOUSE_SENSITIVITY := 0.003

@export var camera_follow_speed := 14.0
@export var push_force := 120.0
@export var attack: MeleeAttack

var _is_running := false
var _double_tap_left := 0.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D


func _ready() -> void:
	super()
	camera_pivot.global_position = global_position + Vector3.UP * CAMERA_HEIGHT


# a camera e top_level; seguir a posicao interpolada evita tremer entre os quadros de fisica
func _process(delta: float) -> void:
	var target := get_global_transform_interpolated().origin + Vector3.UP * CAMERA_HEIGHT
	camera_pivot.global_position = camera_pivot.global_position.lerp(target, minf(camera_follow_speed * delta, 1.0))


func _physics_process(delta: float) -> void:
	super(delta)
	_double_tap_left -= delta
	_push_bodies(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_camera(event.relative * MOUSE_SENSITIVITY)
	elif event.is_action_pressed("attack") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		attack_toward_camera()
	elif event.is_action_pressed("move_forward") and not event.is_echo():
		_is_running = _double_tap_left > 0.0
		_double_tap_left = DOUBLE_TAP_WINDOW
	elif event.is_action_released("move_forward"):
		_is_running = false
	elif event.is_action_pressed("jump"):
		request_jump()


func attack_toward_camera() -> bool:
	if not attack.try_attack(self):
		return false
	var forward := -camera_pivot.global_basis.z
	model.rotation.y = atan2(forward.x, forward.z) - global_rotation.y
	return true


func _get_move_direction() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return camera_pivot.global_basis * Vector3(input.x, 0.0, input.y)


func _wants_to_run() -> bool:
	return _is_running


# CharacterBody3D nao empurra RigidBody3D sozinho
func _push_bodies(delta: float) -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var body := collision.get_collider() as RigidBody3D
		if body:
			var direction := -collision.get_normal().slide(Vector3.UP).normalized()
			body.apply_central_impulse(direction * push_force * delta)


func _rotate_camera(amount: Vector2) -> void:
	camera_pivot.rotation.y -= amount.x
	spring_arm.rotation.x = clampf(spring_arm.rotation.x - amount.y, PITCH_MIN, PITCH_MAX)
