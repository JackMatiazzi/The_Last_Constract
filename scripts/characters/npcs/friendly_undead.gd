class_name FriendlyUndead
extends Chaser
## morto-vivo que puxa papo com quem chega perto e aguenta apanhar calado. O contrato manda derrubar todo
## morto-vivo, ele tambem, entao ele conta na fase como os outros. Quando a vida fica baixa ele saca uma
## espada da cintura e briga; a cada nova queda saca mais uma, ate o estilo de tres espadas. Brigando, so
## sente uma fracao de cada golpe. Depois da primeira rodada de falas ele pede para entrar no grupo: aceito,
## segue e ajuda (o CompanionBrain cuida disso); com o fogo amigo ligado, as espadas dele pegam o grupo
## tambem. Continua contando na clausula. Quem decide reacao, fala, estilo, grupo e andar e o host

const TALK_REACH := 4.0
const LINE_TIME := 9.0
const STEP_OUT := 2.0
## depois do susto ele pula para fora da sombra; o resto do combo nao corta a fala
const STARTLE_GRACE := 2.0
## no grupo, longe assim do lider ele corre para alcancar
const FOUND_RUN_DISTANCE := 6.0
## {singular|plural} nas falas: escolhe pelo tamanho do grupo
const GROUP_FORM := "\\{([^|}]*)\\|([^}]*)\\}"
const ADVENTURERS_LAYER := 2
const UNDEAD_LAYER := 4
## perdido longe assim do lider, quando o grupo sobe de andar ele aparece na frente, como sempre
const LOST_ON_FLOOR_CHANGE := 20.0

## um ponto por andar; quando o grupo chega ao pe de cada escada ele aparece "perdido" no andar seguinte
@export var spots: Array[Marker3D] = []
## Area3D no pe de cada descida; a primeira leva ao segundo ponto, e assim por diante.
@export var floor_triggers: Array[Area3D] = []
@export var speech: Label3D
## Acende quando ele sai do escuro.
@export var lantern: OmniLight3D
@export var talk_area: Area3D
@export var prompt: Label3D
@export var talk_action := "Conversar"
@export_group("Estilos")
## estilo N comeca quando a vida chega ao limite N; cada estilo tem o proprio golpe e saca a espada N
@export var style_thresholds := PackedFloat32Array([3.0, 2.0, 1.0])
@export var style_attacks: Array[Attack] = []
@export var drawn_blades: Array[Node3D] = []
@export var sheathed_blades: Array[Node3D] = []
@export var style_lines := PackedStringArray()
## Fracao de cada golpe que ele sente depois de sacar as espadas.
@export var fighting_damage_factor := 0.25
@export_group("Falas")
## Dita no primeiro golpe no escuro, que so o assusta.
@export var startle_line := ""
## a primeira conversa, em qualquer andar: depois dela o nome dele vale no historico de dano e nos avisos
@export var introduction := ""
## Nome dele depois da apresentacao, no historico de dano e nos avisos.
@export var known_name := ""
## por andar: a primeira e o cumprimento; as outras voltam quando nao ha assunto novo
@export var floor_lines: Array[PackedStringArray] = []
## assuntos ligados ao que o grupo fez e ao que falta, na ordem de prioridade
@export var topics: Array[DialogueTopic] = []
## Ditas em rodizio quando apanha sem brigar.
@export var hurt_lines := PackedStringArray()
@export var death_line := ""
@export_group("Companheiro")
@export var companion: CompanionBrain
@export var accept_action := "Aceitar"
@export var decline_action := "Recusar"
## Pedido para entrar no grupo, depois da primeira rodada de falas do andar.
@export var invite_line := ""
## Dita quando aceitam.
@export var accept_line := ""
## Dita quando recusam; ele pergunta de novo no andar seguinte.
@export var decline_line := ""
## No grupo, dita quando alguem do grupo bate nele.
@export var ally_hurt_line := ""
## Dita quando uma armadilha o pega (ela nao fere).
@export var trap_line := ""
## Dita quando, perdido, ele aparece antes do grupo no andar seguinte.
@export var ahead_line := ""

var in_the_dark := true
var is_introduced := false
var style := 0
var is_companion := false
var awaiting_answer := false
var floor_index := 0
var _greeted := false
var _floor_line := 0
var _topic_line := {}
var _hurt_index := 0
var _startled_until := 0.0
var _round_done := false
var _declined_floor := -1
var _group_form := RegEx.create_from_string(GROUP_FORM)
var _listener: Adventurer
var _hide_tween: Tween

@onready var health_bar: HealthBar3D = $HealthBar3D


func _ready() -> void:
	super()
	assert(speech and lantern and talk_area and prompt and companion, "FriendlyUndead: aponte speech, lantern, talk_area, prompt e companion")
	var styles := style_thresholds.size()
	assert(style_attacks.size() == styles and drawn_blades.size() == styles and sheathed_blades.size() == styles
			and style_lines.size() == styles, "FriendlyUndead: um golpe, uma espada sacada, uma na cintura e uma fala por estilo")
	add_to_group(UndeadCensus.GROUP)
	speech.hide()
	prompt.hide()
	lantern.visible = false
	talk_area.body_entered.connect(_on_listener_entered)
	talk_area.body_exited.connect(_on_listener_exited)
	for index in floor_triggers.size():
		floor_triggers[index].body_entered.connect(_on_floor_reached.bind(index + 1))
	if not spots.is_empty():
		global_transform = spots[0].global_transform


func get_display_name() -> String:
	return known_name if is_introduced and not known_name.is_empty() else "Espadachim perdido"


func is_hunting() -> bool:
	return style > 0


func wants_to_run() -> bool:
	return style >= 2 or (is_companion and companion.far_from_leader(FOUND_RUN_DISTANCE))


func _physics_process(delta: float) -> void:
	if is_multiplayer_authority() and is_companion and style == 0 and not is_dead:
		companion.tick(delta)
	super(delta)


func _get_move_direction() -> Vector3:
	if is_companion and style == 0 and is_multiplayer_authority():
		return companion.move_direction()
	return super()


## Fala para todas as maquinas; e por aqui que o CompanionBrain fala.
func speak(line: String) -> void:
	if not line.is_empty():
		_say.rpc(line)


## Golpe do companheiro no inimigo escolhido pelo CompanionBrain.
func strike(enemy: Character) -> void:
	_look_toward(enemy.global_position)
	attack.try_attack(self)


## o primeiro golpe no escuro so o assusta; depois ele aguenta reclamando, ate a vida baixar e ele sacar
func take_damage(amount: float, source: Node3D = null) -> void:
	if not is_multiplayer_authority() or is_dead:
		super(amount, source)
		return
	if in_the_dark:
		_step_out_of_the_dark(source as Adventurer)
		return
	if _now() < _startled_until:
		return
	# armadilha nao fere ele, em grupo ou nao; so arranca a reclamacao
	if source and not source is Character:
		speak(trap_line)
		return
	super(amount * (fighting_damage_factor if style > 0 else 1.0), source)
	if is_dead:
		return
	var next_style := _style_for(health)
	if next_style > style:
		_draw_swords.rpc(next_style)
		_target = source as Adventurer
	elif style == 0 and is_companion:
		speak(ally_hurt_line)
	elif style == 0 and not hurt_lines.is_empty():
		_say.rpc(hurt_lines[_hurt_index % hurt_lines.size()])
		_hurt_index += 1


func _style_for(current_health: float) -> int:
	var reached := 0
	for threshold in style_thresholds:
		if current_health <= threshold:
			reached += 1
	return reached


@rpc("authority", "call_local", "reliable")
func _draw_swords(new_style: int) -> void:
	if is_companion:
		_leave_group()
	style = new_style
	attack = style_attacks[style - 1]
	for index in style:
		drawn_blades[index].show()
		sheathed_blades[index].hide()
	health_bar.set_bar_visible(true)
	lantern.visible = true
	prompt.hide()
	_play_action_locally("Taunt", 1.4, 0.0, 0.8)
	_say(style_lines[style - 1])


func _step_out_of_the_dark(toward: Adventurer) -> void:
	in_the_dark = false
	_startled_until = _now() + STARTLE_GRACE
	_show_lantern.rpc()
	_say.rpc(startle_line)
	var target := global_position
	if toward:
		target += (toward.global_position - global_position).slide(Vector3.UP).limit_length(STEP_OUT)
		_look_toward(toward.global_position)
	create_tween().tween_property(self, "global_position", target, 0.8)


func _die_locally() -> void:
	super()
	if _hide_tween:
		_hide_tween.kill()
	speech.text = for_group(death_line)
	speech.show()
	prompt.hide()


func _unhandled_input(event: InputEvent) -> void:
	if _listener == null or is_dead or style > 0 or _listener.is_dead:
		return
	if awaiting_answer and (event.is_action_pressed("interact") or event.is_action_pressed("decline")):
		_request_answer.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, event.is_action_pressed("interact"))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		_request_talk.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)
		get_viewport().set_input_as_handled()


@rpc("any_peer", "call_local", "reliable")
func _request_talk() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if is_dead or style > 0 or not Adventurer.peer_can_reach(get_tree(), sender, global_position, TALK_REACH):
		return
	var speaker := Adventurer.of_peer(get_tree(), sender)
	_look_toward(speaker.global_position)
	if in_the_dark:
		in_the_dark = false
		_show_lantern.rpc()
	if is_companion and companion.is_lost:
		companion.found()
		return
	var line := next_line()
	if not line.is_empty():
		_say.rpc(line)


@rpc("any_peer", "call_local", "reliable")
func _request_answer(accepted: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not awaiting_answer or is_dead or style > 0 or not Adventurer.peer_can_reach(get_tree(), sender, global_position, TALK_REACH):
		return
	if accepted:
		_net_join.rpc(sender)
	else:
		_net_decline.rpc()


@rpc("authority", "call_local", "reliable")
func _net_invite() -> void:
	awaiting_answer = true
	_refresh_prompt()


@rpc("authority", "call_local", "reliable")
func _net_join(leader_peer: int) -> void:
	awaiting_answer = false
	is_companion = true
	drawn_blades[0].show()
	sheathed_blades[0].hide()
	attack = style_attacks[0]
	_aim_blades(UNDEAD_LAYER | (ADVENTURERS_LAYER if Net.friendly_fire else 0))
	if is_multiplayer_authority():
		companion.start(Adventurer.of_peer(get_tree(), leader_peer))
	_refresh_prompt()
	_say(accept_line)


@rpc("authority", "call_local", "reliable")
func _net_decline() -> void:
	awaiting_answer = false
	_declined_floor = floor_index
	_refresh_prompt()
	_say(decline_line)


# virou a briga: sai do grupo e as espadas voltam a so querer o grupo
func _leave_group() -> void:
	is_companion = false
	companion.stop()
	_aim_blades(ADVENTURERS_LAYER)


func _aim_blades(mask: int) -> void:
	for style_attack in style_attacks:
		(style_attack.get_node("Hitbox") as Area3D).collision_mask = mask


## cumprimento do andar, depois o assunto mais importante que ja vale e ainda tem fala, depois as do andar
func next_line() -> String:
	if not is_introduced and not introduction.is_empty():
		_introduce.rpc()
		return introduction
	if _round_done and not is_companion and not awaiting_answer and _declined_floor != floor_index and not invite_line.is_empty():
		_net_invite.rpc()
		return invite_line
	var lines: PackedStringArray = floor_lines[floor_index] if floor_index < floor_lines.size() else PackedStringArray()
	if not _greeted and not lines.is_empty():
		_greeted = true
		return lines[0]
	for index in topics.size():
		var topic := topics[index]
		var said: int = _topic_line.get(index, 0)
		if said < topic.lines.size() and topic.holds(self):
			_topic_line[index] = said + 1
			return topic.lines[said].replace("{valor}", str(topic.read(self)))
	if lines.size() <= 1:
		_round_done = true
		return lines[0] if lines.size() == 1 else ""
	_floor_line = _floor_line % (lines.size() - 1) + 1
	if _floor_line == lines.size() - 1:
		_round_done = true
	return lines[_floor_line]


# sozinho ou perdido longe do grupo, ele aparece no andar seguinte antes de todo mundo; no grupo, vai junto
func _on_floor_reached(body: Node3D, new_floor: int) -> void:
	if not multiplayer.is_server() or not body is Adventurer or is_dead or style > 0 or new_floor <= floor_index or new_floor >= spots.size():
		return
	floor_index = new_floor
	_greeted = false
	_floor_line = 0
	_round_done = false
	in_the_dark = false
	_show_lantern.rpc()
	if is_companion and not companion.far_from_leader(LOST_ON_FLOOR_CHANGE):
		return
	global_transform = spots[new_floor].global_transform
	reset_physics_interpolation()
	if is_companion:
		companion.found(true)
		speak(ahead_line)


func for_group(line: String) -> String:
	var form := 1 if get_tree().get_nodes_in_group("players").size() <= 1 else 2
	return _group_form.sub(line, "$%d" % form, true)


@rpc("authority", "call_local", "reliable")
func _say(line: String) -> void:
	speech.text = for_group(line)
	speech.show()
	if _hide_tween:
		_hide_tween.kill()
	_hide_tween = create_tween()
	_hide_tween.tween_interval(LINE_TIME)
	_hide_tween.tween_callback(speech.hide)


@rpc("authority", "call_local", "reliable")
func _introduce() -> void:
	is_introduced = true


@rpc("authority", "call_local", "reliable")
func _show_lantern() -> void:
	lantern.visible = true


# so quem esta perto ve o aviso; tocar E conversa em vez de beber
func _on_listener_entered(body: Node3D) -> void:
	var adventurer := body as Adventurer
	if adventurer and adventurer.is_multiplayer_authority() and _listener == null:
		_listener = adventurer
		adventurer.interactables_in_reach += 1
		_refresh_prompt()


func _refresh_prompt() -> void:
	if _listener == null or style > 0 or is_dead:
		prompt.hide()
		return
	var gamepad := Settings.uses_gamepad()
	if awaiting_answer:
		prompt.text = "%s  %s      %s  %s" % ["X" if gamepad else "E", accept_action, "B" if gamepad else "F", decline_action]
	else:
		prompt.text = "%s  %s" % ["X" if gamepad else "E", talk_action]
	prompt.show()


func _on_listener_exited(body: Node3D) -> void:
	if body == _listener:
		_listener.interactables_in_reach -= 1
		_listener = null
		prompt.hide()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
