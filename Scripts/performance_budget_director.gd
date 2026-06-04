extends Node
class_name PerformanceBudgetDirector

## Central place for scalable budgets. It does not own gameplay behavior; it
## nudges existing systems toward affordable settings for the selected tier.

enum QualityTier { LOW, MEDIUM, HIGH }

@export var enabled: bool = true
@export_enum("Low", "Medium", "High") var quality_tier: int = QualityTier.MEDIUM
@export var apply_interval: float = 1.0
@export var auto_low_fps_threshold: int = 54
@export var auto_recover_fps_threshold: int = 72
@export var auto_adjust_quality: bool = true
@export var projectile_pressure_threshold: int = 180
@export var enemy_pressure_threshold: int = 36

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
	_apply_gravity_scar_budget(scene, low, medium)
	_apply_event_horizon_budget(scene, low)
	_apply_vfx_budget(scene, low, medium)
	_apply_enemy_ai_budget(scene, low, medium)
	_apply_player_budget(low)
	_apply_juice_coordinator_budget(scene, low)
	_apply_new_director_budget(scene, low, medium)


func _apply_resonance_budget(scene: Node, low: bool, medium: bool) -> void:
	var resonance := scene.find_child("GravityResonanceManager", true, false)
	if resonance == null:
		return
	_set_if_present(resonance, "max_gravity_sources", 5 if low else (7 if medium else 9))
	_set_if_present(resonance, "maximum_resonance_zones", 1 if low else 2)
	_set_if_present(resonance, "max_projectiles_per_zone", 10 if low else (16 if medium else 24))
	_set_if_present(resonance, "max_bodies_per_zone", 12 if low else (20 if medium else 28))
	_set_if_present(resonance, "resonance_visual_quality", 1 if low else 2)
	_set_if_present(resonance, "max_visual_particles_per_zone", 6 if low else (12 if medium else 20))
	_set_if_present(resonance, "visual_ring_segments", 32 if low else (44 if medium else 56))


func _apply_time_budget(scene: Node, low: bool) -> void:
	var time_manager := scene.find_child("TimeDilationManager", true, false)
	if time_manager == null:
		return
	_set_if_present(time_manager, "max_targets_per_tick", 24 if low else 44)
	_set_if_present(time_manager, "enable_afterimages", not low)
	_set_if_present(time_manager, "field_tick_interval", 0.055 if low else 0.04)


func _apply_gravity_scar_budget(scene: Node, low: bool, medium: bool) -> void:
	var scars := scene.find_child("GravityScarManager", true, false)
	if scars == null:
		return
	_set_if_present(scars, "max_active_scars", 4 if low else (5 if medium else 7))
	_set_if_present(scars, "visual_quality", 1 if low else 2)
	_set_if_present(scars, "max_particles_per_scar", 6 if low else (12 if medium else 22))
	_set_if_present(scars, "max_body_targets_per_tick", 16 if low else (24 if medium else 32))
	_set_if_present(scars, "max_projectile_targets_per_tick", 18 if low else (30 if medium else 42))
	_set_if_present(scars, "field_tick_interval", 0.075 if low else 0.055)


func _apply_event_horizon_budget(scene: Node, low: bool) -> void:
	var horizon := scene.find_child("EventHorizonDirector", true, false)
	if horizon == null:
		return
	_set_if_present(horizon, "max_targets_per_tick", 28 if low else 52)
	_set_if_present(horizon, "field_tick_interval", 0.055 if low else 0.04)
	_set_if_present(horizon, "screen_warp_enabled", not low)


func _apply_vfx_budget(scene: Node, low: bool, medium: bool) -> void:
	var vfx := scene.find_child("OrbitalVFXDirector", true, false)
	if vfx == null:
		return
	_set_if_present(vfx, "visual_quality", 1 if low else 2)
	_set_if_present(vfx, "low_performance_mode", low)
	_set_if_present(vfx, "max_active_bursts", 5 if low else (8 if medium else 12))
	_set_if_present(vfx, "max_particles_per_burst", 16 if low else (28 if medium else 44))


func _apply_enemy_ai_budget(scene: Node, low: bool, medium: bool) -> void:
	var director := scene.find_child("PhysicsAwareEnemyDirector", true, false)
	if director == null:
		return
	_set_if_present(director, "think_interval", 0.22 if low else (0.17 if medium else 0.14))
	_set_if_present(director, "max_tracked_enemies", 16 if low else (24 if medium else 30))
	_set_if_present(director, "max_gravity_sources_sampled", 3 if low else 4)
	_set_if_present(director, "max_bodies_per_field", 18 if low else (28 if medium else 38))


func _apply_juice_coordinator_budget(scene: Node, low: bool) -> void:
	var juice := scene.find_child("JuiceCoordinator", true, false)
	if juice == null:
		return
	_set_if_present(juice, "low_performance_mode", low)
	_set_if_present(juice, "disable_mastery_line2d", low)


func _apply_new_director_budget(scene: Node, low: bool, medium: bool) -> void:
	var late_instability := scene.find_child("LateGameInstabilityDirector", true, false)
	if late_instability != null:
		_set_if_present(late_instability, "max_targets_per_event", 10 if low else (16 if medium else 22))
		_set_if_present(late_instability, "event_interval", 18.0 if low else (15.0 if medium else 13.0))
	var coop_combo := scene.find_child("CoopComboDirector", true, false)
	if coop_combo != null:
		_set_if_present(coop_combo, "max_slow_targets", 8 if low else (12 if medium else 18))
	var adaptive_music := scene.find_child("AdaptiveMusicStateDirector", true, false)
	if adaptive_music != null:
		_set_if_present(adaptive_music, "sample_interval", 0.35 if low else 0.2)
	var transition := scene.find_child("RunTransitionDirector", true, false)
	if transition != null:
		_set_if_present(transition, "wash_alpha", 0.12 if low else (0.18 if medium else 0.24))
	var tear := scene.find_child("SpacetimeTearDirector", true, false)
	if tear != null:
		_set_if_present(tear, "max_active_tears", 1 if low else (2 if medium else 3))
		_set_if_present(tear, "max_alive_tear_enemies", 3 if low else (4 if medium else 6))
		_set_if_present(tear, "max_enemies_per_tear", 1 if low else 2)
	var wave := scene.find_child("WaveDirector", true, false)
	if wave != null:
		_set_if_present(wave, "max_regular_enemies", 7 if low else (8 if medium else 10))


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
	var projectile_pressure := _group_count(&"Projectiles") + _group_count(&"enemy_projectiles")
	var enemy_pressure := _group_count(&"enemies")
	if projectile_pressure >= projectile_pressure_threshold or enemy_pressure >= enemy_pressure_threshold:
		quality_tier = QualityTier.LOW
		return
	if fps > 0 and fps < auto_low_fps_threshold and quality_tier > QualityTier.LOW:
		quality_tier = QualityTier.LOW
	elif fps >= auto_recover_fps_threshold and quality_tier == QualityTier.LOW:
		quality_tier = QualityTier.MEDIUM


func _set_if_present(target: Node, property_name: StringName, value: Variant) -> void:
	if target.get(property_name) == null:
		return
	target.set(property_name, value)


func _group_count(group_name: StringName) -> int:
	if RuntimeRegistry != null:
		return RuntimeRegistry.get_count(group_name)
	return get_tree().get_nodes_in_group(group_name).size()


func get_budget_debug_state() -> Dictionary:
	return {
		"enabled": enabled,
		"quality": quality_tier,
		"fps": Engine.get_frames_per_second(),
	}
