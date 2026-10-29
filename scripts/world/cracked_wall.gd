class_name CrackedWall
extends StaticBody3D
## parede rachada: so o golpe marcado para isso no inspetor (o giro pesado do Barbarian) derruba.
## Quem golpeou pede, o host confere e derruba em todas as maquinas

const GROUP := "cracked_walls"
const HIT_MARGIN := 1.5

## Some quando a parede cai.
@export var visual: Node3D
## Lascas soltas quando a parede cai.
@export var debris_scene: PackedScene
@export var sound: AudioStreamPlayer3D

var is_broken := false


func _ready() -> void:
	assert(visual and debris_scene, "CrackedWall: aponte visual e debris_scene")
	add_to_group(GROUP)


func break_near(point: Vector3, radius: float) -> void:
	if not is_broken and point.distance_to(global_position + Vector3.UP) <= radius + HIT_MARGIN:
		_request_break.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)


@rpc("any_peer", "call_local", "reliable")
func _request_break() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not is_broken and Adventurer.peer_can_reach(get_tree(), sender, global_position, Character.REMOTE_HIT_REACH, false):
		_net_break.rpc()


@rpc("authority", "call_local", "reliable")
func _net_break() -> void:
	if is_broken:
		return
	is_broken = true
	visual.hide()
	collision_layer = 0
	if sound:
		sound.play()
	for offset in [Vector3(-1, 1, 0), Vector3(0, 2, 0), Vector3(1, 0.6, 0)]:
		var debris := debris_scene.instantiate() as Node3D
		get_parent().add_child(debris)
		debris.global_position = global_transform * offset
