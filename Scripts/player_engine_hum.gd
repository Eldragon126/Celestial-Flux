extends AudioStreamPlayer2D

# Procedural engine hum. It uses a tiny AudioStreamGenerator so the feature
# does not require a new sound file, then modulates pitch/volume from speed.

const MIX_RATE = 22050.0

@export var base_frequency = 54.0
@export var thrust_frequency_boost = 72.0
@export var quiet_volume_db = -34.0
@export var loud_volume_db = -16.0

var _player: Node = null
var _playback: AudioStreamGeneratorPlayback = null
var _phase = 0.0
var _amplitude = 0.0

func _ready() -> void:
    _player = get_parent()

    # Godot's headless audio backend can be fragile with generated streams.
    # Keep gameplay tests stable while preserving the hum in normal runs.
    if DisplayServer.get_name() == "headless":
        set_process(false)
        return

    var generator = AudioStreamGenerator.new()
    generator.mix_rate = MIX_RATE
    generator.buffer_length = 0.12
    stream = generator
    volume_db = quiet_volume_db
    autoplay = true
    play()
    _playback = get_stream_playback()

func _process(delta: float) -> void:
    if _player == null or not is_instance_valid(_player):
        return

    var velocity = _player.get("velocity")
    var max_speed = maxf(float(_player.get("max_speed")), 1.0)
    var speed_ratio = clampf(velocity.length() / max_speed, 0.0, 1.0)
    var thrusting = Input.is_action_pressed("thrust")
    var target_amp = lerpf(0.015, 0.09, speed_ratio)

    if thrusting:
        target_amp += 0.05

    _amplitude = lerpf(_amplitude, target_amp, clampf(delta * 5.0, 0.0, 1.0))
    pitch_scale = lerpf(0.82, 1.55, speed_ratio) + (0.12 if thrusting else 0.0)
    volume_db = lerpf(quiet_volume_db, loud_volume_db, clampf(_amplitude / 0.14, 0.0, 1.0))
    _fill_audio_buffer(speed_ratio, thrusting)

func _fill_audio_buffer(speed_ratio: float, thrusting: bool) -> void:
    if _playback == null:
        return

    var frequency = base_frequency + speed_ratio * thrust_frequency_boost + (24.0 if thrusting else 0.0)
    var available = _playback.get_frames_available()

    for i in range(available):
        _phase = fmod(_phase + TAU * frequency / MIX_RATE, TAU)
        var tone = sin(_phase) * _amplitude
        var harmonic = sin(_phase * 0.5) * _amplitude * 0.35
        var sample = tone + harmonic
        _playback.push_frame(Vector2(sample, sample))
