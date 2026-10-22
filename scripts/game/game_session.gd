class_name GameSession
extends Node

const EXECUTION := "res://scenes/cutscenes/execution.tscn"
const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
# espera a animacao de morte do boss
const VICTORY_DELAY := 2.5
const PLAYER_SPACING := 1.5

# so nas cenas de teste; com encounters o ponto e sorteado
@export var player_spawn: Marker3D
@export var encounters: EncounterSpawner
@export var pause_menu: PauseMenu
@export var death_screen: DeathScreen
@export var hud: Hud
@export var boss_scene: PackedScene
@export var victory_screen: VictoryScreen

# o jogador desta maquina; em grupo os outros ficam em players
var player: Adventurer
var players: Array[Adventurer] = []
var boss: Enemy
var _groups_left := 0
# peer_id -> indice da bencao votada; so o host conta
var _votes := {}
var _vote_paths := PackedStringArray()
var _vote_open := false


func _ready() -> void:
	assert((player_spawn or encounters) and pause_menu and death_screen and hud, "GameSession: aponte spawn, pausa, tela de morte e HUD")
	_spawn_players()
	player.died.connect(release_cursor)
	player.revived.connect(_on_player_revived)
	pause_menu.resumed.connect(_on_resumed)
	pause_menu.abandon_confirmed.connect(_abandon)
	death_screen.gave_up.connect(_give_up)
	death_screen.revive_chosen.connect(_cast_vote)
	if victory_screen:
		victory_screen.back_to_menu.connect(_back_to_menu)
	Net.player_left.connect(_on_player_left)
	capture_cursor()
	Net.report_level_loaded()


func _unhandled_input(event: InputEvent) -> void:
	if player.is_dead or pause_menu.visible or (victory_screen and victory_screen.visible):
		return
	if event.is_action_pressed("pause"):
		release_cursor()
		player.input_locked = true
		pause_menu.open()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# o clique que devolve o controle da camera nao deve virar ataque
		capture_cursor()
		get_viewport().set_input_as_handled()


# todas as maquinas usam a mesma semente: o sorteio de ponto e grupos sai igual;
# semente 0 e a cena aberta direto no editor, que sorteia como sempre
func _spawn_players() -> void:
	if Net.match_seed != 0:
		seed(Net.match_seed)
	var spawn := encounters.pick_player_spot() if encounters else player_spawn
	var peers := _peers_in_match()
	for i in peers.size():
		var peer_id := peers[i]
		var adventurer := _adventurer_of(peer_id).scene.instantiate() as Adventurer
		adventurer.name = str(peer_id) if Net.is_online() else "Player"
		adventurer.set_multiplayer_authority(peer_id)
		adventurer.position = spawn.global_position + Vector3.RIGHT * (i - (peers.size() - 1) / 2.0) * PLAYER_SPACING
		add_child(adventurer)
		adventurer.set_display_name(Net.display_name(peer_id))
		players.append(adventurer)
		adventurer.died.connect(_on_player_died)
		if peer_id == multiplayer.get_unique_id():
			player = adventurer
	player.camera.make_current()
	if encounters:
		_track_groups(encounters.spawn_groups(spawn.global_position))
	hud.bind(player)


func _peers_in_match() -> Array[int]:
	var peers: Array[int] = []
	if Net.is_online():
		peers.assign(Net.peers_in_order())
	else:
		peers.append(multiplayer.get_unique_id())
	return peers


func _adventurer_of(peer_id: int) -> AdventurerInfo:
	if not Net.is_online():
		return RunState.current_adventurer()
	return RunState.roster()[Net.roster[peer_id]]


func _track_groups(groups: Array[EnemyGroup]) -> void:
	_groups_left = groups.size()
	for group in groups:
		group.cleared.connect(_on_group_cleared)
	_show_objective()


func _on_group_cleared() -> void:
	_groups_left -= 1
	_show_objective()
	if _groups_left == 0 and multiplayer.is_server():
		_summon_boss.rpc()


func _show_objective() -> void:
	hud.set_objective("Grupos restantes: %d" % _groups_left)


@rpc("authority", "call_local", "reliable")
func _summon_boss() -> void:
	if boss_scene == null or encounters.boss_spot == null:
		return
	boss = boss_scene.instantiate() as Enemy
	boss.name = "Boss"
	boss.position = encounters.to_local(encounters.boss_spot.global_position)
	boss.start_rising = true
	encounters.add_child(boss)
	boss.died.connect(_on_boss_died)
	hud.show_boss(boss)
	hud.set_objective("Derrote o Necromante")
	hud.announce("O Necromante despertou na praça")


func _on_boss_died() -> void:
	hud.set_objective("")
	await get_tree().create_timer(VICTORY_DELAY).timeout
	if _all_players_dead():
		return
	release_cursor()
	victory_screen.open(RunState.attempt)


# solo e um grupo de um: cai todo mundo, vota todo mundo
func _on_player_died() -> void:
	if not _all_players_dead():
		if player.is_dead:
			hud.announce("Você caiu. Seus aliados ainda lutam.")
		return
	_on_party_down()


func _on_party_down() -> void:
	release_cursor()
	if multiplayer.is_server() and not _vote_open:
		_start_vote()


# democracia: cada jogador vota numa das bencaos sorteadas pelo host; empate e sorteado
func _start_vote() -> void:
	var paths := PackedStringArray()
	for buff in RunState.roll_choices():
		paths.append(buff.resource_path)
	_net_open_vote.rpc(paths)


@rpc("authority", "call_local", "reliable")
func _net_open_vote(paths: PackedStringArray) -> void:
	_vote_open = true
	_votes.clear()
	_vote_paths = paths
	var choices: Array[Buff] = []
	for path in paths:
		var buff := buff_at(path)
		if buff:
			choices.append(buff)
	death_screen.set_recap(player.damage_recap())
	death_screen.open_vote(choices, multiplayer.is_server())


func _cast_vote(buff: Buff) -> void:
	var index := _vote_paths.find(buff.resource_path) if buff else -1
	death_screen.hide()
	if Net.is_coop():
		hud.announce("Voto registrado. Aguardando o grupo.")
	if multiplayer.is_server():
		_register_vote(1, index)
	else:
		_net_vote.rpc_id(1, index)


@rpc("any_peer", "reliable")
func _net_vote(index: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and _vote_open and Net.is_player(sender) and index >= -1 and index < _vote_paths.size():
		_register_vote(sender, index)


func _register_vote(peer_id: int, index: int) -> void:
	_votes[peer_id] = index
	_try_close_vote()


func _try_close_vote() -> void:
	if not multiplayer.is_server() or _votes.is_empty() or _votes.size() < Net.player_count:
		return
	var winner: int = most_voted(_votes).pick_random()
	_votes.clear()
	_vote_open = false
	_net_restart.rpc(_vote_paths[winner] if winner >= 0 else "", randi())


# empatados voltam todos; quem chama sorteia entre eles
static func most_voted(votes: Dictionary) -> Array:
	var tally := {}
	for index: int in votes.values():
		tally[index] = tally.get(index, 0) + 1
	var best: int = tally.values().max()
	return tally.keys().filter(func(index: int) -> bool: return tally[index] == best)


# o caminho vem do host pela rede: so bencaos da pasta de bencaos
static func buff_at(path: String) -> Buff:
	if not path.begins_with(RunState.BUFF_DIR + "/") or not path.ends_with(".tres") or ".." in path:
		return null
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Buff


func _all_players_dead() -> bool:
	return players.all(func(adventurer: Adventurer) -> bool: return adventurer.is_dead)


func _on_player_left(peer_id: int) -> void:
	var adventurer := get_node_or_null(str(peer_id)) as Adventurer
	if adventurer == null:
		return
	players.erase(adventurer)
	adventurer.queue_free()
	hud.announce("Um aliado saiu da partida.")
	_votes.erase(peer_id)
	if _vote_open:
		_try_close_vote()
	elif _all_players_dead():
		_on_party_down()


func _on_resumed() -> void:
	player.input_locked = false
	capture_cursor()


# reviver com o menu aberto nao pode prender o cursor por baixo dele
func _on_player_revived() -> void:
	if not pause_menu.visible:
		capture_cursor()


func _back_to_menu() -> void:
	RunState.reset()
	get_tree().change_scene_to_file(MAIN_MENU)


func capture_cursor() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func release_cursor() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


@rpc("authority", "call_local", "reliable")
func _net_restart(buff_path: String, seed_value: int) -> void:
	RunState.start_next_attempt(buff_at(buff_path))
	Net.match_seed = seed_value
	Net.waiting_for_peers = true
	get_tree().reload_current_scene()


# em grupo, abandonar tira so quem saiu; se for o host, a partida acaba para todos
func _abandon() -> void:
	if Net.is_coop():
		Net.leave()
		_back_to_menu()
		return
	_execute()


func _give_up() -> void:
	_net_execute.rpc()


@rpc("authority", "call_local", "reliable")
func _net_execute() -> void:
	_execute()


func _execute() -> void:
	RunState.reset()
	get_tree().change_scene_to_file(EXECUTION)
