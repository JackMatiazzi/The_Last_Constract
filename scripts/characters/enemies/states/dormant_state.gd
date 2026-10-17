extends EnemyState

const POSE := "Skeletons_Inactive_Floor_Pose"


func enter() -> void:
	brain.stop_moving()
	enemy.perception.sight_enabled = false
	enemy.hold_pose(POSE)


func exit() -> void:
	enemy.perception.sight_enabled = true


func think(_delta: float) -> void:
	var perception := enemy.perception
	var close := perception.target != null and perception.distance_to_target() <= enemy.profile.awaken_distance
	if close:
		perception.force_awareness(perception.target)
	if close or perception.is_aware():
		brain.change_state("Awaken")
