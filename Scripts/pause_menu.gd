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
@export var title_scene_path: String = "res://Nodes/title_screen.tscn"
@export var run_scene_path: String = "res://Nodes/the_abyss.tscn"

@export_group("Pulse")
@export var enable_pulse: bool = true
@export var pulse_strength: float = 0.022
@export var pulse_speed: float = 1.35

@onready var music_player: AudioStreamPlayer = $PauseMusic
@onready var menu_panel: PanelContainer = get_node_or_null("MenuPanel") as PanelContainer
@onready var resume_button: Button = get_node_or_null("MenuPanel/MenuRows/ResumeButton") as Button
@onready var restart_button: Button = get_node_or_null("MenuPanel/MenuRows/RestartButton") as Button
@onready var title_button: Button = get_node_or_null("MenuPanel/MenuRows/TitleButton") as Button
@onready var ui_scale_slider: HSlider = get_node_or_null("MenuPanel/MenuRows/UIScaleRow/UIScaleSlider") as HSlider
@onready var shake_slider: HSlider = get_node_or_null("MenuPanel/MenuRows/ShakeRow/ShakeSlider") as HSlider
@onready var reduce_flash_check: CheckBox = get_node_or_null("MenuPanel/MenuRows/FlashRow/ReduceFlashCheck") as CheckBox
@onready var color_mode_option: OptionButton = get_node_or_null("MenuPanel/MenuRows/ColorRow/ColorModeOption") as OptionButton
@onready var seed_label: Label = get_node_or_null("MenuPanel/MenuRows/SeedRow/SeedLabel") as Label
@onready var copy_seed_button: Button = get_node_or_null("MenuPanel/MenuRows/SeedRow/CopySeedButton") as Button

var active := false
var is_transitioning := false

var pulse_time := 0.0
var shader_time := 0.0
var transition_tween: Tween
var music_tween: Tween
var pre_pause_time_scale: float = 1.0
var _seed_copy_feedback_time: float = 0.0
var _menu_base_scale := Vector2.ONE


func _ready() -> void:
	add_to_group("PauseMenu")
	visible = false
	modulate.a = 0.0
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	music_player.volume_db = -80.0
	_connect_buttons()
	_setup_accessibility_controls()
	_apply_menu_scale()


func _process(_delta: float) -> void:
	var real_delta := get_process_delta_time()
	shader_time += real_delta

	if has_node("SineWaveBack") and $SineWaveBack.material is ShaderMaterial:
		$SineWaveBack.material.set_shader_parameter("real_time", shader_time)

	if active and enable_pulse:
		pulse_time += real_delta * pulse_speed
		_set_menu_panel_scale(_menu_base_scale * (1.0 + sin(pulse_time) * pulse_strength))
	if active:
		_update_seed_label(real_delta)


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
	_set_menu_panel_scale(_menu_base_scale)
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


func _connect_buttons() -> void:
	if resume_button != null and not resume_button.pressed.is_connected(_on_resume_pressed):
		resume_button.pressed.connect(_on_resume_pressed)
	if restart_button != null and not restart_button.pressed.is_connected(_on_restart_pressed):
		restart_button.pressed.connect(_on_restart_pressed)
	if title_button != null and not title_button.pressed.is_connected(_on_title_pressed):
		title_button.pressed.connect(_on_title_pressed)
	if copy_seed_button != null and not copy_seed_button.pressed.is_connected(_on_copy_seed_pressed):
		copy_seed_button.pressed.connect(_on_copy_seed_pressed)


func _setup_accessibility_controls() -> void:
	if Settings == null:
		return

	if ui_scale_slider != null:
		ui_scale_slider.value = Settings.ui_scale
		if not ui_scale_slider.value_changed.is_connected(_on_ui_scale_changed):
			ui_scale_slider.value_changed.connect(_on_ui_scale_changed)

	if shake_slider != null:
		shake_slider.value = Settings.screen_shake_scale
		if not shake_slider.value_changed.is_connected(_on_shake_changed):
			shake_slider.value_changed.connect(_on_shake_changed)

	if reduce_flash_check != null:
		reduce_flash_check.button_pressed = Settings.reduce_flash
		if not reduce_flash_check.toggled.is_connected(_on_reduce_flash_toggled):
			reduce_flash_check.toggled.connect(_on_reduce_flash_toggled)

	if color_mode_option != null:
		color_mode_option.clear()
		color_mode_option.add_item("STANDARD", 0)
		color_mode_option.add_item("DEUTERANOPIA", 1)
		color_mode_option.add_item("PROTANOPIA", 2)
		color_mode_option.add_item("TRITANOPIA", 3)
		color_mode_option.select(clampi(Settings.colorblind_mode, 0, color_mode_option.item_count - 1))
		if not color_mode_option.item_selected.is_connected(_on_color_mode_selected):
			color_mode_option.item_selected.connect(_on_color_mode_selected)


func _on_resume_pressed() -> void:
	if active:
		_exit_pause()


func _on_restart_pressed() -> void:
	_force_unpause()
	RunProgress.begin_new_run(false)
	get_tree().change_scene_to_file(run_scene_path)


func _on_title_pressed() -> void:
	_force_unpause()
	if RunProgress != null:
		RunProgress.clear_anchor()
	get_tree().change_scene_to_file(title_scene_path)


func _on_copy_seed_pressed() -> void:
	if RunProgress == null:
		return
	DisplayServer.clipboard_set(RunProgress.get_run_seed_code())
	if copy_seed_button != null:
		copy_seed_button.text = "COPIED"
		_seed_copy_feedback_time = 1.0


func _update_seed_label(delta: float) -> void:
	if seed_label == null or RunProgress == null:
		return
	seed_label.text = "SEED %s" % RunProgress.get_run_seed_code()
	_seed_copy_feedback_time = maxf(_seed_copy_feedback_time - delta, 0.0)
	if copy_seed_button != null and copy_seed_button.text == "COPIED" and _seed_copy_feedback_time <= 0.0:
		copy_seed_button.text = "COPY SEED"


func _on_ui_scale_changed(value: float) -> void:
	Settings.set_ui_scale(value)
	_apply_menu_scale()


func _on_shake_changed(value: float) -> void:
	Settings.set_screen_shake_scale(value)


func _on_reduce_flash_toggled(enabled: bool) -> void:
	Settings.set_reduce_flash(enabled)


func _on_color_mode_selected(index: int) -> void:
	if color_mode_option == null:
		return
	Settings.set_colorblind_mode(color_mode_option.get_item_id(index))


func _force_unpause() -> void:
	_kill_tweens()
	active = false
	is_transitioning = false
	visible = false
	_set_menu_panel_scale(_menu_base_scale)
	Engine.time_scale = 1.0
	get_tree().paused = false
	if music_player != null:
		music_player.stop()
		music_player.volume_db = -80.0
	_emit_pause_state()


func _apply_menu_scale() -> void:
	if menu_panel == null or Settings == null:
		return
	var requested_scale := clampf(float(Settings.ui_scale), 0.75, 1.35)
	var viewport_size := get_viewport_rect().size
	var base_size := menu_panel.size
	if base_size.x <= 1.0 or base_size.y <= 1.0:
		base_size = Vector2(570.0, 530.0)
	var fit_scale := minf(
		viewport_size.x / maxf(base_size.x + 56.0, 1.0),
		viewport_size.y / maxf(base_size.y + 56.0, 1.0)
	)
	var final_scale := clampf(minf(requested_scale, fit_scale), 0.75, 1.35)
	_menu_base_scale = Vector2.ONE * final_scale
	_set_menu_panel_scale(_menu_base_scale)


func _set_menu_panel_scale(next_scale: Vector2) -> void:
	if menu_panel == null:
		return
	var panel_size := menu_panel.size
	menu_panel.pivot_offset = panel_size * 0.5 if panel_size.x > 1.0 and panel_size.y > 1.0 else Vector2(285.0, 265.0)
	menu_panel.scale = next_scale
