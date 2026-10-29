class_name UndeadCensus
extends Node
## conta os mortos-vivos de pe na fase e mostra na HUD. Todo morto-vivo entra na conta, inclusive o
## espadachim que nunca revida: o numero que nao chega a zero e a pista de que o contrato quer ele tambem

const GROUP := "undead"
const REFRESH_TIME := 0.5

@export var hud: Hud

var _refresh_left := 0.0


func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left > 0.0:
		return
	_refresh_left = REFRESH_TIME
	hud.set_objective("Mortos-vivos restantes: %d" % remaining())


func remaining() -> int:
	return get_tree().get_nodes_in_group(GROUP).filter(func(undead: Character) -> bool: return not undead.is_dead).size()
