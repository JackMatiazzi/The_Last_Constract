class_name Gate
extends Node3D
## portao, ponte levadica: o que abre quando seus acionadores disparam. Com mais de um selo, so abre quando
## todos foram acionados. Cada maquina abre a sua ao receber o acionamento, entao nada passa pela rede aqui

@export var animation_player: AnimationPlayer
## Acionamentos para abrir; 2 para o portao de dois selos.
@export var required := 1

var activations := 0
var is_open := false


func _ready() -> void:
	assert(animation_player, "Gate: aponte o animation_player")


func activate() -> void:
	activations += 1
	if activations >= required and not is_open:
		is_open = true
		animation_player.play("abrir")
