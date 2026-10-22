extends AdventurerState


func next_state(_direction: Vector3) -> String:
	return String(name)


func accepts_input() -> bool:
	return false
