@tool
class_name EnemyGroup
extends Node3D

# so os corpos dentro de gather_radius vao ate o elite; os outros somem como corpo comum

signal elite_formed(elite: Enemy)
signal cleared

@export var elite_scene: PackedScene
@export var merge_delay := 2.0
@export var gather_time := 1.2
@export var gather_radius := 8.0:
	set(value):
		gather_radius = value
		update_configuration_warnings()

var _formed := false


func _ready() -> void:
	if Engine.is_editor_hint():
		child_order_changed.connect(update_configuration_warnings)
		return
	for member in members():
		member.died.connect(_on_member_died)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if members().size() < 2:
		warnings.append("Um grupo precisa de pelo menos 2 mortos-vivos como filhos.")
	for member in members():
		if member.position.length() > gather_radius:
			warnings.append("%s esta a mais de %.0f m do centro do grupo." % [member.name, gather_radius])
	return warnings


func members() -> Array[Enemy]:
	var found: Array[Enemy] = []
	found.assign(get_children().filter(func(child: Node) -> bool: return child is Enemy))
	return found


func _on_member_died() -> void:
	if _formed or not members().all(func(m: Enemy) -> bool: return m.is_dead):
		return
	_formed = true
	if elite_scene == null:
		cleared.emit()
		return
	var timeline := create_tween()
	timeline.tween_interval(merge_delay)
	timeline.tween_callback(_gather)
	timeline.tween_interval(gather_time)
	timeline.tween_callback(_raise_elite)


func _gather() -> void:
	for member in members():
		if member.global_position.distance_to(global_position) <= gather_radius:
			member.absorb_into(global_position, gather_time)


func _raise_elite() -> void:
	var elite := elite_scene.instantiate() as Enemy
	elite.position = get_parent().to_local(global_position)
	elite.start_rising = true
	get_parent().add_child(elite)
	elite.died.connect(cleared.emit)
	elite_formed.emit(elite)
