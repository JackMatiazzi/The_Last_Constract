class_name Portal
extends Area3D

# metade de um par: quem entra aqui sai na frente do outro portal;
# cada maquina so move o proprio aventureiro, e a rede leva a posicao nova aos outros

const TRAVEL_COOLDOWN := 0.5
# sai a frente do portal de destino, longe o bastante para nao entrar nele de volta
const EXIT_OFFSET := 1.4
const CLOSE_TIME := 0.4
const WORLD_LAYER := 1
const VIEW_SCALE := 0.5
# folga do plano de corte: a camera do outro lado nao enxerga o que esta atras do portal
const NEAR_MARGIN := 0.3
const TURN_AROUND := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)

@export var lifetime := 12.0
@export var visual: Node3D
@export var travel_sound: AudioStreamPlayer3D
@export var veil: MeshInstance3D
@export var view: SubViewport
@export var view_camera: Camera3D

var link: Portal

var _showing := false


func _ready() -> void:
	assert(visual and travel_sound and veil and view and view_camera, "Portal: aponte os nos exportados")
	body_entered.connect(_on_body_entered)
	var timeline := create_tween()
	timeline.tween_interval(lifetime)
	timeline.tween_property(visual, "scale", Vector3.ZERO, CLOSE_TIME)
	timeline.tween_callback(queue_free)


func is_linked() -> bool:
	return link != null and is_instance_valid(link)


func _process(_delta: float) -> void:
	var eye := get_viewport().get_camera_3d()
	var showing := is_linked() and eye != null
	if showing != _showing:
		_showing = showing
		veil.set_instance_shader_parameter(&"linked", showing)
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if showing else SubViewport.UPDATE_DISABLED
	if showing:
		_follow(eye)


# a camera do outro lado repete a posicao do olho em relacao a este portal; de qualquer lado
# que se olhe, a imagem e a saida (a frente do outro portal)
func _follow(eye: Camera3D) -> void:
	var wanted := Vector2i(Vector2(get_viewport().get_visible_rect().size) * VIEW_SCALE)
	if view.size != wanted:
		view.size = wanted
	var relative := global_transform.affine_inverse() * eye.global_transform
	if relative.origin.z < 0.0:
		relative = TURN_AROUND * relative
	view_camera.global_transform = link.global_transform * relative
	view_camera.fov = eye.fov
	view_camera.near = maxf(eye.near, absf(relative.origin.z) - NEAR_MARGIN)


# recarga e som em todas as maquinas; so o dono do aventureiro move o boneco
func _on_body_entered(body: Node3D) -> void:
	var traveler := body as Adventurer
	if traveler == null or traveler.is_dead or not is_linked():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if traveler.get_meta(&"portal_ready_at", 0.0) > now:
		return
	traveler.set_meta(&"portal_ready_at", now + TRAVEL_COOLDOWN)
	travel_sound.play()
	if traveler.is_multiplayer_authority():
		# fora do meio da consulta de fisica que disparou o sinal
		_send_through.call_deferred(traveler, link.exit_point())


func _send_through(traveler: Adventurer, point: Vector3) -> void:
	if is_instance_valid(traveler):
		traveler.global_position = point
		traveler.reset_physics_interpolation()


# a frente do portal, no chao; com parede no caminho sai no proprio portal (a recarga evita voltar)
func exit_point() -> Vector3:
	var space := get_world_3d().direct_space_state
	var ahead := global_position - global_basis.z * EXIT_OFFSET
	var wall := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, ahead + Vector3.UP, WORLD_LAYER)
	if not space.intersect_ray(wall).is_empty():
		ahead = global_position
	var ground := PhysicsRayQueryParameters3D.create(ahead + Vector3.UP * 1.5, ahead + Vector3.DOWN * 3.0, WORLD_LAYER)
	var hit := space.intersect_ray(ground)
	return hit.position if hit else ahead
