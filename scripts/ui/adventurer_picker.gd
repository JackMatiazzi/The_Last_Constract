class_name AdventurerPicker
extends Control

signal selection_changed(info: AdventurerInfo)
signal confirmed(info: AdventurerInfo)
signal back_requested

const NUMBER_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4]
const STICK_THRESHOLD := 0.5

var options: Array[AdventurerInfo] = []
var _stick_direction := 0
var selected_index := 0
var selected: AdventurerInfo:
	get: return options[selected_index]

@onready var cards: HBoxContainer = %Cards
@onready var name_label: Label = %NameLabel
@onready var role_label: Label = %RoleLabel
@onready var attack_label: Label = %AttackLabel
@onready var description_label: Label = %DescriptionLabel


func _ready() -> void:
	options = RunState.roster()
	for i in options.size():
		var card := Button.new()
		card.text = "%d   %s" % [i + 1, options[i].title]
		card.toggle_mode = true
		card.custom_minimum_size = Vector2(120, 0)
		card.add_theme_font_size_override("font_size", 18)
		card.pressed.connect(select.bind(i))
		cards.add_child(card)
	%AcceptButton.pressed.connect(func() -> void: confirmed.emit(selected))
	%BackButton.pressed.connect(back_requested.emit)
	select(0)
	%AcceptButton.grab_focus()


func select(index: int) -> void:
	selected_index = wrapi(index, 0, options.size())
	for i in cards.get_child_count():
		(cards.get_child(i) as Button).button_pressed = i == selected_index
	name_label.text = selected.title
	role_label.text = selected.role
	attack_label.text = selected.attack_name
	description_label.text = selected.description
	selection_changed.emit(selected)


# _input porque setas e direcional seriam consumidos pelo foco dos botoes
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_X:
		_follow_stick(event.axis_value)
	elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		back_requested.emit()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("menu_previous"):
		select(selected_index - 1)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("menu_next"):
		select(selected_index + 1)
	elif _number_key(event) in range(options.size()):
		select(_number_key(event))
	else:
		return
	get_viewport().set_input_as_handled()


# o analogico manda varios eventos segurado; troca uma vez por inclinacao
func _follow_stick(value: float) -> void:
	var direction := 0 if absf(value) < STICK_THRESHOLD else signi(value)
	if direction != _stick_direction and direction != 0:
		select(selected_index + direction)
	_stick_direction = direction


func _number_key(event: InputEvent) -> int:
	if event is InputEventKey and event.pressed and not event.echo:
		return NUMBER_KEYS.find(event.physical_keycode)
	return -1
