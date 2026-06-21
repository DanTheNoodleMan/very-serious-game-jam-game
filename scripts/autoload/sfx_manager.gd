extends Node

# how to use SFXManager.play(explode_sound, 0.1, 0.05, -15.0)

const POOL_SIZE = 16 # Max number of sounds that can play at once
var _players: Array[AudioStreamPlayer] = []

# Tracks the last time a specific AudioStream was played to prevent phasing
var _last_played_times: Dictionary = {} 

func _ready() -> void:
	# Create the pool of audio players
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX" # Make sure you route this to an SFX audio bus if you have one!
		add_child(p)
		_players.append(p)

# Call this from ANYWHERE in your game!
func play(stream: AudioStream, pitch_variance: float = 0.1, debounce_time: float = 0.05, volume_db: float = 0.0) -> void:
	if stream == null: return
	
	var now := Time.get_ticks_msec() / 1000.0
	
	# Anti-Phasing: If we just played this exact sound a millisecond ago, ignore it!
	if _last_played_times.has(stream):
		if now - _last_played_times[stream] < debounce_time:
			return 
			
	_last_played_times[stream] = now
	
	# Find an available player in the pool
	for p in _players:
		if not p.playing:
			p.stream = stream
			# Randomize the pitch slightly so repeating sounds feel organic
			p.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
			p.volume_db = volume_db
			p.play()
			return
			
	# Optional: If all 16 players are busy, the sound is just dropped. 
	# In chaotic games, dropping the 17th simultaneous sound is actually good for the mix!
