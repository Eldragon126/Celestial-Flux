extends Node2D

const STRESS_TEST_DIRECTOR_SCENE := preload("res://Nodes/stress_test_director.tscn")

@export var demo_last_wave: int = 7
@export var demo_boss_wave: int = 7
@export var steam_wishlist_url: String = "https://store.steampowered.com/"
@export var starting_upgrade_ids: Array[StringName] = [
	&"apex_vector_core",
	&"barycentric_tether",
	&"frame_dragging_anchor",
	&"relativistic_rail",
]
@export var validation_warmup_frames: int = 180
@export var validation_sample_frames: int = 240
@export var validation_run_stress_on_start: bool = true

var _configure_attempts := 0
var _wave_director: Node = null
var _objective_label: Label = null
var _end_panel: PanelContainer = null
var _end_score_label: Label = null
var _end_code_label: Label = null
var _completed := false
var _validation_mode := false
var _validation_started := false
var _validation_frame := 0
var _validation_sample_count := 0
var _validation_total_frame_ms := 0.0
var _validation_max_frame_ms := 0.0
var _validation_stress_report: Dictionary = {}
var _drop_prompt_seen := false


func _ready() -> void:
	add_to_group("steam_demo_scene")
	_validation_mode = _has_user_arg("--demo-validation")
	if _validation_mode:
		_prepare_validation_pacing()
	if RunProgress != null:
		RunProgress.begin_new_run(false)
		RunProgress.arena_flags["run_profile"] = "steam_demo"
		RunProgress.arena_flags["retry_scene_path"] = "res://Nodes/demo_game.tscn"
		RunProgress.arena_flags["title_scene_path"] = "res://Nodes/title_screen.tscn"
	call_deferred("_configure_demo")


func _process(delta: float) -> void:
	if not _validation_started:
		return
	_validation_frame += 1
	if _validation_frame <= validation_warmup_frames:
		return

	var frame_ms := delta * 1000.0
	_validation_sample_count += 1
	_validation_total_frame_ms += frame_ms
	_validation_max_frame_ms = maxf(_validation_max_frame_ms, frame_ms)

	if _validation_sample_count >= validation_sample_frames:
		_finish_validation()


func _configure_demo() -> void:
	_wave_director = find_child("WaveDirector", true, false)
	if _wave_director == null:
		_configure_attempts += 1
		if _configure_attempts >= 120 and _validation_mode:
			_finish_validation_with_failure("WaveDirector did not install before demo validation timeout")
			return
		get_tree().process_frame.connect(Callable(self, "_configure_demo"), CONNECT_ONE_SHOT)
		return

	_apply_demo_wave_tuning()
	_apply_demo_quality_caps()
	_apply_starting_upgrades()
	_build_demo_overlay()
	_connect_teaching_signals()
	_update_objective("DEMO VECTOR: orbit mass, collect drops, read the rings, survive the boss.")
	_start_validation_if_requested()


func _apply_demo_wave_tuning() -> void:
	if _wave_director == null:
		return
	_set_if_present(_wave_director, &"demo_profile_enabled", true)
	_set_if_present(_wave_director, &"demo_last_wave", demo_last_wave)
	_set_if_present(_wave_director, &"demo_boss_wave", demo_boss_wave)
	_set_if_present(_wave_director, &"boss_every_waves", demo_last_wave)
	_set_if_present(_wave_director, &"max_regular_enemies", 8)
	_set_if_present(_wave_director, &"minimum_regular_wave_duration", 72.0)
	_set_if_present(_wave_director, &"wave_soft_timeout", 132.0)
	_set_if_present(_wave_director, &"rest_between_waves", 4.0)
	_set_if_present(_wave_director, &"pacing_reinforcement_interval", 14.0)
	_set_if_present(_wave_director, &"max_pacing_reinforcement_batches", 2)
	_set_if_present(_wave_director, &"pacing_reinforcement_count", 1)
	_set_if_present(_wave_director, &"far_planet_count", 1)
	_set_if_present(_wave_director, &"enable_interwave_galaxy_gates", false)
	_set_if_present(_wave_director, &"enable_anomaly_easter_eggs", false)
	_set_if_present(_wave_director, &"enable_permanent_wormhole_pair", false)
	_set_if_present(_wave_director, &"demo_max_enemies", 9)
	_set_if_present(_wave_director, &"demo_max_projectiles", 260)
	_set_if_present(_wave_director, &"demo_max_enemy_projectiles", 72)
	_set_if_present(_wave_director, &"demo_max_gravity_sources", 18)
	_set_if_present(_wave_director, &"demo_max_resonance_zones", 4)
	_set_if_present(_wave_director, &"demo_max_active_vfx_bursts", 8)
	_set_if_present(_wave_director, &"demo_max_particles_per_burst", 28)
	_set_if_present(_wave_director, &"demo_max_active_particles", 520)
	_connect_signal(_wave_director, &"wave_cleared", Callable(self, "_on_wave_cleared"))
	_connect_signal(_wave_director, &"boss_wave", Callable(self, "_on_boss_wave"))
	_connect_signal(_wave_director, &"regular_wave", Callable(self, "_on_regular_wave"))


func _apply_demo_quality_caps() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var juice := root.find_child("OrbitalJuiceManager", true, false)
	if juice != null:
		_set_if_present(juice, &"enable_late_game_instability", false)
		_set_if_present(juice, &"enable_spacetime_tear_spawns", false)
		_set_if_present(juice, &"enable_reality_collapse", false)
		_set_if_present(juice, &"enable_secret_bosses", false)
		_set_if_present(juice, &"enable_dynamic_celestial_bodies", false)
		_set_if_present(juice, &"enable_dev_hotkeys", false)
		_set_if_present(juice, &"enable_debug_balance_overlay", false)
		_set_if_present(juice, &"enable_stress_test_tools", _validation_mode)
		_set_if_present(juice, &"low_performance_mode", true)
	var budget := root.find_child("PerformanceBudgetDirector", true, false)
	if budget != null:
		_set_if_present(budget, &"quality_tier", 0)
		_set_if_present(budget, &"projectile_pressure_threshold", 260)
		_set_if_present(budget, &"enemy_pressure_threshold", 9)
	var drops := root.find_child("PhysicsDropSystem", true, false)
	if drops != null:
		_set_if_present(drops, &"max_active_drops", 22)
		_set_if_present(drops, &"momentum_orb_chance", 0.34)
		_set_if_present(drops, &"gravity_residue_chance", 0.28)
	var resonance := root.find_child("GravityResonanceManager", true, false)
	if resonance != null:
		_set_if_present(resonance, &"resonance_visual_quality", 1)
		_set_if_present(resonance, &"maximum_resonance_zones", 4)
		_set_if_present(resonance, &"max_visual_particles_per_zone", 8)
	var vfx := root.find_child("OrbitalVFXDirector", true, false)
	if vfx != null:
		_set_if_present(vfx, &"visual_quality", 1)
		_set_if_present(vfx, &"low_performance_mode", true)
		_set_if_present(vfx, &"max_active_bursts", 8)
		_set_if_present(vfx, &"max_particles_per_burst", 28)
	if _wave_director != null and _wave_director.has_method("_apply_demo_budget_caps"):
		_wave_director.call("_apply_demo_budget_caps")


func _apply_starting_upgrades() -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return
	var inventory := player.get_node_or_null("PowerupInventory")
	if inventory == null:
		inventory = PowerupInventory.new()
		inventory.name = "PowerupInventory"
		player.add_child(inventory)
	for powerup_id in starting_upgrade_ids:
		var definition := PowerupLibrary.get_definition(powerup_id)
		if definition != null and inventory.has_method("apply_powerup"):
			inventory.call("apply_powerup", definition)


func _build_demo_overlay() -> void:
	if _objective_label != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "DemoHUDLayer"
	layer.layer = 60
	add_child(layer)

	var panel := PanelContainer.new()
	panel.name = "DemoObjectivePanel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -330.0
	panel.offset_right = 330.0
	panel.offset_top = 16.0
	panel.offset_bottom = 76.0
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.01, 0.018, 0.032, 0.86), Color(0.2, 0.95, 1.0, 0.58)))
	layer.add_child(panel)

	_objective_label = Label.new()
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_objective_label.add_theme_font_size_override("font_size", 18)
	_objective_label.modulate = Color(0.78, 1.0, 0.96, 1.0)
	panel.add_child(_objective_label)

	_end_panel = PanelContainer.new()
	_end_panel.name = "DemoEndPanel"
	_end_panel.visible = false
	_end_panel.anchor_left = 0.5
	_end_panel.anchor_top = 0.5
	_end_panel.anchor_right = 0.5
	_end_panel.anchor_bottom = 0.5
	_end_panel.offset_left = -300.0
	_end_panel.offset_right = 300.0
	_end_panel.offset_top = -220.0
	_end_panel.offset_bottom = 230.0
	_end_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.014, 0.02, 0.04, 0.94), Color(1.0, 0.75, 0.25, 0.72)))
	layer.add_child(_end_panel)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	_end_panel.add_child(rows)

	var title := Label.new()
	title.text = "DEMO COMPLETE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.modulate = Color(1.0, 0.86, 0.36, 1.0)
	rows.add_child(title)

	var body := Label.new()
	body.text = "You cleared the vertical slice. Wishlist Vector Anomaly to catch the full run."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 16)
	body.modulate = Color(0.78, 0.95, 1.0, 0.92)
	rows.add_child(body)

	_end_score_label = Label.new()
	_end_score_label.text = "SCORE 0"
	_end_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_score_label.add_theme_font_size_override("font_size", 20)
	_end_score_label.modulate = Color(1.0, 0.86, 0.36, 1.0)
	rows.add_child(_end_score_label)

	_end_code_label = Label.new()
	_end_code_label.text = "CHALLENGE CODE: stabilizing"
	_end_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_code_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_code_label.add_theme_font_size_override("font_size", 13)
	_end_code_label.modulate = Color(0.72, 0.94, 1.0, 0.9)
	rows.add_child(_end_code_label)

	var wishlist := _make_button("Wishlist")
	wishlist.pressed.connect(_on_wishlist_pressed)
	rows.add_child(wishlist)

	var retry := _make_button("Retry Demo")
	retry.pressed.connect(_on_retry_pressed)
	rows.add_child(retry)

	var title_button := _make_button("Title Screen")
	title_button.pressed.connect(_on_title_pressed)
	rows.add_child(title_button)


func _on_boss_wave() -> void:
	_update_objective("SHOWCASE BOSS: orbit wide, cut through the gravity lane, spend boosts only for exits.")


func _on_regular_wave() -> void:
	if _wave_director == null or not _wave_director.has_method("get_current_wave"):
		return
	var wave := int(_wave_director.call("get_current_wave"))
	_update_objective(_prompt_for_wave(wave))


func _on_wave_cleared(wave: int) -> void:
	if _completed:
		return
	if wave >= demo_last_wave:
		_completed = true
		_store_demo_completion_summary()
		_update_objective("DEMO COMPLETE: score locked, challenge code ready.")
		if _end_panel != null:
			_end_panel.visible = true
	else:
		_update_objective("Wave %d cleared. Breathe, collect, then re-enter orbit." % wave)


func _prompt_for_wave(wave: int) -> String:
	match wave:
		1:
			return "WAVE 1: pass beside a planet, then leave on the tangent. Speed is survival."
		2:
			return "WAVE 2: gravity wells bend both you and enemies. Curve around them, don't fight straight lines."
		3:
			return "WAVE 3: rings are field rules. PULL, PUSH, FLOW, and SLOW change the route."
		4:
			return "WAVE 4: enemies drop recovery. Route through drops after a kill instead of stopping."
		5:
			return "WAVE 5: pressure test. Chain slingshots, use the field, recover before shields break."
		6:
			return "WAVE 6: showcase wave. Keep one exit angle open while chaos stacks."
		_:
			return "DEMO VECTOR: read gravity first, shoot second, escape always."


func _update_objective(text: String) -> void:
	if _objective_label != null:
		_objective_label.text = text


func _on_wishlist_pressed() -> void:
	if not steam_wishlist_url.strip_edges().is_empty():
		OS.shell_open(steam_wishlist_url)


func _on_title_pressed() -> void:
	get_tree().change_scene_to_file("res://Nodes/title_screen.tscn")


func _on_retry_pressed() -> void:
	if RunProgress != null:
		RunProgress.begin_new_run(false)
	get_tree().change_scene_to_file("res://Nodes/demo_game.tscn")


func _connect_signal(source: Node, signal_name: StringName, callable: Callable) -> void:
	if source != null and source.has_signal(signal_name) and not source.is_connected(signal_name, callable):
		source.connect(signal_name, callable)


func _connect_teaching_signals() -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player != null:
		_connect_signal(player, &"slingshot_window_changed", Callable(self, "_on_slingshot_window_changed"))
		_connect_signal(player, &"slingshot_mastery_scored", Callable(self, "_on_slingshot_mastery_scored"))
	var drops := get_tree().current_scene.find_child("PhysicsDropSystem", true, false) if get_tree().current_scene != null else null
	if drops != null:
		_connect_signal(drops, &"drop_collected", Callable(self, "_on_drop_collected"))


func _on_slingshot_window_changed(data: Dictionary) -> void:
	var state := StringName(data.get("state", &""))
	if state == &"sweet" or state == &"perfect" or state == &"apex":
		_update_objective("SLINGSHOT WINDOW: hold the tangent, then exit with speed.")


func _on_slingshot_mastery_scored(data: Dictionary) -> void:
	var grade := String(data.get("grade", "assist")).to_upper()
	var score := int(round(clampf(float(data.get("score", 0.0)), 0.0, 1.0) * 100.0))
	_update_objective("%s ORBIT %d%%: keep chaining speed through the next gravity well." % [grade, score])


func _on_drop_collected(_drop_type: int, _data: Dictionary) -> void:
	if _drop_prompt_seen:
		return
	_drop_prompt_seen = true
	_update_objective("DROP ROUTE: collect glowing fragments/orbs during exits to recover and snowball.")


func _set_if_present(target: Node, property_name: StringName, value: Variant) -> void:
	if target != null and target.get(property_name) != null:
		target.set(property_name, value)


func _prepare_validation_pacing() -> void:
	ProjectSettings.set_setting("display/window/vsync/vsync_mode", 0)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED, 0)


func _start_validation_if_requested() -> void:
	if not _validation_mode or _validation_started:
		return
	_validation_started = true
	if validation_run_stress_on_start:
		_validation_stress_report = _run_demo_stress_validator()


func _run_demo_stress_validator() -> Dictionary:
	var root := get_tree().current_scene
	if root == null:
		return {}
	var stress := root.find_child("StressTestDirector", true, false)
	if stress == null:
		stress = STRESS_TEST_DIRECTOR_SCENE.instantiate()
		stress.name = "StressTestDirector"
		root.add_child(stress)
	_set_if_present(stress, &"enabled", true)
	_set_if_present(stress, &"projectile_count", 48)
	_set_if_present(stress, &"gravity_well_count", 1)
	_set_if_present(stress, &"max_spawned_nodes", 72)
	_set_if_present(stress, &"spawn_radius", 920.0)
	_set_if_present(stress, &"extreme_velocity", 1650.0)
	if stress.has_method("run_extreme_arena_stress"):
		stress.call("run_extreme_arena_stress")
	if stress.has_method("validate_performance_budgets"):
		var value: Variant = stress.call("validate_performance_budgets")
		if value is Dictionary:
			return value as Dictionary
	return {}


func _finish_validation() -> void:
	_validation_started = false
	var report := _build_validation_report()
	print("DEMO_VALIDATION_REPORT:%s" % JSON.stringify(report))
	var ok := bool(report.get("within_budget", false))
	get_tree().quit(0 if ok else 1)


func _finish_validation_with_failure(reason: String) -> void:
	var report := {
		"profile": "steam_demo",
		"average_frame_ms": 0.0,
		"max_frame_ms": 0.0,
		"projectile_count": 0,
		"active_vfx": 0,
		"enemy_count": 0,
		"budget_failures": [reason],
		"within_budget": false,
	}
	print("DEMO_VALIDATION_REPORT:%s" % JSON.stringify(report))
	get_tree().quit(1)


func _build_validation_report() -> Dictionary:
	var wave_report: Dictionary = {}
	if _wave_director != null and _wave_director.has_method("validate_demo_budgets"):
		var value: Variant = _wave_director.call("validate_demo_budgets")
		if value is Dictionary:
			wave_report = value as Dictionary
	var average_frame_ms := _validation_total_frame_ms / float(maxi(_validation_sample_count, 1))
	var stress_value: Variant = wave_report.get("stress", {})
	var stress_report: Dictionary = stress_value if stress_value is Dictionary else {}
	if stress_report.is_empty():
		stress_report = _validation_stress_report
	var failures: Array = []
	var wave_failures: Variant = wave_report.get("failures", [])
	if wave_failures is Array:
		failures.append_array(wave_failures)
	var reported_fps := float(wave_report.get("fps", Engine.get_frames_per_second()))
	if average_frame_ms > 17.0 or (average_frame_ms > 16.7 and reported_fps < 58.5):
		failures.append("average frame time %.2f ms > 16.70 ms" % average_frame_ms)
	if _validation_max_frame_ms > 33.4:
		failures.append("max frame time %.2f ms > 33.40 ms" % _validation_max_frame_ms)
	var wave_ok := bool(wave_report.get("within_budget", false))
	return {
		"profile": "steam_demo",
		"average_frame_ms": average_frame_ms,
		"max_frame_ms": _validation_max_frame_ms,
		"projectile_count": int(wave_report.get("projectiles", 0)),
		"enemy_projectile_count": int(wave_report.get("enemy_projectiles", 0)),
		"active_vfx": int(wave_report.get("active_vfx_bursts", 0)),
		"enemy_count": int(wave_report.get("enemies", 0)),
		"gravity_sources": int(wave_report.get("gravity_sources", 0)),
		"resonance_zones": int(wave_report.get("resonance_zones", 0)),
		"active_particles": int(wave_report.get("active_particles", 0)),
		"within_budget": wave_ok and failures.is_empty(),
		"budget_failures": failures,
		"wave_report": wave_report,
		"stress": stress_report,
	}


func _store_demo_completion_summary() -> void:
	if RunProgress == null:
		return
	var snapshot_value: Variant = RunProgress.arena_flags.get("score_snapshot", {})
	var snapshot: Dictionary = snapshot_value if snapshot_value is Dictionary else {}
	var challenge_code := String(RunProgress.arena_flags.get("challenge_code", ""))
	RunProgress.arena_flags["demo_completion_summary"] = {
		"score": int(snapshot.get("score", 0)),
		"wave": demo_last_wave,
		"challenge_code": challenge_code,
	}
	if _end_score_label != null:
		_end_score_label.text = "SCORE %d | WAVE %d | APEX %d" % [
			int(snapshot.get("score", 0)),
			int(snapshot.get("wave", demo_last_wave)),
			int(snapshot.get("apex_slingshots", 0)),
		]
	if _end_code_label != null:
		_end_code_label.text = "CHALLENGE CODE: %s" % (challenge_code if not challenge_code.is_empty() else "stabilizing")


func _has_user_arg(flag: String) -> bool:
	for arg in OS.get_cmdline_user_args():
		if String(arg) == flag:
			return true
	return false


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 44.0)
	button.add_theme_font_size_override("font_size", 18)
	return button


func _panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style
