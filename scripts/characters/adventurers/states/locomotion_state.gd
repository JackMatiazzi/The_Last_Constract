extends AdventurerState
## Idle, Walk, Run e Air so mudam a animacao; a passada acompanha a velocidade em Walk e Run

@export var animation := Character.ANIM_IDLE
## a passada acompanha a velocidade real
@export var follows_stride := false


func play(_direction: Vector3) -> void:
	adventurer.play_locomotion(animation, adventurer.stride_speed_scale() if follows_stride else 1.0)
