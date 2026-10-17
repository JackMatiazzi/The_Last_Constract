class_name Chest
extends StaticBody3D

# drop_loot e chamado por uma trilha de metodo da animacao open

signal opened

@export var loot_scene: PackedScene
@export var loot_spot: Marker3D
@export var interact_area: Area3D
@export var prompt: Label3D
@export var animation_player: AnimationPlayer
@export var keyboard_prompt := "E  Abrir"
@export var gamepad_prompt := "X  Abrir"

var is_open := false
var _player: Adventurer


func _ready() -> void:
	prompt.hide()
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if _player and not is_open and not _player.is_dead and event.is_action_pressed("interact"):
		open()
		get_viewport().set_input_as_handled()


func open() -> void:
	is_open = true
	prompt.hide()
	animation_player.play("open")
	opened.emit()


func drop_loot() -> void:
	if loot_scene == null:
		return
	var loot := loot_scene.instantiate() as Node3D
	loot.position = get_parent().to_local(loot_spot.global_position)
	get_parent().add_child(loot)


func _on_body_entered(body: Node3D) -> void:
	if body is Adventurer and not is_open:
		_player = body
		prompt.text = gamepad_prompt if Settings.uses_gamepad() else keyboard_prompt
		prompt.show()


func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_player = null
		prompt.hide()
