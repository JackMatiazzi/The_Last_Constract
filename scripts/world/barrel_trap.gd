class_name BarrelTrap
extends Node3D
## subir a escada solta um barril la de cima, que desce rolando pela rampa. Cada maquina solta o proprio
## barril quando ve o aventureiro pisar no gatilho; o dano do barril e decidido pelo host

@export var barrel_scene: PackedScene
## Pisar aqui solta o barril.
@export var trigger: Area3D
## De onde o barril sai.
@export var spawn: Marker3D
@export var release_sound: AudioStreamPlayer3D
## Velocidade com que o barril sai rolando.
@export var push_speed := 3.0
## giro em torno do eixo do barril, para ele ja sair rolando
@export var spin := 6.0
@export var reload_time := 4.0

var _ready_at := 0.0


func _ready() -> void:
	assert(barrel_scene and trigger and spawn and release_sound, "BarrelTrap: aponte os nos exportados")
	trigger.body_entered.connect(_on_stepped)


func get_display_name() -> String:
	return "Barril rolando"


func _on_stepped(body: Node3D) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if not body is Adventurer or now < _ready_at:
		return
	_ready_at = now + reload_time
	release()


func release() -> RollingBarrel:
	var barrel := barrel_scene.instantiate() as RollingBarrel
	barrel.cause = self
	get_parent().add_child(barrel)
	barrel.global_transform = spawn.global_transform
	var downhill := -spawn.global_basis.z
	barrel.linear_velocity = downhill * push_speed
	barrel.angular_velocity = spawn.global_basis.x * -spin
	release_sound.play()
	return barrel
