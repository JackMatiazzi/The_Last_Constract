extends Node
## Gerenciador de rede e multiplayer (Autoload).
## Responsável por criar/entrar em salas (ENet), gerenciar a lista de jogadores (roster),
## sincronizar nomes, validar caracteres, controlar a barra de carregamento do nível
## e intermediar mensagens RPC de estado de jogo.
# sem peer configurado o Godot usa OfflineMultiplayerPeer: o jogo solo e um host sem ninguem conectado

signal roster_changed
signal connection_failed
signal player_left(peer_id: int)

const PORT := 7777
const MAX_PLAYERS := 4
const MISSION_INTRO := "res://scenes/cutscenes/mission_intro.tscn"
const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const NO_CHOICE := -1
const MAX_NAME_LENGTH := 16
const VIRTUAL_ADAPTERS := ["virtualbox", "vmware", "hyper-v", "vethernet", "wsl", "docker", "loopback"]
## invisiveis ou que invertem a direcao do texto: um nome com eles baguncaria placar e avisos
const HIDDEN_CHARACTERS := [
	[0x7F, 0x9F], [0xAD, 0xAD], [0x61C, 0x61C], [0x115F, 0x1160], [0x180E, 0x180E], [0x200B, 0x200F],
	[0x2028, 0x202E], [0x2060, 0x206F], [0x2800, 0x2800], [0x3164, 0x3164], [0xFE00, 0xFE0F],
	[0xFEFF, 0xFEFF], [0xFFA0, 0xFFA0], [0xE0000, 0xE007F],
]

## peer_id -> indice em RunState.ADVENTURERS
var roster := {}
## peer_id -> nome escolhido no lobby
var names := {}
var friendly_fire := true
var match_seed := 0
## depois do inicio ninguem troca de aventureiro nem de nome
var in_match := false
var last_error := ""
## solo (offline ou host sozinho) conta 1: reviver aliado, votacao e pausa sem congelar ficam desligados
var player_count: int:
	get:
		return maxi(roster.size(), 1) if is_online() else 1
# --host / --join=IP / --adventurer=N / --autostart=N, para testar varias instancias pelo editor
var _command_line := Array(OS.get_cmdline_user_args())
## entre a troca de fase e a barreira ninguem transmite: o estado inicial sai igual em todas as maquinas
var waiting_for_peers := false
# so o host conta quem ja terminou de carregar a fase atual
var _loaded_peers: Array[int] = []


func _ready() -> void:
	# Conecta os sinais nativos do sistema Multiplayer da Godot
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_online() -> bool:
	return not multiplayer.multiplayer_peer is OfflineMultiplayerPeer


func is_coop() -> bool:
	return player_count > 1

## Inicia um servidor ENet na porta especificada.
func host(port := PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_PLAYERS - 1)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	roster = {1: NO_CHOICE}
	names = {1: Settings.player_name}
	roster_changed.emit()
	return OK

## Conecta-se a um servidor hospedado no IP e porta informados.
func join(address: String, port := PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	return OK

## Encerra a conexão de rede e restaura o estado inicial do gerenciador de rede.
func leave() -> void:
	if is_online():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	roster.clear()
	names.clear()
	_loaded_peers.clear()
	waiting_for_peers = false
	friendly_fire = true
	in_match = false

## Solicita a seleção de um aventureiro. Se for o cliente, envia RPC para o servidor.
func choose_adventurer(index: int) -> void:
	if multiplayer.is_server():
		_apply_choice(1, index)
	else:
		_request_choice.rpc_id(1, index)

## Retorna o nome formatado de um peer_id específico.
func display_name(peer_id: int) -> String:
	return names.get(peer_id, Settings.player_name)

## Limpa e valida o nome do jogador, retornando 'Aventureiro' caso o resultado fique vazio.
static func clean_name(raw: String) -> String:
	var cleaned := clean_text(raw, MAX_NAME_LENGTH)
	return cleaned if not cleaned.is_empty() else "Aventureiro"


## texto vindo de outro jogador: sem quebra de linha, caractere de controle ou invisivel
static func clean_text(raw: String, max_length: int) -> String:
	var kept := PackedStringArray()
	for character in raw:
		if _is_visible_character(character.unicode_at(0)):
			kept.append(character)
	return "".join(kept).strip_edges().left(max_length)

## Verifica se um código Unicode de caractere é visível e válido.
static func _is_visible_character(code: int) -> bool:
	if code < 32:
		return false
	return not HIDDEN_CHARACTERS.any(func(span: Array) -> bool: return code >= span[0] and code <= span[1])


## enderecos que outro jogador consegue usar: rede local e VPN de jogo (Tailscale, Radmin);
## placas de maquina virtual ficam de fora porque ninguem de fora alcanca
static func shareable_addresses() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for interface in IP.get_local_interfaces():
		var label: String = interface.friendly
		if VIRTUAL_ADAPTERS.any(func(word: String) -> bool: return word in label.to_lower()):
			continue
		for address: String in interface.addresses:
			if address.count(".") == 3 and not address.begins_with("127.") and not address.begins_with("169.254."):
				found.append({"address": address, "label": label})
	return found


func is_player(peer_id: int) -> bool:
	return roster.has(peer_id)

## Atualiza o nome do jogador local e sincroniza na rede se estiver online.
func set_player_name(raw: String) -> void:
	var cleaned := clean_name(raw)
	Settings.set_value(&"player_name", cleaned)
	if not is_online():
		return
	if multiplayer.is_server():
		names[1] = cleaned
		_share_roster()
	else:
		_request_name.rpc_id(1, cleaned)

## Define e sincroniza o estado do fogo amigo (somente o Host).
func set_friendly_fire(enabled: bool) -> void:
	if multiplayer.is_server():
		friendly_fire = enabled
		_share_roster()

## Verifica se o índice de um aventureiro já foi escolhido por outro jogador.
func is_taken(index: int) -> bool:
	for peer_id in roster:
		if peer_id != multiplayer.get_unique_id() and roster[peer_id] == index:
			return true
	return false

## Verifica se a partida pode ser iniciada (apenas o Host pode iniciar e todos devem ter escolhido personagem).
func can_start() -> bool:
	return multiplayer.is_server() and not roster.is_empty() and not roster.values().has(NO_CHOICE)

## Inicia a partida fechando novas conexões e enviando a semente de jogo para os clientes.
func start_match() -> void:
	if not can_start():
		return
	multiplayer.multiplayer_peer.refuse_new_connections = true
	_start.rpc(randi())

## Verifica se existem argumentos de linha de comando para autostart/host/join.
func has_command_line() -> bool:
	return _command_line.any(func(arg: String) -> bool: return arg == "--host" or arg.begins_with("--join"))


## consumida uma vez so: voltar ao menu nao reconecta sozinho
func take_command_line() -> Array:
	var args := _command_line
	_command_line = []
	return args


## o host so comeca a mandar estado depois que todas as maquinas tem os mesmos nos
func report_level_loaded() -> void:
	if not is_coop():
		waiting_for_peers = false
		return
	get_tree().paused = true
	if multiplayer.is_server():
		_register_loaded(1)
	else:
		_net_level_loaded.rpc_id(1, match_seed)

## RPC enviado pelos clientes ao servidor confirmando o carregamento da fase.
@rpc("any_peer", "reliable")
func _net_level_loaded(seed_value: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and seed_value == match_seed and is_player(sender):
		_register_loaded(sender)

## Registra um peer como carregado no Servidor.
func _register_loaded(peer_id: int) -> void:
	if peer_id not in _loaded_peers:
		_loaded_peers.append(peer_id)
	_release_when_everyone_loaded()

## Quando todos os jogadores carregam a fase, despacha a liberação geral do jogo.
func _release_when_everyone_loaded() -> void:
	if not _loaded_peers.has(1) or _loaded_peers.size() < player_count:
		return
	_loaded_peers.clear()
	_net_everyone_loaded.rpc()

## RPC enviado pelo servidor para despausar o jogo em todos os clientes simultaneamente.
@rpc("authority", "call_local", "reliable")
func _net_everyone_loaded() -> void:
	waiting_for_peers = false
	get_tree().paused = false

## Retorna uma lista ordenada dos IDs dos jogadores conectados.
func peers_in_order() -> Array:
	var ids := roster.keys()
	ids.sort()
	return ids

## RPC recebido pelo servidor solicitando alteração de nome de um cliente.
@rpc("any_peer", "reliable")
func _request_name(raw: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	var cleaned := clean_name(raw)
	if multiplayer.is_server() and not in_match and is_player(sender) and names.get(sender) != cleaned:
		names[sender] = cleaned
		_share_roster()

## RPC recebido pelo servidor solicitando escolha de personagem.
@rpc("any_peer", "reliable")
func _request_choice(index: int) -> void:
	if multiplayer.is_server() and not in_match and index >= 0 and index < RunState.ADVENTURERS.size():
		_apply_choice(multiplayer.get_remote_sender_id(), index)

## Processa a escolha de aventureiro de um peer e sincroniza com o grupo.
func _apply_choice(peer_id: int, index: int) -> void:
	for other in roster:
		if other != peer_id and roster[other] == index:
			return
	roster[peer_id] = index
	_share_roster()

## Sincroniza a lista inteira de jogadores e configurações do lobby para todos os clientes.
func _share_roster() -> void:
	_sync_roster.rpc(roster, names, friendly_fire)
	roster_changed.emit()

## RPC de autoridade que substitui o estado do lobby local pelos dados atualizados do host.
@rpc("authority", "reliable")
func _sync_roster(shared: Dictionary, shared_names: Dictionary, shared_friendly_fire: bool) -> void:
	roster = shared
	names = shared_names
	friendly_fire = shared_friendly_fire
	roster_changed.emit()

## RPC enviado pelo Host para iniciar a transição de cena e o loop da partida.
@rpc("authority", "call_local", "reliable")
func _start(seed_value: int) -> void:
	match_seed = seed_value
	waiting_for_peers = true
	in_match = true
	_loaded_peers.clear()
	RunState.reset()
	RunState.adventurer = RunState.roster()[roster[multiplayer.get_unique_id()]]
	get_tree().change_scene_to_file(MISSION_INTRO)

## Callback executado no Host quando um novo cliente se conecta.
func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		roster[peer_id] = NO_CHOICE
		names[peer_id] = "Jogador %d" % roster.size()
		_share_roster()


# sai da lista antes de avisar: quem conta votos e prontos ja ve o grupo menor
func _on_peer_disconnected(peer_id: int) -> void:
	roster.erase(peer_id)
	names.erase(peer_id)
	_loaded_peers.erase(peer_id)
	player_left.emit(peer_id)
	if multiplayer.is_server():
		_share_roster()
		_release_when_everyone_loaded()

## Callback de falha ao tentar conectar em um servidor.
func _on_connection_failed() -> void:
	last_error = "Não foi possível conectar ao host."
	leave()
	connection_failed.emit()

## Callback executado quando o servidor fecha a sala ou cai.
func _on_server_disconnected() -> void:
	last_error = "O host encerrou a partida."
	leave()
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU)
