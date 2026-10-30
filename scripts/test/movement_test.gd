extends Node3D

# K causa dano no jogador para testar morte e buffs

const TEST_DAMAGE := 3.0

@onready var session: GameSession = $GameSession


func _unhandled_input(event: InputEvent) -> void:
	# Verifica se a tecla 'K' foi pressionada (ignora eventos de repetição/pressionado contínuo)
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_K:
		session.player.take_damage(TEST_DAMAGE)
