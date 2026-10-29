class_name Mimic
extends Chaser
## parece um bau ate alguem tentar abrir ou bater nele: entao morde quem mexeu e persegue aos pulos o
## aventureiro mais perto. So o host decide, como os mortos-vivos; derrotado, solta o tesouro de verdade. Nao
## e morto-vivo, entao nao entra na conta do contrato

const OPEN_REACH := 3.0

@export var prompt: Label3D
## Area em que aparece o aviso de abrir.
@export var open_area: Area3D
## Dentes e lingua: escondidos ate ele acordar.
@export var mouth: Node3D
## O que cai quando ele e derrotado.
@export var loot_scene: PackedScene
@export var keyboard_prompt := "E  Abrir"
@export var gamepad_prompt := "X  Abrir"

var is_awake := false
var _player: Adventurer

@onready var health_bar: HealthBar3D = $HealthBar3D


func _ready() -> void:
	super()
	assert(prompt and open_area and mouth and loot_scene, "Mimic: aponte prompt, open_area, mouth e loot_scene")
	prompt.hide()
	health_bar.set_bar_visible(false)
	open_area.body_entered.connect(_on_body_entered)
	open_area.body_exited.connect(_on_body_exited)


func get_display_name() -> String:
	return "Mímico"


func take_damage(amount: float, source: Node3D = null) -> void:
	super(amount, source)
	if is_multiplayer_authority() and not is_dead and not is_awake:
		_wake(source as Adventurer)


func is_hunting() -> bool:
	return is_awake


func wants_to_run() -> bool:
	return is_awake


func _wake(opener: Adventurer) -> void:
	_net_wake.rpc()
	_target = opener if opener else _nearest_player()
	if _target:
		_look_toward(_target.global_position)
		attack.try_attack(self)


@rpc("authority", "call_local", "reliable")
func _net_wake() -> void:
	is_awake = true
	mouth.show()
	prompt.hide()
	health_bar.set_bar_visible(true)
	if _player:
		_player.interactables_in_reach -= 1
		_player = null


# o tesouro cai em todas as maquinas com o mesmo nome, para a pocao ser a mesma em todas
func _die_locally() -> void:
	super()
	var loot := loot_scene.instantiate() as Node3D
	loot.name = "%sLoot" % name
	get_parent().add_child(loot)
	loot.global_position = global_position + model.global_basis.z * 1.4


func _unhandled_input(event: InputEvent) -> void:
	if _player and not is_awake and not is_dead and not _player.is_dead and event.is_action_pressed("interact"):
		_request_open.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)
		get_viewport().set_input_as_handled()


@rpc("any_peer", "call_local", "reliable")
func _request_open() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not is_awake and not is_dead and Adventurer.peer_can_reach(get_tree(), sender, global_position, OPEN_REACH):
		_wake(Adventurer.of_peer(get_tree(), sender))


# igual a um bau: o aviso de abrir aparece para quem chega perto
func _on_body_entered(body: Node3D) -> void:
	var adventurer := body as Adventurer
	if adventurer and adventurer.is_multiplayer_authority() and _player == null and not is_awake and not is_dead:
		_player = adventurer
		adventurer.interactables_in_reach += 1
		prompt.text = gamepad_prompt if Settings.uses_gamepad() else keyboard_prompt
		prompt.show()


func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_player.interactables_in_reach -= 1
		_player = null
		prompt.hide()
