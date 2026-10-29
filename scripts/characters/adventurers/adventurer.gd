class_name Adventurer
extends Character

signal energy_short(pool: EnergyPool)
signal ability_changed

const ATTACK_BUFFER := 0.2
const PITCH_MIN := deg_to_rad(-60.0)
const PITCH_MAX := deg_to_rad(30.0)
const CAMERA_HEIGHT := 1.5
const BASE_MOUSE_SENSITIVITY := 0.003
const BASE_STICK_SPEED := 2.8
const MOVE_DEADZONE := 0.1
const AIM_RANGE := 40.0
const AIM_LAYERS := 1 | 4
const REVIVE_RANGE := 2.2
const REVIVE_HEALTH_FRACTION := 0.5
# segurar o ataque alem disso vira golpe pesado; soltar antes e golpe rapido
const HEAVY_HOLD_TIME := 0.35
# segurar interagir bebe o item selecionado; o tempo segurando e o gole, exposto aos golpes
const DRINK_HOLD_TIME := 0.6
const REVIVE_READY_COLOR := Color(1.0, 0.88, 0.6)
const REVIVE_MISSING_COLOR := Color(0.62, 0.6, 0.58)
const MAX_ENERGY := 100.0
# ritmo de recarga comum a todos; cada classe ajusta com os multiplicadores
const BASE_REGEN := 30.0
# depois de zerar a estamina correndo, so volta a correr com a barra neste ponto
const RUN_RECOVER_FRACTION := 0.3

@export var camera_follow_speed := 14.0
@export var push_force := 120.0
@export var secondary_attack: Attack
@export var block: BlockAbility
# a roda para cima percorre esta lista; vazia = so o ataque principal
@export var abilities: Array[Attack] = []

# todos tem estamina (correr, escudo, golpes fisicos); quem usa mana paga os feiticos com ela
@export_group("Energia")
@export var uses_mana := false
@export var stamina_regen_multiplier := 1.0
@export var mana_regen_multiplier := 1.0
@export var stamina_regen_delay := 0.6
@export var mana_regen_delay := 1.0
# custo do ataque, pago da mana se o aventureiro usa mana, senao da estamina
@export var quick_cost := 15.0
@export var heavy_cost := 35.0
# por segundo de corrida
@export var run_cost := 12.0
# segurar o escudo cansa devagar; cada golpe defendido custa mais; sem estamina a guarda quebra
@export var block_cost := 6.0
@export var block_hit_cost := 12.0
# o urro que o esqueletinho tanto pede (so o Barbarian)
@export var roars := false

var is_blocking := false
# menu aberto em grupo: o mundo nao pausa, mas o boneco para de obedecer. Soltar um botao com o
# menu aberto nao chega ao boneco, entao travar ja solta o escudo e cancela o que estava segurado
var input_locked := false:
	set(locked):
		input_locked = locked
		if locked:
			_attack_hold = -1.0
			_interact_hold = -1.0
			release_secondary()
# so existe com pocao no inventario; o aviso aparece mesmo sem pocao
var revive_target: Adventurer
# baus e afins ao alcance: tocar E interage com eles em vez de comecar a beber
var interactables_in_reach := 0
var stamina: EnergyPool
# null em quem nao usa mana
var mana: EnergyPool

# o clique do analogico liga a corrida ate o boneco parar; no teclado corre enquanto segura Espaco
var _run_toggled := false
var _attack_buffer_left := 0.0
# -1 = botao solto; senao, ha quanto tempo o ataque esta segurado
var _attack_hold := -1.0
var _interact_hold := -1.0
var _hinted_ally: Adventurer
var _ability_index := 0
var _exhausted := false
var _aim_query := PhysicsRayQueryParameters3D.new()

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var name_tag: Label3D = $NameTag
@onready var health_bar: HealthBar3D = $HealthBar3D
@onready var revive_hint: Label3D = $ReviveHint
@onready var state_machine: AdventurerStateMachine = $StateMachine
@onready var inventory: QuickInventory = $Inventory


func _ready() -> void:
	super()
	add_to_group("players")
	died.connect(state_machine.change_state.bind("Dead"))
	if abilities.is_empty() and attack:
		abilities.append(attack)
	stamina = EnergyPool.new(MAX_ENERGY, BASE_REGEN * stamina_regen_multiplier, stamina_regen_delay)
	if uses_mana:
		mana = EnergyPool.new(MAX_ENERGY, BASE_REGEN * mana_regen_multiplier, mana_regen_delay)
	_aim_query.collision_mask = AIM_LAYERS
	camera_pivot.global_position = global_position + Vector3.UP * CAMERA_HEIGHT
	if not is_multiplayer_authority():
		camera.current = false
		camera_pivot.process_mode = Node.PROCESS_MODE_DISABLED
		name_tag.show()
		health_bar.set_bar_visible(true)
	revived.connect(_on_revived)
	if Net.is_coop() and Net.friendly_fire:
		_allow_friendly_fire()


# a camera e top_level e segue a posicao interpolada, senao treme entre os passos de fisica
func _process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	var target := get_global_transform_interpolated().origin + Vector3.UP * CAMERA_HEIGHT
	camera_pivot.global_position = camera_pivot.global_position.lerp(target, minf(camera_follow_speed * delta, 1.0))
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look != Vector2.ZERO and not is_dead and _has_control():
		_rotate_camera(look * BASE_STICK_SPEED * Settings.stick_sensitivity * delta)


func _physics_process(delta: float) -> void:
	super(delta)
	if not is_multiplayer_authority():
		return
	_push_bodies(delta)
	_attack_buffer_left -= delta
	if _run_toggled and _read_move_input().length() < MOVE_DEADZONE:
		_run_toggled = false
	if not is_dead:
		if not _drain_for_running(delta) and not _drain_for_blocking(delta):
			stamina.regenerate(delta)
		if mana:
			mana.regenerate(delta)
	_track_attack_hold(delta)
	_track_interact_hold(delta)
	if _attack_buffer_left > 0.0 and attack_toward_camera():
		_attack_buffer_left = 0.0
	_update_revive_target()


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or input_locked or not state_machine.current_state.accepts_input():
		return
	var has_control := _has_control()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not Settings.uses_gamepad():
		_rotate_camera(event.relative * BASE_MOUSE_SENSITIVITY * Settings.mouse_sensitivity)
	elif event.is_action_pressed("attack") and has_control:
		_attack_hold = 0.0
	elif event.is_action_released("attack"):
		if _attack_hold >= 0.0:
			_attack_hold = -1.0
			request_attack()
	elif event.is_action_pressed("secondary") and has_control and not is_blocking:
		use_secondary()
	elif event.is_action_released("secondary"):
		release_secondary()
	elif event.is_action_pressed("run") and event is InputEventJoypadButton:
		_run_toggled = true
	elif event.is_action_pressed("interact"):
		if revive_target:
			revive_ally()
			get_viewport().set_input_as_handled()
		elif interactables_in_reach == 0:
			_interact_hold = 0.0
	elif event.is_action_pressed("next_ability") and has_control:
		next_ability()
	elif event.is_action_pressed("next_item") and has_control:
		inventory.select_next()


# o aventureiro que o jogador peer_id controla; null se ele saiu ou ainda nao nasceu
static func of_peer(tree: SceneTree, peer_id: int) -> Adventurer:
	for adventurer: Adventurer in tree.get_nodes_in_group("players"):
		if adventurer.get_multiplayer_authority() == peer_id:
			return adventurer
	return null


# pedido vindo da rede so vale de quem esta perto do que quer mexer; tiro pode chegar depois de
# o atirador cair, entao quem confere um tiro passa alive_only = false
static func peer_can_reach(tree: SceneTree, peer_id: int, point: Vector3, reach: float, alive_only := true) -> bool:
	var adventurer := of_peer(tree, peer_id)
	if adventurer == null or (alive_only and adventurer.is_dead):
		return false
	return adventurer.global_position.distance_to(point) <= reach


func set_display_name(display_name: String) -> void:
	name_tag.text = display_name


func get_display_name() -> String:
	return name_tag.text if not name_tag.text.is_empty() else name


func _allow_friendly_fire() -> void:
	_aim_query.collision_mask |= collision_layer
	for chosen: Attack in abilities + [secondary_attack]:
		if chosen is MeleeAttack:
			chosen.get_node("Hitbox").collision_mask |= collision_layer
		elif chosen is RangedAttack:
			chosen.target_layers |= collision_layer


func _on_revived() -> void:
	state_machine.change_state("Idle")
	stamina.refill()
	if mana:
		mana.refill()
	if not is_multiplayer_authority():
		health_bar.set_bar_visible(true)
		health_bar.modulate.a = 1.0


func next_ability() -> void:
	if abilities.size() < 2:
		return
	_ability_index = (_ability_index + 1) % abilities.size()
	attack = abilities[_ability_index]
	ability_changed.emit()


func can_use(item: QuickItem) -> bool:
	return item.heal_amount > 0.0 or (item.mana_amount > 0.0 and mana != null)


# com a vida e a mana cheias o item nao e gasto
func use_item() -> bool:
	var item := inventory.selected()
	if item == null or is_dead:
		return false
	var restores_health := item.heal_amount > 0.0 and health < get_max_health()
	var restores_mana := item.mana_amount > 0.0 and mana != null and mana.current < mana.maximum
	if not (restores_health or restores_mana):
		return false
	if restores_health:
		heal(item.heal_amount)
	if restores_mana:
		mana.restore(item.mana_amount)
	inventory.take(item)
	return true


# o item so e gasto quando o reviver vale; em grupo quem decide e a maquina do aliado caido,
# que confirma de volta (outro jogador pode ter revivido antes)
func revive_ally() -> void:
	if inventory.first_healing() == null or not is_instance_valid(revive_target) or not revive_target.is_dead:
		return
	var target := revive_target
	target.revive_hint.hide()
	revive_target = null
	if target.is_multiplayer_authority():
		spend_revive_item()
	target.revive(target.get_max_health() * REVIVE_HEALTH_FRACTION)


func spend_revive_item() -> void:
	var item := inventory.first_healing()
	if item:
		inventory.take(item)


func _update_revive_target() -> void:
	var nearest: Adventurer = null
	if not is_dead:
		for ally: Adventurer in get_tree().get_nodes_in_group("players"):
			if ally != self and ally.is_dead and ally.global_position.distance_to(global_position) <= REVIVE_RANGE:
				nearest = ally
				break
	if nearest != _hinted_ally:
		if is_instance_valid(_hinted_ally):
			_hinted_ally.revive_hint.hide()
		_hinted_ally = nearest
	revive_target = nearest if nearest and inventory.first_healing() else null
	if nearest:
		_show_revive_hint(nearest)


# so aparece na tela de quem esta perto: o aviso fica no aliado caido, nao no HUD
func _show_revive_hint(ally: Adventurer) -> void:
	var item := inventory.first_healing()
	var key := "X" if Settings.uses_gamepad() else "E"
	var text := "%s  Reviver  (%s ×%d)" % [key, item.title, inventory.count_of(item)] if item else "Sem poção para reviver"
	if ally.revive_hint.text != text:
		ally.revive_hint.text = text
		ally.revive_hint.modulate = REVIVE_READY_COLOR if item else REVIVE_MISSING_COLOR
	ally.revive_hint.show()


func drink_progress() -> float:
	return _interact_hold / DRINK_HOLD_TIME if _interact_hold >= 0.0 else 0.0


func heavy_progress() -> float:
	return _attack_hold / HEAVY_HOLD_TIME if _attack_hold >= 0.0 else 0.0


func _push_bodies(delta: float) -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var body := collision.get_collider() as RigidBody3D
		if body:
			var direction := -collision.get_normal().slide(Vector3.UP).normalized()
			body.apply_central_impulse(direction * push_force * delta)


func _has_control() -> bool:
	return not input_locked and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or Settings.uses_gamepad())


func request_attack() -> void:
	if not attack_toward_camera():
		_attack_buffer_left = ATTACK_BUFFER


func attack_toward_camera() -> bool:
	return _attack_toward_camera(attack)


func heavy_attack() -> bool:
	return _attack_toward_camera(attack, true)


# o evento de soltar pode se perder (janela sem foco): sem o botao, so cancela
func _track_attack_hold(delta: float) -> void:
	if _attack_hold < 0.0:
		return
	if not (_has_control() and Input.is_action_pressed("attack")):
		_attack_hold = -1.0
		return
	_attack_hold += delta
	if _attack_hold >= HEAVY_HOLD_TIME:
		_attack_hold = -1.0
		heavy_attack()


func _track_interact_hold(delta: float) -> void:
	if _interact_hold < 0.0:
		return
	if not Input.is_action_pressed("interact"):
		_interact_hold = -1.0
		return
	_interact_hold += delta
	if _interact_hold >= DRINK_HOLD_TIME:
		_interact_hold = -1.0
		use_item()


func _drain_for_running(delta: float) -> bool:
	if _exhausted and stamina.current >= stamina.maximum * RUN_RECOVER_FRACTION:
		_exhausted = false
	var running := wants_to_run() and is_on_floor() and _read_move_input().length() >= MOVE_DEADZONE
	if not running:
		return false
	stamina.spend(run_cost * delta)
	if stamina.current == 0.0:
		_exhausted = true
		energy_short.emit(stamina)
	return true


func _drain_for_blocking(delta: float) -> bool:
	if not is_blocking:
		return false
	stamina.spend(block_cost * delta)
	if stamina.current == 0.0:
		_break_guard()
	return true


func _break_guard() -> void:
	release_secondary()
	energy_short.emit(stamina)


func cost_of(chosen: Attack, heavy := false) -> float:
	if chosen.cost_override >= 0.0:
		return chosen.cost_override
	return heavy_cost if heavy else quick_cost


func attack_pool() -> EnergyPool:
	return mana if mana else stamina


func use_secondary() -> void:
	if block:
		_start_blocking()
	elif secondary_attack:
		_attack_toward_camera(secondary_attack)


func release_secondary() -> void:
	if is_blocking:
		_end_action()
		state_machine.change_state("Idle")


func _attack_toward_camera(chosen: Attack, heavy := false) -> bool:
	if not chosen or is_blocking or not chosen.can_attack(self):
		return false
	var cost := cost_of(chosen, heavy)
	var pool := attack_pool()
	var power := pool.affordable_power(cost)
	if power == 0.0:
		energy_short.emit(pool)
		return false
	face_camera()
	if not chosen.try_attack(self, heavy, power):
		return false
	pool.spend(cost * power)
	return true


func _start_blocking() -> void:
	if not can_act():
		return
	face_camera()
	play_action(block.animation, 1.0, block.move_factor)
	state_machine.change_state("Block")


func face_camera() -> void:
	var forward := -camera_pivot.global_basis.z
	model.rotation.y = atan2(forward.x, forward.z) - global_rotation.y


func _blocks(source: Node3D) -> bool:
	if not (is_blocking and block.covers(self, source)):
		return false
	if stamina.current < block_hit_cost:
		_break_guard()
		return false
	stamina.spend(block_hit_cost)
	return true


# o raio comeca depois do personagem para nao bater em algo entre a camera e ele
func get_aim_point() -> Vector3:
	var center := get_viewport().get_visible_rect().size / 2.0
	var origin := camera.project_ray_origin(center)
	var direction := camera.project_ray_normal(center)
	var behind_player := origin.distance_to(camera_pivot.global_position)
	_aim_query.from = origin + direction * behind_player
	_aim_query.to = origin + direction * AIM_RANGE
	var hit := get_world_3d().direct_space_state.intersect_ray(_aim_query)
	return hit.position if hit else _aim_query.to


func _get_move_direction() -> Vector3:
	var input := _read_move_input()
	return camera_pivot.global_basis * Vector3(input.x, 0.0, input.y)


func _read_move_input() -> Vector2:
	if input_locked:
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func wants_to_run() -> bool:
	if _exhausted or input_locked or not is_multiplayer_authority():
		return false
	return _run_toggled or Input.is_action_pressed("run")


func _update_animation(direction: Vector3) -> void:
	state_machine.step(direction)


func _rotate_camera(amount: Vector2) -> void:
	var vertical := -amount.y if Settings.invert_y else amount.y
	camera_pivot.rotation.y -= amount.x
	spring_arm.rotation.x = clampf(spring_arm.rotation.x - vertical, PITCH_MIN, PITCH_MAX)
