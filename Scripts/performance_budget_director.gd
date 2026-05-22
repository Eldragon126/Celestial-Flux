extends Node
class_name PerformanceBudgetDirector

## Central place for scalable budgets. It does not own gameplay behavior; it
## nudges existing systems toward affordable settings for the selected tier.

enum QualityTier { LOW, MEDIUM, HIGH }

@export var enabled: bool = true
@export_enum("Low", "Medium", "High") var quality_tier: int = QualityTier.HIGH
@export var apply_interval: float = 1.0
@export var auto_low_fps_threshold: int = 42
@export var auto_recover_fps_threshold: int = 55
@export var auto_adjust_quality: bool = true

var _elapsed := 999.0


func _ready() -> void:
	add_to_group("performance_budget_director")
	set_process(true)
	call_deferred("apply_budgets")


func _process(delta: float) -> void:
	if not enabled:
		return
	_elapsed += delta
	if _elapsed < maxf(apply_interval, 0.25):
		return
	_elapsed = 0.0
	_update_auto_quality()
	apply_budgets()


func apply_budgets() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return

	var low := quality_tier == QualityTier.LOW
	var medium := quality_tier == QualityTier.MEDIUM

	_apply_resonance_budget(scene, low, medium)
	_apply_time_budget(scene, low)
	_apply_vfx_budget(scene, low, medium)
	_apply_enemy_ai_budget(scene, low, medium)
	_apply_player_budget(low)
	_apply_juice_coordinator_budget(scene, low)


func _apply_resonance_budget(scene: Node, low: bool, medium: bool) -> void:
	var resonance := scene.find_child("GravityResonanceManager", true, false)
	if resonance == null:
		return
	_set_if_present(resonance, "max_gravity_sources", 7 if low else (10 if medium else 12))
	_set_if_present(resonance, "maximum_resonance_zones", 2 if low else 3)
	_set_if_present(resonance, "max_projectiles_per_zone", 14 if low else (22 if medium else 32))
	_set_if_present(resonance, "max_bodies_per_zone", 18 if low else (28 if medium else 36))
	_set_if_present(resonance, "resonance_visual_quality", 1 if low else 2)
	_set_if_present(resonance, "max_visual_particles_per_zone", 12 if low else (24 if medium else 42))


func _apply_time_budget(scene: Node, low: bool) -> void:
	var time_manager := scene.find_child("TimeDilationManager", true, false)
	if time_manager == null:
		return
	_set_if_present(time_manager, "max_targets_per_tick", 32 if low else 64)
	_set_if_present(time_manager, "enable_afterimages", not low)
	_set_if_present(time_manager, "field_tick_interval", 0.045 if low else 0.03)


func _apply_vfx_budget(scene: Node, low: bool, medium: bool) -> void:
	var vfx := scene.find_child("OrbitalVFXDirector", true, false)
	if vfx == null:
		return
	_set_if_present(vfx, "visual_quality", 1 if low else 2)
	_set_if_present(vfx, "low_performance_mode", low)
	_set_if_present(vfx, "max_active_bursts", 8 if low else (12 if medium else 18))
	_set_if_present(vfx, "max_particles_per_burst", 28 if low else (48 if medium else 72))


func _apply_enemy_ai_budget(scene: Node, low: bool, medium: bool) -> void:
	var director := scene.find_child("PhysicsAwareEnemyDirector", true, false)
	if director == null:
		return
	_set_if_present(director, "think_interval", 0.18 if low else (0.14 if medium else 0.12))
	_set_if_present(director, "max_tracked_enemies", 20 if low else (28 if medium else 34))
	_set_if_present(director, "max_gravity_sources_sampled", 4 if low else 6)
	_set_if_present(director, "max_bodies_per_field", 26 if low else (36 if medium else 48))


func _apply_juice_coordinator_budget(scene: Node, low: bool) -> void:
	var juice := scene.find_child("JuiceCoordinator", true, false)
	if juice == null:
		return
	_set_if_present(juice, "low_performance_mode", low)
	_set_if_present(juice, "disable_mastery_line2d", low)


func _apply_player_budget(low: bool) -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return
	_set_if_present(player, "max_gravity_sources", 3 if low else 4)
	_set_if_present(player, "gravity_source_refresh_interval", 0.45 if low else 0.35)


func _update_auto_quality() -> void:
	if not auto_adjust_quality:
		return
	var fps := Engine.get_frames_per_second()
	if fps > 0 and fps < auto_low_fps_threshold and quality_tier > QualityTier.LOW:
		quality_tier = QualityTier.LOW
	elif fps >= auto_recover_fps_threshold and quality_tier == QualityTier.LOW:
		quality_tier = QualityTier.MEDIUM


func _set_if_present(target: Node, property_name: StringName, value: Variant) -> void:
	if target.get(property_name) == null:
		return
	target.set(property_name, value)


func get_budget_debug_state() -> Dictionary:
	return {
		"enabled": enabled,
		"quality": quality_tier,
		"fps": Engine.get_frames_per_second(),
	}
