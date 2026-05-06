extends Node

const SFX := {
	"jump": preload("res://assets/sounds/jump.wav"),
	"hurt": preload("res://assets/sounds/hurt.wav"),
	"coin": preload("res://assets/sounds/coin.wav"),
	"explosion": preload("res://assets/sounds/explosion.wav"),
	"power_up": preload("res://assets/sounds/power_up.wav"),
	"tap": preload("res://assets/sounds/tap.wav"),
}

var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -15.0
	add_child(_music_player)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.volume_db = -9.0
	add_child(_sfx_player)

	var music: AudioStream = load("res://assets/music/time_for_adventure.mp3")
	if music is AudioStreamMP3:
		music.loop = true
	_music_player.stream = music
	_music_player.play()


func play_sfx(sfx_name: String) -> void:
	if SFX.has(sfx_name):
		_sfx_player.stream = SFX[sfx_name]
		_sfx_player.play()
