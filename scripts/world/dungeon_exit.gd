class_name DungeonExit
extends Interactable
## sair do calabouco encerra o contrato: com todo morto-vivo derrubado ele e cumprido; com algum de pe,
## falha

@export var census: UndeadCensus
@export var session: GameSession


func _ready() -> void:
	super()
	assert(census and session, "DungeonExit: aponte census e session")


func _use(_by: Adventurer) -> void:
	session.end_contract(census.remaining() == 0)
