# Audio.gd — Autoload singleton
# Handles SFX and music playback. All sounds are optional;
# the game runs silently if no audio assets are present.

extends Node

# Audio buses (auto-created by Godot)
var _sfx_bus: int = -1
var _music_bus: int = -1

# Cache loaded streams
var _sfx_cache: Dictionary = {}
var _music_player: AudioStreamPlayer


func _ready() -> void:
	_sfx_bus = AudioServer.get_bus_index("SFX") if AudioServer.get_bus_index("SFX") >= 0 else AudioServer.get_bus_index("Master")
	_music_bus = AudioServer.get_bus_index("Music") if AudioServer.get_bus_index("Music") >= 0 else AudioServer.get_bus_index("Master")
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	add_child(_music_player)


func play_sfx(name: String) -> void:
	if not _sfx_cache.has(name):
		_load_sfx(name)
	var stream: AudioStream = _sfx_cache.get(name)
	if stream:
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
		player.finished.connect(player.queue_free)
		add_child(player)
		player.play()


func _load_sfx(name: String) -> void:
	var path := "res://assets/audio/%s.ogg" % name
	if ResourceLoader.exists(path):
		_sfx_cache[name] = load(path)
	else:
		_sfx_cache[name] = null   # cache the miss


func play_music(name: String) -> void:
	var path := "res://assets/audio/%s.ogg" % name
	if ResourceLoader.exists(path):
		var stream := load(path) as AudioStream
		if stream:
			_music_player.stream = stream
			_music_player.play()


func stop_music() -> void:
	_music_player.stop()
