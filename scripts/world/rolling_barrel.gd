class_name RollingBarrel
extends RigidBody3D
## barril solto por armadilha: atropela quem estiver no caminho enquanto rola rapido. Cada maquina
## simula o proprio barril, mas o dano e decidido so pelo host, como qualquer golpe sem dono

## devagar o barril so encosta; nao fere
const MIN_HIT_SPEED := 2.5

## Dano em quem ele atropela rapido o bastante.
@export var damage := 2.0
## Empurrao de quem e atropelado.
@export var knockback := 7.0
## Some depois deste tempo.
@export var lifetime := 8.0

## a armadilha que soltou o barril; vira a causa no historico de dano
var cause: Node3D
var _hit: Array[Character] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)


func _on_body_entered(body: Node3D) -> void:
	var victim := body as Character
	if victim == null or victim.is_dead or victim in _hit or linear_velocity.length() < MIN_HIT_SPEED:
		return
	_hit.append(victim)
	if victim.is_multiplayer_authority():
		victim.velocity += linear_velocity.normalized() * knockback
	if multiplayer.is_server():
		victim.take_damage(damage, cause)
