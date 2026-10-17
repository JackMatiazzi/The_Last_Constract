class_name GameSession
extends Node

const EXECUTION := "res://scenes/cutscenes/execution.tscn"
const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
# espera a animacao de morte do boss
const VICTORY_DELAY := 2.5

# so nas cenas de teste; com encounters o ponto e sorteado
@export var player_spawn: Marker3D
@export var encounters: EncounterSpawner
@export var pause_menu: PauseMenu
@export var death_screen: DeathScreen
@export var hud: Hud
@export var boss_scene: PackedScene
@export var victory_screen: VictoryScreen

var player: Adventurer
var boss: Enemy
var _groups_left := 0


func _ready() -> void:
	assert((player_spawn or encounters) and pause_menu and death_screen and hud, "GameSession: aponte spawn, pausa, tela de morte e HUD")
	_spawn_player()
	player.died.connect(release_cursor)
	pause_menu.resumed.connect(capture_cursor)
	pause_menu.abandon_confirmed.connect(_execute)
	death_screen.gave_up.connect(_execute)
	death_screen.revive_chosen.connect(_start_next_attempt)
	if victory_screen:
		victory_screen.back_to_menu.connect(_back_to_menu)
	capture_cursor()


func _unhandled_input(event: InputEvent) -> void:
	if player.is_dead or (victory_screen and victory_screen.visible):
		return
	if event.is_action_pressed("pause"):
		release_cursor()
		pause_menu.open()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# o clique que devolve o controle da camera nao deve virar ataque
		capture_cursor()
		get_viewport().set_input_as_handled()


func _spawn_player() -> void:
	player = RunState.current_adventurer().scene.instantiate()
	player.name = "Player"
	var spawn := encounters.pick_player_spot() if encounters else player_spawn
	player.position = spawn.global_position
	add_child(player)
	if encounters:
		_track_groups(encounters.spawn_groups(player.global_position))
	hud.bind(player)
	death_screen.bind(player)


func _track_groups(groups: Array[EnemyGroup]) -> void:
	_groups_left = groups.size()
	for group in groups:
		group.cleared.connect(_on_group_cleared)
	_show_objective()


func _on_group_cleared() -> void:
	_groups_left -= 1
	_show_objective()
	if _groups_left == 0:
		_summon_boss()


func _show_objective() -> void:
	hud.set_objective("Grupos restantes: %d" % _groups_left)


func _summon_boss() -> void:
	if boss_scene == null or encounters.boss_spot == null:
		return
	boss = boss_scene.instantiate() as Enemy
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
	if player.is_dead:
		return
	release_cursor()
	victory_screen.open(RunState.attempt)


func _back_to_menu() -> void:
	RunState.reset()
	get_tree().change_scene_to_file(MAIN_MENU)


func capture_cursor() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func release_cursor() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _start_next_attempt(buff: Buff) -> void:
	RunState.start_next_attempt(buff)
	get_tree().reload_current_scene()


func _execute() -> void:
	RunState.reset()
	get_tree().change_scene_to_file(EXECUTION)
