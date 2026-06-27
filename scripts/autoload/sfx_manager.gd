extends Node

# how to use SFXManager.play(explode_sound, 0.1, 0.05, -15.0)

const POOL_SIZE = 16 # Max number of sounds that can play at once
var _players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer # Dedicated player for BGM

# Tracks the last time a specific AudioStream was played to prevent phasing
var _last_played_times: Dictionary = {} 

func _ready() -> void:
	# Create the dedicated Music Player
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music" # Assign to Music bus
	add_child(_music_player)
	
	# Create the pool of SFX players
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX" # Assign to SFX bus
		add_child(p)
		_players.append(p)

# Call this from anywhere
func play(stream: AudioStream, pitch_variance: float = 0.1, debounce_time: float = 0.0, volume_db: float = 0.0, 
override_pitch: float = 0.0, from_position: float = 0.0) -> void:
	if stream == null: return
	
	var now := Time.get_ticks_msec() / 1000.0
	if _last_played_times.has(stream):
		if now - _last_played_times[stream] < debounce_time:
			return 
	_last_played_times[stream] = now
	
	# Find an available player in the pool
	for p in _players:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = override_pitch if override_pitch != 0.0 else randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
			p.volume_db = volume_db
			p.play(from_position)
			return

# --- MUSIC LOGIC ---
func play_music(stream: AudioStream, volume: float = 0.0) -> void:
	if stream == null: return
	
	# If this exact track is already playing, don't restart it! (Great for scene transitions)
	if _music_player.stream == stream and _music_player.playing:
		return 
		
	_music_player.stream = stream
	_music_player.volume_db = volume
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()
