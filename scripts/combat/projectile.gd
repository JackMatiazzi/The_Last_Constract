class_name Projectile
extends Area3D

# a area so pega personagens; parede e checada por raio para nao atravessar em alta velocidade

const WORLD_LAYER := 1
const STICK_DEPTH := 0.15

@export var speed := 15.0
@export var max_distance := 20.0
@export var pierce := false
@export var impact_scene: PackedScene

var damage := 0.0
var _shooter: Character
var _direction := Vector3.FORWARD
var _travelled := 0.0
var _already_hit: Array[Character] = []
var _world_query := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_world_query.collision_mask = WORLD_LAYER


# a frente da cena do projetil e -Z
func launch(shooter: Character, origin: Vector3, direction: Vector3, hit_damage: float, target_layers: int) -> void:
	_shooter = shooter
	_direction = direction
	damage = hit_damage
	collision_mask = target_layers
	global_transform = Transform3D(Basis.looking_at(direction), origin)
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	var step := speed * delta
	_world_query.from = global_position
	_world_query.to = global_position + _direction * step
	var hit := get_world_3d().direct_space_state.intersect_ray(_world_query)
	if not hit.is_empty():
		_leave_impact(hit.position, hit.normal)
		queue_free()
		return
	global_position = _world_query.to
	_travelled += step
	if _travelled >= max_distance:
		queue_free()


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
	target.take_damage(damage, _shooter)
	if not pierce:
		var point := global_position + _direction * STICK_DEPTH
		_leave_impact(point, -_direction, _stick_holder(target, point))
		queue_free()


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
