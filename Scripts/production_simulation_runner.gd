extends SceneTree

const LEVEL_SCENE := preload("res://Nodes/the_abyss.tscn")
const WARMUP_FRAMES := 45
const SAMPLE_FRAMES := 240
const MAX_AVERAGE_FRAME_MS := 16.7
const MAX_FRAME_MS := 33.4
const MAX_PROJECTILES := 1200

var _sample_count: int = 0
var _total_frame_ms: float = 0.0
var _max_frame_ms: float = 0.0


func _initialize() -> void:
	if RunProgress != null and RunProgress.has_method("begin_new_run"):
		RunProgress.begin_new_run(false)

	var level := LEVEL_SCENE.instantiate()
	_configure_level_for_production_sample(level)
	root.add_child(level)
	current_scene = level

	await process_frame
	await process_frame

	for frame in range(WARMUP_FRAMES + SAMPLE_FRAMES):
		var started_usec := Time.get_ticks_usec()
		await physics_frame
		await process_frame
		var elapsed_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
		if frame >= WARMUP_FRAMES:
			_sample_frame(elapsed_ms)

	var report := _build_report(level)
	var failure := _validate_report(report)
	if failure.is_empty():
		print("Production simulation passed: %s" % JSON.stringify(report))
		quit(0)
	else:
		push_error("Production simulation failed: %s | %s" % [failure, JSON.stringify(report)])
		quit(1)


func _configure_level_for_production_sample(level: Node) -> void:
	var juice := level.find_child("OrbitalJuiceManager", true, false)
	if juice == null:
		return
	_set_if_present(juice, &"enable_debug_balance_overlay", false)
	_set_if_present(juice, &"enable_dev_hotkeys", false)
	_set_if_present(juice, &"enable_stress_test_tools", true)
	_set_if_present(juice, &"run_stress_test_on_ready", true)
	_set_if_present(juice, &"spawn_showcase_content", false)
	_set_if_present(juice, &"low_performance_mode", false)


func _sample_frame(elapsed_ms: float) -> void:
	_sample_count += 1
	_total_frame_ms += elapsed_ms
	_max_frame_ms = maxf(_max_frame_ms, elapsed_ms)


func _build_report(level: Node) -> Dictionary:
	var report := {
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

	return report


func _validate_report(report: Dictionary) -> String:
	if int(report.get("samples", 0)) <= 0:
		return "no samples collected"
	if float(report.get("average_frame_ms", 999.0)) > MAX_AVERAGE_FRAME_MS:
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

	return ""


func _registry_count(group_name: StringName) -> int:
	if RuntimeRegistry != null:
		return RuntimeRegistry.get_count(group_name)
	return root.get_tree().get_nodes_in_group(group_name).size()


func _set_if_present(target: Node, property_name: StringName, value: Variant) -> void:
	if target.get(property_name) != null:
		target.set(property_name, value)
