extends Node

# Standalone audio manager for music and SFX.
# Use via autoload singleton: AudioManager.play_music(...), play_sfx(...)

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	music_player.bus = "Music"  # Usa bus Music para controle de volume

	# Create a small pool for overlapping SFX
	for i in range(4):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"  # Usa bus SFX para controle de volume
		add_child(p)
		sfx_players.append(p)

## Play background music. Accepts a path (String) or AudioStream.
func play_music(stream_or_path: Variant, volume_db: float = 0.0, loop: bool = true) -> void:
	var stream := _to_stream(stream_or_path)
	if stream == null:
		push_warning("AudioManager: music stream not found: " + str(stream_or_path))
		return
	music_player.stop()
	music_player.stream = stream
	music_player.volume_db = volume_db
	_set_loop(stream, loop)
	music_player.play()

func stop_music() -> void:
	music_player.stop()

## Fade out current music over `seconds`, then stop.
func fade_out_music(seconds: float = 1.0) -> void:
	if not music_player.playing:
		return
	var t := create_tween()
	t.tween_property(music_player, "volume_db", -60.0, seconds)
	t.finished.connect(func(): stop_music())

## Play a one-shot sound effect. Accepts path or stream.
func play_sfx(stream_or_path: Variant, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var stream := _to_stream(stream_or_path)
	if stream == null:
		push_warning("AudioManager: sfx stream not found: " + str(stream_or_path))
		return
	var player := _get_available_sfx_player()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()

func _get_available_sfx_player() -> AudioStreamPlayer:
	for p in sfx_players:
		if not p.playing:
			return p
	return sfx_players[0]

func _to_stream(stream_or_path: Variant) -> AudioStream:
	if stream_or_path is AudioStream:
		return stream_or_path
	if stream_or_path is String:
		var res := load(stream_or_path)
		return res if res is AudioStream else null
	return null

func _set_loop(stream: AudioStream, loop: bool) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
