class_name DartTrap
extends Node3D
## pisar numa placa dispara um dardo de cada boca na parede, contra aventureiro ou morto-vivo. O dardo e
## um projetil sem atirador, entao so o host aplica o dano, como qualquer golpe sem dono. Com fire_delay a
## placa estala antes, como no Dark Souls: tempo de erguer o escudo. Uma alavanca desarma (activate)

const TARGETS := 2 | 4

## Dano de cada dardo.
@export var damage := 2.0
## Tempo minimo entre dois disparos.
@export var reload_time := 1.5
## Estalo antes do disparo; com 0 dispara na hora.
@export var fire_delay := 0.0
@export var dart_scene: PackedScene
## Pisar em qualquer uma dispara.
@export var plates: Array[Area3D] = []
## Cada Marker3D filho dispara um dardo para o proprio -Z.
@export var muzzles: Node3D
@export var animation_player: AnimationPlayer
@export var click_sound: AudioStreamPlayer3D

var is_armed := true
var _ready_at := 0.0


func _ready() -> void:
	assert(dart_scene and muzzles and animation_player and not plates.is_empty(), "DartTrap: aponte os nos exportados")
	for plate in plates:
		plate.body_entered.connect(_on_stepped.bind(plate))


func activate() -> void:
	is_armed = false


func get_display_name() -> String:
	return "Dardos"


func _on_stepped(body: Node3D, plate: Area3D) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if not body is Character or now < _ready_at or not is_armed:
		return
	_ready_at = now + reload_time
	if fire_delay > 0.0:
		if click_sound:
			click_sound.global_position = plate.global_position
			click_sound.play()
		await get_tree().create_timer(fire_delay).timeout
	# a cena pode ter trocado ou a alavanca desarmado durante o estalo
	if is_armed and is_inside_tree():
		_fire()


func _fire() -> void:
	animation_player.play("disparo")
	for muzzle: Marker3D in muzzles.get_children():
		var dart := dart_scene.instantiate() as Projectile
		get_parent().add_child(dart)
		dart.launch(null, muzzle.global_position, -muzzle.global_basis.z, damage, TARGETS, self)
