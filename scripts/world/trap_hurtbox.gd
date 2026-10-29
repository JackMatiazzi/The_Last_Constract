class_name TrapHurtbox
extends Area3D
## parte que fere de uma armadilha: cada golpe fere cada um uma vez so, aventureiro ou morto-vivo.
## Cada maquina so fere quem ela controla, como o resto do dano do jogo

## Dano de cada golpe.
@export var damage := 2.0
@export var cause := "Armadilha"
## desligada (espinhos baixos) ninguem se fere ao entrar
@export var active := true

var _hit: Array[Character] = []


func _ready() -> void:
	body_entered.connect(_hurt)


func get_display_name() -> String:
	return cause


## golpe novo: quem ja foi ferido no anterior pode ser de novo, e quem ja esta dentro e ferido agora
func strike() -> void:
	active = true
	_hit.clear()
	for body in get_overlapping_bodies():
		_hurt(body)


func stop() -> void:
	active = false


func _hurt(body: Node3D) -> void:
	var victim := body as Character
	if not active or victim == null or victim.is_dead or victim in _hit or not victim.is_multiplayer_authority():
		return
	_hit.append(victim)
	victim.take_damage(damage, self)
