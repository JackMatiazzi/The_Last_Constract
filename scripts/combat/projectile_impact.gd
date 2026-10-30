class_name ProjectileImpact
extends Node3D

## quanto tempo a marca fica
@export var lifetime := 5.0
## tempo sumindo, no fim
@export var fade_time := 0.6
## encosta a marca na superficie atingida
@export var align_to_surface := true
@export var flash: OmniLight3D


func place(point: Vector3, normal: Vector3, direction: Vector3) -> void:
	if align_to_surface:
		global_transform = Transform3D(_basis_facing_out(normal), point + normal * 0.01)
	else:
		global_transform = Transform3D(Basis.looking_at(direction), point)
	reset_physics_interpolation()
	if flash:
		create_tween().tween_property(flash, "light_energy", 0.0, 0.4)
	var timeline := create_tween()
	timeline.tween_interval(lifetime)
	timeline.tween_property(self, "scale", Vector3.ZERO, fade_time)
	timeline.tween_callback(queue_free)


# o Decal projeta pelo eixo Y, entao Y vai na normal
func _basis_facing_out(normal: Vector3) -> Basis:
	var reference := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var x := reference.cross(normal).normalized()
	return Basis(x, normal, x.cross(normal).normalized())
