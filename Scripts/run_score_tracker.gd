extends Node
class_name RunScoreTracker

signal score_changed(score: int, snapshot: Dictionary)
signal challenge_code_changed(code: String)
signal physics_anomaly_achieved(type: String, kinetic_factor: float, score_value: int, snapshot: Dictionary)
signal run_chain_changed(chain_count: int, multiplier: float, timer: float, reason: StringName)

const GROUP_PLAYER: StringName = &"Player"
const GROUP_ENEMIES: StringName = &"enemies"
const GROUP_OBJECTS_WITH_GRAVITY: StringName = &"Objects_With_Gravity"
const ANOMALY_KINETIC_MULTIPLIER: String = "kinetic_multiplier"
const ANOMALY_VECTOR_SHEAR: String = "vector_shear"
const ANOMALY_EVENT_HORIZON_GRAZE: String = "event_horizon_graze"
const ANOMALY_EVENT_HORIZON_ESCAPE: String = "event_horizon_escape"
const ANOMALY_APEX_SLINGSHOT: String = "apex_slingshot"
const ANOMALY_PERFECT_SLINGSHOT: String = "perfect_slingshot"
const ANOMALY_VECTOR_CHAIN: String = "vector_chain"
const ANOMALY_SURFACE_SKIM: String = "surface_skim"
const ANOMALY_WEAPON_KILL: String = "weapon_kill"
const KINETIC_PAYLOAD_SPEED: StringName = &"speed"
const KINETIC_PAYLOAD_DESTRUCTION_SPEED: StringName = &"destruction_speed"
const SHEAR_PAYLOAD_IMPULSE: StringName = &"impulse"
const SHEAR_PAYLOAD_TIME: StringName = &"time"
const GRAZE_RADIUS_PROPERTIES: Array[StringName] = [&"radius", &"body_radius", &"base_radius", &"endpoint_radius", &"consume_radius"]

@export var mode_id: StringName = &"standard"
@export var enabled: bool = true
@export var wave_clear_score: int = 800
@export var boss_defeat_score: int = 5000
@export var secret_boss_score: int = 9000
@export var perfect_slingshot_score: int = 320
@export var apex_slingshot_score: int = 700
@export var event_horizon_escape_score: int = 1400
@export var rare_event_score: int = 1200
@export var coop_combo_score: int = 1800

@export var kinetic_multiplier_base_score: int = 90
@export var kinetic_multiplier_speed_floor: float = 650.0
@export var kinetic_multiplier_reference_speed: float = 1800.0
@export var kinetic_multiplier_exponent: float = 1.55
@export var kinetic_multiplier_score_cap: int = 2400
@export var vector_shear_score: int = 850
@export var vector_shear_min_intensity: float = 0.72
@export var vector_shear_impulse_floor: float = 1200.0
@export var vector_shear_cooldown: float = 0.35
@export var vector_shear_opposition_dot: float = -0.62
@export var vector_shear_pair_window: float = 0.42
@export var vector_chain_milestone_score: int = 360
@export var vector_chain_milestone_interval: int = 3
@export var horizon_graze_score: int = 650
@export var horizon_graze_velocity_floor: float = 90.0
@export var horizon_graze_distance: float = 112.0
@export var horizon_graze_max_effective_radius: float = 320.0
@export var surface_skim_score: int = 110
@export var surface_skim_min_quality: float = 0.62
@export var surface_skim_cooldown: float = 0.25
@export var weapon_kill_score: int = 140
@export var weapon_kill_chain_window: float = 2.5
@export var apex_tangential_reference_speed: float = 1850.0
@export var signal_reconnect_interval: float = 0.5

@export_group("Run Chain")
@export var run_chain_enabled: bool = true
@export var run_chain_window: float = 4.2
@export var run_chain_bonus_per_link: float = 0.08
@export var run_chain_multiplier_cap: float = 2.4
@export var run_chain_timer_bonus_per_link: float = 0.08
@export var run_chain_max_count: int = 99
@export var run_chain_energy_burst_per_link: float = 1.2
@export var run_chain_energy_burst_cap: float = 9.0
@export var run_chain_fire_spike_threshold: int = 3
@export var run_chain_fire_spike_duration: float = 1.4
@export_range(0.55, 1.0, 0.01) var run_chain_fire_interval_multiplier: float = 0.82

var score: int = 0
var waves_cleared: int = 0
var bosses_defeated: int = 0
var perfect_slingshots: int = 0
var apex_slingshots: int = 0
var event_horizon_escapes: int = 0
var event_horizon_grazes: int = 0
var rare_events: int = 0
var secret_bosses: int = 0
var coop_combos: int = 0
var kinetic_multipliers: int = 0
var vector_shears: int = 0
var vector_chains: int = 0
var surface_skims: int = 0
var weapon_kills: int = 0
var physics_anomaly_total: int = 0
var last_physics_anomaly: Dictionary = {}
var run_chain_count: int = 0
var best_run_chain: int = 0

var _last_challenge_code: String = ""
var _player: Node2D = null
var _momentum_component: Node = null
var _resonance_manager: Node = null
var _scar_manager: Node = null
var _event_horizon_active: bool = false
var _event_horizon_graze_awarded: bool = false
var _event_horizon_damage_taken: bool = false
var _event_horizon_start_health: float = 0.0
var _event_horizon_start_shield: float = 0.0
var _last_player_health: float = 0.0
var _last_player_shield: float = 0.0
var _last_vector_shear_time: float = -999.0
var _signal_reconnect_elapsed: float = 999.0
var _run_chain_timer: float = 0.0
var _run_chain_multiplier: float = 1.0
var _last_momentum_combo_awarded: int = 0
var _last_surface_skim_time: float = -999.0
var _pending_kinetic_kills: Dictionary = {}
var _last_body_shear_impulses: Dictionary = {}

func _ready() -> void:
	add_to_group("run_score_tracker")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	call_deferred("_bootstrap")
	_emit_score_changed()


func _process(delta: float) -> void:
	_update_run_chain(delta)
	_signal_reconnect_elapsed += delta
	if _signal_reconnect_elapsed < maxf(signal_reconnect_interval, 0.1):
		return
	_signal_reconnect_elapsed = 0.0
	_cache_player()
	_connect_player_signal()
	_connect_momentum_signal()
	_connect_player_damage_signals()
	_connect_node_signal(_find_scene_node(&"WaveDirector"), &"wave_cleared", Callable(self, "_on_wave_cleared"))
	_connect_node_signal(_find_scene_node(&"WaveDirector"), &"boss_defeated_anchor", Callable(self, "_on_boss_defeated"))
	_connect_node_signal(_find_scene_node(&"ArenaDestabilizationManager"), &"arena_hazard_spawned", Callable(self, "_on_arena_hazard_spawned"))
	_connect_node_signal(_resonance_singleton(), &"fracture_applied", Callable(self, "_on_resonance_fracture_applied"))
	_connect_node_signal(_scar_singleton(), &"gravity_scar_applied", Callable(self, "_on_gravity_scar_applied"))


func _bootstrap() -> void:
	_cache_player()
	_connect_node_signal(_find_scene_node(&"WaveDirector"), &"wave_cleared", Callable(self, "_on_wave_cleared"))
	_connect_node_signal(_find_scene_node(&"WaveDirector"), &"boss_defeated_anchor", Callable(self, "_on_boss_defeated"))
	_connect_node_signal(_find_scene_node(&"RunVariationDirector"), &"rare_event_started", Callable(self, "_on_rare_event_started"))
	_connect_node_signal(_find_scene_node(&"SecretBossDirector"), &"secret_boss_defeated", Callable(self, "_on_secret_boss_defeated"))
	_connect_node_signal(_find_scene_node(&"EventHorizonDirector"), &"event_horizon_started", Callable(self, "_on_event_horizon_started"))
	_connect_node_signal(_find_scene_node(&"EventHorizonDirector"), &"event_horizon_ended", Callable(self, "_on_event_horizon_ended"))
	_connect_node_signal(_find_scene_node(&"EventHorizonDirector"), &"horizon_escape_scored", Callable(self, "_on_horizon_escape_scored"))
	_connect_node_signal(_find_scene_node(&"ArenaDestabilizationManager"), &"arena_hazard_spawned", Callable(self, "_on_arena_hazard_spawned"))
	_connect_node_signal(_find_scene_node(&"CoopComboDirector"), &"coop_combo_triggered", Callable(self, "_on_coop_combo_triggered"))
	_connect_node_signal(_resonance_singleton(), &"fracture_applied", Callable(self, "_on_resonance_fracture_applied"))
	_connect_node_signal(_scar_singleton(), &"gravity_scar_applied", Callable(self, "_on_gravity_scar_applied"))
	_connect_player_signal()
	_connect_momentum_signal()
	_connect_player_damage_signals()


func reset_score() -> void:
	score = 0
	waves_cleared = 0
	bosses_defeated = 0
	perfect_slingshots = 0
	apex_slingshots = 0
	event_horizon_escapes = 0
	event_horizon_grazes = 0
	rare_events = 0
	secret_bosses = 0
	coop_combos = 0
	kinetic_multipliers = 0
	vector_shears = 0
	vector_chains = 0
	surface_skims = 0
	weapon_kills = 0
	physics_anomaly_total = 0
	last_physics_anomaly.clear()
	run_chain_count = 0
	best_run_chain = 0
	_run_chain_timer = 0.0
	_run_chain_multiplier = 1.0
	_last_momentum_combo_awarded = 0
	_last_surface_skim_time = -999.0
	_pending_kinetic_kills.clear()
	_last_challenge_code = ""
	_last_vector_shear_time = -999.0
	_event_horizon_active = false
	_event_horizon_graze_awarded = false
	_event_horizon_damage_taken = false
	_event_horizon_start_health = 0.0
	_event_horizon_start_shield = 0.0
	_last_player_health = _player_health_value()
	_last_player_shield = _player_shield_value()
	_last_body_shear_impulses.clear()
	_emit_score_changed()


func _connect_node_signal(source: Object, signal_name: StringName, callback: Callable) -> void:
	if source == null:
		return
	if not source.has_signal(signal_name):
		return
	if source.is_connected(signal_name, callback):
		return
	source.connect(signal_name, callback)


func _cache_player() -> void:
	if _player != null and is_instance_valid(_player):
		if _momentum_component == null or not is_instance_valid(_momentum_component):
			_momentum_component = _player.get_node_or_null("MomentumCombatComponent")
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var found: Node = tree.get_first_node_in_group(GROUP_PLAYER)
	if found == null or not is_instance_valid(found):
		return
	if not (found is Node2D):
		return
	_player = found as Node2D
	_momentum_component = _player.get_node_or_null("MomentumCombatComponent")
	_last_player_health = _player_health_value()
	_last_player_shield = _player_shield_value()


func _connect_player_signal() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var callback: Callable = Callable(self, "_on_slingshot_mastery_scored")
	if _player.has_signal(&"slingshot_mastery_scored") and not _player.is_connected(&"slingshot_mastery_scored", callback):
		_player.connect(&"slingshot_mastery_scored", callback)


func _connect_momentum_signal() -> void:
	if _momentum_component == null or not is_instance_valid(_momentum_component):
		return
	_connect_node_signal(_momentum_component, &"kinetic_impact_dealt", Callable(self, "_on_kinetic_impact_dealt"))
	_connect_node_signal(_momentum_component, &"near_miss_velocity_gained", Callable(self, "_on_near_miss_velocity_gained"))
	_connect_node_signal(_momentum_component, &"momentum_combo_changed", Callable(self, "_on_momentum_combo_changed"))


func _connect_player_damage_signals() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var health := _player.get_node_or_null("HealthComponent")
	_connect_node_signal(health, &"health_changed", Callable(self, "_on_player_health_changed"))
	var shield := _player.get_node_or_null("Shield")
	_connect_node_signal(shield, &"shield_hit", Callable(self, "_on_player_shield_hit"))
	_connect_node_signal(shield, &"shield_restored", Callable(self, "_on_player_shield_restored"))


func _find_scene_node(node_name: StringName) -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var root: Node = tree.current_scene
	if root == null:
		return null
	return root.find_child(String(node_name), true, false)


func _resonance_singleton() -> Node:
	if _resonance_manager != null and is_instance_valid(_resonance_manager):
		return _resonance_manager
	_resonance_manager = _find_scene_node(&"GravityResonanceManager")
	return _resonance_manager


func _scar_singleton() -> Node:
	if _scar_manager != null and is_instance_valid(_scar_manager):
		return _scar_manager
	_scar_manager = _find_scene_node(&"GravityScarManager")
	return _scar_manager


func _on_wave_cleared(wave_index: int) -> void:
	waves_cleared = maxi(waves_cleared, wave_index)
	_add_score(_score_with_run_chain(wave_clear_score + maxi(wave_index - 1, 0) * 90))


func _on_boss_defeated(_boss_scene_path: String) -> void:
	bosses_defeated += 1
	_add_score(_score_with_run_chain(boss_defeat_score + bosses_defeated * 450))


func _on_rare_event_started(_event_id: StringName, _wave: int) -> void:
	rare_events += 1
	_add_score(_score_with_run_chain(rare_event_score))


func _on_secret_boss_defeated(_secret_id: StringName) -> void:
	secret_bosses += 1
	_add_score(_score_with_run_chain(secret_boss_score))


func _on_coop_combo_triggered(_combo_id: StringName, _data: Dictionary) -> void:
	coop_combos += 1
	_add_score(_score_with_run_chain(coop_combo_score))


func _on_event_horizon_started(_data: Dictionary) -> void:
	_event_horizon_active = true
	_event_horizon_graze_awarded = false
	_event_horizon_damage_taken = false
	_event_horizon_start_health = _player_health_value()
	_event_horizon_start_shield = _player_shield_value()
	_last_player_health = _event_horizon_start_health
	_last_player_shield = _event_horizon_start_shield


func _on_event_horizon_ended(_data: Dictionary) -> void:
	_event_horizon_active = false
	_event_horizon_graze_awarded = false
	_event_horizon_damage_taken = false
	_event_horizon_start_health = 0.0
	_event_horizon_start_shield = 0.0


func _on_horizon_escape_scored(_data: Dictionary) -> void:
	event_horizon_escapes += 1
	_add_anomaly_score(ANOMALY_EVENT_HORIZON_ESCAPE, 1.0, event_horizon_escape_score, {
		"player_speed": _player_speed_snapshot()
	})


func _on_near_miss_velocity_gained(target: Node, amount: float) -> void:
	_score_surface_skim(target, amount)
	if not _event_horizon_active:
		return
	if _event_horizon_graze_awarded:
		return
	if amount < horizon_graze_velocity_floor:
		return
	if target == null or not is_instance_valid(target):
		return
	if not target.is_in_group(GROUP_OBJECTS_WITH_GRAVITY):
		return
	var target_2d := target as Node2D
	if target_2d == null or _player == null or not is_instance_valid(_player):
		return
	var graze_distance := _target_surface_distance(target_2d)
	if graze_distance > horizon_graze_distance:
		return
	if not _player_remained_undamaged_since_horizon_start():
		return
	_event_horizon_graze_awarded = true
	event_horizon_grazes += 1
	var factor: float = maxf(1.0, amount / horizon_graze_velocity_floor)
	var value: int = horizon_graze_score + int(round(amount * 0.35))
	_add_anomaly_score(ANOMALY_EVENT_HORIZON_GRAZE, factor, value, {
		"distance": _snap_float(graze_distance, 0.1),
		"player_speed": _player_speed_snapshot(),
		"source_key": String(target.name)
	})


func record_weapon_kill(enemy: Node) -> void:
	if not enabled:
		return
	if enemy == null or not is_instance_valid(enemy):
		return
	var now := _now_seconds()
	var hit_time := float(enemy.get_meta(&"last_player_weapon_hit_time", -999.0))
	if now - hit_time > weapon_kill_chain_window:
		return
	var weapon_id := String(enemy.get_meta(&"last_player_weapon_id", "weapon"))
	var hit_damage := float(enemy.get_meta(&"last_player_weapon_hit_damage", 0.0))
	weapon_kills += 1
	var factor := 1.0 + minf(float(run_chain_count) * 0.05, 0.65)
	var value := weapon_kill_score + int(round(minf(hit_damage, 500.0) * 0.2 + float(run_chain_count) * 12.0))
	_add_anomaly_score(ANOMALY_WEAPON_KILL, factor, value, {
		"weapon_id": weapon_id,
		"target_key": String(enemy.name),
		"hit_damage": _snap_float(hit_damage, 0.1)
	})


func _on_momentum_combo_changed(combo: int, tier: StringName, timer: float) -> void:
	if combo <= 0:
		_last_momentum_combo_awarded = 0
		return
	var interval := maxi(vector_chain_milestone_interval, 1)
	var award_combo := int(float(combo) / float(interval)) * interval
	if award_combo < interval or award_combo <= _last_momentum_combo_awarded:
		return
	_last_momentum_combo_awarded = award_combo
	vector_chains += 1
	var factor := 1.0 + float(award_combo) * 0.12
	var value := vector_chain_milestone_score + int(round(float(award_combo) * 42.0 + timer * 28.0))
	_add_anomaly_score(ANOMALY_VECTOR_CHAIN, factor, value, {
		"combo": award_combo,
		"tier": String(tier),
		"timer": _snap_float(timer, 0.1),
	})


func _on_player_health_changed(current_health: float, _max_health: float) -> void:
	if _event_horizon_active and current_health < _last_player_health - 0.001:
		_event_horizon_damage_taken = true
	_last_player_health = current_health


func _on_player_shield_hit(amount: float, current_energy: float, _max_capacity: float) -> void:
	if _event_horizon_active and amount > 0.0:
		_event_horizon_damage_taken = true
	_last_player_shield = current_energy


func _on_player_shield_restored(_amount: float, current_energy: float, _max_capacity: float) -> void:
	_last_player_shield = current_energy


func _on_slingshot_mastery_scored(mastery_data: Dictionary) -> void:
	var grade: String = String(mastery_data.get("grade", ""))
	var tangent: Vector2 = mastery_data.get("tangent", Vector2.RIGHT)
	if tangent.length_squared() <= 0.001:
		tangent = Vector2.RIGHT
	tangent = tangent.normalized()
	var player_velocity := _player_velocity_snapshot()
	var tangential_speed: float = maxf(player_velocity.dot(tangent), 0.0)
	if tangential_speed <= 0.0:
		tangential_speed = float(mastery_data.get("tangential_speed", mastery_data.get("speed_after", 0.0)))
	if grade == "apex":
		apex_slingshots += 1
		var apex_factor: float = _safe_ratio(tangential_speed, apex_tangential_reference_speed)
		var apex_value: int = apex_slingshot_score + int(round(apex_slingshot_score * apex_factor))
		var source_value: Variant = mastery_data.get("source")
		var source_key := ""
		if source_value is Node:
			source_key = String(source_value.name)
		_add_anomaly_score(ANOMALY_APEX_SLINGSHOT, maxf(1.0, apex_factor), apex_value, {
			"tangential_exit_speed": _snap_float(tangential_speed, 0.1),
			"exit_velocity": _snap_vector(player_velocity, 0.1),
			"source_key": source_key
		})
		return
	if grade == "perfect":
		perfect_slingshots += 1
		_add_anomaly_score(ANOMALY_PERFECT_SLINGSHOT, 1.0, perfect_slingshot_score, {
			"tangential_exit_speed": _snap_float(tangential_speed, 0.1)
		})


func _on_kinetic_impact_dealt(target: Node, _damage: float, speed: float) -> void:
	if speed < kinetic_multiplier_speed_floor:
		return
	if target == null or not is_instance_valid(target):
		return
	if not _is_hostile_node(target):
		return
	var target_id: int = target.get_instance_id()
	_pending_kinetic_kills[target_id] = {
		KINETIC_PAYLOAD_SPEED: speed,
		"target_key": String(target.name)
	}
	var health: Node = target.get_node_or_null("HealthComponent")
	if health == null or not is_instance_valid(health):
		return
	if not health.has_signal(&"died"):
		return
	var callback: Callable = Callable(self, "_on_kinetic_target_died").bind(target_id)
	if health.is_connected(&"died", callback):
		return
	health.connect(&"died", callback, CONNECT_ONE_SHOT)


func _on_kinetic_target_died(target_id: int) -> void:
	if not _pending_kinetic_kills.has(target_id):
		return
	var payload: Dictionary = _pending_kinetic_kills[target_id]
	_pending_kinetic_kills.erase(target_id)
	var destruction_snapshot := _capture_player_velocity_snapshot()
	var speed: float = float(destruction_snapshot.get(KINETIC_PAYLOAD_DESTRUCTION_SPEED, 0.0))
	if speed < kinetic_multiplier_speed_floor:
		return
	var kinetic_factor: float = maxf(1.0, speed / kinetic_multiplier_speed_floor)
	var scaled_score: float = float(kinetic_multiplier_base_score) * pow(kinetic_factor, kinetic_multiplier_exponent)
	var value: int = mini(kinetic_multiplier_score_cap, int(round(scaled_score)))
	kinetic_multipliers += 1
	_add_anomaly_score(ANOMALY_KINETIC_MULTIPLIER, kinetic_factor, value, {
		"destruction_velocity_snapshot": destruction_snapshot,
		"impact_speed": _snap_float(float(payload.get(KINETIC_PAYLOAD_SPEED, 0.0)), 0.1),
		"target_key": String(payload.get("target_key", "hostile"))
	})


func _on_resonance_fracture_applied(_position: Vector2, intensity: float) -> void:
	if intensity < vector_shear_min_intensity:
		return
	_score_vector_shear(maxf(1.0, intensity / vector_shear_min_intensity))


func _on_gravity_scar_applied(body: Node, impulse: Vector2, _scar_data: Dictionary) -> void:
	if body == null or not is_instance_valid(body):
		return
	if not _is_hostile_node(body):
		return
	var impulse_strength: float = impulse.length()
	if impulse_strength < vector_shear_impulse_floor:
		return
	_score_vector_shear(maxf(1.0, impulse_strength / vector_shear_impulse_floor), {
		"source": "gravity_scar",
		"body_key": String(body.name),
		"impulse": _snap_vector(impulse, 0.1)
	})


func _on_arena_hazard_spawned(hazard: Node, _event_id: StringName) -> void:
	if hazard == null or not is_instance_valid(hazard):
		return
	_connect_node_signal(hazard, &"body_affected", Callable(self, "_on_tide_body_affected"))


func _on_tide_body_affected(body: Node, impulse: Vector2, mode: int) -> void:
	if body == null or not is_instance_valid(body):
		return
	if not _is_hostile_node(body):
		return
	if impulse.length() < vector_shear_impulse_floor * 0.18:
		return
	var body_id := body.get_instance_id()
	var now := _now_seconds()
	var previous: Dictionary = _last_body_shear_impulses.get(body_id, {})
	_last_body_shear_impulses[body_id] = {
		SHEAR_PAYLOAD_IMPULSE: impulse,
		SHEAR_PAYLOAD_TIME: now,
		"mode": mode
	}
	if previous.is_empty():
		return
	var previous_impulse: Vector2 = previous.get(SHEAR_PAYLOAD_IMPULSE, Vector2.ZERO)
	if previous_impulse.length_squared() <= 0.001:
		return
	if now - float(previous.get(SHEAR_PAYLOAD_TIME, -999.0)) > vector_shear_pair_window:
		return
	var opposition := previous_impulse.normalized().dot(impulse.normalized())
	if opposition > vector_shear_opposition_dot:
		return
	var combined := previous_impulse.length() + impulse.length()
	var factor := maxf(1.0, combined / vector_shear_impulse_floor)
	_score_vector_shear(factor, {
		"source": "counter_opposing_gravity_zones",
		"body_key": String(body.name),
		"opposition": _snap_float(opposition, 0.001),
		"mode": mode,
		"combined_impulse": _snap_float(combined, 0.1)
	})


func _score_vector_shear(factor: float, details: Dictionary = {}) -> void:
	var now: float = _now_seconds()
	if now - _last_vector_shear_time < vector_shear_cooldown:
		return
	_last_vector_shear_time = now
	vector_shears += 1
	var value: int = vector_shear_score + int(round(vector_shear_score * minf(factor - 1.0, 2.0) * 0.5))
	_add_anomaly_score(ANOMALY_VECTOR_SHEAR, factor, value, details)


func _score_surface_skim(target: Node, amount: float) -> void:
	if not enabled or _player == null or not is_instance_valid(_player):
		return
	var now := _now_seconds()
	if now - _last_surface_skim_time < surface_skim_cooldown:
		return
	var quality := float(_player.get_meta(&"last_near_miss_quality", 0.0))
	if quality < surface_skim_min_quality:
		return
	_last_surface_skim_time = now
	surface_skims += 1
	var surface_distance := float(_player.get_meta(&"last_near_miss_surface_distance", 0.0))
	var value := surface_skim_score + int(round(float(surface_skim_score) * quality + minf(amount * 0.32, 260.0)))
	_add_anomaly_score(ANOMALY_SURFACE_SKIM, 1.0 + quality, value, {
		"quality": _snap_float(quality, 0.01),
		"surface_distance": _snap_float(surface_distance, 0.1),
		"velocity_gain": _snap_float(amount, 0.1),
		"source_key": String(target.name) if target != null else ""
	})


func _is_hostile_node(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if node.is_in_group(GROUP_ENEMIES):
		return true
	if node.has_method("take_damage") and node.has_method("get_gravity_pull"):
		return true
	return false


func _add_anomaly_score(type: String, kinetic_factor: float, value: int, details: Dictionary = {}) -> void:
	if not enabled:
		return
	if value <= 0:
		return
	_extend_run_chain(StringName(type))
	var scored_value := _score_with_run_chain(value)
	var event_details := details.duplicate(true)
	event_details["run_chain_count"] = run_chain_count
	event_details["run_chain_multiplier"] = _snap_float(_run_chain_multiplier, 0.001)
	physics_anomaly_total += 1
	last_physics_anomaly = {
		"type": type,
		"factor": _snap_float(kinetic_factor, 0.001),
		"score": scored_value,
		"base_score": value,
		"sequence": physics_anomaly_total,
		"details": event_details
	}
	_add_score(scored_value)
	physics_anomaly_achieved.emit(type, kinetic_factor, scored_value, get_score_snapshot())


func _add_score(amount: int) -> void:
	if not enabled:
		return
	if amount <= 0:
		return
	score += amount
	_emit_score_changed()


func _emit_score_changed() -> void:
	var snapshot: Dictionary = get_score_snapshot()
	score_changed.emit(score, snapshot)
	var next_code: String = get_challenge_code()
	if RunProgress != null:
		RunProgress.arena_flags["score_snapshot"] = snapshot.duplicate(true)
		RunProgress.arena_flags["challenge_code"] = next_code
	if next_code == _last_challenge_code:
		return
	_last_challenge_code = next_code
	challenge_code_changed.emit(next_code)


func get_score_snapshot() -> Dictionary:
	return {
		"mode": _run_mode_id(),
		"seed": _run_seed_code(),
		"seed_code": _run_seed_code(),
		"wave": _run_wave_index(),
		"score": score,
		"waves_cleared": waves_cleared,
		"bosses_defeated": bosses_defeated,
		"secret_bosses_defeated": secret_bosses,
		"perfect_slingshots": perfect_slingshots,
		"apex_slingshots": apex_slingshots,
		"event_horizon_escapes": event_horizon_escapes,
		"event_horizon_grazes": event_horizon_grazes,
		"rare_events": rare_events,
		"secret_bosses": secret_bosses,
		"coop_combos": coop_combos,
		"kinetic_multipliers": kinetic_multipliers,
		"vector_shears": vector_shears,
		"vector_chains": vector_chains,
		"surface_skims": surface_skims,
		"weapon_kills": weapon_kills,
		"physics_anomaly_total": physics_anomaly_total,
		"last_physics_anomaly": last_physics_anomaly,
		"run_chain_count": run_chain_count,
		"best_run_chain": best_run_chain,
		"run_chain_timer": _snap_float(_run_chain_timer, 0.1),
		"run_chain_multiplier": _snap_float(_run_chain_multiplier, 0.001)
	}


func get_challenge_code() -> String:
	var snapshot: Dictionary = get_score_snapshot()
	var code_snapshot := _challenge_code_snapshot(snapshot)
	var checksum: String = _score_checksum(code_snapshot)
	return "%s:%s:%d:%d_%s" % [
		String(snapshot["mode"]),
		String(snapshot["seed_code"]),
		int(snapshot["wave"]),
		score,
		checksum
	]


func _update_run_chain(delta: float) -> void:
	if _run_chain_timer <= 0.0:
		return
	_run_chain_timer = maxf(_run_chain_timer - delta, 0.0)
	if _run_chain_timer > 0.0:
		return
	run_chain_count = 0
	_run_chain_multiplier = 1.0
	run_chain_changed.emit(run_chain_count, _run_chain_multiplier, _run_chain_timer, &"expired")


func _extend_run_chain(reason: StringName) -> void:
	if not run_chain_enabled:
		return
	if _run_chain_timer <= 0.0:
		run_chain_count = 0
	run_chain_count = mini(run_chain_count + 1, maxi(run_chain_max_count, 1))
	best_run_chain = maxi(best_run_chain, run_chain_count)
	_run_chain_timer = run_chain_window + minf(float(run_chain_count) * run_chain_timer_bonus_per_link, 1.6)
	_run_chain_multiplier = _current_run_chain_multiplier()
	if RunProgress != null:
		RunProgress.arena_flags["last_run_chain"] = {
			"count": run_chain_count,
			"best": best_run_chain,
			"multiplier": _snap_float(_run_chain_multiplier, 0.001),
			"reason": String(reason),
		}
	_apply_run_chain_rewards()
	run_chain_changed.emit(run_chain_count, _run_chain_multiplier, _run_chain_timer, reason)


func _apply_run_chain_rewards() -> void:
	_cache_player()
	if _player == null or not is_instance_valid(_player):
		return
	var energy_component := _player.get_node_or_null("EnergyComponent")
	if energy_component != null and energy_component.has_method("restore"):
		var burst := minf(float(run_chain_count) * run_chain_energy_burst_per_link, run_chain_energy_burst_cap)
		if burst > 0.0:
			energy_component.call("restore", burst)
	if run_chain_count < run_chain_fire_spike_threshold:
		return
	var now := _now_seconds()
	var chain_pressure := clampf(float(run_chain_count - run_chain_fire_spike_threshold + 1) / 6.0, 0.0, 1.0)
	var multiplier := lerpf(0.94, run_chain_fire_interval_multiplier, chain_pressure)
	_player.set_meta(&"run_chain_fire_interval_multiplier", multiplier)
	_player.set_meta(&"run_chain_fire_interval_until", now + run_chain_fire_spike_duration)


func _current_run_chain_multiplier() -> float:
	if not run_chain_enabled or run_chain_count <= 0 or _run_chain_timer <= 0.0:
		return 1.0
	return minf(1.0 + float(run_chain_count) * run_chain_bonus_per_link, maxf(run_chain_multiplier_cap, 1.0))


func _score_with_run_chain(amount: int) -> int:
	if amount <= 0:
		return amount
	if not run_chain_enabled or run_chain_count <= 0 or _run_chain_timer <= 0.0:
		return amount
	return int(round(float(amount) * _current_run_chain_multiplier()))


func _challenge_code_snapshot(snapshot: Dictionary) -> Dictionary:
	var stable := snapshot.duplicate(true)
	stable.erase("run_chain_timer")
	return stable


func _run_seed_code() -> String:
	if RunProgress == null:
		return "NO-SEED"
	var seed_value: Variant = RunProgress.get("run_seed")
	if seed_value == null:
		return "NO-SEED"
	return str(int(seed_value))


func _run_mode_id() -> String:
	if RunProgress == null:
		return String(mode_id)
	if bool(RunProgress.get("boss_rush_mode")):
		return "boss_rush"
	if bool(RunProgress.get("challenge_mode")):
		return "challenge"
	return String(mode_id)


func _run_wave_index() -> int:
	if RunProgress == null:
		return waves_cleared
	var wave_value: Variant = RunProgress.get("wave_index")
	if wave_value == null:
		return waves_cleared
	return int(wave_value)


func _score_checksum(snapshot: Dictionary) -> String:
	var payload: String = _stable_serialize(snapshot)
	var context := HashingContext.new()
	var err := context.start(HashingContext.HASH_SHA256)
	if err != OK:
		return "%05d" % (absi(hash(payload)) % 100000)
	context.update(payload.to_utf8_buffer())
	return context.finish().hex_encode().substr(0, 10).to_upper()


func _stable_serialize(value: Variant) -> String:
	match typeof(value):
		TYPE_DICTIONARY:
			var dict: Dictionary = value
			var keys := dict.keys()
			keys.sort_custom(func(a: Variant, b: Variant) -> bool:
				return str(a) < str(b)
			)
			var parts: Array[String] = []
			for key in keys:
				parts.append("%s:%s" % [str(key), _stable_serialize(dict[key])])
			return "{%s}" % ",".join(parts)
		TYPE_ARRAY:
			var array_value: Array = value
			var array_parts: Array[String] = []
			for entry in array_value:
				array_parts.append(_stable_serialize(entry))
			return "[%s]" % ",".join(array_parts)
		TYPE_VECTOR2:
			var vector_value: Vector2 = value
			return "v2(%.3f,%.3f)" % [vector_value.x, vector_value.y]
		TYPE_FLOAT:
			return "%.6f" % float(value)
		TYPE_STRING:
			return JSON.stringify(str(value))
		TYPE_STRING_NAME:
			return JSON.stringify(str(value))
		_:
			return JSON.stringify(value)


func _safe_ratio(value: float, reference: float) -> float:
	if reference <= 0.0:
		return 0.0
	return value / reference


func _snap_float(value: float, step: float) -> float:
	if step <= 0.0:
		return value
	return round(value / step) * step


func _snap_vector(value: Vector2, step: float) -> Vector2:
	return Vector2(_snap_float(value.x, step), _snap_float(value.y, step))


func _target_surface_distance(target: Node2D) -> float:
	if target == null or _player == null or not is_instance_valid(_player):
		return INF
	var center_distance := _player.global_position.distance_to(target.global_position)
	return maxf(center_distance - _target_effective_radius(target), 0.0)


func _target_effective_radius(target: Node2D) -> float:
	if target == null:
		return 0.0
	var radius := 0.0
	for property_name in GRAZE_RADIUS_PROPERTIES:
		var value: Variant = target.get(String(property_name))
		if value is float or value is int:
			radius = maxf(radius, float(value))
	var collision := target.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		collision = target.find_child("CollisionShape2D", true, false) as CollisionShape2D
	if collision != null and collision.shape is CircleShape2D:
		radius = maxf(radius, (collision.shape as CircleShape2D).radius)
	return clampf(radius * maxf(absf(target.scale.x), absf(target.scale.y)), 0.0, maxf(horizon_graze_max_effective_radius, 0.0))


func _capture_player_velocity_snapshot() -> Dictionary:
	var velocity_value := _player_velocity_snapshot()
	return {
		KINETIC_PAYLOAD_DESTRUCTION_SPEED: _snap_float(velocity_value.length(), 0.1),
		"velocity": _snap_vector(velocity_value, 0.1)
	}


func _player_velocity_snapshot() -> Vector2:
	_cache_player()
	if _player == null or not is_instance_valid(_player):
		return Vector2.ZERO
	var linear_velocity_value: Variant = _player.get("linear_velocity")
	if linear_velocity_value is Vector2:
		return linear_velocity_value
	var velocity_value: Variant = _player.get("velocity")
	if velocity_value is Vector2:
		return velocity_value
	return Vector2.ZERO


func _player_speed_snapshot() -> float:
	return _snap_float(_player_velocity_snapshot().length(), 0.1)


func _player_health_value() -> float:
	_cache_player()
	if _player == null or not is_instance_valid(_player):
		return 0.0
	var health := _player.get_node_or_null("HealthComponent")
	if health == null:
		return 0.0
	var value: Variant = health.get("current_health")
	if value is float or value is int:
		return float(value)
	return 0.0


func _player_shield_value() -> float:
	_cache_player()
	if _player == null or not is_instance_valid(_player):
		return 0.0
	var shield := _player.get_node_or_null("Shield")
	if shield == null:
		return 0.0
	var value: Variant = shield.get("current_energy")
	if value is float or value is int:
		return float(value)
	return 0.0


func _player_remained_undamaged_since_horizon_start() -> bool:
	return (
		not _event_horizon_damage_taken
		and _player_health_value() >= _event_horizon_start_health
		and _player_shield_value() >= _event_horizon_start_shield
	)


func _now_seconds() -> float:
	return Time.get_ticks_msec() * 0.001
