class_name MusicPlayer
extends AudioStreamPlayer

const FADE_TIME := 1.2
const SILENT_DB := -40.0

var _fade: Tween


func play_track(track: AudioStream) -> void:
	if track == stream and playing:
		return
	if _fade:
		_fade.kill()
	_fade = create_tween()
	if playing:
		_fade.tween_property(self, "volume_db", SILENT_DB, FADE_TIME * 0.5)
	_fade.tween_callback(_switch_to.bind(track))
	if track:
		_fade.tween_property(self, "volume_db", 0.0, FADE_TIME)


func _switch_to(track: AudioStream) -> void:
	stream = track
	if track:
		volume_db = SILENT_DB
		play()
	else:
		stop()
