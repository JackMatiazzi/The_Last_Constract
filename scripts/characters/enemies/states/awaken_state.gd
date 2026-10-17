class_name AwakenState
extends EnemyState

const ANIMATION := "Skeletons_Awaken_Floor"


func enter() -> void:
	enemy.health_bar.show()
	enemy.play_action(ANIMATION)
	if enemy.rise_sound:
		enemy.rise_sound.play()


func think(_delta: float) -> void:
	if enemy.is_busy:
		return
	brain.change_state("Chase" if _has_live_target() else "Idle")
