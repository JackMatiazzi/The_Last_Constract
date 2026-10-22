class_name Projectile
extends Area3D

# a area so pega personagens; parede e checada por raio para nao atravessar em alta velocidade

const WORLD_LAYER := 1
const STICK_DEPTH := 0.15
const BREAK_RADIUS := 0.9
# sai um pouco a frente do outro portal para nao contar a passagem de novo
const PORTAL_EXIT_NUDGE := 0.05

@export var speed := 15.0
@export var max_distance := 20.0
@export var pierce := false
@export var impact_scene: PackedScene

var damage := 0.0
# so o disparo pesado quebra barris e caixotes
var breaks_props := false
var _shooter: Character
var _direction := Vector3.FORWARD
var _travelled := 0.0
var _already_hit: Array[Character] = []
var _world_query := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_world_query.collision_mask = WORLD_LAYER


# a frente da cena do projetil e -Z
func launch(shooter: Character, origin: Vector3, direction: Vector3, hit_damage: float, target_layers: int) -> void:
	_shooter = shooter
	_direction = direction
	damage = hit_damage
	collision_mask = target_layers
	global_transform = Transform3D(Basis.looking_at(direction), origin)
	reset_physics_interpolation()


# parede antes do portal segura o tiro; portal antes da parede leva o tiro para o outro lado
func _physics_process(delta: float) -> void:
	var step := speed * delta
	var target := global_position + _direction * step
	var gate := Portal.first_crossed(get_tree(), global_position, target)
	if gate:
		target = global_position.lerp(target, gate.crossing_fraction(global_position, target))
	_world_query.from = global_position
	_world_query.to = target
	var hit := get_world_3d().direct_space_state.intersect_ray(_world_query)
	if not hit.is_empty():
		if breaks_props and hit.collider is BreakableProps and _shooter_owns_the_hit():
			(hit.collider as BreakableProps).break_near(hit.position, BREAK_RADIUS)
		_leave_impact(hit.position, hit.normal)
		queue_free()
		return
	if gate:
		_pass_through(gate, target)
	else:
		global_position = target
	_travelled += step
	if _travelled >= max_distance:
		queue_free()


func _pass_through(gate: Portal, crossing: Vector3) -> void:
	var came_from := global_position
	global_transform = gate.carry(Transform3D(global_basis, crossing), came_from)
	_direction = -global_basis.z
	global_position += _direction * PORTAL_EXIT_NUDGE
	reset_physics_interpolation()


func _leave_impact(point: Vector3, normal: Vector3, holder: Node = get_parent()) -> void:
	if impact_scene == null:
		return
	var impact := impact_scene.instantiate() as ProjectileImpact
	holder.add_child(impact)
	impact.place(point, normal, _direction)


func _on_body_entered(body: Node3D) -> void:
	if body == _shooter or not body is Character:
		return
	var target := body as Character
	if target.is_dead or target in _already_hit:
		return
	_already_hit.append(target)
	if not is_instance_valid(_shooter):
		if multiplayer.is_server():
			target.take_damage(damage)
	elif _shooter.is_multiplayer_authority():
		target.take_damage(damage, _shooter)
	if not pierce:
		var point := global_position + _direction * STICK_DEPTH
		_leave_impact(point, -_direction, _stick_holder(target, point))
		queue_free()


# so o tiro de quem atirou quebra; nas outras maquinas o projetil so some
func _on_area_entered(area: Area3D) -> void:
	if not area is HealthPotion:
		return
	if _shooter_owns_the_hit():
		(area as HealthPotion).shatter()
	if not pierce:
		_leave_impact(global_position, -_direction)
		queue_free()


func _shooter_owns_the_hit() -> bool:
	return not is_instance_valid(_shooter) or _shooter.is_multiplayer_authority()


# preso ao osso mais proximo para acompanhar o alvo andando e caindo
func _stick_holder(target: Character, point: Vector3) -> Node3D:
	var skeletons := target.model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return target.model
	var skeleton := skeletons[0] as Skeleton3D
	var nearest := 0
	var nearest_distance := INF
	for bone in skeleton.get_bone_count():
		var distance := (skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin).distance_to(point)
		if distance < nearest_distance:
			nearest = bone
			nearest_distance = distance
	var attachment := BoneAttachment3D.new()
	attachment.bone_idx = nearest
	# ja na pose atual: o BoneAttachment so se atualiza no proximo passo da animacao
	attachment.transform = skeleton.get_bone_global_pose(nearest)
	skeleton.add_child(attachment)
	attachment.child_exiting_tree.connect(func(_node: Node) -> void: attachment.queue_free())
	return attachment
