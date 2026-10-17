class_name CharacterSelect
extends Node3D

const MISSION_INTRO := "res://scenes/cutscenes/mission_intro.tscn"
const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const SLOT_SPACING := 2.4
const STEP_FORWARD := 0.9
const HIGHLIGHT_TIME := 0.25
const NAME_HEIGHT := 2.9
const DIMMED := Color(0.75, 0.7, 0.65, 0.55)
const HIGHLIGHT := Color(1.0, 0.84, 0.5, 1.0)

@export var stage: Node3D
@export var ring: Node3D
@export var spotlight: SpotLight3D

var models: Array[Node3D] = []
var name_tags: Array[Label3D] = []

@onready var picker: AdventurerPicker = %AdventurerPicker


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in picker.options.size():
		_add_slot(i, picker.options[i])
	picker.selection_changed.connect(_highlight)
	picker.confirmed.connect(_start_contract)
	picker.back_requested.connect(get_tree().change_scene_to_file.bind(MAIN_MENU))
	_highlight(picker.selected)


func _add_slot(index: int, info: AdventurerInfo) -> void:
	var model := info.model.instantiate() as Node3D
	model.position.x = (index - (picker.options.size() - 1) / 2.0) * SLOT_SPACING
	stage.add_child(model)
	_animation_player(model).play(Character.ANIM_IDLE)
	models.append(model)

	var tag := Label3D.new()
	tag.text = "%d  %s" % [index + 1, info.title]
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 56
	tag.outline_size = 14
	tag.position.y = NAME_HEIGHT
	model.add_child(tag)
	name_tags.append(tag)


func _highlight(_info: AdventurerInfo) -> void:
	var chosen := picker.selected_index
	var tween := create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	for i in models.size():
		var forward := STEP_FORWARD if i == chosen else 0.0
		tween.tween_property(models[i], "position:z", forward, HIGHLIGHT_TIME)
		tween.tween_property(name_tags[i], "modulate", HIGHLIGHT if i == chosen else DIMMED, HIGHLIGHT_TIME)
	var spot := models[chosen].position + Vector3(0, 0, STEP_FORWARD)
	tween.tween_property(ring, "position", Vector3(spot.x, ring.position.y, spot.z), HIGHLIGHT_TIME)
	tween.tween_property(spotlight, "global_position:x", stage.to_global(spot).x, HIGHLIGHT_TIME)

	var player := _animation_player(models[chosen])
	player.play("Cheer")
	player.queue(Character.ANIM_IDLE)


func _start_contract(info: AdventurerInfo) -> void:
	RunState.reset()
	RunState.adventurer = info
	get_tree().change_scene_to_file(MISSION_INTRO)


func _animation_player(model: Node) -> AnimationPlayer:
	return model.get_node("AnimationPlayer")
