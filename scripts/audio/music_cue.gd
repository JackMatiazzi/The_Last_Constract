class_name MusicCue
extends Node
## Gatilho automático de trilha sonora para trocas de cena.

## A faixa de áudio (AudioStream) que deve tocar ao carregar esta cena.
@export var track: AudioStream

func _ready() -> void:
	# Envia a faixa exportada para o gerenciador global/Autoload 'Music'
	Music.play_track(track)
