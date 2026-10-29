class_name Rope
extends StaticBody3D
## corda alta demais para a lamina: so um virote corta (o projetil marca isso no inspetor). Quem atirou
## pede, o host confere e corta em todas as maquinas, acionando os alvos

## Nos com activate() acionados quando a corda e cortada.
@export var targets: Array[Node] = []
## Some quando a corda e cortada.
@export var visual: Node3D

var is_cut := false


func request_cut() -> void:
	if not is_cut:
		_request_cut.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)


@rpc("any_peer", "call_local", "reliable")
func _request_cut() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not is_cut and Adventurer.peer_can_reach(get_tree(), sender, global_position, Character.REMOTE_HIT_REACH, false):
		_net_cut.rpc()


@rpc("authority", "call_local", "reliable")
func _net_cut() -> void:
	if is_cut:
		return
	is_cut = true
	visual.hide()
	collision_layer = 0
	for target in targets:
		target.activate()
