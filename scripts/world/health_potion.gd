class_name HealthPotion
extends Area3D
## vai para o inventario de quem passa por cima e quebra com golpe ou projetil. Em grupo o host
## decide quem pegou: dois jogadores na mesma pocao nao levam uma cada

const PICK_UP_REACH := 3.0

## item guardado no inventario de quem pega
@export var item: QuickItem
@export var model: Node3D
@export var pickup_sound: AudioStreamPlayer3D
@export var break_sound: AudioStreamPlayer3D

var _consumed := false


func _ready() -> void:
	body_entered.connect(_try_pick_up)
	body_exited.connect(_stop_waiting)


# com o limite cheio a pocao fica no chao esperando: gastar uma em cima dela ja pega esta
func _try_pick_up(body: Node3D) -> void:
	var adventurer := body as Adventurer
	if adventurer == null or adventurer.is_dead or not adventurer.is_multiplayer_authority() or _consumed:
		return
	if adventurer.inventory.count_of(item) >= item.max_carried:
		if not adventurer.inventory.changed.is_connected(_try_pick_up):
			adventurer.inventory.changed.connect(_try_pick_up.bind(adventurer), CONNECT_ONE_SHOT)
		return
	_request_pick_up.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)


func _stop_waiting(body: Node3D) -> void:
	var adventurer := body as Adventurer
	if adventurer and adventurer.inventory.changed.is_connected(_try_pick_up):
		adventurer.inventory.changed.disconnect(_try_pick_up)


func shatter() -> void:
	if not _consumed:
		_request_shatter.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)


@rpc("any_peer", "call_local", "reliable")
func _request_pick_up() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if _consumed or not Adventurer.peer_can_reach(get_tree(), sender, global_position, PICK_UP_REACH):
		return
	_give.rpc_id(sender)
	_vanish.rpc(false)


@rpc("authority", "call_local", "reliable")
func _give() -> void:
	var adventurer := Adventurer.of_peer(get_tree(), multiplayer.get_unique_id())
	if adventurer:
		adventurer.inventory.add(item)


@rpc("any_peer", "call_local", "reliable")
func _request_shatter() -> void:
	if not _consumed and Adventurer.peer_can_reach(get_tree(), multiplayer.get_remote_sender_id(), global_position, Character.REMOTE_HIT_REACH, false):
		_vanish.rpc(true)


@rpc("authority", "call_local", "reliable")
func _vanish(broken: bool) -> void:
	if _consumed:
		return
	_consumed = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	model.hide()
	var sound := break_sound if broken else pickup_sound
	sound.play()
	sound.finished.connect(queue_free)
