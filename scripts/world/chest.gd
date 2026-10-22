class_name Chest
extends StaticBody3D

# drop_loot e chamado por uma trilha de metodo da animacao open

signal opened

# um pouco alem da area de interacao: a posicao do jogador chega atrasada pela rede
const OPEN_REACH := 4.0

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
		_request_open.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)
		get_viewport().set_input_as_handled()


# o host confere e abre em todas as maquinas juntas: nenhuma abre por conta propria
@rpc("any_peer", "call_local", "reliable")
func _request_open() -> void:
	if not is_open and Adventurer.peer_can_reach(get_tree(), multiplayer.get_remote_sender_id(), global_position, OPEN_REACH):
		_open_everywhere.rpc()


@rpc("authority", "call_local", "reliable")
func _open_everywhere() -> void:
	if not is_open:
		open()


func open() -> void:
	is_open = true
	prompt.hide()
	_set_player(null)
	animation_player.play("open")
	opened.emit()


func drop_loot() -> void:
	if loot_scene == null:
		return
	var loot := loot_scene.instantiate() as Node3D
	loot.name = "%sLoot" % name
	loot.position = get_parent().to_local(loot_spot.global_position)
	get_parent().add_child(loot)


func _on_body_entered(body: Node3D) -> void:
	if body is Adventurer and body.is_multiplayer_authority() and not is_open:
		_set_player(body)
		prompt.text = gamepad_prompt if Settings.uses_gamepad() else keyboard_prompt
		prompt.show()


func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_set_player(null)
		prompt.hide()


# avisa o aventureiro que ha algo para interagir: tocar E abre o bau em vez de beber
func _set_player(adventurer: Adventurer) -> void:
	if is_instance_valid(_player):
		_player.interactables_in_reach -= 1
	_player = adventurer
	if _player:
		_player.interactables_in_reach += 1
