# pause_menu.gd — cinematic deceleration into full pause; reliable unpause.
extends Control

signal pause_state_changed(blocked: bool)

const UI_PAUSE_OPEN_STREAM := preload("res://Assets/Sound Effects/sfx_ui_pause_open.mp3")
const UI_PAUSE_CLOSE_STREAM := preload("res://Assets/Sound Effects/sfx_ui_pause_close.mp3")
const UI_SETTINGS_CHANGED_STREAM := preload("res://Assets/Sound Effects/sfx_ui_settings_changed.mp3")
const RUN_LOADING_SCENE_PATH := "res://Nodes/run_loading_screen.tscn"
const MAIN_RUN_SCENE_PATH := "res://Nodes/the_abyss.tscn"
const TUTORIAL_SCENE_PATH := "res://Nodes/playable_tutorial.tscn"
const STEAM_DEMO_SCENE_PATH := "res://Nodes/demo_game.tscn"
const CLIP_LAB_SCENE_PATH := "res://Nodes/clip_lab_scene.tscn"
const SECTION_ACCENTS := {
	"AccessibilityLabel": Color(0.45, 0.9, 1.0, 0.96),
	"WeaponLabel": Color(0.88, 1.0, 0.46, 0.96),
	"ModdingLabel": Color(0.7, 0.78, 1.0, 0.96),
	"MultiplayerLabel": Color(0.55, 1.0, 0.82, 0.96),
}

@export_group("Visual Fade")
@export var fade_in_duration: float = 1.55
@export var fade_out_duration: float = 0.22

@export_group("Music")
@export var music_fade_in_duration: float = 0.5
@export var music_fade_out_duration: float = 0.15
@export var target_music_volume_db: float = -10.0
@export var title_scene_path: String = "res://Nodes/title_screen.tscn"
@export var run_scene_path: String = "res://Nodes/the_abyss.tscn"

@export_group("Tutorial")
@export var disable_pause_in_tutorial: bool = false

@export_group("Pulse")
@export var enable_pulse: bool = true
@export var pulse_strength: float = 0.022
@export var pulse_speed: float = 1.35

@export_group("Pause Tabs")
@export var pause_tab_button_height: float = 36.0
@export var pause_tab_button_font_size: int = 14
@export var pause_tab_panel_min_height: float = 360.0
@export var pause_tab_settings_columns: int = 2
@export var pause_tab_panel_bg_color: Color = Color(0.004, 0.01, 0.018, 0.54)
@export var pause_tab_panel_border_color: Color = Color(0.0, 0.86, 1.0, 0.18)

@onready var music_player: AudioStreamPlayer = $PauseMusic
@onready var menu_panel: PanelContainer = find_child("MenuPanel", true, false) as PanelContainer
@onready var status_label: Label = find_child("StatusLabel", true, false) as Label
@onready var resume_button: Button = find_child("ResumeButton", true, false) as Button
@onready var restart_button: Button = find_child("RestartButton", true, false) as Button
@onready var title_button: Button = find_child("TitleButton", true, false) as Button
@onready var ui_scale_slider: HSlider = find_child("UIScaleSlider", true, false) as HSlider
@onready var shake_slider: HSlider = find_child("ShakeSlider", true, false) as HSlider
@onready var reduce_flash_check: CheckBox = find_child("ReduceFlashCheck", true, false) as CheckBox
@onready var readability_halos_check: CheckBox = find_child("ReadabilityHalosCheck", true, false) as CheckBox
@onready var color_mode_option: OptionButton = find_child("ColorModeOption", true, false) as OptionButton
@onready var trackpad_camera_check: CheckBox = find_child("TrackpadCameraCheck", true, false) as CheckBox
@onready var alternate_movement_check: CheckBox = find_child("AlternateMovementCheck", true, false) as CheckBox
@onready var controller_deadzone_slider: HSlider = find_child("ControllerDeadzoneSlider", true, false) as HSlider
@onready var controller_deadzone_value_label: Label = find_child("ControllerDeadzoneValueLabel", true, false) as Label
@onready var controller_right_stick_check: CheckBox = find_child("ControllerRightStickCheck", true, false) as CheckBox
@onready var player_auto_orbit_check: CheckBox = find_child("PlayerAutoOrbitCheck", true, false) as CheckBox
@onready var auto_orbiting_celestials_check: CheckBox = find_child("AutoOrbitingCelestialsCheck", true, false) as CheckBox
@onready var seed_label: Label = find_child("SeedLabel", true, false) as Label
@onready var copy_seed_button: Button = find_child("CopySeedButton", true, false) as Button
@onready var mod_summary_label: Label = find_child("ModSummaryLabel", true, false) as Label
@onready var mod_entries_label: Label = find_child("ModEntriesLabel", true, false) as Label
@onready var reload_mods_button: Button = find_child("ReloadModsButton", true, false) as Button
@onready var multiplayer_status_label: Label = find_child("MultiplayerStatusLabel", true, false) as Label
@onready var weapon_status_label: Label = find_child("WeaponStatusLabel", true, false) as Label
@onready var weapon_previous_button: Button = find_child("WeaponPreviousButton", true, false) as Button
@onready var weapon_next_button: Button = find_child("WeaponNextButton", true, false) as Button

var damage_numbers_option: OptionButton = null
var hit_flash_option: OptionButton = null
var skill_callout_option: OptionButton = null
var combat_particles_option: OptionButton = null
var active := false
var is_transitioning := false

var pulse_time := 0.0
var shader_time := 0.0
var transition_tween: Tween
var music_tween: Tween
var pre_pause_time_scale: float = 1.0
var _seed_copy_feedback_time: float = 0.0
var _mod_reload_feedback_time: float = 0.0
var _menu_base_scale := Vector2.ONE
var _ui_audio_player: AudioStreamPlayer = null
var _next_settings_sound_time := 0.0
var _button_tweens: Dictionary = {}
var _pause_tab_pages: Dictionary = {}
var _pause_tab_buttons: Dictionary = {}
var _current_pause_tab: StringName = &"settings"


func _ready() -> void:
	_remove_pause_scroll_shell()
	_normalize_pause_checkbox_layout()
	_prioritize_pause_actions()
	add_to_group("PauseMenu")
	visible = false
	modulate.a = 0.0
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	music_player.volume_db = -80.0
	_setup_ui_audio()
	_connect_buttons()
	_apply_pause_readability_palette()
	_configure_weapon_status_label()
	_ensure_optional_input_rows()
	_ensure_combat_feedback_rows()
	_ensure_pause_tab_shell()
	_setup_accessibility_controls()
	_apply_pause_readability_palette()
	_apply_menu_scale()
	_update_modding_menu()
	_update_multiplayer_menu()
	_update_weapon_menu()
	_refresh_context_buttons()
	call_deferred("_focus_resume_button")
	call_deferred("_setup_button_tweens")


func _process(_delta: float) -> void:
	var real_delta := get_process_delta_time()
	shader_time += real_delta
	if (active or is_transitioning) and _pause_disabled_for_current_scene():
		_force_unpause()
		return

	if has_node("SineWaveBack") and $SineWaveBack.material is ShaderMaterial:
		$SineWaveBack.material.set_shader_parameter("real_time", shader_time)

	if active and enable_pulse and not is_transitioning:
		pulse_time += real_delta * pulse_speed
		_set_menu_panel_scale(_menu_base_scale * (1.0 + sin(pulse_time) * pulse_strength))
	if active:
		_refresh_context_buttons()
		_update_seed_label(real_delta)
		_update_modding_feedback(real_delta)
		_update_multiplayer_menu()
		_update_weapon_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Menu") and _pause_disabled_for_current_scene():
		_force_unpause()
		get_viewport().set_input_as_handled()
		return
	if not active and not is_transitioning:
		return
	if event.is_action_pressed("Menu"):
		toggle_pause()
		get_viewport().set_input_as_handled()


func is_gameplay_blocked() -> bool:
	return active or is_transitioning or get_tree().paused


func toggle_pause() -> void:
	if _pause_disabled_for_current_scene():
		if active or is_transitioning:
			_force_unpause()
		return
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
	_play_ui_sound(UI_PAUSE_OPEN_STREAM, -8.0, 0.96)
	_update_modding_menu()
	_update_multiplayer_menu()
	_update_weapon_menu()
	_refresh_context_buttons()
	call_deferred("_focus_resume_button")
	_emit_pause_state()

	pre_pause_time_scale = Engine.time_scale
	if pre_pause_time_scale < 0.05:
		pre_pause_time_scale = 1.0

	_kill_tweens()
	if menu_panel != null:
		menu_panel.modulate.a = 0.0
		_set_menu_panel_scale(_menu_base_scale * 0.92)

	transition_tween = create_tween()
	transition_tween.set_ignore_time_scale(true)
	transition_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	transition_tween.parallel().tween_property(self, "modulate:a", 1.0, fade_in_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	transition_tween.parallel().tween_property(Engine, "time_scale", 0.0, fade_in_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if menu_panel != null:
		transition_tween.parallel().tween_property(menu_panel, "modulate:a", 1.0, 0.24)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		transition_tween.parallel().tween_property(menu_panel, "scale", _menu_base_scale, 0.28)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
	_play_ui_sound(UI_PAUSE_CLOSE_STREAM, -10.0, 1.04)
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
	if menu_panel != null:
		transition_tween.parallel().tween_property(menu_panel, "scale", _menu_base_scale * 0.96, fade_out_duration)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

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


func _setup_ui_audio() -> void:
	_ui_audio_player = AudioStreamPlayer.new()
	_ui_audio_player.name = "PauseUiCue"
	_ui_audio_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_ui_audio_player.bus = &"Player Sound Effects"
	add_child(_ui_audio_player)


func _remove_pause_scroll_shell() -> void:
	if menu_panel == null:
		return
	var scroll := find_child("PauseScroll", true, false) as ScrollContainer
	if scroll == null:
		return
	var margin := scroll.get_node_or_null("PauseContentMargin") as MarginContainer
	var rows := scroll.find_child("MenuRows", true, false) as VBoxContainer
	var previous_parent := scroll.get_parent()
	if rows == null or previous_parent == null:
		return
	var row_index := scroll.get_index()
	if margin != null and rows.get_parent() == margin:
		margin.remove_child(rows)
	else:
		rows.get_parent().remove_child(rows)
	previous_parent.remove_child(scroll)
	scroll.queue_free()
	previous_parent.add_child(rows)
	previous_parent.move_child(rows, mini(row_index, previous_parent.get_child_count() - 1))
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 8)


func _prioritize_pause_actions() -> void:
	var rows := find_child("MenuRows", true, false) as VBoxContainer
	if rows == null:
		return
	var insert_index := 1
	if status_label != null:
		var status_row := status_label.get_parent() as Control
		if status_row != null and status_row.get_parent() == rows:
			insert_index = status_row.get_index() + 1
	for button in [resume_button, restart_button, title_button]:
		var control := button as Control
		if control == null:
			continue
		var row := control.get_parent() as Control
		if row == null or row.get_parent() != rows:
			row = control
		if row.get_parent() == rows:
			rows.move_child(row, mini(insert_index, rows.get_child_count() - 1))
			insert_index += 1


func _focus_resume_button() -> void:
	if resume_button != null and is_instance_valid(resume_button) and resume_button.visible and not resume_button.disabled:
		resume_button.grab_focus()


func _normalize_pause_checkbox_layout() -> void:
	var rows := find_child("MenuRows", true, false) as VBoxContainer
	if rows == null:
		return
	for checkbox in [
		reduce_flash_check,
		readability_halos_check,
		player_auto_orbit_check,
		auto_orbiting_celestials_check,
		trackpad_camera_check,
		alternate_movement_check,
		controller_right_stick_check,
	]:
		var check := checkbox as CheckBox
		if check == null:
			continue
		_apply_checkbox_readability_style(check)
		var parent := check.get_parent()
		if parent is HBoxContainer and String(parent.name) == "FlashRow":
			_move_checkbox_to_solo_row(rows, check, parent as HBoxContainer)
	var flash_row := rows.get_node_or_null("FlashRow") as HBoxContainer
	if flash_row != null and flash_row.get_child_count() == 0:
		flash_row.visible = false


func _move_checkbox_to_solo_row(rows: VBoxContainer, checkbox: CheckBox, old_row: HBoxContainer) -> void:
	var row_name := "%sSoloRow" % checkbox.name
	if rows.get_node_or_null(row_name) != null:
		return
	var insert_index := old_row.get_index() + 1
	old_row.remove_child(checkbox)
	var row := HBoxContainer.new()
	row.name = row_name
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_child(row)
	rows.move_child(row, mini(insert_index, rows.get_child_count() - 1))
	checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(checkbox)


func _apply_checkbox_readability_style(checkbox: CheckBox) -> void:
	if checkbox == null:
		return
	checkbox.scale = Vector2.ONE
	checkbox.pivot_offset = Vector2.ZERO
	checkbox.clip_text = true
	checkbox.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	checkbox.custom_minimum_size = Vector2(maxf(checkbox.custom_minimum_size.x, 280.0), maxf(checkbox.custom_minimum_size.y, 34.0))
	checkbox.add_theme_font_size_override("font_size", 14)
	checkbox.add_theme_color_override("font_color", Color(0.78, 0.98, 1.0, 0.96))
	checkbox.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))


func _apply_section_accents() -> void:
	for node_name in SECTION_ACCENTS.keys():
		var label := find_child(String(node_name), true, false) as Label
		if label == null:
			continue
		var accent_value: Variant = SECTION_ACCENTS[node_name]
		var accent: Color = accent_value if accent_value is Color else Color(0.62, 0.92, 1.0, 0.96)
		accent = _readability_color(accent)
		label.add_theme_color_override("font_color", accent)
		label.add_theme_color_override("font_outline_color", Color(accent.r, accent.g, accent.b, 0.22))
		label.add_theme_constant_override("outline_size", 4)


func _apply_pause_readability_palette() -> void:
	_apply_section_accents()
	var accent := _readability_color(Color(0.0, 0.86, 1.0, 0.5))
	var hot := _readability_color(Color(0.78, 1.0, 0.38, 0.88))
	var quiet := _readability_color(Color(0.52, 0.72, 0.82, 0.34))
	var background := get_node_or_null("SineWaveBack") as ColorRect
	if background != null and background.material is ShaderMaterial:
		var mat := background.material as ShaderMaterial
		mat.set_shader_parameter("color_a", _readability_color(Color(0.0, 1.0, 1.0, 0.42)))
		mat.set_shader_parameter("color_b", _readability_color(Color(0.18, 0.0, 0.36, 0.36)))
		mat.set_shader_parameter("color_neon", _readability_color(Color(0.92, 0.86, 1.0, 0.9)))
	if menu_panel != null:
		menu_panel.custom_minimum_size = Vector2(760.0, 650.0)
		menu_panel.add_theme_stylebox_override(
			"panel",
			_make_readability_style(Color(0.006, 0.012, 0.024, 0.965), Color(accent.r, accent.g, accent.b, 0.72), 2)
		)
	_apply_label_readability_style(self)
	var buttons: Array[Button] = []
	_collect_buttons(self, buttons)
	for button in buttons:
		_apply_button_readability_style(button, accent, hot, quiet)


func _apply_button_readability_style(button: Button, accent: Color, hot: Color, quiet: Color) -> void:
	if button == null:
		return
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 38.0)
	if button is CheckBox:
		_apply_checkbox_readability_style(button as CheckBox)
		return
	button.add_theme_color_override("font_color", Color(0.78, 0.98, 1.0, 0.96))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.02, 0.08, 0.09, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.52, 0.62, 0.68, 0.72))
	button.add_theme_stylebox_override("normal", _make_readability_style(Color(0.012, 0.05, 0.075, 0.9), Color(accent.r, accent.g, accent.b, 0.5), 1))
	button.add_theme_stylebox_override("hover", _make_readability_style(Color(0.016, 0.1, 0.14, 0.96), Color(accent.r, accent.g, accent.b, 0.84), 1))
	button.add_theme_stylebox_override("pressed", _make_readability_style(Color(0.62, 1.0, 0.92, 0.95), hot, 1))
	button.add_theme_stylebox_override("disabled", _make_readability_style(Color(0.022, 0.026, 0.038, 0.72), quiet, 1))


func _apply_label_readability_style(root: Node) -> void:
	for child in root.get_children():
		if child is Label:
			var label := child as Label
			label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
			label.add_theme_constant_override("shadow_offset_x", 1)
			label.add_theme_constant_override("shadow_offset_y", 2)
			label.add_theme_constant_override("shadow_outline_size", 3)
		_apply_label_readability_style(child)


func _make_readability_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(10)
	style.border_blend = true
	style.shadow_color = Color(border.r, border.g, border.b, 0.18)
	style.shadow_size = 16
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	return style


func _readability_color(color: Color) -> Color:
	if Settings != null and Settings.has_method("apply_readability_color"):
		return Settings.apply_readability_color(color)
	return color


func _pause_disabled_for_current_scene() -> bool:
	if get_tree() == null:
		return false
	var scene := get_tree().current_scene
	if scene != null:
		if scene.is_in_group("pause_disabled"):
			return true
		if not disable_pause_in_tutorial:
			return false
		var scene_name := String(scene.name).to_lower()
		var scene_path := String(scene.scene_file_path).to_lower()
		if scene.is_in_group("tutorial") or scene_name.contains("tutorial") or scene_path.ends_with("playable_tutorial.tscn"):
			return true
	if get_tree().get_first_node_in_group("pause_disabled") != null:
		return true
	if not disable_pause_in_tutorial:
		return false
	var tutorial_node := get_tree().get_first_node_in_group("tutorial")
	return tutorial_node != null


func _play_ui_sound(stream: AudioStream, volume_db: float = -12.0, pitch: float = 1.0) -> void:
	if _ui_audio_player == null or stream == null:
		return
	_ui_audio_player.stream = stream
	_ui_audio_player.volume_db = volume_db
	_ui_audio_player.pitch_scale = pitch
	_ui_audio_player.play()


func _play_settings_sound() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _next_settings_sound_time:
		return
	_next_settings_sound_time = now + 0.12
	_play_ui_sound(UI_SETTINGS_CHANGED_STREAM, -13.0, 1.0)


func _setup_button_tweens() -> void:
	var buttons: Array[Button] = []
	_collect_buttons(self, buttons)
	for button in buttons:
		if button is CheckBox:
			(button as CheckBox).scale = Vector2.ONE
			_apply_checkbox_readability_style(button as CheckBox)
			continue
		button.pivot_offset = button.size * 0.5
		var hover_callable := Callable(self, "_on_pause_button_hovered").bind(button)
		if not button.mouse_entered.is_connected(hover_callable):
			button.mouse_entered.connect(hover_callable)
		var focus_callable := Callable(self, "_on_pause_button_hovered").bind(button)
		if not button.focus_entered.is_connected(focus_callable):
			button.focus_entered.connect(focus_callable)
		var exit_callable := Callable(self, "_on_pause_button_unhovered").bind(button)
		if not button.mouse_exited.is_connected(exit_callable):
			button.mouse_exited.connect(exit_callable)
		var blur_callable := Callable(self, "_on_pause_button_unhovered").bind(button)
		if not button.focus_exited.is_connected(blur_callable):
			button.focus_exited.connect(blur_callable)
		var press_callable := Callable(self, "_on_pause_button_pressed_feedback").bind(button)
		if not button.pressed.is_connected(press_callable):
			button.pressed.connect(press_callable)


func _collect_buttons(root: Node, output: Array[Button]) -> void:
	for child in root.get_children():
		if child is Button:
			output.append(child as Button)
		_collect_buttons(child, output)


func _on_pause_button_hovered(button: Button) -> void:
	_tween_pause_button(button, Vector2(1.035, 1.08), Color(1.0, 1.0, 1.0, 1.0), 0.12)


func _on_pause_button_unhovered(button: Button) -> void:
	_tween_pause_button(button, Vector2.ONE, Color(1.0, 1.0, 1.0, 1.0), 0.16)


func _on_pause_button_pressed_feedback(button: Button) -> void:
	_tween_pause_button(button, Vector2(0.97, 0.95), Color(0.72, 1.0, 0.96, 1.0), 0.07)


func _tween_pause_button(button: Button, scale_value: Vector2, color: Color, duration: float) -> void:
	if button == null or not is_instance_valid(button):
		return
	var id := button.get_instance_id()
	var old_tween_value: Variant = _button_tweens.get(id, null)
	var old_tween: Tween = old_tween_value as Tween
	if old_tween != null:
		old_tween.kill()
	var tween := create_tween()
	_button_tweens[id] = tween
	tween.set_ignore_time_scale(true)
	if button is CheckBox:
		button.scale = Vector2.ONE
		tween.tween_property(button, "modulate", color, duration)
		return
	tween.tween_property(button, "scale", scale_value, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(button, "modulate", color, duration)


func _connect_buttons() -> void:
	if resume_button != null and not resume_button.pressed.is_connected(_on_resume_pressed):
		resume_button.pressed.connect(_on_resume_pressed)
	if restart_button != null and not restart_button.pressed.is_connected(_on_restart_pressed):
		restart_button.pressed.connect(_on_restart_pressed)
	if title_button != null and not title_button.pressed.is_connected(_on_title_pressed):
		title_button.pressed.connect(_on_title_pressed)
	if copy_seed_button != null and not copy_seed_button.pressed.is_connected(_on_copy_seed_pressed):
		copy_seed_button.pressed.connect(_on_copy_seed_pressed)
	if reload_mods_button != null and not reload_mods_button.pressed.is_connected(_on_reload_mods_pressed):
		reload_mods_button.pressed.connect(_on_reload_mods_pressed)
	if weapon_previous_button != null and not weapon_previous_button.pressed.is_connected(_on_weapon_previous_pressed):
		weapon_previous_button.pressed.connect(_on_weapon_previous_pressed)
	if weapon_next_button != null and not weapon_next_button.pressed.is_connected(_on_weapon_next_pressed):
		weapon_next_button.pressed.connect(_on_weapon_next_pressed)


func _configure_weapon_status_label() -> void:
	if weapon_status_label == null:
		return
	weapon_status_label.clip_text = false
	weapon_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	weapon_status_label.custom_minimum_size = Vector2(maxf(weapon_status_label.custom_minimum_size.x, 440.0), 62.0)


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

	if readability_halos_check != null:
		readability_halos_check.button_pressed = bool(Settings.readability_halos_enabled)
		if not readability_halos_check.toggled.is_connected(_on_readability_halos_toggled):
			readability_halos_check.toggled.connect(_on_readability_halos_toggled)

	if color_mode_option != null:
		color_mode_option.clear()
		color_mode_option.add_item("STANDARD", 0)
		color_mode_option.add_item("DEUTERANOPIA", 1)
		color_mode_option.add_item("PROTANOPIA", 2)
		color_mode_option.add_item("TRITANOPIA", 3)
		color_mode_option.select(clampi(Settings.colorblind_mode, 0, color_mode_option.item_count - 1))
		if not color_mode_option.item_selected.is_connected(_on_color_mode_selected):
			color_mode_option.item_selected.connect(_on_color_mode_selected)

	if controller_deadzone_slider != null:
		controller_deadzone_slider.min_value = 0.08
		controller_deadzone_slider.max_value = 0.55
		controller_deadzone_slider.step = 0.01
		controller_deadzone_slider.value = Settings.controller_deadzone
		_update_controller_deadzone_value(Settings.controller_deadzone)
		if not controller_deadzone_slider.value_changed.is_connected(_on_controller_deadzone_changed):
			controller_deadzone_slider.value_changed.connect(_on_controller_deadzone_changed)

	if controller_right_stick_check != null:
		controller_right_stick_check.button_pressed = bool(Settings.controller_right_stick_aim)
		if not controller_right_stick_check.toggled.is_connected(_on_controller_right_stick_toggled):
			controller_right_stick_check.toggled.connect(_on_controller_right_stick_toggled)

	if trackpad_camera_check != null:
		trackpad_camera_check.button_pressed = bool(Settings.trackpad_direct_camera)
		if not trackpad_camera_check.toggled.is_connected(_on_trackpad_camera_toggled):
			trackpad_camera_check.toggled.connect(_on_trackpad_camera_toggled)

	if alternate_movement_check != null:
		alternate_movement_check.button_pressed = bool(Settings.alternate_movement_enabled)
		if not alternate_movement_check.toggled.is_connected(_on_alternate_movement_toggled):
			alternate_movement_check.toggled.connect(_on_alternate_movement_toggled)

	if player_auto_orbit_check != null:
		player_auto_orbit_check.button_pressed = bool(Settings.player_auto_orbit_enabled)
		if not player_auto_orbit_check.toggled.is_connected(_on_player_auto_orbit_toggled):
			player_auto_orbit_check.toggled.connect(_on_player_auto_orbit_toggled)

	if auto_orbiting_celestials_check != null:
		auto_orbiting_celestials_check.button_pressed = bool(Settings.auto_orbiting_celestials_enabled)
		if not auto_orbiting_celestials_check.toggled.is_connected(_on_auto_orbiting_celestials_toggled):
			auto_orbiting_celestials_check.toggled.connect(_on_auto_orbiting_celestials_toggled)

	if damage_numbers_option != null:
		_select_option_by_id(damage_numbers_option, int(Settings.damage_numbers_mode))
		if not damage_numbers_option.item_selected.is_connected(_on_damage_numbers_selected):
			damage_numbers_option.item_selected.connect(_on_damage_numbers_selected)

	if hit_flash_option != null:
		_select_option_by_id(hit_flash_option, int(Settings.hit_flash_mode))
		if not hit_flash_option.item_selected.is_connected(_on_hit_flash_selected):
			hit_flash_option.item_selected.connect(_on_hit_flash_selected)

	if skill_callout_option != null:
		_select_option_by_id(skill_callout_option, int(Settings.skill_callout_mode))
		if not skill_callout_option.item_selected.is_connected(_on_skill_callout_selected):
			skill_callout_option.item_selected.connect(_on_skill_callout_selected)

	if combat_particles_option != null:
		_select_option_by_id(combat_particles_option, int(Settings.combat_particles_mode))
		if not combat_particles_option.item_selected.is_connected(_on_combat_particles_selected):
			combat_particles_option.item_selected.connect(_on_combat_particles_selected)


func _ensure_optional_input_rows() -> void:
	var rows := find_child("MenuRows", true, false) as VBoxContainer
	if rows == null:
		return
	if readability_halos_check == null:
		readability_halos_check = _make_pause_checkbox_row(rows, "READABILITY HALOS", "ReadabilityHalosCheck")
	if controller_deadzone_slider == null:
		controller_deadzone_slider = _make_pause_slider_row(rows, "CONTROLLER DEADZONE", "ControllerDeadzoneSlider", 0.08, 0.55, 0.01)
		controller_deadzone_value_label = find_child("ControllerDeadzoneValueLabel", true, false) as Label
	if controller_right_stick_check == null:
		controller_right_stick_check = _make_pause_checkbox_row(rows, "RIGHT STICK AIM", "ControllerRightStickCheck")
	if trackpad_camera_check == null:
		trackpad_camera_check = _make_pause_checkbox_row(rows, "TRACKPAD LOW-MOTION CAMERA", "TrackpadCameraCheck")
	if alternate_movement_check == null:
		alternate_movement_check = _make_pause_checkbox_row(rows, "ALT MOVEMENT: BACK / A-D AIM NUDGE", "AlternateMovementCheck")
	if player_auto_orbit_check == null:
		player_auto_orbit_check = _make_pause_checkbox_row(rows, "PLAYER AUTO-ORBIT ASSIST", "PlayerAutoOrbitCheck")
	if auto_orbiting_celestials_check == null:
		auto_orbiting_celestials_check = _make_pause_checkbox_row(rows, "ORBITING CELESTIAL EVENTS", "AutoOrbitingCelestialsCheck")
	_move_control_row_before(rows, controller_deadzone_slider, "SeedRow")
	_move_control_row_before(rows, controller_right_stick_check, "SeedRow")
	_move_control_row_before(rows, trackpad_camera_check, "SeedRow")
	_move_control_row_before(rows, alternate_movement_check, "SeedRow")


func _ensure_combat_feedback_rows() -> void:
	var rows := find_child("MenuRows", true, false) as VBoxContainer
	if rows == null:
		return
	var existing_label := rows.get_node_or_null("CombatFeedbackLabel") as Label
	if existing_label == null:
		var label := Label.new()
		label.name = "CombatFeedbackLabel"
		label.text = "COMBAT FEEDBACK"
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.34, 0.96))
		rows.add_child(label)
		existing_label = label

	if damage_numbers_option == null:
		damage_numbers_option = _make_pause_option_row(rows, "DAMAGE NUMBERS", "DamageNumbersOption", ["OFF", "MINIMAL", "FULL"], [0, 1, 2])
	if hit_flash_option == null:
		hit_flash_option = _make_pause_option_row(rows, "HIT FLASHES", "HitFlashOption", ["REDUCED", "NORMAL"], [0, 1])
	if skill_callout_option == null:
		skill_callout_option = _make_pause_option_row(rows, "SKILL CALLOUTS", "SkillCalloutOption", ["OFF", "IMPORTANT", "FULL"], [0, 1, 2])
	if combat_particles_option == null:
		combat_particles_option = _make_pause_option_row(rows, "COMBAT PARTICLES", "CombatParticlesOption", ["LOW", "NORMAL", "HIGH"], [0, 1, 2])

	_move_control_row_before(rows, damage_numbers_option, "SeedRow")
	_move_control_row_before(rows, hit_flash_option, "SeedRow")
	_move_control_row_before(rows, skill_callout_option, "SeedRow")
	_move_control_row_before(rows, combat_particles_option, "SeedRow")
	if existing_label.get_parent() == rows:
		var first_row := damage_numbers_option.get_parent() as Control
		if first_row != null and first_row.get_parent() == rows:
			rows.move_child(existing_label, maxi(0, first_row.get_index()))


func _make_pause_option_row(parent: VBoxContainer, label_text: String, option_name: String, labels: Array, ids: Array) -> OptionButton:
	var row := HBoxContainer.new()
	row.name = "%sRow" % option_name.trim_suffix("Option")
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)

	var label := Label.new()
	label.name = "%sLabel" % option_name.trim_suffix("Option")
	label.text = label_text
	label.clip_text = true
	label.custom_minimum_size = Vector2(220.0, 34.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 14)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.modulate = Color(0.76, 0.94, 0.95, 0.92)
	row.add_child(label)

	var option := OptionButton.new()
	option.name = option_name
	option.custom_minimum_size = Vector2(230.0, 34.0)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.add_theme_font_size_override("font_size", 14)
	for index in range(labels.size()):
		option.add_item(str(labels[index]), int(ids[index]))
	row.add_child(option)
	return option


func _select_option_by_id(option: OptionButton, id: int) -> void:
	if option == null:
		return
	for index in range(option.item_count):
		if option.get_item_id(index) == id:
			option.select(index)
			return


func _make_pause_checkbox_row(parent: VBoxContainer, label_text: String, checkbox_name: String) -> CheckBox:
	var row := HBoxContainer.new()
	row.name = "%sRow" % checkbox_name.trim_suffix("Check")
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)

	var checkbox := CheckBox.new()
	checkbox.name = checkbox_name
	checkbox.text = label_text
	checkbox.focus_mode = Control.FOCUS_ALL
	_apply_checkbox_readability_style(checkbox)
	row.add_child(checkbox)
	return checkbox


func _make_pause_slider_row(parent: VBoxContainer, label_text: String, slider_name: String, minimum: float, maximum: float, step_value: float) -> HSlider:
	var row := HBoxContainer.new()
	var base_name := slider_name.trim_suffix("Slider")
	row.name = "%sRow" % base_name
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)

	var label := Label.new()
	label.name = "%sLabel" % base_name
	label.text = label_text
	label.clip_text = true
	label.custom_minimum_size = Vector2(220.0, 32.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.modulate = Color(0.76, 0.94, 0.95, 0.92)
	row.add_child(label)

	var slider := HSlider.new()
	slider.name = slider_name
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(230.0, 32.0)
	row.add_child(slider)

	var value_label := Label.new()
	value_label.name = "%sValueLabel" % base_name
	value_label.text = "%.2f" % minimum
	value_label.custom_minimum_size = Vector2(54.0, 32.0)
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.modulate = Color(0.78, 0.98, 1.0, 0.96)
	row.add_child(value_label)
	return slider


func _move_control_row_before(rows: VBoxContainer, control: Control, anchor_name: String) -> void:
	if rows == null or control == null:
		return
	var row := control.get_parent() as Control
	var anchor := rows.get_node_or_null(anchor_name) as Control
	if row == null or anchor == null or row == anchor or row.get_parent() != rows:
		return
	if row.get_index() < anchor.get_index():
		return
	rows.move_child(row, anchor.get_index())


func _ensure_pause_tab_shell() -> void:
	var rows := find_child("MenuRows", true, false) as VBoxContainer
	if rows == null:
		return
	if rows.get_node_or_null("PauseTabRow") != null:
		_show_pause_tab(_current_pause_tab)
		return
	var seed_row := rows.get_node_or_null("SeedRow") as Control
	if seed_row != null and title_button != null:
		var action_row := title_button.get_parent() as Control
		if action_row != null and action_row.get_parent() == rows:
			rows.move_child(seed_row, mini(action_row.get_index() + 1, rows.get_child_count() - 1))

	var tab_row := HBoxContainer.new()
	tab_row.name = "PauseTabRow"
	tab_row.add_theme_constant_override("separation", 8)
	tab_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_child(tab_row)
	var insert_index := 5
	if seed_row != null and seed_row.get_parent() == rows:
		insert_index = seed_row.get_index() + 1
	rows.move_child(tab_row, mini(insert_index, rows.get_child_count() - 1))

	var page_panel := PanelContainer.new()
	page_panel.name = "PauseTabPanel"
	page_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_panel.custom_minimum_size = Vector2(0.0, pause_tab_panel_min_height)
	page_panel.add_theme_stylebox_override("panel", _make_readability_style(pause_tab_panel_bg_color, pause_tab_panel_border_color, 1))
	rows.add_child(page_panel)
	rows.move_child(page_panel, mini(tab_row.get_index() + 1, rows.get_child_count() - 1))

	var pages_root := Control.new()
	pages_root.name = "PauseTabPages"
	pages_root.custom_minimum_size = Vector2(0.0, maxf(pause_tab_panel_min_height - 20.0, 240.0))
	pages_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_panel.add_child(pages_root)

	_create_pause_tab(tab_row, pages_root, &"settings", "SETTINGS", [
		"AccessibilityLabel",
		"UIScaleRow",
		"ShakeRow",
		"FlashRow",
		"ReduceFlashCheckSoloRow",
		"ReadabilityHalosCheckSoloRow",
		"PlayerAutoOrbitCheckSoloRow",
		"CelestialOrbitRow",
		"AutoOrbitingCelestialsCheckSoloRow",
		"ColorRow",
		"ControllerDeadzoneRow",
		"ControllerRightStickRow",
		"TrackpadCameraRow",
		"AlternateMovementRow",
	])
	_create_pause_tab(tab_row, pages_root, &"combat", "COMBAT", [
		"CombatFeedbackLabel",
		"DamageNumbersRow",
		"HitFlashRow",
		"SkillCalloutRow",
		"CombatParticlesRow",
	])
	_create_pause_tab(tab_row, pages_root, &"weapons", "WEAPONS", [
		"WeaponLabel",
		"WeaponStatusLabel",
		"WeaponButtonsRow",
	])
	_create_pause_tab(tab_row, pages_root, &"mods", "MODS", [
		"ModdingLabel",
		"ModSummaryLabel",
		"ModEntriesLabel",
		"ReloadModsButton",
	])
	_create_pause_tab(tab_row, pages_root, &"network", "NETWORK", [
		"MultiplayerLabel",
		"MultiplayerStatusLabel",
	])
	_show_pause_tab(_current_pause_tab)


func _create_pause_tab(tab_row: HBoxContainer, pages_root: Control, tab_id: StringName, label: String, node_names: Array[String]) -> void:
	var button := Button.new()
	button.name = "%sTabButton" % String(tab_id).capitalize()
	button.text = label
	button.custom_minimum_size = Vector2(0.0, pause_tab_button_height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", pause_tab_button_font_size)
	tab_row.add_child(button)
	_pause_tab_buttons[tab_id] = button
	var callable := Callable(self, "_show_pause_tab").bind(tab_id)
	if not button.pressed.is_connected(callable):
		button.pressed.connect(callable)

	var page: Container
	if tab_id == &"settings":
		var grid := GridContainer.new()
		grid.columns = maxi(pause_tab_settings_columns, 1)
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 7)
		page = grid
	else:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 8)
		page = column
	page.name = "%sPausePage" % String(tab_id).capitalize()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	pages_root.add_child(page)
	_pause_tab_pages[tab_id] = page

	for node_name in node_names:
		_move_named_pause_row(node_name, page)


func _move_named_pause_row(node_name: String, page: Container) -> void:
	var node := find_child(node_name, true, false) as Control
	if node == null:
		return
	var movable := node
	var parent := node.get_parent()
	if parent is HBoxContainer and String(parent.name).ends_with("Row"):
		movable = parent as Control
	if parent is VBoxContainer and String(parent.name) == "MenuRows":
		movable = node
	var old_parent := movable.get_parent()
	if old_parent == null or old_parent == page:
		return
	old_parent.remove_child(movable)
	movable.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(movable)


func _show_pause_tab(tab_id: StringName) -> void:
	_current_pause_tab = tab_id
	for key in _pause_tab_pages.keys():
		var page := _pause_tab_pages[key] as Control
		if page != null:
			page.visible = StringName(key) == tab_id
	for key in _pause_tab_buttons.keys():
		var button := _pause_tab_buttons[key] as Button
		if button != null:
			var active_tab := StringName(key) == tab_id
			button.disabled = active_tab
			button.modulate = Color(0.74, 1.0, 0.92, 1.0) if active_tab else Color(1.0, 1.0, 1.0, 0.86)


func _update_controller_deadzone_value(value: float) -> void:
	if controller_deadzone_value_label == null:
		controller_deadzone_value_label = find_child("ControllerDeadzoneValueLabel", true, false) as Label
	if controller_deadzone_value_label != null:
		controller_deadzone_value_label.text = "%.2f" % clampf(value, 0.08, 0.55)


func _on_resume_pressed() -> void:
	if active:
		_exit_pause()


func _on_restart_pressed() -> void:
	var profile := _current_scene_profile()
	var next_scene := _retry_scene_path_for_profile(profile)
	if NetworkSession != null and NetworkSession.is_network_active():
		if not multiplayer.is_server():
			return
		_force_unpause()
		NetworkSession.restart_hosted_run()
		return
	_force_unpause()
	_begin_context_run(profile)
	if next_scene == MAIN_RUN_SCENE_PATH:
		get_tree().change_scene_to_file(RUN_LOADING_SCENE_PATH)
	else:
		get_tree().change_scene_to_file(next_scene)


func _on_title_pressed() -> void:
	var next_scene := _title_scene_path_for_profile(_current_scene_profile())
	_force_unpause()
	if NetworkSession != null and NetworkSession.is_network_active():
		NetworkSession.leave_session()
	if RunProgress != null:
		RunProgress.clear_anchor()
	get_tree().change_scene_to_file(next_scene)


func _begin_context_run(profile: String) -> void:
	if RunProgress == null:
		return
	RunProgress.begin_new_run(false)
	match profile:
		"steam_demo":
			RunProgress.arena_flags["run_profile"] = "steam_demo"
			RunProgress.arena_flags["retry_scene_path"] = STEAM_DEMO_SCENE_PATH
			RunProgress.arena_flags["title_scene_path"] = title_scene_path
		"tutorial":
			RunProgress.arena_flags["run_profile"] = "tutorial"
			RunProgress.arena_flags["retry_scene_path"] = TUTORIAL_SCENE_PATH
			RunProgress.arena_flags["title_scene_path"] = title_scene_path
		"clip_lab":
			RunProgress.arena_flags["run_profile"] = "clip_lab"
			RunProgress.arena_flags["retry_scene_path"] = CLIP_LAB_SCENE_PATH
			RunProgress.arena_flags["title_scene_path"] = title_scene_path
		_:
			RunProgress.arena_flags["retry_scene_path"] = run_scene_path
			RunProgress.arena_flags["title_scene_path"] = title_scene_path


func _current_scene_profile() -> String:
	if get_tree() == null:
		return "run"
	if RunProgress != null:
		var profile := String(RunProgress.arena_flags.get("run_profile", "")).strip_edges().to_lower()
		if profile == "steam_demo" or profile == "tutorial" or profile == "clip_lab":
			return profile
	var scene := get_tree().current_scene
	if scene != null:
		var scene_name := String(scene.name).to_lower()
		var scene_path := String(scene.scene_file_path).to_lower()
		if scene.is_in_group("steam_demo_scene") or scene_path.ends_with("demo_game.tscn") or scene_name.contains("demo"):
			return "steam_demo"
		if scene.is_in_group("clip_lab_scene") or scene_path.ends_with("clip_lab_scene.tscn") or scene_name.contains("clip"):
			return "clip_lab"
		if scene.is_in_group("tutorial") or scene_path.ends_with("playable_tutorial.tscn") or scene_name.contains("tutorial"):
			return "tutorial"
	if get_tree().get_first_node_in_group("steam_demo_scene") != null:
		return "steam_demo"
	if get_tree().get_first_node_in_group("clip_lab_scene") != null:
		return "clip_lab"
	if get_tree().get_first_node_in_group("tutorial") != null:
		return "tutorial"
	return "run"


func _retry_scene_path_for_profile(profile: String) -> String:
	if RunProgress != null:
		var flagged := String(RunProgress.arena_flags.get("retry_scene_path", "")).strip_edges()
		if not flagged.is_empty():
			return flagged
	match profile:
		"steam_demo":
			return STEAM_DEMO_SCENE_PATH
		"tutorial":
			return TUTORIAL_SCENE_PATH
		"clip_lab":
			return CLIP_LAB_SCENE_PATH
		_:
			return run_scene_path if not run_scene_path.strip_edges().is_empty() else MAIN_RUN_SCENE_PATH


func _title_scene_path_for_profile(_profile: String) -> String:
	if RunProgress != null:
		var flagged := String(RunProgress.arena_flags.get("title_scene_path", "")).strip_edges()
		if not flagged.is_empty():
			return flagged
	return title_scene_path


func _restart_label_for_profile(profile: String) -> String:
	match profile:
		"steam_demo":
			return "RETRY STEAM DEMO"
		"tutorial":
			return "RESTART TUTORIAL"
		"clip_lab":
			return "RESET CLIP LAB"
		_:
			return "RESTART RUN"


func _title_label_for_profile(profile: String) -> String:
	match profile:
		"steam_demo":
			return "EXIT DEMO TO TITLE"
		"tutorial":
			return "EXIT TUTORIAL"
		"clip_lab":
			return "EXIT CLIP LAB"
		_:
			return "ABORT & QUIT TO TITLE"


func _status_for_profile(profile: String, network_active: bool) -> String:
	if network_active:
		return "SIMULATION PAUSED | NETWORK SESSION HELD"
	match profile:
		"steam_demo":
			return "STEAM DEMO PAUSED | DEMO LOOP HELD"
		"tutorial":
			return "TUTORIAL PAUSED | CALIBRATION HELD"
		"clip_lab":
			return "CLIP LAB PAUSED | CAPTURE STATE HELD"
		_:
			return "SIMULATION PAUSED | LOCAL PHYSICS FROZEN"


func _refresh_context_buttons() -> void:
	var network_status := _get_network_status()
	var network_active := bool(network_status.get("active", false))
	var profile := _current_scene_profile()
	if restart_button != null:
		restart_button.text = _restart_label_for_profile(profile)
	if title_button != null:
		title_button.text = _title_label_for_profile(profile)
	if status_label != null:
		status_label.text = _status_for_profile(profile, network_active)


func _on_copy_seed_pressed() -> void:
	if RunProgress == null:
		return
	DisplayServer.clipboard_set(RunProgress.get_run_seed_code())
	_play_settings_sound()
	if copy_seed_button != null:
		copy_seed_button.text = "COPIED"
		_seed_copy_feedback_time = 1.0


func _on_reload_mods_pressed() -> void:
	var registry := _get_mod_registry()
	if registry != null and registry.has_method("reload_registry"):
		registry.call("reload_registry")
	_play_settings_sound()
	_mod_reload_feedback_time = 1.0
	if reload_mods_button != null:
		reload_mods_button.text = "RELOADED"
	_update_modding_menu()


func _on_weapon_previous_pressed() -> void:
	var weapon_system := _get_weapon_system()
	if weapon_system != null and weapon_system.has_method("select_previous_weapon"):
		weapon_system.call("select_previous_weapon")
		_play_settings_sound()
	_update_weapon_menu()


func _on_weapon_next_pressed() -> void:
	var weapon_system := _get_weapon_system()
	if weapon_system != null and weapon_system.has_method("select_next_weapon"):
		weapon_system.call("select_next_weapon")
		_play_settings_sound()
	_update_weapon_menu()


func _update_seed_label(delta: float) -> void:
	if seed_label == null or RunProgress == null:
		return
	seed_label.text = "SEED %s" % RunProgress.get_run_seed_code()
	_seed_copy_feedback_time = maxf(_seed_copy_feedback_time - delta, 0.0)
	if copy_seed_button != null and copy_seed_button.text == "COPIED" and _seed_copy_feedback_time <= 0.0:
		copy_seed_button.text = "COPY SEED"


func _update_modding_feedback(delta: float) -> void:
	_mod_reload_feedback_time = maxf(_mod_reload_feedback_time - delta, 0.0)
	if reload_mods_button != null and reload_mods_button.text == "RELOADED" and _mod_reload_feedback_time <= 0.0:
		reload_mods_button.text = "RESCAN MODS"


func _update_modding_menu() -> void:
	if mod_summary_label == null or mod_entries_label == null:
		return
	var registry := _get_mod_registry()
	if registry == null:
		mod_summary_label.text = "MOD REGISTRY OFFLINE"
		mod_entries_label.text = "Install ModContentRegistry through OrbitalJuiceManager."
		return
	if registry.has_method("get_registry_summary"):
		var summary_value: Variant = registry.call("get_registry_summary")
		var summary: Dictionary = summary_value if summary_value is Dictionary else {}
		mod_summary_label.text = _format_mod_summary(summary)
	mod_entries_label.text = _format_mod_entries(registry)


func _format_mod_summary(summary: Dictionary) -> String:
	return "MODS %d | CONTENT %d | OFF %d | TOGGLED %d | WARN %d | FAIL %d" % [
		int(summary.get("manifest_count", 0)),
		int(summary.get("content_total", 0)),
		int(summary.get("disabled", 0)),
		int(summary.get("user_disabled", 0)),
		int(summary.get("dependency_warnings", 0)),
		int(summary.get("failed", 0)),
	]


func _format_mod_entries(registry: Node) -> String:
	if not registry.has_method("get_registry_snapshot"):
		return "No registry snapshot available."
	var snapshot_value: Variant = registry.call("get_registry_snapshot")
	var snapshot: Dictionary = snapshot_value if snapshot_value is Dictionary else {}
	var manifests_value: Variant = snapshot.get("manifests", {})
	var manifests: Dictionary = manifests_value if manifests_value is Dictionary else {}
	var failed_value: Variant = snapshot.get("failed_manifests", {})
	var failed: Dictionary = failed_value if failed_value is Dictionary else {}
	var warnings_value: Variant = snapshot.get("dependency_warnings", {})
	var warnings: Dictionary = warnings_value if warnings_value is Dictionary else {}
	var content_value: Variant = snapshot.get("content", {})
	var content: Dictionary = content_value if content_value is Dictionary else {}
	var load_order_value: Variant = snapshot.get("load_order", [])
	var load_order: Array = load_order_value if load_order_value is Array else []
	if manifests.is_empty() and failed.is_empty():
		return "No manifests found. Drop vector_anomaly_mod.json or mod.json into user mods, res://Mods, or the exported game's mods folder."
	var lines: Array[String] = []
	for manifest_id_value in load_order:
		var manifest_id := String(manifest_id_value)
		if not manifests.has(manifest_id):
			continue
		var manifest_value: Variant = manifests[manifest_id]
		var manifest: Dictionary = manifest_value if manifest_value is Dictionary else {}
		var user_disabled := bool(manifest.get("user_disabled", false))
		var status := "OK" if bool(manifest.get("enabled", true)) else "OFF"
		if user_disabled:
			status = "USER OFF"
		elif not bool(manifest.get("enabled", true)):
			status = "BLOCKED"
		var author := str(manifest.get("author", "")).strip_edges()
		lines.append("[%s] %s v%s%s" % [
			status,
			str(manifest.get("display_name", manifest_id)),
			str(manifest.get("version", "1")),
			" by %s" % author if not author.is_empty() else "",
		])
		var source_kind := str(manifest.get("source_kind", "")).strip_edges()
		var source_path := str(manifest.get("source_display_path", manifest.get("source_path", ""))).strip_edges()
		if not source_kind.is_empty() and not source_path.is_empty():
			lines.append("    %s | %s" % [source_kind.to_upper(), source_path])
		var counts := _manifest_content_counts(content, manifest_id)
		if not counts.is_empty():
			lines.append("    %s" % _format_content_counts(counts))
		var disabled_reason := str(manifest.get("disabled_reason", "")).strip_edges()
		if not disabled_reason.is_empty():
			lines.append("    disabled: %s" % disabled_reason)
	for warning_value in warnings.values():
		if not (warning_value is Dictionary):
			continue
		var warning: Dictionary = warning_value
		lines.append("! %s -> %s: %s" % [
			String(warning.get("manifest_id", "")),
			String(warning.get("dependency_id", "")),
			String(warning.get("reason", "")),
		])
	for path in failed.keys():
		lines.append("! %s: %s" % [str(path), str(failed[path])])
	var scan_roots_value: Variant = snapshot.get("scan_roots", [])
	var scan_roots: Array = scan_roots_value if scan_roots_value is Array else []
	if not scan_roots.is_empty():
		lines.append("")
		lines.append("Scan roots:")
		for root_value in scan_roots:
			if not (root_value is Dictionary):
				continue
			var root: Dictionary = root_value
			var marker := "OK" if bool(root.get("exists", false)) else "MISS"
			lines.append("    [%s] %s: %s" % [
				marker,
				str(root.get("source_kind", "custom")).to_upper(),
				str(root.get("display_path", root.get("source_root", ""))),
			])
	return _join_lines(lines)


func _manifest_content_counts(content: Dictionary, manifest_id: String) -> Dictionary:
	var counts := {}
	for bucket in content.keys():
		var bucket_value: Variant = content[bucket]
		if not (bucket_value is Dictionary):
			continue
		var count := 0
		var bucket_entries := bucket_value as Dictionary
		for entry_value in bucket_entries.values():
			if not (entry_value is Dictionary):
				continue
			var entry: Dictionary = entry_value
			if String(entry.get("manifest_id", "")) == manifest_id:
				count += 1
		if count > 0:
			counts[String(bucket)] = count
	return counts


func _format_content_counts(counts: Dictionary) -> String:
	var order := ["arenas", "waves", "upgrades", "rules", "powerups", "weapons", "enemies", "bosses", "arena_events", "sfx", "music", "script_packs"]
	var parts: Array[String] = []
	for bucket in order:
		if counts.has(bucket):
			parts.append("%s %d" % [bucket.to_upper(), int(counts[bucket])])
	for bucket in counts.keys():
		if order.has(String(bucket)):
			continue
		parts.append("%s %d" % [String(bucket).to_upper(), int(counts[bucket])])
	var packed_parts := PackedStringArray()
	for part in parts:
		packed_parts.append(part)
	return " | ".join(packed_parts)


func _join_lines(lines: Array[String]) -> String:
	var packed_lines := PackedStringArray()
	for line in lines:
		packed_lines.append(line)
	return "\n".join(packed_lines)


func _update_multiplayer_menu() -> void:
	if multiplayer_status_label == null:
		return
	var network_status := _get_network_status()
	var network_active := bool(network_status.get("active", false))
	var host_controls := network_active and multiplayer.is_server()
	_configure_network_pause_buttons(network_active, host_controls)
	var quality := String(network_status.get("connection_quality", "OFFLINE")).to_upper()
	var protocol := int(network_status.get("network_protocol", 0))
	var sync := _get_multiplayer_foundation()
	if sync == null or not sync.has_method("get_readability_budget"):
		multiplayer_status_label.text = "%s | %s | NET%d | SYNC FOUNDATION OFFLINE" % [
			String(network_status.get("mode_label", "OFFLINE")),
			quality,
			protocol,
		]
		return
	var budget_value: Variant = sync.call("get_readability_budget")
	var budget: Dictionary = budget_value if budget_value is Dictionary else {}
	multiplayer_status_label.text = (
		"%s | P%d | %s | NET%d | ARROWS %d | WARN %d"
		% [
			String(network_status.get("mode_label", "OFFLINE")),
			int(budget.get("peer_count", 1)),
			quality,
			protocol,
			int(budget.get("enemy_arrow_limit", 0)),
			int(budget.get("projectile_warning_limit", 0)),
		]
	)


func _configure_network_pause_buttons(network_active: bool, host_controls: bool) -> void:
	var profile := _current_scene_profile()
	if restart_button != null:
		restart_button.disabled = network_active and not host_controls
		restart_button.text = "HOST RESTART ONLY" if network_active and not host_controls else _restart_label_for_profile(profile)
	if title_button != null:
		title_button.text = "LEAVE SESSION" if network_active else _title_label_for_profile(profile)
	if status_label != null:
		status_label.text = _status_for_profile(profile, network_active)


func _update_weapon_menu() -> void:
	if weapon_status_label == null:
		return
	var weapon_system := _get_weapon_system()
	if weapon_system == null or not weapon_system.has_method("get_weapon_debug_state"):
		weapon_status_label.text = "WEAPON SYSTEM OFFLINE"
		return
	var state_value: Variant = weapon_system.call("get_weapon_debug_state")
	var state: Dictionary = state_value if state_value is Dictionary else {}
	var display_name := String(state.get("display_name", "Vector Bolt")).to_upper()
	var index := int(state.get("index", 0)) + 1
	var count := int(state.get("count", 1))
	var energy := int(round(float(state.get("energy", 0.0))))
	var max_energy := int(round(float(state.get("max_energy", 1.0))))
	var fire_mode := StringName(state.get("fire_mode", &"projectile"))
	var mode_label := String(fire_mode).to_upper()
	var raw_cost := float(state.get("cost_per_second", 0.0))
	if fire_mode == &"field":
		raw_cost = float(state.get("cost_per_use", 0.0))
	elif fire_mode != &"beam":
		raw_cost = float(state.get("cost_per_shot", 0.0))
	var cost := int(round(raw_cost))
	var cost_label := "/s" if fire_mode == &"beam" else ("/use" if fire_mode == &"field" else "/shot")
	var unlocked := int(state.get("unlocked_count", count))
	var total := maxi(int(state.get("total_weapon_count", unlocked)), unlocked)
	var next_wave := int(state.get("next_unlock_wave", -1))
	var pool_text := "ALL WEAPONS" if total <= unlocked else "%d/%d UNLOCKED" % [unlocked, total]
	var next_text := "" if next_wave < 0 or total <= unlocked else " | NEXT WAVE %d" % next_wave
	var role := String(state.get("role", "baseline vector shot")).to_upper()
	var play_hint := String(state.get("play_hint", "surf gravity, keep the chain alive")).to_upper()
	weapon_status_label.text = "%d/%d | %s | %s | E %d/%d | %d%s\n%s | %s%s\n%s" % [
		index,
		count,
		display_name,
		mode_label,
		energy,
		max_energy,
		cost,
		cost_label,
		role,
		pool_text,
		next_text,
		play_hint,
	]


func _get_mod_registry() -> Node:
	var registry := get_tree().get_first_node_in_group("mod_content_registry")
	if registry != null:
		return registry
	var scene := get_tree().current_scene
	return scene.find_child("ModContentRegistry", true, false) if scene != null else null


func _get_multiplayer_foundation() -> Node:
	var sync := get_tree().get_first_node_in_group("multiplayer_sync_foundation")
	if sync != null:
		return sync
	var scene := get_tree().current_scene
	return scene.find_child("MultiplayerSyncFoundation", true, false) if scene != null else null


func _get_network_status() -> Dictionary:
	if NetworkSession != null and NetworkSession.has_method("get_status_snapshot"):
		return NetworkSession.get_status_snapshot()
	return {"mode_label": "OFFLINE"}


func _get_weapon_system() -> Node:
	var weapon_system := get_tree().get_first_node_in_group("weapon_system")
	if weapon_system != null:
		return weapon_system
	var player := MultiplayerTargeting.local_player(get_tree())
	if player != null:
		return player.get_node_or_null("WeaponSystem")
	var scene := get_tree().current_scene
	return scene.find_child("WeaponSystem", true, false) if scene != null else null


func _on_ui_scale_changed(value: float) -> void:
	Settings.set_ui_scale(value)
	_play_settings_sound()
	_apply_menu_scale()


func _on_shake_changed(value: float) -> void:
	Settings.set_screen_shake_scale(value)
	_play_settings_sound()


func _on_reduce_flash_toggled(enabled: bool) -> void:
	Settings.set_reduce_flash(enabled)
	_play_settings_sound()
	_apply_pause_readability_palette()


func _on_readability_halos_toggled(enabled: bool) -> void:
	Settings.set_readability_halos_enabled(enabled)
	_play_settings_sound()


func _on_color_mode_selected(index: int) -> void:
	if color_mode_option == null:
		return
	Settings.set_colorblind_mode(color_mode_option.get_item_id(index))
	_play_settings_sound()
	_apply_pause_readability_palette()


func _on_damage_numbers_selected(index: int) -> void:
	if damage_numbers_option == null:
		return
	Settings.set_damage_numbers_mode(damage_numbers_option.get_item_id(index))
	_play_settings_sound()


func _on_hit_flash_selected(index: int) -> void:
	if hit_flash_option == null:
		return
	Settings.set_hit_flash_mode(hit_flash_option.get_item_id(index))
	_play_settings_sound()


func _on_skill_callout_selected(index: int) -> void:
	if skill_callout_option == null:
		return
	Settings.set_skill_callout_mode(skill_callout_option.get_item_id(index))
	_play_settings_sound()


func _on_combat_particles_selected(index: int) -> void:
	if combat_particles_option == null:
		return
	Settings.set_combat_particles_mode(combat_particles_option.get_item_id(index))
	_play_settings_sound()


func _on_controller_deadzone_changed(value: float) -> void:
	Settings.set_controller_deadzone(value)
	_update_controller_deadzone_value(value)
	_play_settings_sound()


func _on_controller_right_stick_toggled(enabled: bool) -> void:
	Settings.set_controller_right_stick_aim(enabled)
	_play_settings_sound()


func _on_trackpad_camera_toggled(enabled: bool) -> void:
	Settings.set_trackpad_direct_camera(enabled)
	_play_settings_sound()


func _on_alternate_movement_toggled(enabled: bool) -> void:
	Settings.set_alternate_movement_enabled(enabled)
	_play_settings_sound()


func _on_player_auto_orbit_toggled(enabled: bool) -> void:
	Settings.set_player_auto_orbit_enabled(enabled)
	_play_settings_sound()


func _on_auto_orbiting_celestials_toggled(enabled: bool) -> void:
	Settings.set_auto_orbiting_celestials_enabled(enabled)
	_play_settings_sound()


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
		base_size = Vector2(760.0, 840.0)
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
	menu_panel.pivot_offset = panel_size * 0.5 if panel_size.x > 1.0 and panel_size.y > 1.0 else Vector2(380.0, 420.0)
	menu_panel.scale = next_scale
