class_name VictoryScreen
extends CanvasLayer

signal back_to_menu

@onready var summary_label: Label = %SummaryLabel


func _ready() -> void:
	hide()
	%MenuButton.pressed.connect(back_to_menu.emit)


func open(attempt: int) -> void:
	summary_label.text = "A vila está livre. Vencido na tentativa %d." % attempt
	show()
	%MenuButton.grab_focus()
