# pause_menu.gd — cinematic deceleration into full pause; reliable unpause.
extends Control

signal pause_state_changed(blocked: bool)

const UI_PAUSE_OPEN_STREAM := preload("res://Assets/Sound Effects/sfx_ui_pause_open.mp3")
const UI_PAUSE_CLOSE_STREAM := preload("res://Assets/Sound Effects/sfx_ui_pause_close.mp3")
const UI_SETTINGS_CHANGED_STREAM := preload("res://Assets/Sound Effects/sfx_ui_settings_changed.mp3")

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
@onready var menu_panel: PanelContainer = find_child("MenuPanel", true, false) as PanelContainer
@onready var resume_button: Button = find_child("ResumeButton", true, false) as Button
@onready var restart_button: Button = find_child("RestartButton", true, false) as Button
@onready var title_button: Button = find_child("TitleButton", true, false) as Button
@onready var ui_scale_slider: HSlider = find_child("UIScaleSlider", true, false) as HSlider
@onready var shake_slider: HSlider = find_child("ShakeSlider", true, false) as HSlider
@onready var reduce_flash_check: CheckBox = find_child("ReduceFlashCheck", true, false) as CheckBox
@onready var color_mode_option: OptionButton = find_child("ColorModeOption", true, false) as OptionButton
@onready var seed_label: Label = find_child("SeedLabel", true, false) as Label
@onready var copy_seed_button: Button = find_child("CopySeedButton", true, false) as Button
@onready var mod_summary_label: Label = find_child("ModSummaryLabel", true, false) as Label
@onready var mod_entries_label: Label = find_child("ModEntriesLabel", true, false) as Label
@onready var reload_mods_button: Button = find_child("ReloadModsButton", true, false) as Button
@onready var multiplayer_status_label: Label = find_child("MultiplayerStatusLabel", true, false) as Label
@onready var weapon_status_label: Label = find_child("WeaponStatusLabel", true, false) as Label
@onready var weapon_previous_button: Button = find_child("WeaponPreviousButton", true, false) as Button
@onready var weapon_next_button: Button = find_child("WeaponNextButton", true, false) as Button

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


func _ready() -> void:
	$MenuPanel/MenuRows/UIScaleRow/UIScaleSlider.grab_focus()
	add_to_group("PauseMenu")
	visible = false
	modulate.a = 0.0
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	music_player.volume_db = -80.0
	_setup_ui_audio()
	_connect_buttons()
	_setup_accessibility_controls()
	_apply_menu_scale()
	_update_modding_menu()
	_update_multiplayer_menu()
	_update_weapon_menu()


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
		_update_modding_feedback(real_delta)
		_update_weapon_menu()


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
	_play_ui_sound(UI_PAUSE_OPEN_STREAM, -8.0, 0.96)
	_update_modding_menu()
	_update_multiplayer_menu()
	_update_weapon_menu()
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
	return "MODS %d | CONTENT %d | OFF %d | WARN %d | FAIL %d" % [
		int(summary.get("manifest_count", 0)),
		int(summary.get("content_total", 0)),
		int(summary.get("disabled", 0)),
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
		return "No manifests found. Drop vector_anomaly_mod.json into res://Mods or user://mods."
	var lines: Array[String] = []
	for manifest_id_value in load_order:
		var manifest_id := String(manifest_id_value)
		if not manifests.has(manifest_id):
			continue
		var manifest_value: Variant = manifests[manifest_id]
		var manifest: Dictionary = manifest_value if manifest_value is Dictionary else {}
		var status := "OK" if bool(manifest.get("enabled", true)) else "OFF"
		var author := str(manifest.get("author", "")).strip_edges()
		lines.append("[%s] %s v%s%s" % [
			status,
			str(manifest.get("display_name", manifest_id)),
			str(manifest.get("version", "1")),
			" by %s" % author if not author.is_empty() else "",
		])
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
	var sync := _get_multiplayer_foundation()
	if sync == null or not sync.has_method("get_readability_budget"):
		multiplayer_status_label.text = "SYNC FOUNDATION OFFLINE"
		return
	var budget_value: Variant = sync.call("get_readability_budget")
	var budget: Dictionary = budget_value if budget_value is Dictionary else {}
	multiplayer_status_label.text = (
		"SYNC READY | P%d | ARROWS %d | WARN %d"
		% [
			int(budget.get("peer_count", 1)),
			int(budget.get("enemy_arrow_limit", 0)),
			int(budget.get("projectile_warning_limit", 0)),
		]
	)


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
	var cost := int(round(float(state.get("cost_per_second", 0.0))))
	weapon_status_label.text = "%d/%d | %s | E %d/%d | %d/s" % [
		index,
		count,
		display_name,
		energy,
		max_energy,
		cost,
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


func _get_weapon_system() -> Node:
	var weapon_system := get_tree().get_first_node_in_group("weapon_system")
	if weapon_system != null:
		return weapon_system
	var player := get_tree().get_first_node_in_group("Player")
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


func _on_color_mode_selected(index: int) -> void:
	if color_mode_option == null:
		return
	Settings.set_colorblind_mode(color_mode_option.get_item_id(index))
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
