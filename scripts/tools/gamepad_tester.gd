extends Control

# rodar a cena (F6) e apertar o controle para ver o que o Godot recebe

const BUTTON_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "View", JOY_BUTTON_GUIDE: "Guia", JOY_BUTTON_START: "Menu (Start)",
	JOY_BUTTON_LEFT_STICK: "L3 (clique esquerdo)", JOY_BUTTON_RIGHT_STICK: "R3 (clique direito)",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "Cima", JOY_BUTTON_DPAD_DOWN: "Baixo", JOY_BUTTON_DPAD_LEFT: "Esquerda",
	JOY_BUTTON_DPAD_RIGHT: "Direita", JOY_BUTTON_MISC1: "Compartilhar",
}
const ACTION_NAMES := {
	"move_forward": "Mover", "move_back": "Mover", "move_left": "Mover", "move_right": "Mover",
	"look_left": "Câmera", "look_right": "Câmera", "look_up": "Câmera", "look_down": "Câmera",
	"attack": "Atacar", "secondary": "Habilidade", "jump": "Pular", "run": "Correr", "pause": "Pausar",
	"ui_accept": "Confirmar (menu)", "ui_cancel": "Voltar (menu)",
	"menu_previous": "Aba/opção anterior", "menu_next": "Próxima aba/opção",
}
const LOG_SIZE := 8

var _log: PackedStringArray = []

@onready var device_label: Label = %DeviceLabel
@onready var sticks_label: Label = %SticksLabel
@onready var left_trigger: ProgressBar = %LeftTrigger
@onready var right_trigger: ProgressBar = %RightTrigger
@onready var buttons_label: Label = %ButtonsLabel
@onready var actions_label: Label = %ActionsLabel
@onready var log_label: Label = %LogLabel


func _process(_delta: float) -> void:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		device_label.text = "Nenhum controle conectado"
		return
	var pad := pads[0]
	var names := PackedStringArray()
	for id in pads:
		names.append("%d: %s" % [id, Input.get_joy_name(id)])
	var hidapi_8bitdo := OS.get_environment("SDL_JOYSTICK_HIDAPI_8BITDO")
	device_label.text = "Controles: %s\nModo do jogo: %s   ·   SDL_JOYSTICK_HIDAPI_8BITDO = %s" % [
		", ".join(names), "Controle" if Settings.uses_gamepad() else "Teclado e mouse",
		hidapi_8bitdo if hidapi_8bitdo else "(não definida)"]
	sticks_label.text = "Analógico esquerdo  x %+.2f  y %+.2f\nAnalógico direito   x %+.2f  y %+.2f" % [
		Input.get_joy_axis(pad, JOY_AXIS_LEFT_X), Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y),
		Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X), Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y)]
	left_trigger.value = Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_LEFT)
	right_trigger.value = Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT)
	var pressed := PackedStringArray()
	for button: JoyButton in BUTTON_NAMES:
		if Input.is_joy_button_pressed(pad, button):
			pressed.append(BUTTON_NAMES[button])
	buttons_label.text = "Botões: " + (", ".join(pressed) if pressed else "nenhum")
	var actions := PackedStringArray()
	for action: String in ACTION_NAMES:
		var name: String = ACTION_NAMES[action]
		if Input.is_action_pressed(action) and name not in actions:
			actions.append(name)
	actions_label.text = "Ações do jogo: " + (", ".join(actions) if actions else "nenhuma")


func _input(event: InputEvent) -> void:
	var is_strong_motion := event is InputEventJoypadMotion and absf(event.axis_value) > 0.5
	if (event is InputEventJoypadButton and event.pressed) or is_strong_motion:
		_log.append(event.as_text())
		if _log.size() > LOG_SIZE:
			_log.remove_at(0)
		log_label.text = "\n".join(_log)
		print(event.as_text())
