extends Node

var _player_music_front: AudioStreamPlayer
var _player_music_back: AudioStreamPlayer

var _player_sfx: Dictionary = {} # { [key]: AudioStreamPlayer }

var _music_xfade_tween: Tween

var _player_music_front_volume_linear: float:
	get: return db_to_linear(_player_music_front.volume_db)
	set(v): _player_music_front.volume_db = linear_to_db(v)

var _player_music_back_volume_linear: float:
	get: return db_to_linear(_player_music_back.volume_db)
	set(v): _player_music_back.volume_db = linear_to_db(v)

func _ready() -> void:
	_player_music_front = AudioStreamPlayer.new()
	_player_music_front.name = "Music1"
	_player_music_front.bus = &"Music"
	add_child(_player_music_front)
	_player_music_back = AudioStreamPlayer.new()
	_player_music_back.name = "Music2"
	_player_music_back.bus = &"Music"
	add_child(_player_music_back)

func music(stream: AudioStream, xfade: float = 1.0) -> void:
	if _player_music_front.playing and _player_music_front.stream == stream:
		return
	
	var tmp := _player_music_front
	_player_music_front = _player_music_back
	_player_music_back = tmp
	
	_player_music_front.stream = stream
	_player_music_front.playing = true
	
	if _music_xfade_tween:
		_music_xfade_tween.kill()
		_music_xfade_tween = null
	
	if xfade > 0.0:
		_player_music_front_volume_linear = 0.0
		
		_music_xfade_tween = create_tween()
		_music_xfade_tween.set_parallel(true)
		_music_xfade_tween.tween_property(self, "_player_music_front_volume_linear", 1.0, xfade)
		_music_xfade_tween.tween_property(self, "_player_music_back_volume_linear", 0.0, xfade)
		
		await _music_xfade_tween.finished
		
		_music_xfade_tween = null
	
	_player_music_front_volume_linear = 1.0
	_player_music_back_volume_linear = 0.0
	
	_player_music_back.playing = false
	_player_music_back.stream = null


func sfx(stream: AudioStream, who = null, max_polyphony: int = 1) -> void:
	assert(stream != null)
	assert(max_polyphony >= 0)
	
	if who is Object:
		who = who.get_instance_id()
	
	var stream_id := stream.get_instance_id()
	
	var key := [who, stream_id]
	
	var audio_stream_player: AudioStreamPlayer = _player_sfx.get(key, null)
	
	if not audio_stream_player:
		audio_stream_player = AudioStreamPlayer.new()
		audio_stream_player.name = "SFX_%s_%s" % [stream.resource_path.get_file(), who]
		audio_stream_player.bus = &"SFX"
		audio_stream_player.max_polyphony = max_polyphony
		audio_stream_player.stream = stream
		audio_stream_player.finished.connect(func ():
			if not audio_stream_player.playing:
				audio_stream_player.queue_free()
				_player_sfx.erase(key))
		add_child(audio_stream_player)
		_player_sfx[key] = audio_stream_player
	
	if max_polyphony != audio_stream_player.max_polyphony:
		push_warning("MusicMan.sfx(): max_polyphony does not match initial value for this stream, ignoring new value.")
	
	audio_stream_player.play()