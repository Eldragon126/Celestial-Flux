extends Node
class_name MechanicAudioDirector

## Lightweight, signal-driven audio signatures for major mechanics.
## This is intentionally not a full audio manager; it only binds readable cues.

const PLAYER_SHOOT_STREAM := preload("res://Assets/Sound Effects/PlayerShoot.wav")
const IMPACT_STREAM := preload("res://Assets/Sound Effects/explosion.wav")
const SLINGSHOT_APEX_STREAM := preload("res://Assets/Sound Effects/sfx_slingshot_apex.mp3")
const SLINGSHOT_GREAT_STREAM := preload("res://Assets/Sound Effects/sfx_slingshot_great.mp3")
const KINETIC_IMPACT_STREAM := preload("res://Assets/Sound Effects/sfx_kinetic_impact_heavy.mp3")
const TIME_DILATION_START_STREAM := preload("res://Assets/Sound Effects/sfx_time_dilation_start.mp3")
const TIME_DILATION_END_STREAM := preload("res://Assets/Sound Effects/sfx_time_dilation_end.mp3")
const TIME_POCKET_ENTER_STREAM := preload("res://Assets/Sound Effects/sfx_time_pocket_enter.mp3")
const TIME_POCKET_EXIT_STREAM := preload("res://Assets/Sound Effects/sfx_time_pocket_exit.mp3")
const RESONANCE_CREATED_STREAM := preload("res://Assets/Sound Effects/sfx_resonance_created.mp3")
const RESONANCE_INTENSIFY_STREAM := preload("res://Assets/Sound Effects/sfx_resonance_intensify.mp3")
const RESONANCE_DECAY_STREAM := preload("res://Assets/Sound Effects/sfx_resonance_decay.mp3")
const RESONANCE_SLIPSTREAM_STREAM := preload("res://Assets/Sound Effects/sfx_resonance_slipstream.mp3")
const RESONANCE_HARMONIC_STREAM := preload("res://Assets/Sound Effects/sfx_resonance_harmonic_orbit.mp3")
const INSTABILITY_CHANGED_STREAM := preload("res://Assets/Sound Effects/sfx_instability_changed.mp3")
const GRAVITY_SCAR_CREATED_STREAM := preload("res://Assets/Sound Effects/sfx_gravity_scar_created.mp3")
const GRAVITY_SCAR_INTENSIFY_STREAM := preload("res://Assets/Sound Effects/sfx_gravity_scar_intensify.mp3")
const GRAVITY_SCAR_APPLIED_STREAM := preload("res://Assets/Sound Effects/sfx_gravity_scar_applied.mp3")
const GRAVITY_SCAR_DECAY_STREAM := preload("res://Assets/Sound Effects/sfx_gravity_scar_decay.mp3")
const WORMHOLE_SWIRL_STREAM := preload("res://Assets/Sound Effects/sfx_wormhole_swirl.mp3")
const WORMHOLE_PULSE_STREAM := preload("res://Assets/Sound Effects/sfx_wormhole_loop_pulse.mp3")
const BOSS_TELEGRAPH_STREAM := preload("res://Assets/Sound Effects/sfx_boss_telegraph_high.mp3")
const BOSS_ATTACK_STREAM := preload("res://Assets/Sound Effects/sfx_boss_attack_release.mp3")
const TIDE_POCKET_STREAM := preload("res://Assets/Sound Effects/sfx_tide_pocket_large.mp3")
const VOLATILE_MOON_STREAM := preload("res://Assets/Sound Effects/sfx_volatile_moon_unstable.mp3")
const NEBULA_SHEAR_STREAM := preload("res://Assets/Sound Effects/sfx_nebula_shear_harsh.mp3")
const RARE_EVENT_STREAM := preload("res://Assets/Sound Effects/sfx_rare_event_distinct.mp3")
const LATE_GAME_OVERFOLD_STREAM := preload("res://Assets/Sound Effects/sfx_late_game_overfold.mp3")
const COLLAPSE_LANE_STREAM := preload("res://Assets/Sound Effects/sfx_collapse_lane_intense.mp3")
const SPACETIME_SWIM_STREAM := preload("res://Assets/Sound Effects/sfx_spacetime_swim_phase.mp3")
const TIME_DILATION_BREAK_STREAM := preload("res://Assets/Sound Effects/sfx_time_dilation_break.mp3")
const FRACTURE_BOSS_TELEGRAPH_STREAM := preload("res://Assets/Sound Effects/sfx_fracture_boss_telegraph.mp3")
const ORBIT_BOSS_TELEGRAPH_STREAM := preload("res://Assets/Sound Effects/sfx_orbit_boss_telegraph.mp3")
const OVERFOLD_BOSS_TELEGRAPH_STREAM := preload("res://Assets/Sound Effects/sfx_overfold_boss_telegraph.mp3")
const SINGULARITY_BOSS_TELEGRAPH_STREAM := preload("res://Assets/Sound Effects/sfx_singularity_boss_telegraph.mp3")
const MOMENTUM_SURGE_STREAM := preload("res://Assets/Sound Effects/sfx_momentum_surge.mp3")
const METALLIC_DECAY_STREAM := preload("res://Assets/Sound Effects/sfx_metallic_decay.mp3")
const THRUST_VECTOR_SURGE_STREAM := preload("res://Assets/Sound Effects/sfx_thrust_vector_surge.mp3")
const ENERGY_EXHAUSTED_STREAM := preload("res://Assets/Sound Effects/sfx_energy_exhausted_low.mp3")

@export var enabled: bool = true
@export var max_simultaneous_cues: int = 6
@export var minimum_cue_gap: float = 0.09
@export var source_refresh_interval: float = 1.0
@export var bus_name: StringName = &"Player Sound Effects"
@export_file("*.json") var audio_manifest_path: String = "res://Assets/Audio/vector_anomaly_audio_manifest.json"

@export_group("Volumes")
@export var time_cue_volume_db: float = -13.0
@export var resonance_cue_volume_db: float = -17.0
@export var momentum_cue_volume_db: float = -11.0
@export var powerup_cue_volume_db: float = -10.0
@export var shield_cue_volume_db: float = -14.0

var _player: Node2D = null
var _time_manager: Node = null
var _resonance_manager: Node = null
var _momentum: Node = null
var _inventory: Node = null
var _shield: Node = null
var _energy_component: Node = null
var _gravity_scar_manager: Node = null
var _wave_director: Node = null
var _arena_instability: Node = null
var _arena_destabilization: Node = null
var _tear_director: Node = null
var _physics_drop_system: Node = null
var _late_game_instability: Node = null
var _recovery_director: Node = null
var _reality_collapse: Node = null
var _celestial_director: Node = null
var _swim_director: Node = null
var _weapon_system: Node = null
var _active_players: Array[AudioStreamPlayer2D] = []
var _last_cue_time := -999.0
var _next_gravity_scar_apply_cue := 0.0
var _next_weapon_cue_time := 0.0
var _next_drop_collect_cue := 0.0
var _next_thrust_cue := 0.0
var _next_resource_warning_cue := 0.0
var _source_refresh_elapsed := 999.0
var _sfx_overrides: Dictionary = {}


func _ready() -> void:
	add_to_group("mechanic_audio_director")
	_load_audio_manifest_overrides()
	call_deferred("_connect_sources")


func _process(delta: float) -> void:
	_prune_players()
	_update_movement_audio()
	_source_refresh_elapsed += delta
	if _source_refresh_elapsed >= maxf(source_refresh_interval, 0.2):
		_source_refresh_elapsed = 0.0
		_connect_sources()


func _connect_sources() -> void:
	var scene := get_tree().current_scene
	_resolve_sources()
	_connect_signal(_time_manager, &"dilation_started", Callable(self, "_on_dilation_started"))
	_connect_signal(_time_manager, &"dilation_ended", Callable(self, "_on_dilation_ended"))
	_connect_signal(_time_manager, &"local_time_pocket_entered", Callable(self, "_on_local_time_pocket_entered"))
	_connect_signal(_resonance_manager, &"resonance_zone_created", Callable(self, "_on_resonance_zone_created"))
	_connect_signal(_resonance_manager, &"resonance_zone_intensified", Callable(self, "_on_resonance_zone_intensified"))
	_connect_signal(_momentum, &"kinetic_overload_started", Callable(self, "_on_kinetic_overload_started"))
	_connect_signal(_momentum, &"kinetic_shockwave_created", Callable(self, "_on_kinetic_shockwave_created"))
	_connect_signal(_momentum, &"slingshot_mastery_triggered", Callable(self, "_on_slingshot_mastery_triggered"))
	_connect_signal(_inventory, &"powerup_applied", Callable(self, "_on_powerup_applied"))
	_connect_signal(_inventory, &"law_fusion_triggered", Callable(self, "_on_law_fusion_triggered"))
	_connect_signal(_shield, &"shield_broken", Callable(self, "_on_shield_broken"))
	_connect_signal(_shield, &"shield_hit", Callable(self, "_on_shield_hit"))
	_connect_signal(_shield, &"shield_restored", Callable(self, "_on_shield_restored"))
	_connect_signal(_energy_component, &"energy_depleted", Callable(self, "_on_energy_depleted"))
	_connect_signal(_resonance_manager, &"resonance_zone_decayed_detailed", Callable(self, "_on_resonance_zone_decayed"))
	_connect_signal(_momentum, &"kinetic_overload_ended", Callable(self, "_on_kinetic_overload_ended"))
	_connect_signal(_time_manager, &"time_tear_intensity_changed", Callable(self, "_on_time_tear_intensity_changed"))
	_connect_signal(_time_manager, &"local_time_pocket_expired", Callable(self, "_on_local_time_pocket_expired"))
	_connect_signal(_gravity_scar_manager, &"gravity_scar_created", Callable(self, "_on_gravity_scar_created"))
	_connect_signal(_gravity_scar_manager, &"gravity_scar_intensified", Callable(self, "_on_gravity_scar_intensified"))
	_connect_signal(_gravity_scar_manager, &"gravity_scar_applied", Callable(self, "_on_gravity_scar_applied"))
	_connect_signal(_gravity_scar_manager, &"gravity_scar_decayed", Callable(self, "_on_gravity_scar_decayed"))
	_connect_signal(_wave_director, &"boss_wave", Callable(self, "_on_boss_wave"))
	_connect_signal(_arena_instability, &"arena_instability_event_telegraphed", Callable(self, "_on_arena_instability_event_telegraphed"))
	_connect_signal(_arena_instability, &"arena_instability_event_started", Callable(self, "_on_arena_instability_event_started"))
	_connect_signal(_tear_director, &"spacetime_tear_opened", Callable(self, "_on_spacetime_tear_opened"))
	_connect_signal(_tear_director, &"spacetime_tear_enemy_spawned", Callable(self, "_on_spacetime_tear_enemy_spawned"))
	_connect_signal(_player, &"player_hit_invulnerability_started", Callable(self, "_on_player_hit_invulnerability_started"))
	_connect_signal(_player, &"damage_ignored_during_invulnerability", Callable(self, "_on_damage_ignored_during_invulnerability"))
	_connect_signal(_physics_drop_system, &"drop_sequence_spawned", Callable(self, "_on_drop_sequence_spawned"))
	_connect_signal(_late_game_instability, &"impossible_event_started", Callable(self, "_on_impossible_event_started"))
	_connect_signal(_recovery_director, &"recovery_opportunity_started", Callable(self, "_on_recovery_opportunity_started"))
	_connect_signal(_recovery_director, &"recovery_opportunity_resolved", Callable(self, "_on_recovery_opportunity_resolved"))
	_connect_signal(_recovery_director, &"near_miss_recorded", Callable(self, "_on_near_miss_recorded"))
	_connect_signal(_reality_collapse, &"reality_breach_opened", Callable(self, "_on_reality_breach_opened"))
	_connect_signal(_reality_collapse, &"physics_constants_shifted", Callable(self, "_on_physics_constants_shifted"))
	_connect_signal(_celestial_director, &"celestial_event_started", Callable(self, "_on_celestial_event_started"))
	_connect_signal(_celestial_director, &"celestial_body_spawned", Callable(self, "_on_celestial_body_spawned"))
	_connect_signal(_swim_director, &"spacetime_swim_triggered", Callable(self, "_on_spacetime_swim_triggered"))
	_connect_signal(_swim_director, &"spacetime_glitch_triggered", Callable(self, "_on_spacetime_glitch_triggered"))
	_connect_signal(_weapon_system, &"weapon_fired", Callable(self, "_on_weapon_fired"))
	_connect_signal(_weapon_system, &"weapon_energy_failed", Callable(self, "_on_weapon_energy_failed"))
	_connect_ambient_audio_sources(scene)
	_connect_boss_audio_sources()


func _connect_ambient_audio_sources(scene: Node) -> void:
	if scene == null:
		return
	_connect_signal(_arena_destabilization, &"chaos_level_changed", Callable(self, "_on_chaos_level_changed"))
	_connect_signal(_arena_destabilization, &"arena_event_started", Callable(self, "_on_arena_event_started"))
	_connect_signal(_arena_destabilization, &"arena_hazard_spawned", Callable(self, "_on_arena_hazard_spawned"))
	for pocket in get_tree().get_nodes_in_group("gravity_tide_pocket"):
		_connect_signal(pocket, &"pocket_activated", Callable(self, "_on_tide_pocket_activated"))
		_connect_signal(pocket, &"pocket_expired", Callable(self, "_on_tide_pocket_expired"))
	for wormhole in get_tree().get_nodes_in_group("wormhole_pair"):
		_connect_signal(wormhole, &"wormhole_teleport", Callable(self, "_on_wormhole_teleport"))


func _resolve_sources() -> void:
	var scene := get_tree().current_scene
	_player = get_tree().get_first_node_in_group("Player") as Node2D
	if scene != null:
		_time_manager = scene.find_child("TimeDilationManager", true, false)
		_resonance_manager = scene.find_child("GravityResonanceManager", true, false)
		_gravity_scar_manager = scene.find_child("GravityScarManager", true, false)
		_wave_director = scene.find_child("WaveDirector", true, false)
		_arena_destabilization = scene.find_child("ArenaDestabilizationManager", true, false)
		_arena_instability = scene.find_child("ArenaInstabilityDirector", true, false)
		_tear_director = scene.find_child("SpacetimeTearDirector", true, false)
		_physics_drop_system = scene.find_child("PhysicsDropSystem", true, false)
		_late_game_instability = scene.find_child("LateGameInstabilityDirector", true, false)
		_recovery_director = scene.find_child("RecoveryOpportunityDirector", true, false)
		_reality_collapse = scene.find_child("RealityCollapseDirector", true, false)
		_celestial_director = scene.find_child("CelestialBodyDirector", true, false)
		_swim_director = scene.find_child("SpacetimeSwimDirector", true, false)
	if _player != null:
		_momentum = _player.get_node_or_null("MomentumCombatComponent")
		_inventory = _player.get_node_or_null("PowerupInventory")
		_shield = _player.get_node_or_null("Shield")
		_energy_component = _player.get_node_or_null("EnergyComponent")
		_weapon_system = _player.get_node_or_null("WeaponSystem")


func _connect_signal(source: Node, signal_name: StringName, callable: Callable) -> void:
	if source == null or not is_instance_valid(source) or not source.has_signal(signal_name):
		return
	if not source.is_connected(signal_name, callable):
		source.connect(signal_name, callable)


func _connect_boss_audio_sources() -> void:
	for boss in get_tree().get_nodes_in_group("bosses"):
		if boss == null or not is_instance_valid(boss) or boss.is_queued_for_deletion():
			continue
		var breach_callable := Callable(self, "_on_breacher_attack_started")
		if boss.has_signal("breach_attack_started") and not boss.is_connected("breach_attack_started", breach_callable):
			boss.connect("breach_attack_started", breach_callable)
		var phase_callable := Callable(self, "_on_boss_phase_entered").bind(boss)
		if boss.has_signal("phase_entered") and not boss.is_connected("phase_entered", phase_callable):
			boss.connect("phase_entered", phase_callable)


func _update_movement_audio() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var local_value: Variant = _player.get("network_is_local")
	var is_local := bool(local_value) if typeof(local_value) == TYPE_BOOL else true
	if not is_local:
		return
	if not InputMap.has_action("thrust") or not Input.is_action_just_pressed("thrust"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < _next_thrust_cue:
		return
	_next_thrust_cue = now + 0.28
	var velocity_value: Variant = _player.get("velocity")
	var speed = velocity_value.length() if velocity_value is Vector2 else 0.0
	_play_player_cue(THRUST_VECTOR_SURGE_STREAM, momentum_cue_volume_db - 6.0, lerpf(0.88, 1.18, clampf(speed / 1800.0, 0.0, 1.0)))


func _on_dilation_started() -> void:
	_play_player_cue(TIME_DILATION_START_STREAM, time_cue_volume_db, 0.82)


func _on_dilation_ended() -> void:
	_play_player_cue(TIME_DILATION_END_STREAM, time_cue_volume_db - 4.0, 0.95)


func _on_local_time_pocket_entered(target: Node, multiplier: float, _duration: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var target_2d := target as Node2D
	if target_2d == null:
		return
	_play_positional_cue(TIME_POCKET_ENTER_STREAM, target_2d.global_position, resonance_cue_volume_db - 3.0, lerpf(0.65, 0.42, 1.0 - multiplier))


func _on_local_time_pocket_expired(_target_id: int) -> void:
	_play_player_cue(TIME_POCKET_EXIT_STREAM, time_cue_volume_db - 6.0, 0.76)


func _on_resonance_zone_created(zone_data: Dictionary) -> void:
	_play_zone_cue(zone_data, -3.0, false)


func _on_resonance_zone_intensified(zone_data: Dictionary) -> void:
	_play_zone_cue(zone_data, 0.0, true)


func _on_kinetic_overload_started(speed: float) -> void:
	_play_player_cue(SLINGSHOT_GREAT_STREAM, momentum_cue_volume_db, lerpf(0.86, 1.26, clampf(speed / 2400.0, 0.0, 1.0)))


func _on_kinetic_shockwave_created(shockwave_data: Dictionary) -> void:
	var position: Vector2 = shockwave_data.get("position", _player.global_position if _player != null else Vector2.ZERO)
	var speed := float(shockwave_data.get("speed", 1200.0))
	_play_positional_cue(KINETIC_IMPACT_STREAM, position, momentum_cue_volume_db, lerpf(0.82, 1.18, clampf(speed / 2600.0, 0.0, 1.0)))


func _on_slingshot_mastery_triggered(data: Dictionary) -> void:
	var coordinator := JuiceCoordinator.find_coordinator(get_tree())
	if coordinator != null and not coordinator.should_play_slingshot_audio(data):
		return
	var score := clampf(float(data.get("score", 0.0)), 0.0, 1.0)
	var position: Vector2 = data.get("position", _player.global_position if _player != null else Vector2.ZERO)
	var stream := SLINGSHOT_APEX_STREAM if score >= 0.92 else SLINGSHOT_GREAT_STREAM
	_play_positional_cue(stream, position, momentum_cue_volume_db - 2.0, lerpf(0.95, 1.42, score))


func _on_powerup_applied(_definition: PowerupDefinition, stacks: int) -> void:
	_play_player_cue(RESONANCE_CREATED_STREAM, powerup_cue_volume_db, 1.0 + float(stacks) * 0.06)


func _on_law_fusion_triggered(fusion_id: StringName, fusion_data: Dictionary) -> void:
	var position: Vector2 = fusion_data.get("position", _player.global_position if _player != null else Vector2.ZERO)
	var stream := RESONANCE_INTENSIFY_STREAM
	var pitch := 1.18
	match fusion_id:
		&"momentum_singularity":
			stream = KINETIC_IMPACT_STREAM
			pitch = 0.78
		&"singularity_orbital":
			stream = GRAVITY_SCAR_APPLIED_STREAM
			pitch = 0.92
		&"slingshot_law_convergence":
			stream = SLINGSHOT_APEX_STREAM
			pitch = 1.28
	_play_positional_cue(stream, position, powerup_cue_volume_db - 2.0, pitch)


func _on_shield_broken() -> void:
	_play_player_cue(IMPACT_STREAM, shield_cue_volume_db, 0.72)


func _on_shield_hit(amount: float, current_energy: float, max_capacity: float) -> void:
	if amount <= 0.0:
		return
	var ratio := clampf(current_energy / maxf(max_capacity, 1.0), 0.0, 1.0)
	_play_player_cue(METALLIC_DECAY_STREAM, shield_cue_volume_db - 5.0, lerpf(1.18, 0.78, ratio))


func _on_shield_restored(_amount: float, _current_energy: float, _max_capacity: float) -> void:
	_play_player_cue(RESONANCE_CREATED_STREAM, shield_cue_volume_db - 2.0, 1.12)


func _on_energy_depleted() -> void:
	_play_resource_warning(0.72)


func _on_weapon_energy_failed(_weapon_id: StringName, _required_energy: float, _available_energy: float) -> void:
	_play_resource_warning(0.86)


func _play_resource_warning(pitch: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _next_resource_warning_cue:
		return
	_next_resource_warning_cue = now + 0.7
	_play_player_cue(ENERGY_EXHAUSTED_STREAM, shield_cue_volume_db - 3.0, pitch)


func _on_resonance_zone_decayed(zone_data: Dictionary) -> void:
	if not bool(zone_data.get("manual", false)) and float(zone_data.get("intensity", 0.0)) < 0.58:
		return
	var position: Vector2 = zone_data.get("midpoint", Vector2.ZERO)
	_play_positional_cue(RESONANCE_DECAY_STREAM, position, resonance_cue_volume_db - 6.0, 0.76)


func _on_kinetic_overload_ended(speed: float) -> void:
	_play_player_cue(SLINGSHOT_GREAT_STREAM, momentum_cue_volume_db - 5.0, lerpf(0.64, 0.9, clampf(speed / 2000.0, 0.0, 1.0)))


func _on_chaos_level_changed(value: float) -> void:
	if value < 0.55:
		return
	_play_player_cue(INSTABILITY_CHANGED_STREAM, resonance_cue_volume_db - 8.0, lerpf(0.82, 1.1, value))


func _on_tide_pocket_activated(_mode: int, position: Vector2) -> void:
	_play_positional_cue(TIDE_POCKET_STREAM, position, time_cue_volume_db - 4.0, 0.88)


func _on_tide_pocket_expired(_mode: int, position: Vector2) -> void:
	_play_positional_cue(TIME_POCKET_EXIT_STREAM, position, time_cue_volume_db - 7.0, 0.62)


func _on_wormhole_teleport(position: Vector2, _destination: Vector2, _body: Node) -> void:
	_play_positional_cue(WORMHOLE_PULSE_STREAM, position, time_cue_volume_db - 5.0, 0.92)


func _on_time_tear_intensity_changed(intensity: float) -> void:
	if intensity < 0.2:
		return
	_play_player_cue(INSTABILITY_CHANGED_STREAM, time_cue_volume_db - 2.0, lerpf(0.75, 1.25, intensity))


func _on_gravity_scar_created(scar_data: Dictionary) -> void:
	var position: Vector2 = scar_data.get("position", _player.global_position if _player != null else Vector2.ZERO)
	var intensity := clampf(float(scar_data.get("intensity", 0.45)), 0.0, 1.0)
	_play_positional_cue(GRAVITY_SCAR_CREATED_STREAM, position, resonance_cue_volume_db - 4.0, lerpf(0.82, 1.08, intensity))


func _on_gravity_scar_intensified(scar_data: Dictionary) -> void:
	var position: Vector2 = scar_data.get("position", _player.global_position if _player != null else Vector2.ZERO)
	var intensity := clampf(float(scar_data.get("intensity", 0.6)), 0.0, 1.0)
	_play_positional_cue(GRAVITY_SCAR_INTENSIFY_STREAM, position, resonance_cue_volume_db - 3.0, lerpf(0.9, 1.18, intensity))


func _on_gravity_scar_applied(body: Node, impulse: Vector2, scar_data: Dictionary) -> void:
	if impulse.length_squared() < 180.0 * 180.0:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < _next_gravity_scar_apply_cue:
		return
	_next_gravity_scar_apply_cue = now + 0.45
	var body_2d := body as Node2D
	var position: Vector2 = body_2d.global_position if body_2d != null else scar_data.get("position", _player.global_position if _player != null else Vector2.ZERO)
	_play_positional_cue(GRAVITY_SCAR_APPLIED_STREAM, position, resonance_cue_volume_db - 6.0, lerpf(0.72, 1.08, clampf(impulse.length() / 1200.0, 0.0, 1.0)))


func _on_gravity_scar_decayed(_scar_id: int) -> void:
	_play_player_cue(GRAVITY_SCAR_DECAY_STREAM, resonance_cue_volume_db - 8.0, 0.78)


func _on_boss_wave() -> void:
	_play_player_cue(BOSS_TELEGRAPH_STREAM, momentum_cue_volume_db - 2.0, 0.92)


func _on_arena_instability_event_telegraphed(event_id: StringName, data: Dictionary) -> void:
	var position: Vector2 = data.get("center", _player.global_position if _player != null else Vector2.ZERO)
	var stream := _instability_stream(event_id, false)
	_play_positional_cue(stream, position, resonance_cue_volume_db - 5.0, 0.86)


func _on_arena_instability_event_started(event_id: StringName, data: Dictionary) -> void:
	var position: Vector2 = data.get("center", _player.global_position if _player != null else Vector2.ZERO)
	var stream := _instability_stream(event_id, true)
	_play_positional_cue(stream, position, resonance_cue_volume_db - 3.0, 1.0)


func _on_spacetime_tear_opened(data: Dictionary) -> void:
	var position: Vector2 = data.get("position", _player.global_position if _player != null else Vector2.ZERO)
	var intensity := clampf(float(data.get("intensity", 0.5)), 0.0, 1.0)
	_play_positional_cue(WORMHOLE_SWIRL_STREAM, position, time_cue_volume_db - 4.0, lerpf(0.74, 1.08, intensity))


func _on_spacetime_tear_enemy_spawned(enemy: Node, data: Dictionary) -> void:
	var enemy_2d := enemy as Node2D
	var position: Vector2 = enemy_2d.global_position if enemy_2d != null else data.get("position", _player.global_position if _player != null else Vector2.ZERO)
	_play_positional_cue(WORMHOLE_PULSE_STREAM, position, time_cue_volume_db - 8.0, 0.72)


func _on_player_hit_invulnerability_started(_duration: float) -> void:
	_play_player_cue(METALLIC_DECAY_STREAM, shield_cue_volume_db - 2.0, 1.08)


func _on_damage_ignored_during_invulnerability(amount: float) -> void:
	if amount <= 0.0:
		return
	_play_player_cue(MOMENTUM_SURGE_STREAM, shield_cue_volume_db - 8.0, 1.24)


func _on_weapon_fired(weapon_id: StringName, weapon_data: Dictionary) -> void:
	if weapon_id == &"vector_bolt":
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < _next_weapon_cue_time:
		return
	_next_weapon_cue_time = now + 0.42
	var position := _event_position(weapon_data)
	var stream := MOMENTUM_SURGE_STREAM
	var pitch := 0.94
	match weapon_id:
		&"relativistic_rail":
			stream = KINETIC_IMPACT_STREAM
			pitch = 1.24
		&"barycentric_splitter", &"harmonic_needle":
			stream = RESONANCE_HARMONIC_STREAM
			pitch = 1.06
		&"vacuum_collapse_seed", &"singularity_pin":
			stream = GRAVITY_SCAR_CREATED_STREAM
			pitch = 0.86
		&"temporal_splinter":
			stream = TIME_DILATION_BREAK_STREAM
			pitch = 1.08
		&"inversion_disc":
			stream = RESONANCE_CREATED_STREAM
			pitch = 0.92
		&"shear_comet":
			stream = MOMENTUM_SURGE_STREAM
			pitch = 1.18
		&"event_horizon_shard":
			stream = LATE_GAME_OVERFOLD_STREAM
			pitch = 0.7
		&"gravity_wave_beam":
			stream = TIDE_POCKET_STREAM
			pitch = 0.82
		&"chronal_refraction_beam":
			stream = TIME_DILATION_BREAK_STREAM
			pitch = 0.72
		&"positron_beam":
			stream = KINETIC_IMPACT_STREAM
			pitch = 1.16
	_play_positional_cue(stream, position, powerup_cue_volume_db - 6.0, pitch)


func _on_drop_sequence_spawned(enemy: Node, drops: Array, data: Dictionary) -> void:
	if drops.is_empty():
		return
	var position := _node_position(enemy, _event_position(data))
	var rarity := int(data.get("rarity", 0))
	var is_boss := bool(data.get("is_boss", false))
	var stream := RARE_EVENT_STREAM if rarity >= 3 else RESONANCE_CREATED_STREAM
	if is_boss:
		stream = LATE_GAME_OVERFOLD_STREAM
	_play_positional_cue(stream, position, powerup_cue_volume_db - 4.0, 0.9 + float(mini(rarity, 5)) * 0.08)
	for drop_value in drops:
		var drop := drop_value as Node
		if drop == null or not is_instance_valid(drop):
			continue
		var callback := Callable(self, "_on_physics_drop_collected")
		if drop.has_signal("physics_drop_collected") and not drop.is_connected("physics_drop_collected", callback):
			drop.connect("physics_drop_collected", callback)


func _on_physics_drop_collected(drop_type: int, data: Dictionary) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _next_drop_collect_cue:
		return
	_next_drop_collect_cue = now + 0.16
	var stream := _drop_stream(drop_type)
	var position := _event_position(data)
	var pitch := 0.92 + float(drop_type) * 0.04
	_play_positional_cue(stream, position, powerup_cue_volume_db - 3.0, pitch)


func _on_impossible_event_started(event_id: StringName, data: Dictionary) -> void:
	var stream := _impossible_event_stream(event_id)
	_play_positional_cue(stream, _event_position(data), resonance_cue_volume_db - 2.0, 0.86)


func _on_recovery_opportunity_started(opportunity_id: StringName, data: Dictionary) -> void:
	var stream := _recovery_stream(opportunity_id)
	_play_positional_cue(stream, _event_position(data), momentum_cue_volume_db - 4.0, 1.08)


func _on_recovery_opportunity_resolved(_opportunity_id: StringName, data: Dictionary) -> void:
	var success := bool(data.get("success", true))
	var stream := SLINGSHOT_APEX_STREAM if success else TIME_POCKET_EXIT_STREAM
	_play_positional_cue(stream, _event_position(data), momentum_cue_volume_db - 5.0, 1.12 if success else 0.74)


func _on_near_miss_recorded(data: Dictionary) -> void:
	var severity := clampf(float(data.get("severity", data.get("risk", 0.0))), 0.0, 1.0)
	if severity < 0.42:
		return
	_play_positional_cue(MOMENTUM_SURGE_STREAM, _event_position(data), momentum_cue_volume_db - 8.0, lerpf(0.88, 1.3, severity))


func _on_reality_breach_opened(breach_id: StringName, data: Dictionary) -> void:
	var stream := OVERFOLD_BOSS_TELEGRAPH_STREAM if breach_id == &"edge_breach" else LATE_GAME_OVERFOLD_STREAM
	_play_positional_cue(stream, _event_position(data), resonance_cue_volume_db - 2.0, 0.82)


func _on_physics_constants_shifted(data: Dictionary) -> void:
	_play_positional_cue(TIME_DILATION_BREAK_STREAM, _event_position(data), time_cue_volume_db - 5.0, 0.66)


func _on_celestial_event_started(event_id: StringName, data: Dictionary) -> void:
	var stream := VOLATILE_MOON_STREAM
	match event_id:
		&"binary_system":
			stream = ORBIT_BOSS_TELEGRAPH_STREAM
		&"wandering_singularity":
			stream = SINGULARITY_BOSS_TELEGRAPH_STREAM
		&"rogue_planet":
			stream = TIDE_POCKET_STREAM
	_play_positional_cue(stream, _event_position(data), resonance_cue_volume_db - 5.0, 0.82)


func _on_celestial_body_spawned(body: Node, data: Dictionary) -> void:
	var position := _node_position(body, _event_position(data))
	var kind_value: Variant = data.get("kind", -1)
	var kind_type := typeof(kind_value)
	var is_singularity := false
	if kind_type == TYPE_INT:
		is_singularity = int(kind_value) == DynamicCelestialBody.BodyKind.SINGULARITY
	elif kind_type == TYPE_STRING or kind_type == TYPE_STRING_NAME:
		is_singularity = StringName(kind_value) == &"singularity"
	var stream := SINGULARITY_BOSS_TELEGRAPH_STREAM if is_singularity else TIDE_POCKET_STREAM
	_play_positional_cue(stream, position, resonance_cue_volume_db - 8.0, 0.72)


func _on_spacetime_swim_triggered(data: Dictionary) -> void:
	_play_positional_cue(SPACETIME_SWIM_STREAM, _event_position(data), time_cue_volume_db - 7.0, lerpf(0.82, 1.2, clampf(float(data.get("intensity", 0.5)), 0.0, 1.0)))


func _on_spacetime_glitch_triggered(data: Dictionary) -> void:
	_play_positional_cue(TIME_DILATION_BREAK_STREAM, _event_position(data), time_cue_volume_db - 8.0, 0.64)


func _on_arena_event_started(event_id: StringName, value: float) -> void:
	if value < 0.28:
		return
	_play_player_cue(_ambient_event_stream(event_id), resonance_cue_volume_db - 7.0, lerpf(0.72, 1.05, clampf(value, 0.0, 1.0)))


func _on_arena_hazard_spawned(hazard: Node, event_id: StringName) -> void:
	_play_positional_cue(_ambient_event_stream(event_id), _node_position(hazard, _player.global_position if _player != null else Vector2.ZERO), resonance_cue_volume_db - 6.0, 0.82)


func _on_breacher_attack_started(attack_id: StringName, data: Dictionary) -> void:
	_play_positional_cue(_breacher_attack_stream(attack_id), _event_position(data), momentum_cue_volume_db - 2.0, 0.86)


func _on_boss_phase_entered(phase: int, boss: Node) -> void:
	if boss == null or not is_instance_valid(boss):
		return
	var stream := _boss_telegraph_stream(boss)
	var boss_2d := boss as Node2D
	var position := boss_2d.global_position if boss_2d != null else (_player.global_position if _player != null else Vector2.ZERO)
	_play_positional_cue(stream, position, momentum_cue_volume_db - 3.0, 0.84 + float(phase) * 0.08)


func _play_zone_cue(zone_data: Dictionary, volume_offset: float, intensified: bool) -> void:
	var position: Vector2 = zone_data.get("midpoint", Vector2.ZERO)
	var intensity := clampf(float(zone_data.get("intensity", 0.35)), 0.0, 1.0)
	var manual := bool(zone_data.get("manual", false))
	if intensity < 0.5 and not manual:
		return
	var zone_name := StringName(zone_data.get("zone_type_name", &"compression"))
	if zone_name == &"harmonic_orbit" and intensity < 0.68 and not manual:
		return
	var stream := _zone_stream(zone_name, intensified)
	var pitch := 0.78
	match zone_name:
		&"slipstream":
			pitch = 1.05
		&"inversion":
			pitch = 0.62
		&"temporal_scar":
			pitch = 0.48
		&"harmonic_orbit":
			pitch = 1.32
	_play_positional_cue(stream, position, resonance_cue_volume_db + volume_offset, pitch + intensity * 0.18)


func _load_audio_manifest_overrides() -> void:
	_sfx_overrides.clear()
	if audio_manifest_path.strip_edges().is_empty() or not FileAccess.file_exists(audio_manifest_path):
		return
	var file := FileAccess.open(audio_manifest_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return
	var manifest: Dictionary = parsed
	var sfx_value: Variant = manifest.get("sfx", {})
	var sfx: Dictionary = sfx_value if sfx_value is Dictionary else {}
	for key in sfx.keys():
		var stream := _load_audio_stream(String(sfx[key]))
		if stream != null:
			_sfx_overrides[StringName(str(key))] = stream


func _load_audio_stream(path: String) -> AudioStream:
	var clean_path := path.strip_edges()
	if clean_path.is_empty():
		return null
	var resource := load(clean_path)
	return resource as AudioStream


func _override_stream(key: StringName, fallback: AudioStream) -> AudioStream:
	var value: Variant = _sfx_overrides.get(key, null)
	if value is AudioStream:
		return value
	return fallback


func _zone_stream(zone_name: StringName, intensified: bool) -> AudioStream:
	match zone_name:
		&"slipstream":
			return _override_stream(&"resonance.slipstream", RESONANCE_SLIPSTREAM_STREAM)
		&"harmonic_orbit":
			return _override_stream(&"resonance.harmonic_orbit", RESONANCE_HARMONIC_STREAM)
		&"temporal_scar":
			return _override_stream(&"resonance.temporal_scar", TIME_POCKET_ENTER_STREAM)
		&"inversion":
			return _override_stream(&"resonance.inversion", INSTABILITY_CHANGED_STREAM)
	return _override_stream(&"resonance.intensify", RESONANCE_INTENSIFY_STREAM) if intensified else _override_stream(&"resonance.created", RESONANCE_CREATED_STREAM)


func _instability_stream(event_id: StringName, started: bool) -> AudioStream:
	match event_id:
		&"gravity_tide":
			return _override_stream(&"arena.gravity_tide", TIDE_POCKET_STREAM)
		&"slipstream_surge":
			return _override_stream(&"arena.slipstream_surge.start", SLINGSHOT_GREAT_STREAM) if started else _override_stream(&"arena.slipstream_surge.telegraph", RESONANCE_SLIPSTREAM_STREAM)
		&"collapsing_orbit_lane":
			return _override_stream(&"arena.collapsing_orbit_lane", COLLAPSE_LANE_STREAM)
		&"resonance_storm":
			return _override_stream(&"arena.resonance_storm", RESONANCE_INTENSIFY_STREAM)
		&"spacetime_fracture":
			return _override_stream(&"arena.spacetime_fracture.start", WORMHOLE_PULSE_STREAM) if started else _override_stream(&"arena.spacetime_fracture.telegraph", TIME_DILATION_BREAK_STREAM)
		&"momentum_inversion":
			return _override_stream(&"arena.momentum_inversion.start", BOSS_ATTACK_STREAM) if started else _override_stream(&"arena.momentum_inversion.telegraph", INSTABILITY_CHANGED_STREAM)
	return _override_stream(&"time.pocket_exit", TIME_POCKET_EXIT_STREAM) if started else _override_stream(&"time.pocket_enter", TIME_POCKET_ENTER_STREAM)


func _drop_stream(drop_type: int) -> AudioStream:
	match drop_type:
		PhysicsDrop.DropType.MOMENTUM_ORB:
			return _override_stream(&"drop.momentum_orb", MOMENTUM_SURGE_STREAM)
		PhysicsDrop.DropType.GRAVITY_RESIDUE:
			return _override_stream(&"drop.gravity_residue", TIDE_POCKET_STREAM)
		PhysicsDrop.DropType.TEMPORAL_CHARGE:
			return _override_stream(&"drop.temporal_charge", TIME_POCKET_ENTER_STREAM)
		PhysicsDrop.DropType.INSTABILITY_SHARD:
			return _override_stream(&"drop.instability_shard", RARE_EVENT_STREAM)
		PhysicsDrop.DropType.ANOMALY_SEED:
			return _override_stream(&"drop.anomaly_seed", WORMHOLE_SWIRL_STREAM)
		PhysicsDrop.DropType.CELESTIAL_CORE:
			return _override_stream(&"drop.celestial_core", LATE_GAME_OVERFOLD_STREAM)
	return _override_stream(&"resonance.created", RESONANCE_CREATED_STREAM)


func _impossible_event_stream(event_id: StringName) -> AudioStream:
	match event_id:
		&"collapse_lane":
			return _override_stream(&"impossible.collapse_lane", COLLAPSE_LANE_STREAM)
		&"gravity_braid":
			return _override_stream(&"impossible.gravity_braid", TIDE_POCKET_STREAM)
		&"temporal_splinter":
			return _override_stream(&"impossible.temporal_splinter", TIME_DILATION_BREAK_STREAM)
		&"resonance_overfold":
			return _override_stream(&"impossible.resonance_overfold", LATE_GAME_OVERFOLD_STREAM)
	return _override_stream(&"rare.event", RARE_EVENT_STREAM)


func _recovery_stream(opportunity_id: StringName) -> AudioStream:
	match opportunity_id:
		&"emergency_wormhole_exit":
			return _override_stream(&"recovery.emergency_wormhole_exit", WORMHOLE_PULSE_STREAM)
		&"time_dilation_dodge_window":
			return _override_stream(&"recovery.time_dilation_dodge_window", TIME_POCKET_ENTER_STREAM)
		&"resonance_rebound":
			return _override_stream(&"recovery.resonance_rebound", RESONANCE_HARMONIC_STREAM)
		&"momentum_conservation_chain":
			return _override_stream(&"recovery.momentum_conservation_chain", MOMENTUM_SURGE_STREAM)
	return _override_stream(&"slingshot.great", SLINGSHOT_GREAT_STREAM)


func _ambient_event_stream(event_id: StringName) -> AudioStream:
	match event_id:
		&"tide_slipstream", &"gravity_tide":
			return _override_stream(&"ambient.gravity_tide", TIDE_POCKET_STREAM)
		&"volatile_moon":
			return _override_stream(&"ambient.volatile_moon", VOLATILE_MOON_STREAM)
		&"nebula_shear":
			return _override_stream(&"ambient.nebula_shear", NEBULA_SHEAR_STREAM)
		&"collapse_lane", &"collapsing_orbit_lane":
			return _override_stream(&"ambient.collapse_lane", COLLAPSE_LANE_STREAM)
		&"wormhole_shear":
			return _override_stream(&"ambient.wormhole_shear", WORMHOLE_SWIRL_STREAM)
		&"temporal_pocket":
			return _override_stream(&"time.pocket_enter", TIME_POCKET_ENTER_STREAM)
		&"rupture_pulse", &"finale_storm":
			return _override_stream(&"ambient.finale_storm", LATE_GAME_OVERFOLD_STREAM)
	return _override_stream(&"rare.event", RARE_EVENT_STREAM)


func _breacher_attack_stream(attack_id: StringName) -> AudioStream:
	match attack_id:
		&"moving_singularity":
			return _override_stream(&"boss.attack.moving_singularity", SINGULARITY_BOSS_TELEGRAPH_STREAM)
		&"moon_fragment_orbit":
			return _override_stream(&"boss.attack.moon_fragment_orbit", ORBIT_BOSS_TELEGRAPH_STREAM)
		&"slipstream_corridor":
			return _override_stream(&"boss.attack.slipstream_corridor", RESONANCE_SLIPSTREAM_STREAM)
		&"unstable_wormhole":
			return _override_stream(&"boss.attack.unstable_wormhole", WORMHOLE_SWIRL_STREAM)
		&"timeline_slam":
			return _override_stream(&"boss.attack.timeline_slam", TIME_DILATION_BREAK_STREAM)
		&"outside_space_breach":
			return _override_stream(&"boss.attack.outside_space_breach", OVERFOLD_BOSS_TELEGRAPH_STREAM)
	return _override_stream(&"boss.telegraph.fracture", FRACTURE_BOSS_TELEGRAPH_STREAM)


func _boss_telegraph_stream(boss: Node) -> AudioStream:
	var boss_name := boss.name.to_lower()
	if boss_name.contains("singularity") or boss_name.contains("seraph") or boss_name.contains("accretion"):
		return _override_stream(&"boss.telegraph.singularity", SINGULARITY_BOSS_TELEGRAPH_STREAM)
	if boss_name.contains("rift") or boss_name.contains("fracture") or boss_name.contains("polymorph"):
		return _override_stream(&"boss.telegraph.fracture", FRACTURE_BOSS_TELEGRAPH_STREAM)
	if boss_name.contains("centrifuge") or boss_name.contains("orbit") or boss_name.contains("warden"):
		return _override_stream(&"boss.telegraph.orbit", ORBIT_BOSS_TELEGRAPH_STREAM)
	if boss_name.contains("breacher") or boss_name.contains("overfold"):
		return _override_stream(&"boss.telegraph.overfold", OVERFOLD_BOSS_TELEGRAPH_STREAM)
	return _override_stream(&"boss.telegraph.default", BOSS_TELEGRAPH_STREAM)


func _event_position(data: Dictionary) -> Vector2:
	for key in [&"position", &"center", &"origin", &"midpoint"]:
		var value: Variant = data.get(key, null)
		if value is Vector2:
			return value
	return _player.global_position if _player != null else Vector2.ZERO


func _node_position(node: Node, fallback: Vector2) -> Vector2:
	var node_2d := node as Node2D
	if node_2d == null or not is_instance_valid(node_2d):
		return fallback
	return node_2d.global_position


func _play_player_cue(stream: AudioStream, volume_db: float, pitch: float) -> void:
	var position := _player.global_position if _player != null else Vector2.ZERO
	_play_positional_cue(stream, position, volume_db, pitch)


func _play_positional_cue(stream: AudioStream, position: Vector2, volume_db: float, pitch: float) -> void:
	if not enabled or stream == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_cue_time < minimum_cue_gap:
		return
	if _active_players.size() >= max_simultaneous_cues:
		return
	_last_cue_time = now
	var scene

	if get_tree().current_scene != null and is_instance_valid(get_tree().current_scene):
		scene = get_tree().current_scene
		if scene == null:
			return
	var player := AudioStreamPlayer2D.new()
	player.name = "MechanicCue"
	player.stream = stream
	player.global_position = position
	player.volume_db = volume_db
	player.pitch_scale = clampf(pitch, 0.35, 1.9)
	player.bus = bus_name
	scene.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	_active_players.append(player)


func _prune_players() -> void:
	for idx in range(_active_players.size() - 1, -1, -1):
		var player := _active_players[idx]
		if player == null or not is_instance_valid(player) or player.is_queued_for_deletion():
			_active_players.remove_at(idx)
