extends Node2D

const BASE_ENEMY_SCENE := preload("res://Nodes/base_enemy.tscn")
const SHOOTER_ENEMY_SCENE := preload("res://Nodes/base_shooter_enemy.tscn")
const GRAVITY_WARDEN_SCENE := preload("res://Nodes/gravity_warden_boss.tscn")
const MUSIC_RESONANCE_BOSS_SCENE := preload("res://Nodes/music_resonance_boss.tscn")
const BLACK_HOLE_SCENE := preload("res://Nodes/black_hole.tscn")
const GRAVITY_WAVE_MAKER_SCENE := preload("res://Nodes/gravity_wave_maker.tscn")
const PULSATING_GRAVITY_SPAWNER_SCENE := preload("res://Nodes/pulsating_gravity_spawner.tscn")

const CAPTURE_OUTPUT_DIR := "user://marketing_captures"
const CAPTURE_PRESET_KEYS: Array[StringName] = [
	&"early_clean",
	&"slingshot_mastery",
	&"midrun_resonance",
	&"boss_rule",
	&"late_collapse",
	&"music_finale",
	&"accessibility_late_game",
]

var _overlay: PanelContainer = null
var _instruction_label: Label = null
var _spawned: Array[Node] = []
var _active_capture_preset: StringName = &"early_clean"
var _reduced_flash_capture: bool = false
var _last_capture_path: String = ""
var _original_reduce_flash: bool = false
var _has_original_reduce_flash: bool = false


func _ready() -> void:
	add_to_group("clip_lab_scene")
	_capture_original_readability_settings()
	if RunProgress != null:
		RunProgress.begin_new_run(false)
	call_deferred("_configure_lab")


func _exit_tree() -> void:
	_restore_original_readability_settings()


func _configure_lab() -> void:
	_grant_showcase_upgrades()
	_build_overlay()
	_spawn_enemy_ring()
	_load_capture_preset(&"early_clean")


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_F1:
			if _overlay != null:
				_overlay.visible = not _overlay.visible
		KEY_F2:
			_spawn_enemy_ring()
		KEY_F3:
			_spawn_mini_boss()
		KEY_F4:
			_spawn_resonance_showcase()
		KEY_F5:
			_grant_showcase_upgrades()
		KEY_F6:
			get_tree().reload_current_scene()
		KEY_F8:
			_clear_spawned()
		KEY_F9:
			_capture_viewport_png()
		KEY_F10:
			_write_capture_metadata("", "")
		KEY_1:
			_load_capture_preset(&"early_clean")
		KEY_2:
			_load_capture_preset(&"slingshot_mastery")
		KEY_3:
			_load_capture_preset(&"midrun_resonance")
		KEY_4:
			_load_capture_preset(&"boss_rule")
		KEY_5:
			_load_capture_preset(&"late_collapse")
		KEY_6:
			_load_capture_preset(&"music_finale")
		KEY_7:
			_load_capture_preset(&"accessibility_late_game")
		KEY_0:
			_apply_capture_readability(not _reduced_flash_capture)
			_refresh_overlay_text("Reduced flash %s" % ("ON" if _reduced_flash_capture else "OFF"))
		KEY_ESCAPE:
			if _pause_menu_available():
				return
			get_tree().change_scene_to_file("res://Nodes/title_screen.tscn")


func _build_overlay() -> void:
	if _overlay != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "ClipLabHUD"
	layer.layer = 70
	add_child(layer)

	_overlay = PanelContainer.new()
	_overlay.name = "ClipLabControls"
	_overlay.anchor_left = 1.0
	_overlay.anchor_right = 1.0
	_overlay.offset_left = -456.0
	_overlay.offset_right = -18.0
	_overlay.offset_top = 18.0
	_overlay.offset_bottom = 282.0
	_overlay.add_theme_stylebox_override("panel", _panel_style(Color(0.01, 0.016, 0.03, 0.88), Color(0.32, 1.0, 0.9, 0.6)))
	layer.add_child(_overlay)

	_instruction_label = Label.new()
	_instruction_label.text = _capture_overlay_text("Ready")
	_instruction_label.add_theme_font_size_override("font_size", 16)
	_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_instruction_label.modulate = Color(0.78, 1.0, 0.96, 1.0)
	_overlay.add_child(_instruction_label)


func _spawn_enemy_ring() -> void:
	var player := get_tree().get_first_node_in_group("Player") as Node2D
	var center := player.global_position if player != null else Vector2.ZERO
	for i in range(8):
		var scene := BASE_ENEMY_SCENE if i % 2 == 0 else SHOOTER_ENEMY_SCENE
		var enemy := scene.instantiate() as Node2D
		if enemy == null:
			continue
		var angle := TAU * float(i) / 8.0
		enemy.global_position = center + Vector2(cos(angle), sin(angle)) * 680.0
		add_child(enemy)
		_spawned.append(enemy)


func _spawn_mini_boss() -> void:
	var player := get_tree().get_first_node_in_group("Player") as Node2D
	var boss := GRAVITY_WARDEN_SCENE.instantiate() as Node2D
	if boss == null:
		return
	boss.global_position = (player.global_position if player != null else Vector2.ZERO) + Vector2(820.0, -260.0)
	if boss.get("max_health") != null:
		boss.set("max_health", 1200.0)
	add_child(boss)
	_spawned.append(boss)


func _load_capture_preset(preset: StringName) -> void:
	if not CAPTURE_PRESET_KEYS.has(preset):
		return
	_active_capture_preset = preset
	_clear_spawned()
	_grant_showcase_upgrades()
	_apply_capture_readability(preset == &"accessibility_late_game")
	var player := get_tree().get_first_node_in_group("Player") as Node2D
	var center := player.global_position if player != null else Vector2.ZERO
	match preset:
		&"early_clean":
			_spawn_enemy_arc(center + Vector2(540.0, -160.0), 4, 360.0)
			_set_instruction_suffix("Preset 1: clean vector start")
		&"slingshot_mastery":
			_spawn_scene(BLACK_HOLE_SCENE, center + Vector2(920.0, -260.0), "CaptureSlingshotBlackHole")
			_spawn_enemy_arc(center + Vector2(420.0, 240.0), 5, 420.0)
			_stage_mastery_signatures(center)
			_set_instruction_suffix("Preset 2: slingshot mastery path")
		&"midrun_resonance":
			_spawn_resonance_showcase()
			_spawn_enemy_arc(center + Vector2(520.0, 120.0), 6, 520.0)
			_set_instruction_suffix("Preset 3: resonance route read")
		&"boss_rule":
			_spawn_mini_boss()
			_spawn_resonance_showcase()
			_set_instruction_suffix("Preset 4: boss rule mutation")
		&"late_collapse":
			var hole := _spawn_scene(BLACK_HOLE_SCENE, center + Vector2(980.0, -360.0), "CaptureCollapseBlackHole")
			if hole != null and hole.get("event_horizon_radius") != null:
				hole.set("event_horizon_radius", 760.0)
			_spawn_scene(GRAVITY_WAVE_MAKER_SCENE, center + Vector2(-460.0, 220.0), "CaptureGravityWaveMaker")
			_spawn_scene(PULSATING_GRAVITY_SPAWNER_SCENE, center + Vector2(420.0, 380.0), "CapturePulsatingSpawner")
			_spawn_enemy_arc(center + Vector2(660.0, 40.0), 8, 640.0)
			_stage_rupture_transition()
			_set_instruction_suffix("Preset 5: late collapse readability")
		&"music_finale":
			var boss := _spawn_scene(MUSIC_RESONANCE_BOSS_SCENE, center + Vector2(820.0, -220.0), "CaptureMusicFinaleBoss")
			if boss != null and boss.get("max_health") != null:
				boss.set("max_health", 1600.0)
			_spawn_resonance_showcase()
			_stage_music_transition()
			_set_instruction_suffix("Preset 6: music finale pulse")
		&"accessibility_late_game":
			var hole := _spawn_scene(BLACK_HOLE_SCENE, center + Vector2(860.0, -300.0), "CaptureAccessibilityBlackHole")
			if hole != null and hole.get("event_horizon_radius") != null:
				hole.set("event_horizon_radius", 680.0)
			_spawn_scene(GRAVITY_WAVE_MAKER_SCENE, center + Vector2(-380.0, 220.0), "CaptureAccessibilityWaveMaker")
			_spawn_resonance_showcase()
			_spawn_enemy_arc(center + Vector2(560.0, 80.0), 7, 560.0)
			_stage_accessibility_readout()
			_set_instruction_suffix("Preset 7: reduced-flash late-game readability")


func _spawn_enemy_arc(center: Vector2, count: int, radius: float) -> void:
	for i in range(maxi(count, 1)):
		var scene := BASE_ENEMY_SCENE if i % 2 == 0 else SHOOTER_ENEMY_SCENE
		var angle := -PI * 0.35 + PI * 0.7 * float(i) / float(maxi(count - 1, 1))
		_spawn_scene(scene, center + Vector2(cos(angle), sin(angle)) * radius, "CaptureEnemy%d" % i)


func _spawn_scene(scene: PackedScene, position: Vector2, node_name: String) -> Node2D:
	var node := scene.instantiate() as Node2D
	if node == null:
		return null
	node.name = node_name
	node.global_position = position
	add_child(node)
	_spawned.append(node)
	return node


func _set_instruction_suffix(text: String) -> void:
	if _instruction_label == null:
		return
	_refresh_overlay_text(text)


func _spawn_resonance_showcase() -> void:
	var player := get_tree().get_first_node_in_group("Player") as Node2D
	var center := player.global_position if player != null else Vector2.ZERO
	var manager := find_child("GravityResonanceManager", true, false)
	if manager == null or not manager.has_method("create_manual_resonance_zone"):
		return
	manager.call("create_manual_resonance_zone", center + Vector2(360.0, 0.0), 210.0, 4, 0.86, 4.0)
	manager.call("create_manual_resonance_zone", center + Vector2(-320.0, -120.0), 190.0, 1, 0.76, 4.0)
	manager.call("create_manual_resonance_zone", center + Vector2(0.0, 340.0), 180.0, 3, 0.68, 4.0)


func _stage_mastery_signatures(center: Vector2) -> void:
	var signatures := find_child("SkillSignatureDirector", true, false)
	if signatures != null and signatures.has_method("_on_slingshot_mastery_scored"):
		signatures.call("_on_slingshot_mastery_scored", {
			"position": center + Vector2(220.0, -60.0),
			"tangent": Vector2(1.0, -0.18).normalized(),
			"score": 0.98,
			"grade": "APEX",
			"combo": 3,
		})
	var hud := find_child("OrbitalHUD", true, false)
	if hud != null and hud.has_method("_on_slingshot_mastery_triggered"):
		hud.call("_on_slingshot_mastery_triggered", {
			"score": 0.98,
			"grade": "APEX",
			"combo": 3,
		})


func _stage_rupture_transition() -> void:
	var transition := find_child("RunTransitionDirector", true, false)
	if transition != null and transition.has_method("play_transition"):
		transition.call("play_transition", "LAWS CRACKING: WAVE GENERATOR OFFLINE", Color(1.0, 0.28, 0.12, 1.0))


func _stage_music_transition() -> void:
	var transition := find_child("RunTransitionDirector", true, false)
	if transition != null and transition.has_method("play_transition"):
		transition.call("play_transition", "MUSIC DEFINES REALITY", Color(0.72, 0.95, 1.0, 1.0))


func _stage_accessibility_readout() -> void:
	var transition := find_child("RunTransitionDirector", true, false)
	if transition != null and transition.has_method("play_transition"):
		transition.call("play_transition", "REDUCED FLASH READABILITY PASS", Color(0.42, 1.0, 0.88, 1.0))


func _apply_capture_readability(reduced_flash: bool) -> void:
	_reduced_flash_capture = reduced_flash
	if Settings != null:
		Settings.reduce_flash = reduced_flash
		if Settings.has_method("export_accessibility_settings") and Settings.has_signal("accessibility_changed"):
			Settings.emit_signal("accessibility_changed", Settings.export_accessibility_settings())
	var juice := find_child("OrbitalJuiceManager", true, false)
	if juice != null:
		if juice.get("low_performance_mode") != null:
			juice.set("low_performance_mode", reduced_flash)
		if juice.get("resonance_visual_quality") != null:
			juice.set("resonance_visual_quality", 1 if reduced_flash else 2)
		if juice.has_method("_apply_quality_settings"):
			juice.call("_apply_quality_settings", get_tree().current_scene)


func _capture_original_readability_settings() -> void:
	if _has_original_reduce_flash or Settings == null:
		return
	_original_reduce_flash = bool(Settings.reduce_flash)
	_has_original_reduce_flash = true


func _restore_original_readability_settings() -> void:
	if not _has_original_reduce_flash or Settings == null:
		return
	Settings.reduce_flash = _original_reduce_flash
	if Settings.has_method("export_accessibility_settings") and Settings.has_signal("accessibility_changed"):
		Settings.emit_signal("accessibility_changed", Settings.export_accessibility_settings())


func _capture_viewport_png() -> void:
	call_deferred("_capture_viewport_png_deferred")


func _capture_viewport_png_deferred() -> void:
	var overlay_was_visible := _overlay != null and _overlay.visible
	if _overlay != null:
		_overlay.visible = false
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if _overlay != null:
		_overlay.visible = overlay_was_visible
	if image == null:
		_refresh_overlay_text("Capture failed: viewport image unavailable")
		return
	if not _ensure_capture_output_dir():
		_refresh_overlay_text("Capture failed: could not create output directory")
		return
	var stamp := _capture_timestamp()
	var slug := _capture_slug(_active_capture_preset)
	var path := "%s/%s_%s.png" % [CAPTURE_OUTPUT_DIR, slug, stamp]
	var absolute_path := ProjectSettings.globalize_path(path)
	var err := image.save_png(absolute_path)
	if err != OK:
		_refresh_overlay_text("Capture failed: save error %d" % err)
		return
	_last_capture_path = absolute_path
	_write_capture_metadata(path, stamp)
	_refresh_overlay_text("Saved %s" % _last_capture_path)


func _write_capture_metadata(image_path: String, stamp: String = "") -> void:
	if not _ensure_capture_output_dir():
		return
	var capture_stamp := stamp if not stamp.is_empty() else _capture_timestamp()
	var slug := _capture_slug(_active_capture_preset)
	var path := "%s/%s_%s.json" % [CAPTURE_OUTPUT_DIR, slug, capture_stamp]
	var spec := _capture_spec(_active_capture_preset)
	var metadata := {
		"preset": String(_active_capture_preset),
		"press_id": String(spec.get("press_id", "")),
		"clip_id": String(spec.get("clip_id", "")),
		"title": String(spec.get("title", "")),
		"requirements": spec.get("requirements", []),
		"normal_run_capture": true,
		"reduced_flash": _reduced_flash_capture,
		"image_path": image_path,
		"absolute_image_path": ProjectSettings.globalize_path(image_path) if not image_path.is_empty() else "",
		"created_at": Time.get_datetime_string_from_system(false, true),
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_refresh_overlay_text("Metadata failed: %s" % ProjectSettings.globalize_path(path))
		return
	file.store_string(JSON.stringify(metadata, "\t"))
	_refresh_overlay_text("Metadata saved %s" % ProjectSettings.globalize_path(path))


func _ensure_capture_output_dir() -> bool:
	var absolute_dir := ProjectSettings.globalize_path(CAPTURE_OUTPUT_DIR)
	var err := DirAccess.make_dir_recursive_absolute(absolute_dir)
	return err == OK or err == ERR_ALREADY_EXISTS


func _capture_timestamp() -> String:
	return Time.get_datetime_string_from_system(false, true).replace("-", "").replace(":", "").replace(" ", "_")


func _capture_slug(preset: StringName) -> String:
	var spec := _capture_spec(preset)
	var press_id := String(spec.get("press_id", ""))
	if not press_id.is_empty():
		return press_id
	var clip_id := String(spec.get("clip_id", ""))
	if not clip_id.is_empty():
		return clip_id
	return String(preset)


func _capture_spec(preset: StringName) -> Dictionary:
	match preset:
		&"early_clean":
			return {
				"press_id": "press_01_clean_vector_start",
				"clip_id": "",
				"title": "Clean vector start",
				"requirements": ["player", "gravity source", "active threat", "trajectory predictor"],
			}
		&"slingshot_mastery":
			return {
				"press_id": "press_02_slingshot_mastery",
				"clip_id": "clip_02_mastery_arc",
				"title": "Slingshot mastery path",
				"requirements": ["player", "gravity source", "trajectory path", "apex recovery payoff"],
			}
		&"midrun_resonance":
			return {
				"press_id": "press_03_resonance_zone",
				"clip_id": "clip_03_midrun_resonance",
				"title": "Resonance route read",
				"requirements": ["player", "resonance glyph", "threat route", "readable HUD field rule"],
			}
		&"boss_rule":
			return {
				"press_id": "press_04_boss_rule",
				"clip_id": "clip_04_boss_rule_mutation",
				"title": "Boss rule mutation",
				"requirements": ["player", "boss silhouette", "non-bullet physics pressure", "threat arrows"],
			}
		&"late_collapse":
			return {
				"press_id": "press_05_rupture_readability",
				"clip_id": "clip_01_three_second_hook, clip_05_rupture",
				"title": "Hook collapse and Rupture readability",
				"requirements": ["player", "near-death collapse", "law cracking", "gravity source", "active threats", "no full-screen wash"],
			}
		&"music_finale":
			return {
				"press_id": "",
				"clip_id": "clip_06_music_finale",
				"title": "Music finale pulse",
				"requirements": ["player", "finale boss", "music pulse transition", "readable resonance field"],
			}
		&"accessibility_late_game":
			return {
				"press_id": "press_06_accessibility_late_game",
				"clip_id": "clip_06_accessibility_readability",
				"title": "Reduced-flash late-game readability",
				"requirements": ["player", "late-game spectacle", "reduced flash enabled", "clear threat positions"],
			}
	return {
		"press_id": "",
		"clip_id": "",
		"title": String(preset),
		"requirements": [],
	}


func _capture_overlay_text(status: String) -> String:
	var spec := _capture_spec(_active_capture_preset)
	var last_path := _last_capture_path if not _last_capture_path.is_empty() else ProjectSettings.globalize_path(CAPTURE_OUTPUT_DIR)
	return "CLIP LAB CAPTURE\n1 early  2 slingshot  3 resonance  4 boss  5 rupture  6 finale  7 accessibility\n0 reduced flash  F9 PNG  F10 JSON  F1 hide UI  F6 reset  F8 clear\nPRESET: %s\nPRESS: %s  CLIP: %s\nNEEDS: %s\nFLASH: %s\nSTATUS: %s\nOUT: %s" % [
		String(spec.get("title", String(_active_capture_preset))).to_upper(),
		String(spec.get("press_id", "--")),
		String(spec.get("clip_id", "--")),
		_requirements_text(spec.get("requirements", [])),
		"REDUCED" if _reduced_flash_capture else "NORMAL",
		status,
		last_path,
	]


func _requirements_text(requirements_value: Variant) -> String:
	if typeof(requirements_value) != TYPE_ARRAY:
		return "--"
	var requirements: Array = requirements_value
	if requirements.is_empty():
		return "--"
	var parts := PackedStringArray()
	for item in requirements:
		parts.append(String(item))
	return ", ".join(parts)


func _refresh_overlay_text(status: String) -> void:
	if _instruction_label != null:
		_instruction_label.text = _capture_overlay_text(status)


func _pause_menu_available() -> bool:
	var pause_menu := get_tree().get_first_node_in_group("PauseMenu")
	return pause_menu != null and pause_menu.has_method("toggle_pause")


func _grant_showcase_upgrades() -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return
	var inventory := player.get_node_or_null("PowerupInventory")
	if inventory == null:
		inventory = PowerupInventory.new()
		inventory.name = "PowerupInventory"
		player.add_child(inventory)
	for powerup_id in [&"barycentric_tether", &"frame_dragging_anchor", &"apex_vector_core", &"relativistic_rail"]:
		var definition := PowerupLibrary.get_definition(powerup_id)
		if definition != null and inventory.has_method("apply_powerup"):
			inventory.call("apply_powerup", definition)
	var weapon_system := player.get_node_or_null("WeaponSystem")
	if weapon_system == null:
		return
	if weapon_system.has_method("unlock_all_weapons_for_showcase"):
		weapon_system.call("unlock_all_weapons_for_showcase")
		return
	if weapon_system.get("progressive_weapon_unlocks") != null:
		weapon_system.set("progressive_weapon_unlocks", false)
	if weapon_system.has_method("refresh_weapon_catalog"):
		weapon_system.call("refresh_weapon_catalog")


func _clear_spawned() -> void:
	for node in _spawned:
		if node != null and is_instance_valid(node) and not node.is_queued_for_deletion():
			node.queue_free()
	_spawned.clear()


func _panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style
