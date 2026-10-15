class_name AdventurerCutscene
extends Node3D

signal finished

@export_file("*.tscn") var next_scene := ""
@export var timeline: AnimationPlayer
@export var actor_spots: Array[Marker3D] = []
# mesma ordem de actor_spots
@export var actor_animations := PackedStringArray()

var actors: Array[Node3D] = []
var _done := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var model := RunState.current_adventurer().model
	for i in actor_spots.size():
		var actor := model.instantiate() as Node3D
		actor_spots[i].add_child(actor)
		actors.append(actor)
		if i < actor_animations.size():
			play_actor(i, actor_animations[i])
	timeline.animation_finished.connect(func(_name: StringName) -> void: _finish())


# chamado pelas trilhas de metodo; blend > 0 parte da pose atual (tombar ajoelhado)
func play_actor(index: int, animation: String, blend := -1.0) -> void:
	(actors[index].get_node("AnimationPlayer") as AnimationPlayer).play(animation, blend)


func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.is_pressed():
		timeline.pause()
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	if not next_scene.is_empty():
		get_tree().change_scene_to_file(next_scene)
