class_name EnemyProfile
extends Resource

## aparece no placar e no aviso de quem derrubou quem
@export var display_name := "Morto-vivo"

@export_group("Percepcao")
## alcance da visao
@export var sight_range := 14.0
## graus, o cone inteiro
@export var sight_angle := 120.0
## ouve corrida e ataque ate aqui, mesmo sem ver
@export var hearing_range := 6.0
## percebe ate de costas, se nao tiver parede
@export var proximity_range := 2.5
## quanto tempo lembra onde viu o jogador
@export var memory_time := 3.0
## atraso antes de reagir, para nao parecer onisciente
@export var reaction_time := 0.3
## dormente acorda com o jogador a esta distancia
@export var awaken_distance := 7.0

@export_group("Combate")
## alcance do golpe, medido entre os centros
@export var attack_range := 1.5
## corre quando o destino esta mais longe que isso
@export var chase_run_distance := 5.0

@export_group("Busca")
## tempo procurando onde viu o jogador pela ultima vez
@export var search_time := 2.5
