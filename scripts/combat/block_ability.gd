class_name BlockAbility
extends Node

@export var animation := "Blocking"
@export var icon: Texture2D
## a pose do escudo nao tem passada: andar com ela deslizaria
@export var move_factor := 0.0
## graus, a frente do personagem
@export var arc_degrees := 140.0


func covers(defender: Character, source: Node3D) -> bool:
	return defender.is_facing(source.global_position, arc_degrees * 0.5)
