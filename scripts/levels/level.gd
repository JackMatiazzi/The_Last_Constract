extends Node3D

const FALL_LIMIT := -10.0

@export var player: Adventurer

@onready var _spawn_point := player.global_position


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(_delta: float) -> void:
	if player.global_position.y < FALL_LIMIT:
		player.global_position = _spawn_point
		player.velocity = Vector3.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
