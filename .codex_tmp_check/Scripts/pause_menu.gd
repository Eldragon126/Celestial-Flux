# pause_menu.gd — cinematic deceleration into full pause; reliable unpause.
extends Control

signal pause_state_changed(blocked: bool)

@export_group("Visual Fade")
@export var fade_in_duration: float = 1.55
@export var fade_out_duration: float = 0.22

@export_group("Music")
@export var music_fade_in_duration: float = 0.5
@export var music_fade_out_duration: float = 0.15
@export var target_music_volume_db: float = -10.0

@export_group("Pulse")
@export var enable_pulse: bool = true
@export var pulse_strength: float = 0.022
@export var pulse_speed: float = 1.35

@onready var music_player: AudioStreamPlayer = $PauseMusic

var active := false
var is_transitioning := false

var pulse_time := 0.0
var shader_time := 0.0
var transition_tween: Tween
var music_tween: Tween
var pre_pause_time_scale: float = 1.0


func _ready() -> void:
	add_to_group("PauseMenu")
	visible = false
	modulate.a = 0.0
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	music_player.volume_db = -80.0


func _process(_delta: float) -> void:
	var real_delta := get_process_delta_time()
	shader_time += real_delta

	if has_node("SineWaveBack") and $SineWaveBack.material is ShaderMaterial:
		$SineWaveBack.material.set_shader_parameter("real_time", shader_time)

	if active and enable_pulse:
		pulse_time += real_delta * pulse_speed
		scale = Vector2.ONE * (1.0 + sin(pulse_time) * pulse_strength)


func _unhandled_input(event: InputEvent) -> void:
	if not active and not is_transitioning:
		return
	if event.is_action_pressed("Menu"):
		toggle_pause()
		get_viewport().set_input_as_handled()


func is_gameplay_blocked() -> bool:
	return active or is_transitioning or get_tree().paused


func toggle_pause() -> void:
	if is_transitioning:
		return
	if not active:
		_enter_pause()
	else:
		_exit_pause()


func _enter_pause() -> void:
	active = true
	is_transitioning = true
	visible = true
	_emit_pause_state()

	pre_pause_time_scale = Engine.time_scale
	if pre_pause_time_scale < 0.05:
		pre_pause_time_scale = 1.0

	_kill_tweens()

	transition_tween = create_tween()
	transition_tween.set_ignore_time_scale(true)
	transition_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	transition_tween.parallel().tween_property(self, "modulate:a", 1.0, fade_in_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	transition_tween.parallel().tween_property(Engine, "time_scale", 0.0, fade_in_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	transition_tween.finished.connect(_on_enter_tween_finished)


func _on_enter_tween_finished() -> void:
	Engine.time_scale = 0.0
	get_tree().paused = true
	is_transitioning = false
	_emit_pause_state()
	_begin_music_fade_in()


func _exit_pause() -> void:
	active = false
	is_transitioning = true
	_emit_pause_state()

	get_tree().paused = false
	Engine.time_scale = maxf(pre_pause_time_scale, 0.05)

	_kill_tweens()

	transition_tween = create_tween()
	transition_tween.set_ignore_time_scale(true)
	transition_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	transition_tween.parallel().tween_property(self, "modulate:a", 0.0, fade_out_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	transition_tween.parallel().tween_property(
		Engine, "time_scale", pre_pause_time_scale, fade_out_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	transition_tween.finished.connect(_on_exit_tween_finished)

	if music_tween:
		music_tween.kill()
	music_tween = create_tween()
	music_tween.set_ignore_time_scale(true)
	music_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	music_tween.tween_property(music_player, "volume_db", -80.0, music_fade_out_duration)
	music_tween.finished.connect(func() -> void:
		if music_player:
			music_player.stop()
	)


func _on_exit_tween_finished() -> void:
	Engine.time_scale = pre_pause_time_scale
	is_transitioning = false
	visible = false
	scale = Vector2.ONE
	_emit_pause_state()


func _begin_music_fade_in() -> void:
	if not active or music_player.playing:
		return
	music_player.play()

	if music_tween:
		music_tween.kill()
	music_tween = create_tween()
	music_tween.set_ignore_time_scale(true)
	music_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	music_tween.tween_property(music_player, "volume_db", target_music_volume_db, music_fade_in_duration)


func _emit_pause_state() -> void:
	pause_state_changed.emit(is_gameplay_blocked())


func _kill_tweens() -> void:
	if transition_tween:
		transition_tween.kill()
		transition_tween = null
	if music_tween:
		music_tween.kill()
		music_tween = null
