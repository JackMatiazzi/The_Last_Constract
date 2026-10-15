class_name HealthPotion
extends Area3D

@export var heal_amount := 3.0
@export var model: Node3D
@export var pickup_sound: AudioStreamPlayer3D


func _ready() -> void:
	body_entered.connect(_try_heal)
	body_exited.connect(_stop_waiting)


# com a vida cheia fica esperando: se apanhar em cima da pocao, ela cura
func _try_heal(body: Node3D) -> void:
	var adventurer := body as Adventurer
	if adventurer == null or adventurer.is_dead:
		return
	if adventurer.health >= adventurer.get_max_health():
		if not adventurer.health_changed.is_connected(_on_waiting_health_changed):
			adventurer.health_changed.connect(_on_waiting_health_changed.bind(adventurer))
		return
	_stop_waiting(adventurer)
	adventurer.heal(heal_amount)
	set_deferred("monitoring", false)
	model.hide()
	pickup_sound.play()
	pickup_sound.finished.connect(queue_free)


func _on_waiting_health_changed(_current: float, _maximum: float, adventurer: Adventurer) -> void:
	_try_heal(adventurer)


func _stop_waiting(body: Node3D) -> void:
	var adventurer := body as Adventurer
	if adventurer and adventurer.health_changed.is_connected(_on_waiting_health_changed):
		adventurer.health_changed.disconnect(_on_waiting_health_changed)
