class_name AdventurerCutscene
extends Node3D
## Gerenciador de cutscenes de aventureiros com sincronização multiplayer.
## Instancia os modelos dos personagens (local e aliados) em pontos específicos da cena (Marker3D),
## executa a linha do tempo de animação e aguarda a confirmação de todos os jogadores para avançar.

## Emitido quando a cutscene encerra e o jogo está pronto para transicionar de cena.
signal finished
## Caminho da próxima cena (.tscn) a ser carregada após o fim da cutscene.
@export_file("*.tscn") var next_scene := ""
@export var timeline: AnimationPlayer
## onde cada ator fica
@export var actor_spots: Array[Marker3D] = []
## mesma ordem de actor_spots
@export var actor_animations := PackedStringArray()
## em grupo os aliados entram aqui; vazio = a cutscene nao espera ninguem
@export var party_spots: Array[Marker3D] = []
## animacao dos aliados entrando
@export var party_animation := Character.ANIM_WALK
@export var party_status: Label
@export var skip_hint: Control

var actors: Array[Node3D] = []
var _done := false
# so o host conta quem ja terminou de assistir
var _ready_peers: Array[int] = []
var _ally_models := {}


func _ready() -> void:
	# Libera o ponteiro do mouse para navegação de menus, se necessário
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Instancia o modelo do aventureiro atual nos pontos de atuação principais
	var model := RunState.current_adventurer().model
	for i in actor_spots.size():
		var actor := model.instantiate() as Node3D
		actor_spots[i].add_child(actor)
		actors.append(actor)
		if i < actor_animations.size():
			play_actor(i, actor_animations[i])
	_add_party()
	# Conecta o término natural da animação do AnimationPlayer
	timeline.animation_finished.connect(func(_name: StringName) -> void: _finish())
	Net.player_left.connect(_on_player_left)


# cada maquina mostra o proprio aventureiro na frente e os aliados atras
func _add_party() -> void:
	if not _waits_for_party() or not Net.is_coop():
		return
	var infos := RunState.roster()
	var allies := Net.peers_in_order().filter(func(peer_id: int) -> bool: return peer_id != multiplayer.get_unique_id())
	for i in mini(allies.size(), party_spots.size()):
		var ally := infos[Net.roster[allies[i]]].model.instantiate() as Node3D
		party_spots[i].add_child(ally)
		_ally_models[allies[i]] = ally
		(ally.get_node("AnimationPlayer") as AnimationPlayer).play(party_animation)
	party_status.show()
	if skip_hint:
		skip_hint.hide()
	_show_status(0)


## chamado pelas trilhas de metodo; blend > 0 parte da pose atual (tombar ajoelhado)
func play_actor(index: int, animation: String, blend := -1.0) -> void:
	(actors[index].get_node("AnimationPlayer") as AnimationPlayer).play(animation, blend)

## Intercepta inputs para permitir que o jogador pule ou confirme o término da cutscene.
func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.is_pressed():
		timeline.pause()
		_finish()

## Processa a conclusão da cutscene para o jogador local.
func _finish() -> void:
	if _done:
		return
	_done = true
	if _waits_for_party():
		_mark_ready()
		return
	_leave()

## Emite o sinal de encerramento e transiciona para a próxima cena configurada.
func _leave() -> void:
	finished.emit()
	if not next_scene.is_empty():
		get_tree().change_scene_to_file(next_scene)


# solo e um grupo de um: fica pronto e entra na hora
func _waits_for_party() -> bool:
	return not party_spots.is_empty()

## Notifica o Host que este jogador está pronto para avançar.
func _mark_ready() -> void:
	if multiplayer.is_server():
		_register_ready(1)
	else:
		_net_ready.rpc_id(1)

## RPC recebido pelo Host informando que um cliente concluiu a cutscene.
@rpc("any_peer", "reliable")
func _net_ready() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and Net.is_player(sender):
		_register_ready(sender)

## Registra o peer como pronto e verifica a condição de liberação do grupo.
func _register_ready(peer_id: int) -> void:
	if peer_id not in _ready_peers:
		_ready_peers.append(peer_id)
	_check_party()

## Verifica se todo o grupo está pronto. Caso sim, envia RPC para transição simultânea.
func _check_party() -> void:
	if _ready_peers.size() >= Net.player_count:
		_net_leave_together.rpc()
	elif Net.is_coop():
		_net_status.rpc(_ready_peers.size())

## Trata a desconexão de um jogador removendo seu modelo 3D e reavaliando o grupo.
func _on_player_left(peer_id: int) -> void:
	if _ally_models.has(peer_id):
		_ally_models[peer_id].queue_free()
		_ally_models.erase(peer_id)
	if not multiplayer.is_server():
		return
	_ready_peers.erase(peer_id)
	if not _ready_peers.is_empty():
		_check_party()

## RPC recebido pelos clientes para atualizar a contagem de jogadores prontos na tela.
@rpc("authority", "call_local", "reliable")
func _net_status(ready_count: int) -> void:
	_show_status(ready_count)

## Atualiza o texto do rótulo da UI com o progresso de prontidão do grupo.
func _show_status(ready_count: int) -> void:
	var waiting := "Aguardando o grupo" if _done else "Qualquer tecla quando estiver pronto"
	party_status.text = "%s (%d/%d prontos)" % [waiting, ready_count, Net.player_count]

## RPC do Host ordenando que todas as máquinas encerrem a cutscene simultaneamente.
@rpc("authority", "call_local", "reliable")
func _net_leave_together() -> void:
	_leave()
