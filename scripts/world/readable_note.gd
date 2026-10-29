class_name ReadableNote
extends Interactable
## bilhete deixado pela companhia anterior: ler e so de quem apertou, sem passar pelo host

const READ_TIME := 9.0

## Label3D que mostra o texto lido.
@export var page: Label3D
@export_multiline var text := ""

var _hide_tween: Tween


func _ready() -> void:
	super()
	assert(page, "ReadableNote: aponte a page")
	page.text = text
	page.hide()


func _interact() -> void:
	page.visible = not page.visible
	if _hide_tween:
		_hide_tween.kill()
	if page.visible:
		_hide_tween = create_tween()
		_hide_tween.tween_interval(READ_TIME)
		_hide_tween.tween_callback(page.hide)


func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		page.hide()
	super(body)
