class_name BuffCard
extends Button

signal chosen(buff: Buff)

var buff: Buff

@onready var title_label: Label = %Title
@onready var effects_label: Label = %Effects
@onready var flavor_label: Label = %Flavor
@onready var stacks_label: Label = %Stacks


func _ready() -> void:
	pressed.connect(func() -> void: chosen.emit(buff))


func setup(card_buff: Buff, current_stacks: int) -> void:
	buff = card_buff
	title_label.text = buff.title
	effects_label.text = buff.describe()
	flavor_label.text = buff.flavor
	stacks_label.text = "Acúmulos: %d/%d" % [current_stacks, buff.max_stacks]
