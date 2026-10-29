extends Node
## o foco so soa depois de uma acao do jogador, senao tocaria no grab_focus de cada tela

const FOCUS_AFTER_INPUT := 0.5

@export var click: AudioStreamPlayer
@export var focus: AudioStreamPlayer

var _last_input := -INF


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)


func _input(event: InputEvent) -> void:
	if event.is_pressed():
		_last_input = Time.get_ticks_msec() / 1000.0


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(click.play):
		node.pressed.connect(click.play)
		node.focus_entered.connect(_on_focus)
		node.mouse_entered.connect(focus.play)


func _on_focus() -> void:
	if Time.get_ticks_msec() / 1000.0 - _last_input <= FOCUS_AFTER_INPUT:
		focus.play()
