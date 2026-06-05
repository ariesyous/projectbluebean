extends AudioStreamPlayer
class_name DungeonAmbience
## Procedural looping dungeon bed: low hum, filtered air, and subtle drift.

@export var ambience_volume: float = 0.38
@export var hum_frequency: float = 42.0
@export var wind_amount: float = 0.18

var _playback: AudioStreamGeneratorPlayback
var _phase: float = 0.0
var _wind: float = 0.0
var _sample_rate: float = 22050.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 86173
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = _sample_rate
	generator.buffer_length = 0.5
	stream = generator
	volume_db = linear_to_db(ambience_volume)
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback
	_fill_buffer()

func _process(_delta: float) -> void:
	if not playing:
		play()
	if _playback == null:
		_playback = get_stream_playback() as AudioStreamGeneratorPlayback
	_fill_buffer()

func _fill_buffer() -> void:
	if _playback == null:
		return
	for i in range(_playback.get_frames_available()):
		var sample := _next_sample()
		_playback.push_frame(Vector2(sample, sample))

func _next_sample() -> float:
	_phase = fmod(_phase + TAU * hum_frequency / _sample_rate, TAU)
	var low_hum := sin(_phase) * 0.16
	var breath := sin(_phase * 0.071) * 0.08
	var raw_wind := _rng.randf_range(-1.0, 1.0)
	_wind = lerpf(_wind, raw_wind, 0.018)
	return clampf((low_hum + breath + _wind * wind_amount) * ambience_volume, -0.8, 0.8)
