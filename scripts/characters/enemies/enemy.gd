class_name Enemy
extends Character

@export var profile: EnemyProfile
@export var ai_enabled := true
@export var start_dormant := false
@export var start_rising := false
@export var corpse_time := 6.0
@export var sink_time := 1.5
@export var remains_scene: PackedScene
@export var rise_sound: AudioStreamPlayer3D

var _corpse_timeline: Tween

@onready var perception: Perception = $Perception
@onready var brain: EnemyBrain = $EnemyBrain
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var health_bar: HealthBar3D = $HealthBar3D


func _ready() -> void:
	super()
	assert(profile, "%s: aponte um EnemyProfile no Inspector" % name)
	died.connect(brain.change_state.bind("Dead"))
	died.connect(_clean_up_corpse)
	health_bar.visible = not start_dormant
	if start_rising:
		perception.acquire_target()
		if perception.target:
			perception.force_awareness(perception.target)
		brain.change_state("Awaken")
	else:
		brain.change_state("Dormant" if start_dormant else "Idle")


func _physics_process(delta: float) -> void:
	if ai_enabled and not is_dead:
		brain.physics_step(delta)
	else:
		brain.stop_moving()
	super(delta)
	if brain.has_look_point and not is_busy and not is_dead:
		_face(brain.look_point - global_position, delta)


func take_damage(amount: float, source: Node3D = null) -> void:
	super(amount, source)
	if is_dead:
		return
	perception.acquire_target()
	if perception.target != null:
		perception.force_awareness(perception.target)
	if brain.current_state_name == "Dormant" and ai_enabled:
		brain.change_state("Awaken")


func _can_flinch() -> bool:
	return brain.current_state_name not in ["Dormant", "Awaken"]


func _clean_up_corpse() -> void:
	_corpse_timeline = create_tween()
	_corpse_timeline.tween_interval(corpse_time)
	_corpse_timeline.tween_callback(_leave_remains)
	_corpse_timeline.tween_property(self, "global_position:y", global_position.y - 1.2, sink_time)
	_corpse_timeline.tween_callback(queue_free)


func absorb_into(point: Vector3, duration: float) -> void:
	if _corpse_timeline:
		_corpse_timeline.kill()
	var timeline := create_tween().set_parallel()
	timeline.tween_property(self, "global_position", point + Vector3.DOWN * 1.2, duration).set_ease(Tween.EASE_IN)
	timeline.chain().tween_callback(queue_free)


func _leave_remains() -> void:
	if remains_scene == null:
		return
	var remains := remains_scene.instantiate() as Node3D
	remains.position = global_position
	remains.rotation.y = model.global_rotation.y
	get_parent().add_child(remains)


func _get_move_direction() -> Vector3:
	return brain.desired_direction if ai_enabled else Vector3.ZERO


func _wants_to_run() -> bool:
	return ai_enabled and brain.wants_run
