class_name EnemyProfile
extends Resource

# aparece no placar e no aviso de quem derrubou quem
@export var display_name := "Morto-vivo"

@export_group("Percepcao")
@export var sight_range := 14.0
@export var sight_angle := 120.0 # graus, cone inteiro
@export var hearing_range := 6.0 # corrida e ataque, mesmo sem ver
@export var proximity_range := 2.5 # percebe ate de costas, se nao tiver parede
@export var memory_time := 3.0
@export var reaction_time := 0.3 # para nao parecer onisciente
@export var awaken_distance := 7.0

@export_group("Combate")
@export var attack_range := 1.5 # distancia entre centros
@export var chase_run_distance := 5.0

@export_group("Busca")
@export var search_time := 2.5
