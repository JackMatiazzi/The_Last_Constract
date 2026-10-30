extends Node3D
## Gerenciador básico de nível de testes e limites de queda.
## Controla a captura do mouse para testes rápidos no editor e reposiciona
## o jogador de volta ao ponto inicial caso ele caia fora dos limites do cenário (void).

## Altura no eixo Y considerada o limite máximo de queda do cenário.
const FALL_LIMIT := -10.0
## Referência ao aventureiro presente na cena de teste.
@export var player: Adventurer
## Posição inicial capturada no carregamento para onde o jogador será retornado em caso de queda.
@onready var _spawn_point := player.global_position


func _ready() -> void:
	# Captura e oculta o ponteiro do mouse na inicialização da cena
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(_delta: float) -> void:
	# Revisa a cada frame de física se o jogador caiu abaixo do limite do mapa
	if player.global_position.y < FALL_LIMIT:
		player.global_position = _spawn_point
		player.velocity = Vector3.ZERO


func _unhandled_input(event: InputEvent) -> void:
	# Tecla ESC (ui_cancel) libera o ponteiro do mouse para navegação fora do jogo
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Clique com qualquer botão do mouse captura o ponteiro novamente para controlar a câmera
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
