class_name MusicPlayer
extends AudioStreamPlayer
## Gerenciador de áudio responsável por tocar músicas com transição suave (fade in / fade out).

## Tempo total da transição (fade) em segundos.
const FADE_TIME := 1.2
## Volume em decibéis considerado silencioso para início/fim do fade.
const SILENT_DB := -40.0
## Instância do Tween atual para controlar a transição de volume sem sobreposição.
var _fade: Tween

## Solcita a troca da faixa atual por uma nova, aplicando crossfade suave.
## Caso a faixa solicitada já esteja tocando, a chamada é ignorada.
func play_track(track: AudioStream) -> void:
	# Se a faixa pedida já é a atual e está tocando, não faz nada
	if track == stream and playing:
		return
	# Cancela qualquer transição de áudio que esteja ocorrendo no momento
	if _fade:
		_fade.kill()
	_fade = create_tween()
	# Caso haja áudio tocando, faz o fade out reduzindo o volume
	if playing:
		_fade.tween_property(self, "volume_db", SILENT_DB, FADE_TIME * 0.5)
	# Executa a troca real do stream após o fade out
	_fade.tween_callback(_switch_to.bind(track))
	# Se a nova faixa existir, faz o fade in até o volume padrão (0.0 dB)
	if track:
		_fade.tween_property(self, "volume_db", 0.0, FADE_TIME)

## Altera a faixa do AudioStreamPlayer e ajusta o estado de reprodução.
func _switch_to(track: AudioStream) -> void:
	stream = track
	if track:
		volume_db = SILENT_DB
		play()
	else:
		stop()
