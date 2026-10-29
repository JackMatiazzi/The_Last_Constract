class_name TrapCycle
extends Node3D
## a animacao da cena faz todo o ciclo da armadilha (movimento, som e quando fere); isto so atrasa o
## comeco, para armadilhas iguais lado a lado nao baterem juntas

@export var animation_player: AnimationPlayer
## Quanto do ciclo ja comeca andado, para armadilhas vizinhas nao baterem juntas.
@export var cycle_offset := 0.0
## o que some quando uma corda ou alavanca desarma a armadilha (as laminas cobertas pela ponte)
@export var disarm_hides: Node3D

var is_armed := true


func _ready() -> void:
	assert(animation_player, "TrapCycle: aponte animation_player")
	animation_player.seek(cycle_offset, true)


func activate() -> void:
	is_armed = false
	animation_player.stop()
	for hurtbox: TrapHurtbox in find_children("*", "TrapHurtbox"):
		hurtbox.stop()
	if disarm_hides:
		disarm_hides.hide()
