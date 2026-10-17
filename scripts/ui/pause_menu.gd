class_name PauseMenu
extends CanvasLayer

signal resumed
signal abandon_confirmed

@onready var main_panel: Control = %MainPanel
@onready var confirm_panel: Control = %ConfirmPanel
@onready var settings_menu: SettingsMenu = %SettingsMenu


func _ready() -> void:
	hide()
	%ResumeButton.pressed.connect(close)
	%SettingsButton.pressed.connect(_open_settings)
	%AbandonButton.pressed.connect(_show_panel.bind(confirm_panel))
	%ConfirmAbandonButton.pressed.connect(_abandon_contract)
	%CancelAbandonButton.pressed.connect(_show_panel.bind(main_panel))
	settings_menu.closed.connect(_show_panel.bind(main_panel))


func open() -> void:
	get_tree().paused = true
	show()
	_show_panel(main_panel)


func close() -> void:
	get_tree().paused = false
	hide()
	resumed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		return
	get_viewport().set_input_as_handled()
	if confirm_panel.visible:
		_show_panel(main_panel)
	else:
		close()


func _open_settings() -> void:
	main_panel.hide()
	settings_menu.open()


func _abandon_contract() -> void:
	get_tree().paused = false
	hide()
	abandon_confirmed.emit()


func _show_panel(panel: Control) -> void:
	main_panel.visible = panel == main_panel
	confirm_panel.visible = panel == confirm_panel
	(%ResumeButton if panel == main_panel else %CancelAbandonButton).grab_focus()
