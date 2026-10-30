extends AdventurerState


func enter() -> void:
	adventurer.is_blocking = true


func exit() -> void:
	adventurer.is_blocking = false


## apanhar por tras derruba a guarda: a reacao de dano substitui a animacao do escudo
func next_state(direction: Vector3) -> String:
	if adventurer.animation_player.current_animation != adventurer.block.animation:
		return machine.locomotion_state(direction)
	adventurer.face_camera()
	return String(name)
