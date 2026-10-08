class_name Enemy
extends Character

## Tempo que o corpo fica no chao antes de sumir.
@export var corpse_time := 3.0


func _ready() -> void:
	super()
	died.connect(_remove_corpse)


func _remove_corpse() -> void:
	await get_tree().create_timer(corpse_time).timeout
	queue_free()
