class_name Summoner
extends Node3D

@export var minion_scene: PackedScene
## tempo entre as invocacoes
@export var interval := 9.0
## lacaios por invocacao
@export var per_cast := 2
## maximo de lacaios vivos ao mesmo tempo
@export var max_alive := 4
## distancia dos lacaios em volta de quem invoca
@export var radius := 2.5
@export var animation := "Spellcast_Summon"
## espera entre o gesto e os lacaios aparecerem
@export var raise_delay := 0.7
@export var sound: AudioStreamPlayer3D

var minions: Array[Enemy] = []
var _cooldown_left := 0.0
var _raised := 0

@onready var owner_enemy: Enemy = get_parent() as Enemy


func _ready() -> void:
	_cooldown_left = interval * 0.5
	owner_enemy.died.connect(_release_minions)


func _physics_process(delta: float) -> void:
	if not owner_enemy.is_multiplayer_authority() or owner_enemy.is_dead or not _is_hunting():
		return
	_cooldown_left -= delta
	if _cooldown_left <= 0.0 and owner_enemy.can_act() and _alive_count() < max_alive:
		summon()


func summon() -> void:
	_cooldown_left = interval
	owner_enemy.play_action(animation)
	if sound:
		sound.play()
	await get_tree().create_timer(raise_delay).timeout
	if owner_enemy.is_dead:
		return
	var count := mini(per_cast, max_alive - _alive_count())
	var spots := PackedVector3Array()
	for i in count:
		var angle := TAU * i / count + randf() * 0.6
		spots.append(owner_enemy.global_position + Vector3(cos(angle), 0, sin(angle)) * radius)
	if owner_enemy.is_broadcasting():
		_net_raise_minions.rpc(spots, _raised)
	_raise_minions(spots, _raised)


@rpc("authority", "reliable")
func _net_raise_minions(spots: PackedVector3Array, first_index: int) -> void:
	_raise_minions(spots, first_index)


# nome fixo para o lacaio ter o mesmo caminho em todas as maquinas
func _raise_minions(spots: PackedVector3Array, first_index: int) -> void:
	for i in spots.size():
		var minion := minion_scene.instantiate() as Enemy
		minion.name = "%sMinion%d" % [owner_enemy.name, first_index + i]
		minion.position = owner_enemy.get_parent().to_local(spots[i])
		minion.start_rising = true
		owner_enemy.get_parent().add_child(minion)
		minions.append(minion)
	_raised = first_index + spots.size()


func _is_hunting() -> bool:
	return owner_enemy.brain.current_state_name in ["Chase", "Attack"]


func _alive_count() -> int:
	minions = minions.filter(func(m: Enemy) -> bool: return is_instance_valid(m) and not m.is_dead)
	return minions.size()


func _release_minions() -> void:
	if not owner_enemy.is_multiplayer_authority():
		return
	for minion in minions:
		if is_instance_valid(minion) and not minion.is_dead:
			minion.take_damage(minion.health)
