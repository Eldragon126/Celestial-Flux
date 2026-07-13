extends Node
class_name PerformanceBudgetDirector

## Central place for scalable budgets. It does not own gameplay behavior; it
## nudges existing systems toward affordable settings for the selected tier.

signal quality_tier_changed(tier: int, reason: StringName)
signal performance_spike_recorded(sample: Dictionary)

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
@export_group("Spike Telemetry")
@export var monitor_frame_spikes: bool = true
@export var spike_frame_ms_threshold: float = 42.0
@export var severe_spike_frame_ms_threshold: float = 100.0
@export var auto_low_on_frame_spike: bool = true
@export var spike_reaction_cooldown: float = 1.5
@export var spike_log_capacity: int = 36
@export var write_spikes_to_run_progress: bool = true
@export var run_progress_spike_export_interval: float = 2.0

var _elapsed := 999.0
var _group_buffer: Array[Node2D] = []
var _spike_log: Array[Dictionary] = []
var _spike_cooldown_remaining: float = 0.0
var _spike_export_elapsed: float = 999.0
var _last_quality_reason: StringName = &"initial"


func _ready() -> void:
	add_to_group("performance_budget_director")
	set_process(true)
	call_deferred("apply_budgets")


func _process(delta: float) -> void:
	if not enabled:
		return
	_sample_frame_spike(delta)
	_spike_cooldown_remaining = maxf(_spike_cooldown_remaining - delta, 0.0)
	_spike_export_elapsed += delta
	if write_spikes_to_run_progress and _spike_export_elapsed >= maxf(run_progress_spike_export_interval, 0.25):
		_spike_export_elapsed = 0.0
		_export_spikes_to_run_progress()
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
	_apply_feedback_budget(scene, low, medium)
	_apply_particle_culling_budget(scene, low, medium)
	_apply_modding_budget(scene, low, medium)
	_apply_campaign_budget(scene, low, medium)
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
		_set_if_present(swim, "fabric_update_interval", 0.12 if low else (0.09 if medium else 0.05))
		_set_if_present(swim, "fabric_crack_density", 3.8 if low else (5.2 if medium else 7.0))
	var collapse := scene.find_child("RealityCollapseDirector", true, false)
	if collapse != null:
		_set_if_present(collapse, "enable_fabric_shader", not low)
		_set_if_present(collapse, "fabric_update_interval", 0.13 if low else (0.1 if medium else 0.06))
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
	_fill_group(&"gravity_wave_maker", _group_buffer)
	for hazard in _group_buffer:
		var node := hazard as Node
		if node == null or not is_instance_valid(node):
			continue
		_set_if_present(node, "number_of_points", 18 if low else (22 if medium else 28))
		_set_if_present(node, "max_active_groups", 2 if low else 3)
		_set_if_present(node, "max_physics_points_per_group", 5 if low else (7 if medium else 8))
		_set_if_present(node, "physics_update_interval", 0.075 if low else (0.06 if medium else 0.05))
		_set_if_present(node, "visual_update_interval", 0.065 if low else (0.05 if medium else 0.04))
	_fill_group(&"pulsating_gravity_spawner", _group_buffer)
	for hazard in _group_buffer:
		var node := hazard as Node
		if node == null or not is_instance_valid(node):
			continue
		_set_if_present(node, "max_active_fields", 1 if low else 2)
		_set_if_present(node, "visual_update_interval", 0.08 if low else (0.06 if medium else 0.05))


func _apply_feedback_budget(scene: Node, low: bool, medium: bool) -> void:
	var feedback := scene.find_child("DamageIndicatorManager", true, false)
	if feedback == null:
		return
	var effective_low := low or _is_network_active()
	_set_if_present(feedback, "max_indicators_per_frame", 5 if effective_low else (8 if medium else 12))
	_set_if_present(feedback, "max_rings_per_frame", 3 if effective_low else (5 if medium else 8))
	_set_if_present(feedback, "max_streaks_per_frame", 3 if effective_low else (5 if medium else 8))
	_set_if_present(feedback, "max_target_flashes_per_frame", 7 if effective_low else (11 if medium else 16))
	_set_if_present(feedback, "allow_pool_growth", not effective_low)
	_set_if_present(feedback, "enable_direction_streaks", not effective_low)
	_set_if_present(feedback, "enable_feedback_recoil", not effective_low)
	_set_if_present(feedback, "ring_segments", 24 if effective_low else (34 if medium else 42))


func _apply_particle_culling_budget(scene: Node, low: bool, medium: bool) -> void:
	var culler := scene.find_child("ParticleFocusCuller", true, false)
	if culler == null:
		return
	_set_if_present(culler, "scan_interval", 1.55 if low else (1.15 if medium else 0.9))
	_set_if_present(culler, "focus_refresh_interval", 0.24 if low else (0.18 if medium else 0.14))
	_set_if_present(culler, "max_nodes_per_scan_step", 150 if low else (240 if medium else 360))
	_set_if_present(culler, "max_tracked_particles", 170 if low else (260 if medium else 360))
	_set_if_present(culler, "player_focus_radius", 1250.0 if low else (1550.0 if medium else 1800.0))


func _apply_modding_budget(scene: Node, low: bool, medium: bool) -> void:
	var hooks := scene.find_child("ModHookDirector", true, false)
	if hooks == null:
		return
	_set_if_present(hooks, "reconnect_interval", 0.9 if low else (0.65 if medium else 0.45))
	_set_if_present(hooks, "max_entries_per_hook", 4 if low else (6 if medium else 8))
	_set_if_present(hooks, "max_effects_per_entry", 2 if low else (3 if medium else 4))
	_set_if_present(hooks, "max_projectile_signal_connections_per_pass", 24 if low else (36 if medium else 48))


func _apply_campaign_budget(scene: Node, low: bool, medium: bool) -> void:
	var campaign := scene.find_child("CampaignModeDirector", true, false)
	if campaign == null:
		return
	_set_if_present(campaign, "debug_overlay_refresh_interval", 0.35 if low else (0.25 if medium else 0.18))


func _apply_player_budget(low: bool) -> void:
	_fill_group(&"Player", _group_buffer)
	for player in _group_buffer:
		if player == null or not is_instance_valid(player):
			continue
		_set_if_present(player, "max_gravity_sources", 3 if low else 4)
		_set_if_present(player, "gravity_source_refresh_interval", 0.45 if low else 0.35)


func _apply_prediction_budget(low: bool, medium: bool) -> void:
	var effective_low := low or _is_network_active()
	_fill_group(&"Player", _group_buffer)
	for player in _group_buffer:
		if player == null or not is_instance_valid(player):
			continue
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
	_fill_group(&"Projectiles", _group_buffer)
	for projectile in _group_buffer:
		var node := projectile as Node
		if node == null or not is_instance_valid(node):
			continue
		_set_if_present(node, "vector_trail_particle_cap", vector_cap)
		_set_if_present(node, "rail_trail_particle_cap", rail_cap)
		_set_if_present(node, "visual_pressure_soft_cap", soft_cap)
		_set_if_present(node, "visual_pressure_hard_cap", hard_cap)
		_set_if_present(node, "visual_budget_refresh_interval", 0.24 if effective_low else (0.18 if medium else 0.14))
		_set_if_present(node, "trail_focus_radius", 1300.0 if effective_low else (1650.0 if medium else 1900.0))
		_set_if_present(node, "gravity_source_refresh_interval", 0.32 if effective_low else (0.24 if medium else 0.18))
		_set_if_present(node, "gravity_refresh_distance_threshold", 540.0 if effective_low else (420.0 if medium else 340.0))
		_set_if_present(node, "enemy_projectile_light_reduced_flash_cap", 0.62 if effective_low else (0.82 if medium else 0.92))
		_set_if_present(node, "captured_projectile_light_reduced_flash_cap", 0.72 if effective_low else (0.94 if medium else 1.05))


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
		_set_quality_tier(QualityTier.LOW, &"entity_pressure")
		return
	if fps > 0 and fps < low_fps_threshold and quality_tier > QualityTier.LOW:
		_set_quality_tier(QualityTier.LOW, &"low_fps")
	elif fps >= auto_recover_fps_threshold and quality_tier == QualityTier.LOW:
		_set_quality_tier(QualityTier.MEDIUM, &"fps_recovered")


func _set_quality_tier(next_tier: int, reason: StringName) -> void:
	var clamped := clampi(next_tier, QualityTier.LOW, QualityTier.HIGH)
	if quality_tier == clamped and _last_quality_reason == reason:
		return
	quality_tier = clamped
	_last_quality_reason = reason
	quality_tier_changed.emit(quality_tier, reason)


func _sample_frame_spike(delta: float) -> void:
	if not monitor_frame_spikes:
		return
	var frame_ms := delta * 1000.0
	if frame_ms < maxf(spike_frame_ms_threshold, 1.0):
		return
	var sample: Dictionary = _make_spike_sample(frame_ms)
	_spike_log.append(sample)
	while _spike_log.size() > maxi(spike_log_capacity, 1):
		_spike_log.pop_front()
	performance_spike_recorded.emit(sample.duplicate(true))
	if auto_adjust_quality and auto_low_on_frame_spike and frame_ms >= severe_spike_frame_ms_threshold and _spike_cooldown_remaining <= 0.0:
		_set_quality_tier(QualityTier.LOW, &"frame_spike")
		_spike_cooldown_remaining = maxf(spike_reaction_cooldown, 0.1)


func _make_spike_sample(frame_ms: float) -> Dictionary:
	var scene: Node = get_tree().current_scene
	var wave: int = int(RunProgress.wave_index) if RunProgress != null else 0
	var scene_name: String = String(scene.name) if scene != null else ""
	return {
		"time": Time.get_ticks_msec() / 1000.0,
		"frame_ms": frame_ms,
		"fps": Engine.get_frames_per_second(),
		"quality": quality_tier,
		"reason": String(_last_quality_reason),
		"wave": wave,
		"scene": scene_name,
		"projectiles": _group_count(&"Projectiles"),
		"enemy_projectiles": _group_count(&"enemy_projectiles"),
		"enemies": _group_count(&"enemies"),
		"gravity_sources": _group_count(&"Objects_With_Gravity"),
		"vfx_bursts": _active_vfx_burst_count(scene),
	}


func _active_vfx_burst_count(scene: Node) -> int:
	if scene == null:
		return 0
	var vfx := scene.find_child("OrbitalVFXDirector", true, false)
	if vfx == null or not vfx.has_method("get_vfx_debug_state"):
		return 0
	var state_value: Variant = vfx.call("get_vfx_debug_state")
	if state_value is Dictionary:
		return int((state_value as Dictionary).get("active_bursts", 0))
	return 0


func _export_spikes_to_run_progress() -> void:
	if RunProgress == null or _spike_log.is_empty():
		return
	var exported: Array = []
	for sample: Dictionary in _spike_log:
		exported.append(sample.duplicate(true))
	RunProgress.arena_flags["performance_spikes"] = exported
	RunProgress.arena_flags["performance_quality_tier"] = quality_tier
	RunProgress.arena_flags["performance_quality_reason"] = String(_last_quality_reason)


func _set_if_present(target: Node, property_name: StringName, value: Variant) -> void:
	if target.get(property_name) == null:
		return
	target.set(property_name, value)


func _group_count(group_name: StringName) -> int:
	if RuntimeRegistry != null:
		return int(RuntimeRegistry.get_count(group_name))
	return get_tree().get_nodes_in_group(group_name).size()


func _fill_group(group_name: StringName, out_nodes: Array[Node2D], limit: int = -1) -> void:
	out_nodes.clear()
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_group(group_name, out_nodes, limit)
		return
	for value in get_tree().get_nodes_in_group(group_name):
		if limit >= 0 and out_nodes.size() >= limit:
			return
		var node := value as Node2D
		if node != null and is_instance_valid(node) and not node.is_queued_for_deletion():
			out_nodes.append(node)


func _is_network_active() -> bool:
	return NetworkSession != null and NetworkSession.has_method("is_network_active") and bool(NetworkSession.call("is_network_active"))


func get_budget_debug_state() -> Dictionary:
	return {
		"enabled": enabled,
		"quality": quality_tier,
		"quality_reason": String(_last_quality_reason),
		"fps": Engine.get_frames_per_second(),
		"projectile_pressure": _group_count(&"Projectiles") + _group_count(&"enemy_projectiles"),
		"enemy_pressure": _group_count(&"enemies"),
		"spikes": _spike_log.size(),
	}
