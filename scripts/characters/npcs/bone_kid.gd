class_name BoneKid
extends Character
## esqueletinho que segue quem chega pedindo o urro. So quem urra (o Barbarian) atende: ele desmonta de
## emocao, se remonta e pede de novo; no primeiro urro da um presente e entrega a dica da adega. Apanhar
## so o desmonta. Pequeno demais para o contrato, nao conta na clausula, a nao ser que quem urra negue o
## urro vezes demais: emburrado, ele entra na conta e pode cair. Um urro tardio faz as pazes. Quem decide
## e o host

const ROAR_REACH := 4.0
const FOLLOW_RANGE := 9.0
const KEEP_DISTANCE := 1.6
const PESTER_TIME := 3.5
const LINE_TIME := 3.0
const TUMBLE_TIME := 1.3

@export var speech: Label3D
@export var prompt: Label3D
@export var talk_area: Area3D
@export var roar_sound: AudioStreamPlayer3D
## Presente do primeiro urro.
@export var gift_scene: PackedScene
## Texto do aviso depois do E, so para quem urra.
@export var roar_action := "Urrar"
@export_group("Falas")
## Pedidos ditos em rodizio enquanto alguem esta perto.
@export var pester_lines := PackedStringArray()
## Dita de vez em quando a quem nao sabe urrar.
@export var wrong_hero_line := ""
## Dita depois de cada urro.
@export var again_line := ""
## Dita depois do primeiro urro, junto do presente.
@export var hint_line := ""
## Dita quando apanha sem estar emburrado.
@export var hurt_line := ""
## Dita quando emburra e passa a contar na clausula.
@export var sulk_line := ""
## Dita quando um urro tardio faz as pazes.
@export var make_up_line := ""
## pedidos ouvidos por quem urra, sem urro, ate ele emburrar
@export var denial_limit := 6

var roars_heard := 0
var gift_given := false
var is_sulking := false
var denials := 0
var _home: Vector3
var _pester_left := 0.0
var _pester_index := 0
var _busy_until := 0.0
var _listener: Adventurer
var _hide_tween: Tween

@onready var health_bar: HealthBar3D = $HealthBar3D


func _ready() -> void:
	super()
	assert(speech and prompt and talk_area and roar_sound and gift_scene, "BoneKid: aponte os nos exportados")
	_home = global_position
	speech.hide()
	prompt.hide()
	talk_area.body_entered.connect(_on_listener_entered)
	talk_area.body_exited.connect(_on_listener_exited)


func get_display_name() -> String:
	return "Esqueletinho"


func _physics_process(delta: float) -> void:
	if is_multiplayer_authority() and _now() >= _busy_until and not is_sulking:
		_pester(delta)
	super(delta)


func _pester(delta: float) -> void:
	var fan := _nearest_player()
	if fan == null or pester_lines.is_empty():
		return
	_pester_left -= delta
	if _pester_left > 0.0:
		return
	_pester_left = PESTER_TIME
	if fan.roars and roars_heard == 0:
		denials += 1
		if denials > denial_limit:
			_net_sulk.rpc()
			return
	var line := pester_lines[_pester_index % pester_lines.size()]
	if not fan.roars and _pester_index % 2 == 1 and not wrong_hero_line.is_empty():
		line = wrong_hero_line
	_pester_index += 1
	_say.rpc(line)


func _nearest_player() -> Adventurer:
	var nearest: Adventurer = null
	var nearest_distance := FOLLOW_RANGE
	for player: Adventurer in get_tree().get_nodes_in_group("players"):
		var distance := player.global_position.distance_to(_home)
		if not player.is_dead and distance < nearest_distance:
			nearest = player
			nearest_distance = distance
	return nearest


# vai atras do fa mais perto, sem sair de perto de casa; sem ninguem, volta
func _get_move_direction() -> Vector3:
	if not is_multiplayer_authority() or _now() < _busy_until:
		return Vector3.ZERO
	var fan := _nearest_player() if not is_sulking else null
	var target := fan.global_position if fan else _home
	var to := (target - global_position).slide(Vector3.UP)
	if to.length() <= (KEEP_DISTANCE if fan else 0.3):
		return Vector3.ZERO
	return to.normalized()


func take_damage(amount: float, source: Node3D = null) -> void:
	if not is_multiplayer_authority() or is_sulking:
		super(amount, source)
		return
	_net_tumble.rpc(hurt_line)


func _unhandled_input(event: InputEvent) -> void:
	if _listener and _listener.roars and not _listener.is_dead and not is_dead and _now() >= _busy_until \
			and event.is_action_pressed("interact"):
		_listener.play_action("Cheer", 1.0, 0.0, 1.4)
		_request_roar.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)
		get_viewport().set_input_as_handled()


@rpc("any_peer", "call_local", "reliable")
func _request_roar() -> void:
	var sender := multiplayer.get_remote_sender_id()
	var roarer := Adventurer.of_peer(get_tree(), sender)
	if roarer == null or not roarer.roars or is_dead or _now() < _busy_until:
		return
	if Adventurer.peer_can_reach(get_tree(), sender, global_position, ROAR_REACH):
		_net_roar.rpc(roarer.get_path())


@rpc("authority", "call_local", "reliable")
func _net_roar(roarer_path: NodePath) -> void:
	var roarer := get_node_or_null(roarer_path) as Node3D
	if roarer:
		roar_sound.global_position = roarer.global_position + Vector3.UP * 1.6
	roar_sound.play()
	roars_heard += 1
	if is_sulking:
		_make_up()
	else:
		_tumble(again_line)
	if not gift_given:
		gift_given = true
		var gift := gift_scene.instantiate() as Node3D
		gift.name = "PresenteDoEsqueletinho"
		get_parent().add_child(gift)
		gift.global_position = global_position + model.global_basis.z * 1.2
		_say_after(hint_line, TUMBLE_TIME + LINE_TIME)


# negou o urro: emburra, entra na conta do contrato e passa a poder cair
@rpc("authority", "call_local", "reliable")
func _net_sulk() -> void:
	is_sulking = true
	add_to_group(UndeadCensus.GROUP)
	health_bar.set_bar_visible(true)
	_say(sulk_line)


func _die_locally() -> void:
	super()
	prompt.hide()
	speech.hide()


func _make_up() -> void:
	is_sulking = false
	denials = 0
	remove_from_group(UndeadCensus.GROUP)
	health_bar.set_bar_visible(false)
	_tumble(make_up_line)


@rpc("authority", "call_local", "reliable")
func _net_tumble(line: String) -> void:
	_tumble(line)


# desmonta e se remonta: de emocao com o urro, de susto com o golpe
func _tumble(line: String) -> void:
	_busy_until = _now() + TUMBLE_TIME * 2.0
	_play_action_locally("Death_C_Skeletons", 1.6, 0.0, TUMBLE_TIME)
	get_tree().create_timer(TUMBLE_TIME).timeout.connect(_play_action_locally.bind("Death_C_Skeletons_Resurrect", 1.6, 0.0, TUMBLE_TIME))
	_say_after(line, TUMBLE_TIME)


func _say_after(line: String, delay: float) -> void:
	if not line.is_empty():
		get_tree().create_timer(delay).timeout.connect(_say.bind(line))


@rpc("authority", "call_local", "reliable")
func _say(line: String) -> void:
	speech.text = line
	speech.show()
	if _hide_tween:
		_hide_tween.kill()
	_hide_tween = create_tween()
	_hide_tween.tween_interval(LINE_TIME)
	_hide_tween.tween_callback(speech.hide)


# so quem urra ve o aviso; para os outros o E continua sendo beber
func _on_listener_entered(body: Node3D) -> void:
	var adventurer := body as Adventurer
	if adventurer and adventurer.is_multiplayer_authority() and adventurer.roars and _listener == null:
		_listener = adventurer
		adventurer.interactables_in_reach += 1
		prompt.text = "%s  %s" % ["X" if Settings.uses_gamepad() else "E", roar_action]
		prompt.show()


func _on_listener_exited(body: Node3D) -> void:
	if body == _listener:
		_listener.interactables_in_reach -= 1
		_listener = null
		prompt.hide()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
