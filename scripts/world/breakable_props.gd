class_name BreakableProps
extends GridMap
## o golpe pesado quebra o que e de madeira solta; carroca, cerca e tocha aguentam

const GROUP := "breakable_props"
const BREAKABLE_PREFIXES := ["Prop_Crate", "keg", "crates_stacked", "barrel_"]
## altura de celulas olhada acima e abaixo do golpe
const VERTICAL_REACH := 2.0

@export var debris_scene: PackedScene

var _breakable_items := {}


func _ready() -> void:
	add_to_group(GROUP)
	for item in mesh_library.get_item_list():
		var item_name := mesh_library.get_item_name(item)
		if BREAKABLE_PREFIXES.any(func(prefix: String) -> bool: return item_name.begins_with(prefix)):
			_breakable_items[item] = true


func break_near(point: Vector3, radius: float) -> void:
	var center := local_to_map(to_local(point))
	var reach := Vector3i(ceili(radius / cell_size.x), ceili(VERTICAL_REACH / cell_size.y), ceili(radius / cell_size.z))
	for x in range(-reach.x, reach.x + 1):
		for y in range(-reach.y, reach.y + 1):
			for z in range(-reach.z, reach.z + 1):
				var cell := center + Vector3i(x, y, z)
				if _is_breakable(get_cell_item(cell)) and _horizontal_distance(cell, point) <= radius:
					_request_break.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, cell)


# o host confere e quebra em todas as maquinas juntas
@rpc("any_peer", "call_local", "reliable")
func _request_break(cell: Vector3i) -> void:
	var spot := to_global(map_to_local(cell))
	var sender := multiplayer.get_remote_sender_id()
	if _is_breakable(get_cell_item(cell)) and Adventurer.peer_can_reach(get_tree(), sender, spot, Character.REMOTE_HIT_REACH, false):
		_break_cell.rpc(cell)


@rpc("authority", "call_local", "reliable")
func _break_cell(cell: Vector3i) -> void:
	if not _is_breakable(get_cell_item(cell)):
		return
	var spot := to_global(map_to_local(cell))
	set_cell_item(cell, INVALID_CELL_ITEM)
	if debris_scene:
		var debris := debris_scene.instantiate() as Node3D
		get_parent().add_child(debris)
		debris.global_position = spot


func _is_breakable(item: int) -> bool:
	return _breakable_items.has(item)


func _horizontal_distance(cell: Vector3i, point: Vector3) -> float:
	var spot := to_global(map_to_local(cell))
	return Vector2(spot.x - point.x, spot.z - point.z).length()
