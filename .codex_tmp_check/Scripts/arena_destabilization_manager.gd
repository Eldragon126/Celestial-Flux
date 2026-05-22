extends Node2D
class_name ArenaDestabilizationManager

# Run-scale arena escalation for ORBITRON: VECTORFALL.
# This manager listens to wave progression, raises an instability meter,
# and injects capped modular hazards.

signal instability_changed(value: float, stage: StringName)
signal stage_changed(stage: StringName, value: float)
signal arena_event_started(event_id: StringName, value: float)
signal arena_hazard_spawned(hazard: Node, event_id: StringName)
signal arena_hazard_expired(hazard_name: StringName, event_id: StringName)
signal chaos_level_changed(value: float)

const UNSTABLE_MOON_SCENE = preload("res://Nodes/unstable_moon.tscn")
const NEBULA_SCENE = preload("res://Nodes/nebula_cloud.tscn")
const WORMHOLE_PAIR_SCENE = preload("res://Nodes/wormhole_pair.tscn")
const GRAVITY_TIDE_POCKET_SCENE = preload("res://Nodes/gravity_tide_pocket.tscn")

@export var enabled: bool = true
@export var update_interval: float = 0.35
@export_range(0.0, 1.0, 0.01) var starting_instability: float = 0.0
@export var wave_instability_gain: float = 0.075
@export var boss_wave_bonus: float = 0.16
@export var enemy_pressure_weight: float = 0.01
@export var resonance_pressure_weight: float = 0.07
@export var instability_lerp_rate: float = 1.15

@export_group("Stages")
@export_range(0.0, 1.0, 0.01) var mid_stage_threshold: float = 0.34
@export_range(0.0, 1.0, 0.01) var late_stage_threshold: float = 0.68

@export_group("Events")
@export var min_event_interval: float = 11.0
@export var max_event_interval: float = 18.0
@export var boss_event_interval_multiplier: float = 0.72
@export var max_active_hazards: int = 7
@export var spawn_min_radius: float = 540.0
@export var spawn_max_radius: float = 1320.0
@export var avoid_player_radius: float = 360.0
@export var hazard_lifetime_min: float = 7.0
@export var hazard_lifetime_max: float = 14.0

@export_group("Performance")
@export var low_performance_mode: bool = false
@export var particle_scale: float = 1.0
@export var enable_tide_particles: bool = true
@export var debug_logging: bool = false

var instability: float = 0.0
var chaos_level: float = 0.0

var _player: Node2D = null
var _wave_director: Node = null
var _resonance_manager: Node = null
var _level_root: Node = null
var _stage: StringName = &"early"
var _elapsed := 0.0
var _event_timer := 0.0
var _connected_to_wave_director := false
var _last_wave_seen := 0
var _rng := RandomNumberGenerator.new()
var _active_hazards: Array[Node] = []

func _ready() -> void:
	add_to_group("arena_destabilization_manager")
	_rng.randomize()
	instability = clampf(starting_instability, 0.0, 1.0)
	chaos_level = instability
	_level_root = get_tree().current_scene
	_event_timer = _next_event_interval()
	call_deferred("_resolve_references")
	set_process(true)

func _process(delta: float) -> void:
	if not enabled:
		return

	_elapsed += delta
	_event_timer -= delta
	_cleanup_hazard_tracking()

	if _elapsed >= maxf(update_interval, 0.05):
		_elapsed = 0.0
		_resolve_references()
		_update_instability(update_interval)

	if _event_timer <= 0.0:
		_try_spawn_arena_event()

func get_instability_debug_state() -> Dictionary:
	return {
		"instability": instability,
		"chaos_level": chaos_level,
		"stage": _stage,
		"active_hazards": _count_valid_hazards(),
		"next_event": maxf(_event_timer, 0.0),
	}

func force_arena_event(event_id: StringName = &"") -> void:
	_spawn_event(event_id if not event_id.is_empty() else _choose_event())

func _resolve_references() -> void:
	_level_root = get_tree().current_scene
	_player = get_tree().get_first_node_in_group("Player") as Node2D

	if _level_root != null:
		if _wave_director == null or not is_instance_valid(_wave_director):
			_wave_director = _level_root.find_child("WaveDirector", true, false)
			_connected_to_wave_director = false
		if _resonance_manager == null or not is_instance_valid(_resonance_manager):
			_resonance_manager = _level_root.find_child("GravityResonanceManager", true, false)

	if _wave_director != null and not _connected_to_wave_director:
		_connect_wave_director()

func _connect_wave_director() -> void:
	if _wave_director == null:
		return

	if _wave_director.has_signal("regular_wave"):
		var regular_callable := Callable(self, "_on_regular_wave")
		if not _wave_director.is_connected("regular_wave", regular_callable):
			_wave_director.connect("regular_wave", regular_callable)

	if _wave_director.has_signal("boss_wave"):
		var boss_callable := Callable(self, "_on_boss_wave")
		if not _wave_director.is_connected("boss_wave", boss_callable):
			_wave_director.connect("boss_wave", boss_callable)

	_connected_to_wave_director = true

func _on_regular_wave() -> void:
	_mark_wave_pressure(false)

func _on_boss_wave() -> void:
	_mark_wave_pressure(true)

func _mark_wave_pressure(is_boss_wave: bool) -> void:
	var wave := _current_wave()
	if wave > _last_wave_seen:
		_last_wave_seen = wave
		instability = clampf(instability + wave_instability_gain * 0.45, 0.0, 1.0)

	if is_boss_wave:
		instability = clampf(instability + boss_wave_bonus * 0.35, 0.0, 1.0)
		_event_timer = minf(_event_timer, _next_event_interval() * boss_event_interval_multiplier)

func _update_instability(delta: float) -> void:
	var target := _target_instability()
	instability = lerpf(instability, target, clampf(delta * instability_lerp_rate, 0.0, 1.0))
	instability = clampf(instability, 0.0, 1.0)
	chaos_level = lerpf(chaos_level, instability, clampf(delta * 1.4, 0.0, 1.0))

	var next_stage := _stage_for_instability(instability)
	if next_stage != _stage:
		_stage = next_stage
		stage_changed.emit(_stage, instability)

	instability_changed.emit(instability, _stage)
	chaos_level_changed.emit(chaos_level)

func _target_instability() -> float:
	var wave := _current_wave()
	var target := starting_instability + float(maxi(wave - 1, 0)) * wave_instability_gain
	target += float(_enemy_count()) * enemy_pressure_weight
	target += float(_active_resonance_count()) * resonance_pressure_weight

	if _is_boss_active():
		target += boss_wave_bonus

	if _stage == &"late":
		target += 0.04

	return clampf(target, 0.0, 1.0)

func _try_spawn_arena_event() -> void:
	_event_timer = _next_event_interval()
	if _player == null or _level_root == null:
		return
	if _count_valid_hazards() >= max_active_hazards:
		return
	if instability < 0.12:
		return

	_spawn_event(_choose_event())

func _spawn_event(event_id: StringName) -> void:
	match event_id:
		&"tide_compression":
			_spawn_tide_pocket(GravityTidePocket.TideMode.COMPRESSION)
		&"tide_slipstream":
			_spawn_tide_pocket(GravityTidePocket.TideMode.SLIPSTREAM)
		&"tide_inversion":
			_spawn_tide_pocket(GravityTidePocket.TideMode.INVERSION)
		&"temporal_pocket":
			_spawn_tide_pocket(GravityTidePocket.TideMode.TEMPORAL)
		&"volatile_moon":
			_spawn_volatile_moon()
		&"nebula_shear":
			_spawn_nebula_shear()
		&"wormhole_shear":
			_spawn_wormhole_shear()
		&"resonance_storm":
			_spawn_resonance_storm()
		_:
			_spawn_tide_pocket(GravityTidePocket.TideMode.COMPRESSION)

	arena_event_started.emit(event_id, instability)
	if debug_logging:
		print("Arena event: ", event_id, " instability=", instability)

func _choose_event() -> StringName:
	var roll := _rng.randf()

	if _stage == &"early":
		return &"tide_slipstream" if roll < 0.55 else &"volatile_moon"

	if _stage == &"mid":
		if roll < 0.32:
			return &"tide_compression"
		if roll < 0.56:
			return &"tide_slipstream"
		if roll < 0.7:
			return &"temporal_pocket"
		if roll < 0.84:
			return &"nebula_shear"
		return &"volatile_moon"

	# Late stage
	if roll < 0.18:
		return &"tide_inversion"
	if roll < 0.34:
		return &"temporal_pocket"
	if roll < 0.5:
		return &"resonance_storm"
	if roll < 0.66:
		return &"wormhole_shear"
	if roll < 0.84:
		return &"tide_compression"
	return &"nebula_shear"

func _spawn_tide_pocket(mode: int) -> Node:
	var pocket := GRAVITY_TIDE_POCKET_SCENE.instantiate()
	var pocket_radius := lerpf(230.0, 430.0, instability)
	var pocket_lifetime := _rng.randf_range(hazard_lifetime_min, hazard_lifetime_max)
	var strength := lerpf(520.0, 1120.0, instability)

	if low_performance_mode:
		pocket_radius *= 0.86
		pocket_lifetime *= 0.82
		strength *= 0.82

	if pocket.has_method("configure"):
		pocket.call("configure", mode, pocket_radius, pocket_lifetime, strength)

	pocket.set("particle_cap", int(lerpf(70.0, 170.0, instability) * clampf(particle_scale, 0.0, 2.0)))
	pocket.set("enable_particles", enable_tide_particles and not low_performance_mode)
	return _spawn_hazard_node(pocket, _spawn_position(), _event_id_for_tide_mode(mode))

func _spawn_volatile_moon() -> Node:
	var moon := UNSTABLE_MOON_SCENE.instantiate()
	if moon.get("min_explosion_delay") != null:
		moon.set("min_explosion_delay", lerpf(8.5, 4.5, instability))
	if moon.get("max_explosion_delay") != null:
		moon.set("max_explosion_delay", lerpf(14.0, 7.0, instability))
	if moon.get("bullet_count") != null:
		moon.set("bullet_count", int(lerpf(12.0, 24.0, instability)))
	if moon.get("mass") != null:
		moon.set("mass", lerpf(110000.0, 260000.0, instability))

	return _spawn_hazard_node(moon, _spawn_position(), &"volatile_moon")

func _spawn_nebula_shear() -> Node:
	var nebula := NEBULA_SCENE.instantiate()
	if nebula.get("radius") != null:
		nebula.set("radius", lerpf(180.0, 340.0, instability))
	if nebula.get("speed_multiplier") != null:
		nebula.set("speed_multiplier", lerpf(0.78, 0.48, instability))
	if nebula.get("swirl_speed") != null:
		nebula.set("swirl_speed", lerpf(0.18, 0.64, instability))

	return _spawn_hazard_node(nebula, _spawn_position(), &"nebula_shear")

func _spawn_wormhole_shear() -> Node:
	var wormhole := WORMHOLE_PAIR_SCENE.instantiate()
	var center := _spawn_position()
	var axis := Vector2.RIGHT.rotated(_rng.randf() * TAU)
	var span := lerpf(720.0, 1280.0, instability)

	if wormhole.has_method("set_endpoint_positions"):
		wormhole.call("set_endpoint_positions", center - axis * span * 0.5, center + axis * span * 0.5)

	return _spawn_hazard_node(wormhole, center, &"wormhole_shear")

func _spawn_resonance_storm() -> void:
	var count := 2 if low_performance_mode else 3
	for i in range(count):
		var mode = [
			GravityTidePocket.TideMode.COMPRESSION,
			GravityTidePocket.TideMode.SLIPSTREAM,
			GravityTidePocket.TideMode.TEMPORAL,
		][i % 3]
		_spawn_tide_pocket(mode)

func _spawn_hazard_node(hazard: Node, position: Vector2, event_id: StringName) -> Node:
	if hazard == null or _level_root == null:
		return null

	hazard.name = "%s_%d" % [String(event_id).capitalize().replace(" ", ""), Time.get_ticks_msec()]
	_level_root.add_child(hazard)

	var hazard_2d := hazard as Node2D
	if hazard_2d != null:
		hazard_2d.global_position = position

	hazard.add_to_group("arena_destabilization_hazard")
	_active_hazards.append(hazard)
	hazard.tree_exited.connect(Callable(self, "_on_hazard_tree_exited").bind(hazard.name, event_id))
	call_deferred("_refresh_player_gravity_cache")
	arena_hazard_spawned.emit(hazard, event_id)
	return hazard

func _on_hazard_tree_exited(hazard_name: StringName, event_id: StringName) -> void:
	arena_hazard_expired.emit(hazard_name, event_id)
	call_deferred("_refresh_player_gravity_cache")

func _spawn_position() -> Vector2:
	if _player == null:
		return Vector2.ZERO

	var radius := _rng.randf_range(maxf(spawn_min_radius, avoid_player_radius), maxf(spawn_max_radius, spawn_min_radius + 10.0))
	var angle := _rng.randf() * TAU
	var pos := _player.global_position + Vector2(cos(angle), sin(angle)) * radius

	if pos.distance_to(_player.global_position) < avoid_player_radius:
		pos = _player.global_position + (pos - _player.global_position).normalized() * avoid_player_radius

	return pos

func _refresh_player_gravity_cache() -> void:
	if _player == null:
		return
	if _player.has_method("_refresh_gravity_sources"):
		_player.call("_refresh_gravity_sources", true)
	elif _player.get("planets") != null:
		_player.set("planets", get_tree().get_nodes_in_group("planets"))

func _cleanup_hazard_tracking() -> void:
	var kept: Array[Node] = []
	for hazard in _active_hazards:
		if is_instance_valid(hazard) and not hazard.is_queued_for_deletion():
			kept.append(hazard)
	_active_hazards = kept

func _count_valid_hazards() -> int:
	_cleanup_hazard_tracking()
	return _active_hazards.size()

func _current_wave() -> int:
	if _wave_director == null or not is_instance_valid(_wave_director):
		return _last_wave_seen
	return int(_safe_float(_wave_director.get("_wave"), float(_last_wave_seen)))

func _enemy_count() -> int:
	return get_tree().get_nodes_in_group("enemies").size()

func _active_resonance_count() -> int:
	if _resonance_manager == null or not is_instance_valid(_resonance_manager):
		return 0
	if not _resonance_manager.has_method("get_active_resonance_zones"):
		return 0

	var zones_value: Variant = _resonance_manager.call("get_active_resonance_zones")
	if typeof(zones_value) != TYPE_ARRAY:
		return 0

	return (zones_value as Array).size()

func _is_boss_active() -> bool:
	if _wave_director != null and is_instance_valid(_wave_director):
		var boss := _wave_director.get("_boss") as Node
		if boss != null and is_instance_valid(boss):
			return true

	for boss in get_tree().get_nodes_in_group("bosses"):
		if is_instance_valid(boss):
			return true

	return false

func _stage_for_instability(value: float) -> StringName:
	if value >= late_stage_threshold:
		return &"late"
	if value >= mid_stage_threshold:
		return &"mid"
	return &"early"

func _next_event_interval() -> float:
	var interval := _rng.randf_range(min_event_interval, max_event_interval)
	interval *= lerpf(1.15, 0.58, instability)
	if _is_boss_active():
		interval *= boss_event_interval_multiplier
	if low_performance_mode:
		interval *= 1.35
	return maxf(interval, 3.0)

func _event_id_for_tide_mode(mode_value: int) -> StringName:
	match mode_value:
		GravityTidePocket.TideMode.SLIPSTREAM:
			return &"tide_slipstream"
		GravityTidePocket.TideMode.INVERSION:
			return &"tide_inversion"
		GravityTidePocket.TideMode.TEMPORAL:
			return &"temporal_pocket"
		_:
			return &"tide_compression"

func _safe_float(value: Variant, fallback: float = 0.0) -> float:
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return fallback
