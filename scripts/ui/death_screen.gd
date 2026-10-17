class_name DeathScreen
extends CanvasLayer

signal revive_chosen(buff: Buff)
signal gave_up

const SHOW_DELAY := 1.2

@export var player: Character
@export var buff_card_scene: PackedScene

@onready var death_panel: Control = %DeathPanel
@onready var confirm_panel: Control = %ConfirmPanel
@onready var choice_panel: Control = %ChoicePanel
@onready var attempt_label: Label = %AttemptLabel
@onready var active_buffs_label: Label = %ActiveBuffsLabel
@onready var cards: HBoxContainer = %Cards


func _ready() -> void:
	assert(buff_card_scene, "DeathScreen precisa de buff_card_scene")
	hide()
	if player:
		bind(player)
	%ReviveButton.pressed.connect(_on_revive_pressed)
	%GiveUpButton.pressed.connect(_show_panel.bind(confirm_panel))
	%CancelGiveUpButton.pressed.connect(_show_panel.bind(death_panel))
	%ConfirmGiveUpButton.pressed.connect(gave_up.emit)


func bind(new_player: Character) -> void:
	player = new_player
	player.died.connect(_on_player_died)


func _on_player_died() -> void:
	await get_tree().create_timer(SHOW_DELAY).timeout
	attempt_label.text = "Tentativa %d" % RunState.attempt
	active_buffs_label.text = _active_buffs_text()
	show()
	_show_panel(death_panel)


func _unhandled_input(event: InputEvent) -> void:
	if visible and confirm_panel.visible and event.is_action_pressed("ui_cancel"):
		_show_panel(death_panel)
		get_viewport().set_input_as_handled()
		return
	if not (visible and choice_panel.visible and event is InputEventKey and event.pressed):
		return
	var index: int = [KEY_1, KEY_2].find(event.physical_keycode)
	if index != -1 and index < cards.get_child_count():
		revive_chosen.emit(cards.get_child(index).buff)


func _on_revive_pressed() -> void:
	var choices := RunState.roll_choices()
	if choices.is_empty():
		revive_chosen.emit(null)
		return
	for child in cards.get_children():
		child.queue_free()
	for buff in choices:
		var card := buff_card_scene.instantiate() as BuffCard
		cards.add_child(card)
		card.setup(buff, RunState.stacks_of(buff))
		card.chosen.connect(revive_chosen.emit)
	_show_panel(choice_panel)


func _active_buffs_text() -> String:
	if RunState.buffs.is_empty():
		return "Nenhuma bênção acumulada."
	var titles := PackedStringArray()
	for buff in RunState.buffs:
		titles.append(buff.title)
	return "Bênçãos acumuladas: " + ", ".join(titles)


func _show_panel(panel: Control) -> void:
	for candidate in [death_panel, confirm_panel, choice_panel]:
		candidate.visible = candidate == panel
	var focus: Control = {death_panel: %ReviveButton, confirm_panel: %CancelGiveUpButton}.get(panel, null)
	if focus:
		focus.grab_focus()
	elif cards.get_child_count() > 0:
		(cards.get_child(0) as Control).grab_focus.call_deferred()
