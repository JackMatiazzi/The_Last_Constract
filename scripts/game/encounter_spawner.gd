class_name EncounterSpawner
extends Node3D

@export var player_spots: Node3D
@export var group_spots: Node3D
@export var boss_spot: Marker3D
@export var group_scenes: Array[PackedScene] = []
@export var group_count := 5
@export var min_distance_from_player := 16.0


func pick_player_spot() -> Marker3D:
	return _markers(player_spots).pick_random()


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


func _markers(parent: Node3D) -> Array[Marker3D]:
	var found: Array[Marker3D] = []
	found.assign(parent.get_children().filter(func(child: Node) -> bool: return child is Marker3D))
	return found
