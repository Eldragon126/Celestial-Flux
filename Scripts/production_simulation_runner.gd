extends Node

const LEVEL_SCENE := preload("res://Nodes/the_abyss.tscn")
const DEMO_LEVEL_SCENE := preload("res://Nodes/demo_game.tscn")
const WARMUP_FRAMES := 45
const SAMPLE_FRAMES := 240
const MAX_AVERAGE_FRAME_MS := 16.7
const MAX_FRAME_MS := 33.4
const MAX_PROJECTILES := 1200

var _sample_count: int = 0
var _total_frame_ms: float = 0.0
var _max_frame_ms: float = 0.0
var _demo_profile: bool = false
var _demo_stress_report: Dictionary = {}
var _level: Node = null
var _setup_frames_remaining: int = 0
var _warmup_frames: int = WARMUP_FRAMES
var _sample_frame_index: int = 0
var _stress_started: bool = false


func _ready() -> void:
	set_process(false)
	call_deferred("_start_runner")


func _start_runner() -> void:
	_demo_profile = _has_user_arg("--demo-profile") or _has_user_arg("--steam-demo")
	_prepare_validation_pacing()
	if RunProgress != null and RunProgress.has_method("begin_new_run"):
		RunProgress.begin_new_run(false)
		if _demo_profile:
			RunProgress.arena_flags["run_profile"] = "steam_demo"

	_level = DEMO_LEVEL_SCENE.instantiate() if _demo_profile else LEVEL_SCENE.instantiate()
	_configure_level_for_production_sample(_level)
	get_tree().root.add_child(_level)
	get_tree().current_scene = _level
	_setup_frames_remaining = 24 if _demo_profile else 4
	_warmup_frames = 180 if _demo_profile else WARMUP_FRAMES
	set_process(true)


func _process(delta: float) -> void:
	if _level == null:
		_finish_with_failure("level failed to instantiate")
		return
	if _setup_frames_remaining > 0:
		_setup_frames_remaining -= 1
		return
	if _demo_profile and not _stress_started:
		_stress_started = true
		_demo_stress_report = _run_demo_stress_validator(_level)
		return
	_sample_frame_index += 1
	if _sample_frame_index <= _warmup_frames:
		return
	_sample_frame(delta * 1000.0)
	if _sample_count >= SAMPLE_FRAMES:
		_finish()


func _finish() -> void:
	var report := _build_report(_level)
	var failure := _validate_report(report)
	if failure.is_empty():
		print("Production simulation passed: %s" % JSON.stringify(report))
		get_tree().quit(0)
	else:
		push_error("Production simulation failed: %s | %s" % [failure, JSON.stringify(report)])
		get_tree().quit(1)


func _finish_with_failure(reason: String) -> void:
	push_error("Production simulation failed: %s" % reason)
	get_tree().quit(1)


func _configure_level_for_production_sample(level: Node) -> void:
	var juice := level.find_child("OrbitalJuiceManager", true, false)
	if juice == null:
		return
	_set_if_present(juice, &"enable_debug_balance_overlay", false)
	_set_if_present(juice, &"enable_dev_hotkeys", false)
	_set_if_present(juice, &"enable_stress_test_tools", not _demo_profile)
	_set_if_present(juice, &"run_stress_test_on_ready", not _demo_profile)
	_set_if_present(juice, &"spawn_showcase_content", false)
	_set_if_present(juice, &"low_performance_mode", _demo_profile)


func _sample_frame(elapsed_ms: float) -> void:
	_sample_count += 1
	_total_frame_ms += elapsed_ms
	_max_frame_ms = maxf(_max_frame_ms, elapsed_ms)


func _build_report(level: Node) -> Dictionary:
	var report := {
		"profile": "steam_demo" if _demo_profile else "production",
		"samples": _sample_count,
		"average_frame_ms": _total_frame_ms / float(maxi(_sample_count, 1)),
		"max_frame_ms": _max_frame_ms,
		"projectiles": _registry_count(&"Projectiles"),
		"enemy_projectiles": _registry_count(&"enemy_projectiles"),
		"gravity_sources": _registry_count(&"Objects_With_Gravity"),
		"enemies": _registry_count(&"enemies") + _registry_count(&"wave_enemy"),
	}

	var vfx := level.find_child("OrbitalVFXDirector", true, false)
	if vfx != null and vfx.has_method("get_vfx_debug_state"):
		report["vfx"] = vfx.call("get_vfx_debug_state")

	var budget := level.find_child("PerformanceBudgetDirector", true, false)
	if budget != null and budget.has_method("get_budget_debug_state"):
		report["budget"] = budget.call("get_budget_debug_state")

	var stress := level.find_child("StressTestDirector", true, false)
	if stress != null and stress.has_method("validate_performance_budgets"):
		report["stress"] = stress.call("validate_performance_budgets")
	if _demo_profile:
		var existing_stress: Dictionary = report.get("stress", {})
		if existing_stress.is_empty():
			report["stress"] = _demo_stress_report
		var wave_director := level.find_child("WaveDirector", true, false)
		if wave_director != null and wave_director.has_method("validate_demo_budgets"):
			var value: Variant = wave_director.call("validate_demo_budgets")
			if value is Dictionary:
				report["demo_budget"] = value as Dictionary

	return report


func _validate_report(report: Dictionary) -> String:
	if int(report.get("samples", 0)) <= 0:
		return "no samples collected"
	var reported_fps := _reported_fps(report)
	var average_frame_ms := float(report.get("average_frame_ms", 999.0))
	if average_frame_ms > 17.0 or (average_frame_ms > MAX_AVERAGE_FRAME_MS and reported_fps < 58.5):
		return "average frame time exceeded %.2f ms" % MAX_AVERAGE_FRAME_MS
	if float(report.get("max_frame_ms", 999.0)) > MAX_FRAME_MS:
		return "single frame exceeded %.2f ms" % MAX_FRAME_MS
	if int(report.get("projectiles", 0)) > MAX_PROJECTILES:
		return "projectile budget exceeded"

	var vfx: Dictionary = report.get("vfx", {})
	if not vfx.is_empty() and int(vfx.get("active_bursts", 0)) > int(vfx.get("burst_cap", 0)):
		return "vfx burst cap exceeded"

	var stress: Dictionary = report.get("stress", {})
	if not stress.is_empty() and not bool(stress.get("within_budget", true)):
		return "stress budget validation failed"
	var demo_budget: Dictionary = report.get("demo_budget", {})
	if _demo_profile and (demo_budget.is_empty() or not bool(demo_budget.get("within_budget", false))):
		return "demo budget validation failed"

	return ""


func _reported_fps(report: Dictionary) -> float:
	var budget: Dictionary = report.get("budget", {})
	if not budget.is_empty():
		return float(budget.get("fps", Engine.get_frames_per_second()))
	var demo_budget: Dictionary = report.get("demo_budget", {})
	if not demo_budget.is_empty():
		return float(demo_budget.get("fps", Engine.get_frames_per_second()))
	return float(Engine.get_frames_per_second())


func _registry_count(group_name: StringName) -> int:
	if RuntimeRegistry != null:
		return RuntimeRegistry.get_count(group_name)
	return get_tree().get_nodes_in_group(group_name).size()


func _set_if_present(target: Node, property_name: StringName, value: Variant) -> void:
	if target.get(property_name) != null:
		target.set(property_name, value)


func _prepare_validation_pacing() -> void:
	ProjectSettings.set_setting("display/window/vsync/vsync_mode", 0)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED, 0)


func _run_demo_stress_validator(level: Node) -> Dictionary:
	if level != null and level.has_method("_run_demo_stress_validator"):
		var value: Variant = level.call("_run_demo_stress_validator")
		if value is Dictionary:
			return value as Dictionary
	return {}


func _has_user_arg(flag: String) -> bool:
	for arg in OS.get_cmdline_user_args():
		if String(arg) == flag:
			return true
	return false
