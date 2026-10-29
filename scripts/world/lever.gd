class_name Lever
extends Interactable
## puxada uma vez so, aciona os alvos em todas as maquinas: portao abre, armadilha desarma

## Nos com activate() acionados ao puxar.
@export var targets: Array[Node] = []
@export var animation_player: AnimationPlayer

var is_pulled := false


func can_interact() -> bool:
	return not is_pulled


func _use(_by: Adventurer) -> void:
	_net_pull.rpc()


@rpc("authority", "call_local", "reliable")
func _net_pull() -> void:
	if is_pulled:
		return
	is_pulled = true
	_release_player()
	if animation_player:
		animation_player.play("puxar")
	for target in targets:
		target.activate()
