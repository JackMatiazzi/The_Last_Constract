class_name EncounterSpawner
extends Node3D
## Gerenciador de pontos de nascimento (spawns) de jogadores, grupos de inimigos e chefes na fase.
## Responsável por selecionar aleatoriamente locais de nascimento e instanciar
## os grupos de inimigos garantindo uma distância mínima em relação à posição inicial dos jogadores.

## pontos possiveis de nascimento do jogador
@export var player_spots: Node3D
## pontos possiveis dos grupos de inimigos
@export var group_spots: Node3D
## onde o boss surge
@export var boss_spot: Marker3D
@export var group_scenes: Array[PackedScene] = []
## grupos sorteados por tentativa
@export var group_count := 5
## os grupos nascem pelo menos a esta distancia do jogador
@export var min_distance_from_player := 16.0

## Escolhe aleatoriamente um dos marcadores de posição reservados para os jogadores.
func pick_player_spot() -> Marker3D:
	return _markers(player_spots).pick_random()

## Instancia e posiciona os grupos de inimigos no mapa, respeitando a distância mínima do jogador.
func spawn_groups(player_position: Vector3) -> Array[EnemyGroup]:
	var spots := _markers(group_spots).filter(func(spot: Marker3D) -> bool:
		return spot.global_position.distance_to(player_position) >= min_distance_from_player)
	spots.shuffle()
	var scenes := group_scenes.duplicate()
	scenes.shuffle()
	var spawned: Array[EnemyGroup] = []
	for i in mini(group_count, spots.size()):
		var group := scenes[i % scenes.size()].instantiate() as EnemyGroup
		group.name = "Group%d" % i
		group.transform = global_transform.affine_inverse() * spots[i].global_transform
		add_child(group)
		spawned.append(group)
	return spawned

## Retorna todos os nós do tipo Marker3D que são filhos diretos do nó pai informado.
func _markers(parent: Node3D) -> Array[Marker3D]:
	var found: Array[Marker3D] = []
	found.assign(parent.get_children().filter(func(child: Node) -> bool: return child is Marker3D))
	return found
