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
@export var network_projectile_pressure_threshold: int = 120
@export var network_enemy_pressure_threshold: int = 24
@export var multiplayer_low_fps_threshold: int = 58

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
	_apply_prediction_budget(low, medium)
	_apply_projectile_visual_budget(low, medium)
	_apply_juice_coordinator_budget(scene, low)
	_apply_new_director_budget(scene, low, medium)


func _apply_resonance_budget(scene: Node, low: bool, medium: bool) -> void:
	var resonance := scene.find_child("GravityResonanceManager", true, false)
	if resonance == null:
		return
	var networked := _is_network_active()
	var effective_low := low or networked
	_set_if_present(resonance, "max_gravity_sources", 5 if effective_low else (7 if medium else 9))
	_set_if_present(resonance, "maximum_resonance_zones", 1 if effective_low else 2)
	_set_if_present(resonance, "max_projectiles_per_zone", 10 if effective_low else (16 if medium else 24))
	_set_if_present(resonance, "max_bodies_per_zone", 12 if effective_low else (20 if medium else 28))
	_set_if_present(resonance, "resonance_visual_quality", 1 if effective_low else 2)
	_set_if_present(resonance, "max_visual_particles_per_zone", 6 if effective_low else (12 if medium else 20))
	_set_if_present(resonance, "visual_ring_segments", 32 if effective_low else (44 if medium else 56))


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
	var effective_low := low or _is_network_active()
	_set_if_present(vfx, "visual_quality", 1 if effective_low else 2)
	_set_if_present(vfx, "low_performance_mode", effective_low)
	_set_if_present(vfx, "max_active_bursts", 5 if effective_low else (8 if medium else 12))
	_set_if_present(vfx, "max_particles_per_burst", 16 if effective_low else (28 if medium else 44))


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
		_set_if_present(tear, "horde_max_alive_enemies", 6 if low else (9 if medium else 14))
		_set_if_present(tear, "horde_max_enemies_per_tear", 4 if low else (6 if medium else 8))
		_set_if_present(tear, "horde_spawn_interval", 0.72 if low else (0.56 if medium else 0.42))
	var swim := scene.find_child("SpacetimeSwimDirector", true, false)
	if swim != null:
		_set_if_present(swim, "enable_fabric_shader", not low)
		_set_if_present(swim, "fabric_update_interval", 0.09 if medium else 0.05)
		_set_if_present(swim, "fabric_crack_density", 5.2 if medium else 7.0)
	var collapse := scene.find_child("RealityCollapseDirector", true, false)
	if collapse != null:
		_set_if_present(collapse, "enable_fabric_shader", not low)
		_set_if_present(collapse, "fabric_update_interval", 0.1 if medium else 0.06)
	var anomaly := scene.find_child("VectorAnomalyDirector", true, false)
	if anomaly != null:
		_set_if_present(anomaly, "max_active_micro_lenses", 2 if low else (3 if medium else 4))
		_set_if_present(anomaly, "collapse_event_cooldown", 0.34 if low else (0.26 if medium else 0.22))
		_set_if_present(anomaly, "relativistic_impact_cooldown", 0.22 if low else (0.17 if medium else 0.14))
		_set_if_present(anomaly, "transient_ring_chaos_skip_threshold", 0.52 if low else (0.64 if medium else 0.72))
	var wave := scene.find_child("WaveDirector", true, false)
	if wave != null:
		_set_if_present(wave, "max_regular_enemies", 7 if low else (8 if medium else 10))
	var heat_map := scene.find_child("GravityHeatMapOverlay", true, false)
	if heat_map != null:
		_set_if_present(heat_map, "sample_columns", 25 if low else (33 if medium else 39))
		_set_if_present(heat_map, "sample_rows", 17 if low else (21 if medium else 25))
		_set_if_present(heat_map, "refresh_interval", 0.12 if low else (0.09 if medium else 0.075))
		_set_if_present(heat_map, "max_gravity_sources", 6 if low else (9 if medium else 12))
		_set_if_present(heat_map, "max_contour_segments", 520 if low else (760 if medium else 980))
		_set_if_present(heat_map, "max_gradient_vectors", 48 if low else (72 if medium else 95))
	for hazard in get_tree().get_nodes_in_group("gravity_wave_maker"):
		var node := hazard as Node
		if node == null or not is_instance_valid(node):
			continue
		_set_if_present(node, "number_of_points", 18 if low else (22 if medium else 28))
		_set_if_present(node, "max_active_groups", 2 if low else 3)
		_set_if_present(node, "max_physics_points_per_group", 5 if low else (7 if medium else 8))
		_set_if_present(node, "physics_update_interval", 0.075 if low else (0.06 if medium else 0.05))
		_set_if_present(node, "visual_update_interval", 0.065 if low else (0.05 if medium else 0.04))
	for hazard in get_tree().get_nodes_in_group("pulsating_gravity_spawner"):
		var node := hazard as Node
		if node == null or not is_instance_valid(node):
			continue
		_set_if_present(node, "max_active_fields", 1 if low else 2)
		_set_if_present(node, "visual_update_interval", 0.08 if low else (0.06 if medium else 0.05))


func _apply_player_budget(low: bool) -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return
	_set_if_present(player, "max_gravity_sources", 3 if low else 4)
	_set_if_present(player, "gravity_source_refresh_interval", 0.45 if low else 0.35)


func _apply_prediction_budget(low: bool, medium: bool) -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return
	var effective_low := low or _is_network_active()
	var aim := player.get_node_or_null("ProjectileAimPredictor")
	if aim != null:
		_set_if_present(aim, "prediction_steps", 58 if effective_low else (96 if medium else 110))
		_set_if_present(aim, "substeps", 1 if effective_low else 2)
		_set_if_present(aim, "ghost_count", 0)
		_set_if_present(aim, "max_draw_segments", 42 if effective_low else (96 if medium else 110))
		_set_if_present(aim, "prediction_recalculate_interval", 0.09 if effective_low else (0.06 if medium else 0.045))
		_set_if_present(aim, "pressure_hide_threshold", 72 if effective_low else (104 if medium else 128))
	var trajectory := player.get_node_or_null("OrbitalTrajectoryPredictor")
	if trajectory != null:
		_set_if_present(trajectory, "prediction_steps", 72 if effective_low else (92 if medium else 112))
		_set_if_present(trajectory, "max_gravity_sources", 3 if effective_low else 4)
		_set_if_present(trajectory, "max_branch_count", 1 if effective_low else (2 if medium else 3))
		_set_if_present(trajectory, "max_draw_segments", 52 if effective_low else (68 if medium else 84))
		_set_if_present(trajectory, "prediction_recalculate_interval", 0.1 if effective_low else (0.075 if medium else 0.06))
		_set_if_present(trajectory, "pressure_hide_threshold", 84 if effective_low else (108 if medium else 128))


func _apply_projectile_visual_budget(low: bool, medium: bool) -> void:
	var pressure := _group_count(&"Projectiles")
	var effective_low := low or _is_network_active()
	if not effective_low and pressure < projectile_pressure_threshold:
		return
	var vector_cap := 8 if effective_low else (16 if medium else 22)
	var rail_cap := 10 if effective_low else (18 if medium else 26)
	var soft_cap := 44 if effective_low else (58 if medium else 70)
	var hard_cap := 82 if effective_low else (106 if medium else 128)
	for projectile in get_tree().get_nodes_in_group("Projectiles"):
		var node := projectile as Node
		if node == null or not is_instance_valid(node):
			continue
		_set_if_present(node, "vector_trail_particle_cap", vector_cap)
		_set_if_present(node, "rail_trail_particle_cap", rail_cap)
		_set_if_present(node, "visual_pressure_soft_cap", soft_cap)
		_set_if_present(node, "visual_pressure_hard_cap", hard_cap)


func _update_auto_quality() -> void:
	if not auto_adjust_quality:
		return
	var fps := Engine.get_frames_per_second()
	var projectile_pressure := _group_count(&"Projectiles") + _group_count(&"enemy_projectiles")
	var enemy_pressure := _group_count(&"enemies")
	var networked := _is_network_active()
	var projectile_threshold := network_projectile_pressure_threshold if networked else projectile_pressure_threshold
	var enemy_threshold := network_enemy_pressure_threshold if networked else enemy_pressure_threshold
	var low_fps_threshold := multiplayer_low_fps_threshold if networked else auto_low_fps_threshold
	if projectile_pressure >= projectile_threshold or enemy_pressure >= enemy_threshold:
		quality_tier = QualityTier.LOW
		return
	if fps > 0 and fps < low_fps_threshold and quality_tier > QualityTier.LOW:
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


func _is_network_active() -> bool:
	return NetworkSession != null and NetworkSession.has_method("is_network_active") and bool(NetworkSession.call("is_network_active"))


func get_budget_debug_state() -> Dictionary:
	return {
		"enabled": enabled,
		"quality": quality_tier,
		"fps": Engine.get_frames_per_second(),
		"projectile_pressure": _group_count(&"Projectiles") + _group_count(&"enemy_projectiles"),
		"enemy_pressure": _group_count(&"enemies"),
	}
