class_name MusicCue
extends Node

@export var track: AudioStream


func _ready() -> void:
	Music.play_track(track)
