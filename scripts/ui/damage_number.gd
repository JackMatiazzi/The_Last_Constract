class_name DamageNumber
extends Label3D

const RISE := 0.9
const SIDE_DRIFT := 0.35
const DURATION := 0.8


func show_text(message: String, color: Color) -> void:
	text = message
	modulate = color
	scale = Vector3.ONE * 0.4

	var drift := Vector3(randf_range(-SIDE_DRIFT, SIDE_DRIFT), RISE, 0.0)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", position + drift, DURATION).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, DURATION * 0.4).set_delay(DURATION * 0.6)
	tween.chain().tween_callback(queue_free)
