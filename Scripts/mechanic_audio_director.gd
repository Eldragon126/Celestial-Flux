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

@export var enabled: bool = true
@export var max_simultaneous_cues: int = 6
@export var minimum_cue_gap: float = 0.09
@export var source_refresh_interval: float = 1.0
@export var bus_name: StringName = &"Player Sound Effects"

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
var _gravity_scar_manager: Node = null
var _wave_director: Node = null
var _arena_instability: Node = null
var _tear_director: Node = null
var _active_players: Array[AudioStreamPlayer2D] = []
var _last_cue_time := -999.0
var _next_gravity_scar_apply_cue := 0.0
var _source_refresh_elapsed := 999.0


func _ready() -> void:
	add_to_group("mechanic_audio_director")
	call_deferred("_connect_sources")


func _process(delta: float) -> void:
	_prune_players()
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
	_connect_signal(_shield, &"shield_restored", Callable(self, "_on_shield_restored"))
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
	_connect_ambient_audio_sources(scene)


func _connect_ambient_audio_sources(scene: Node) -> void:
	if scene == null:
		return
	var arena := scene.find_child("ArenaDestabilizationManager", true, false)
	_connect_signal(arena, &"chaos_level_changed", Callable(self, "_on_chaos_level_changed"))
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
		_arena_instability = scene.find_child("ArenaInstabilityDirector", true, false)
		_tear_director = scene.find_child("SpacetimeTearDirector", true, false)
	if _player != null:
		_momentum = _player.get_node_or_null("MomentumCombatComponent")
		_inventory = _player.get_node_or_null("PowerupInventory")
		_shield = _player.get_node_or_null("Shield")


func _connect_signal(source: Node, signal_name: StringName, callable: Callable) -> void:
	if source == null or not is_instance_valid(source) or not source.has_signal(signal_name):
		return
	if not source.is_connected(signal_name, callable):
		source.connect(signal_name, callable)


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


func _on_shield_restored(_amount: float, _current_energy: float, _max_capacity: float) -> void:
	_play_player_cue(RESONANCE_CREATED_STREAM, shield_cue_volume_db - 2.0, 1.12)


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
	_play_positional_cue(WORMHOLE_SWIRL_STREAM, position, time_cue_volume_db - 4.0, 0.88)


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


func _zone_stream(zone_name: StringName, intensified: bool) -> AudioStream:
	match zone_name:
		&"slipstream":
			return RESONANCE_SLIPSTREAM_STREAM
		&"harmonic_orbit":
			return RESONANCE_HARMONIC_STREAM
		&"temporal_scar":
			return TIME_POCKET_ENTER_STREAM
		&"inversion":
			return INSTABILITY_CHANGED_STREAM
	return RESONANCE_INTENSIFY_STREAM if intensified else RESONANCE_CREATED_STREAM


func _instability_stream(event_id: StringName, started: bool) -> AudioStream:
	match event_id:
		&"slipstream_surge":
			return RESONANCE_SLIPSTREAM_STREAM if not started else SLINGSHOT_GREAT_STREAM
		&"resonance_storm", &"collapsing_orbit_lane":
			return RESONANCE_INTENSIFY_STREAM
		&"spacetime_fracture":
			return WORMHOLE_SWIRL_STREAM if not started else WORMHOLE_PULSE_STREAM
		&"momentum_inversion":
			return INSTABILITY_CHANGED_STREAM if not started else BOSS_ATTACK_STREAM
	return TIME_POCKET_ENTER_STREAM if not started else TIME_POCKET_EXIT_STREAM


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

	var scene := get_tree().current_scene
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
