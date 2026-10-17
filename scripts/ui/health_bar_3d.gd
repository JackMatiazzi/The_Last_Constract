class_name HealthBar3D
extends Sprite3D

# so redesenha quando a vida muda ou o rastro anima: com muitos inimigos pesaria

const TRAIL_DELAY := 0.35
const TRAIL_DURATION := 0.45
const DAMAGE_NUMBER_HEIGHT := 0.35
const BLOCKED_COLOR := Color(0.75, 0.85, 1.0)

@export var character: Character
# falso no jogador, a vida dele fica na HUD
@export var show_bar := true
@export var fill_color := Color(0.82, 0.16, 0.13)
@export var damage_number_color := Color(1.0, 0.95, 0.8)
@export var damage_number_scene: PackedScene

var _last_health := -1.0
var _trail_tween: Tween

@onready var viewport: SubViewport = $SubViewport
@onready var fill: ProgressBar = $SubViewport/Fill
@onready var trail: ProgressBar = $SubViewport/Trail


func _ready() -> void:
	assert(character and damage_number_scene, "HealthBar3D precisa de character e damage_number_scene")
	visible = show_bar
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if show_bar else SubViewport.UPDATE_DISABLED
	var style := fill.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	style.bg_color = fill_color
	fill.add_theme_stylebox_override("fill", style)
	character.health_changed.connect(_on_health_changed)
	character.died.connect(_on_died)
	character.blocked.connect(_spawn_text.bind("Bloqueado", BLOCKED_COLOR))
	if character.is_node_ready():
		_on_health_changed(character.health, character.get_max_health())


func _on_health_changed(current: float, maximum: float) -> void:
	fill.max_value = maximum
	trail.max_value = maximum
	fill.value = current
	var lost := _last_health - current
	_last_health = current
	if lost > 0.0:
		_shrink_trail(current)
		_spawn_damage_number(lost)
	else:
		trail.value = current
		_redraw_once()


func _shrink_trail(current: float) -> void:
	if _trail_tween:
		_trail_tween.kill()
	if show_bar:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_trail_tween = create_tween()
	_trail_tween.tween_interval(TRAIL_DELAY)
	_trail_tween.tween_property(trail, "value", current, TRAIL_DURATION).set_ease(Tween.EASE_OUT)
	_trail_tween.tween_callback(_redraw_once)


func _redraw_once() -> void:
	if show_bar:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _spawn_damage_number(amount: float) -> void:
	_spawn_text("-%d" % roundi(amount), damage_number_color)


func _spawn_text(message: String, color: Color) -> void:
	var number := damage_number_scene.instantiate() as DamageNumber
	character.get_parent().add_child(number)
	number.global_position = global_position + Vector3.UP * DAMAGE_NUMBER_HEIGHT
	number.show_text(message, color)


func _on_died() -> void:
	var tween := create_tween()
	tween.tween_interval(TRAIL_DELAY + TRAIL_DURATION)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(hide)
