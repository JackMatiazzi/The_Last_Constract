class_name RangedAttack
extends Attack

@export var projectile_scene: PackedScene
@export_flags_3d_physics var target_layers := 4

@onready var muzzle: Marker3D = $Muzzle


func _perform(attacker: Character, total_damage: float) -> void:
	var projectile := projectile_scene.instantiate() as Projectile
	attacker.get_parent().add_child(projectile)
	var direction := (attacker.get_aim_point() - muzzle.global_position).normalized()
	projectile.launch(attacker, muzzle.global_position, direction, total_damage, target_layers)
