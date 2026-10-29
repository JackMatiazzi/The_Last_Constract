class_name Interactable
extends Area3D
## aviso de "E <acao>" para quem chega perto. Por padrao o host confere o alcance de quem pediu e decide;
## o que for so da tela de quem apertou (ler um bilhete) sobrescreve _interact

@export var prompt: Label3D
## Texto do aviso depois do E.
@export var action := "Usar"
## Distancia maxima que o host aceita para o pedido.
@export var reach := 3.5

var _player: Adventurer


func _ready() -> void:
	assert(prompt, "%s: aponte o prompt" % name)
	prompt.hide()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func can_interact() -> bool:
	return true


func _unhandled_input(event: InputEvent) -> void:
	if _player and not _player.is_dead and can_interact() and event.is_action_pressed("interact"):
		_interact()
		get_viewport().set_input_as_handled()


func _interact() -> void:
	_request_use.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)


@rpc("any_peer", "call_local", "reliable")
func _request_use() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if can_interact() and Adventurer.peer_can_reach(get_tree(), sender, global_position, reach):
		_use(Adventurer.of_peer(get_tree(), sender))


func _use(_by: Adventurer) -> void:
	pass


# chamado em todas as maquinas quando o objeto deixa de servir (alavanca puxada)
func _release_player() -> void:
	prompt.hide()
	if _player:
		_player.interactables_in_reach -= 1
		_player = null


func _on_body_entered(body: Node3D) -> void:
	var adventurer := body as Adventurer
	if adventurer and adventurer.is_multiplayer_authority() and _player == null and can_interact():
		_player = adventurer
		adventurer.interactables_in_reach += 1
		prompt.text = "%s  %s" % ["X" if Settings.uses_gamepad() else "E", action]
		prompt.show()


func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_release_player()
