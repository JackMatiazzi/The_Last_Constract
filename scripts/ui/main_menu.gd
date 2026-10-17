extends Node3D

const CHARACTER_SELECT := "res://scenes/ui/character_select.tscn"
const ORBIT_SPEED := 0.08

@export var camera_pivot: Node3D
@export var knight_animation: AnimationPlayer
@export var skeleton_animation: AnimationPlayer

@onready var menu_panel: Control = %MenuPanel
@onready var settings_menu: SettingsMenu = %SettingsMenu


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	knight_animation.play("Idle")
	skeleton_animation.play("Idle")
	%PlayButton.pressed.connect(_on_play_pressed)
	%SettingsButton.pressed.connect(_open_settings)
	%QuitButton.pressed.connect(get_tree().quit)
	settings_menu.closed.connect(_close_settings)
	%PlayButton.grab_focus()


func _process(delta: float) -> void:
	camera_pivot.rotation.y += ORBIT_SPEED * delta


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(CHARACTER_SELECT)


func _open_settings() -> void:
	menu_panel.hide()
	settings_menu.open()


func _close_settings() -> void:
	menu_panel.show()
	%SettingsButton.grab_focus()
