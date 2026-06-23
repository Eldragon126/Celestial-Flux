extends Node
class_name GravityGhostRecorder
## Keeps a bounded local-player history for the game-over gravity ghost.

signal gravity_ghost_captured(snapshot: Dictionary)

@export var enabled: bool = true
@export_range(8.0, 20.0, 0.5) var history_seconds: float = 14.0
@export_range(5.0, 20.0, 1.0) var samples_per_second: float = 10.0
@export_range(64, 256, 1) var maximum_samples: int = 180
@export_range(4, 32, 1) var maximum_highlights: int = 18
@export_range(2, 12, 1) var maximum_incident_markers: int = 7
@export var minimum_motion_distance: float = 3.0
@export var gravity_pressure_warning_level: float = 850.0
@export var incident_marker_cooldown: float = 1.15

var _player: Node2D = null
var _momentum_component: Node = null
var _recovery_director: Node = null
var _event_horizon_director: Node = null
var _samples: Array[Dictionary] = []
var _highlights: Array[Dictionary] = []
var _gravity_sources: Array[Node2D] = []
var _sample_capacity: int = 0
var _sample_count: int = 0
var _write_index: int = 0
var _sample_elapsed: float = 0.0
var _connection_elapsed: float = 0.0
var _run_clock: float = 0.0
var _captured: bool = false


func _ready() -> void:
	add_to_group("gravity_ghost_recorder")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_configure_sample_buffer()
	call_deferred("_resolve_and_connect_sources")


func _process(delta: float) -> void:
	if not enabled or _captured:
		return
	_run_clock += delta
	_connection_elapsed += delta
	if _connection_elapsed >= 1.0:
		_connection_elapsed = 0.0
		_resolve_and_connect_sources()
	if not _is_recordable_player(_player):
		return
	if bool(_player.get_meta(&"death_in_progress", false)):
		return

	_sample_elapsed += delta
	var interval := 1.0 / maxf(samples_per_second, 1.0)
	if _sample_elapsed < interval:
		return
	_sample_elapsed = fmod(_sample_elapsed, interval)
	_capture_sample(false)


func _configure_sample_buffer() -> void:
	_sample_capacity = clampi(ceili(history_seconds * samples_per_second) + 2, 16, maximum_samples)
	_samples.resize(_sample_capacity)
	for index in range(_sample_capacity):
		_samples[index] = {}


func _resolve_and_connect_sources() -> void:
	if not _is_recordable_player(_player):
		_player = _find_local_player()
	if _player == null:
		return

	_connect_signal(_player, &"death_lesson_generated", Callable(self, "_on_death_lesson_generated"))
	_connect_signal(_player, &"slingshot_mastery_scored", Callable(self, "_on_slingshot_mastery_scored"))

	_momentum_component = _player.get_node_or_null("MomentumCombatComponent")
	_connect_signal(_momentum_component, &"near_miss_velocity_gained", Callable(self, "_on_near_miss_velocity_gained"))

	var root := get_tree().current_scene
	if root == null:
		return
	_recovery_director = root.find_child("RecoveryOpportunityDirector", true, false)
	_event_horizon_director = root.find_child("EventHorizonDirector", true, false)
	_connect_signal(_recovery_director, &"recovery_opportunity_resolved", Callable(self, "_on_recovery_opportunity_resolved"))
	_connect_signal(_event_horizon_director, &"horizon_escape_scored", Callable(self, "_on_horizon_escape_scored"))


func _connect_signal(source: Node, signal_name: StringName, callback: Callable) -> void:
	if source == null or not is_instance_valid(source) or not source.has_signal(signal_name):
		return
	if not source.is_connected(signal_name, callback):
		source.connect(signal_name, callback)


func _find_local_player() -> Node2D:
	for value in get_tree().get_nodes_in_group("Player"):
		var candidate := value as Node2D
		if not _is_recordable_player(candidate):
			continue
		var local_value: Variant = candidate.get("network_is_local")
		if typeof(local_value) != TYPE_BOOL or bool(local_value):
			return candidate
	return null


func _is_recordable_player(candidate: Node2D) -> bool:
	return candidate != null and is_instance_valid(candidate) and not candidate.is_queued_for_deletion()


func _capture_sample(force: bool) -> void:
	if not _is_recordable_player(_player) or _sample_capacity <= 0:
		return
	var position := _player.global_position
	var previous := _latest_sample()
	if not force and not previous.is_empty():
		var previous_position: Vector2 = previous.get("position", position)
		var previous_time := float(previous.get("time", _run_clock))
		if position.distance_to(previous_position) < minimum_motion_distance and _run_clock - previous_time < 0.3:
			return

	var velocity_value: Variant = _player.get("velocity")
	var velocity: Vector2 = velocity_value if velocity_value is Vector2 else Vector2.ZERO
	var pressure := _pressure_breakdown()
	_samples[_write_index] = {
		"time": _run_clock,
		"position": position,
		"speed": velocity.length(),
		"danger": float(pressure.get("danger", 0.0)),
		"projectile_pressure": float(pressure.get("projectile_pressure", 0.0)),
		"enemy_pressure": float(pressure.get("enemy_pressure", 0.0)),
		"health_pressure": float(pressure.get("health_pressure", 0.0)),
		"gravity_pressure": float(pressure.get("gravity_pressure", 0.0)),
		"projectile_count": int(pressure.get("projectile_count", 0)),
		"enemy_count": int(pressure.get("enemy_count", 0)),
		"gravity_strength": float(pressure.get("gravity_strength", 0.0)),
	}
	_write_index = (_write_index + 1) % _sample_capacity
	_sample_count = mini(_sample_count + 1, _sample_capacity)


func _latest_sample() -> Dictionary:
	if _sample_count <= 0 or _sample_capacity <= 0:
		return {}
	var index := (_write_index - 1 + _sample_capacity) % _sample_capacity
	return _samples[index]


func _pressure_breakdown() -> Dictionary:
	var projectile_count := 0
	var enemy_count := 0
	var boss_count := 0
	if RuntimeRegistry != null:
		projectile_count = RuntimeRegistry.get_count(&"enemy_projectiles")
		enemy_count = RuntimeRegistry.get_count(&"enemies")
		boss_count = RuntimeRegistry.get_count(&"bosses")
	else:
		projectile_count = get_tree().get_nodes_in_group("enemy_projectiles").size()
		enemy_count = get_tree().get_nodes_in_group("enemies").size()
		boss_count = get_tree().get_nodes_in_group("bosses").size()
	var projectile_pressure := clampf(float(projectile_count) / 90.0, 0.0, 1.0)
	var enemy_pressure := clampf((float(enemy_count) / 32.0) + float(boss_count) * 0.12, 0.0, 1.0)
	var health_pressure := 0.0
	var health := _player.get_node_or_null("HealthComponent") if _player != null else null
	if health != null:
		var current_value: Variant = health.get("current_health")
		var maximum_value: Variant = health.get("max_health")
		if (current_value is float or current_value is int) and (maximum_value is float or maximum_value is int):
			health_pressure = 1.0 - clampf(float(current_value) / maxf(float(maximum_value), 1.0), 0.0, 1.0)
	var gravity_strength := _gravity_strength_at_player()
	var gravity_pressure := clampf(gravity_strength / maxf(gravity_pressure_warning_level, 1.0), 0.0, 1.0)
	return {
		"danger": clampf(
			projectile_pressure * 0.3
			+ enemy_pressure * 0.2
			+ health_pressure * 0.28
			+ gravity_pressure * 0.22,
			0.0,
			1.0
		),
		"projectile_pressure": projectile_pressure,
		"enemy_pressure": enemy_pressure,
		"health_pressure": health_pressure,
		"gravity_pressure": gravity_pressure,
		"projectile_count": projectile_count,
		"enemy_count": enemy_count + boss_count,
		"gravity_strength": gravity_strength,
	}


func _gravity_strength_at_player() -> float:
	if not _is_recordable_player(_player):
		return 0.0
	var gravity_constant: float = float(_player.get("gravity_constant") or 0.0)
	var min_grav_dist: float = maxf(float(_player.get("min_grav_dist") or 1.0), 1.0)
	var pull_radius := maxf(float(_player.get("gravity_pull_radius") or 0.0), 0.0)
	var max_sources := maxi(int(_player.get("max_gravity_sources") or 4), 1)
	var per_source_cap := maxf(float(_player.get("max_gravity_acceleration_per_source") or 3600.0), 1.0)
	var total_cap := maxf(float(_player.get("max_total_gravity_acceleration") or 7200.0), 1.0)

	_gravity_sources.clear()
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_nearest_gravity_sources(
			_player.global_position,
			_gravity_sources,
			max_sources,
			pull_radius,
			_player
		)
	else:
		var cached_sources: Variant = _player.get("planets")
		if cached_sources is Array:
			for value in cached_sources:
				var source := value as Node2D
				if source != null and is_instance_valid(source) and not source.is_queued_for_deletion():
					_gravity_sources.append(source)
					if _gravity_sources.size() >= max_sources:
						break

	var total := Vector2.ZERO
	for source in _gravity_sources:
		if source == null or not is_instance_valid(source) or source.is_queued_for_deletion():
			continue
		var offset := source.global_position - _player.global_position
		var raw_distance := offset.length()
		if raw_distance <= 0.001 or (pull_radius > 0.0 and raw_distance > pull_radius):
			continue
		var mass_value: Variant = source.get("mass")
		var source_mass := float(mass_value) if mass_value is float or mass_value is int else 100.0
		var distance := maxf(raw_distance, min_grav_dist)
		var contribution := offset / raw_distance * gravity_constant * source_mass / (distance * distance)
		total = (total + contribution.limit_length(per_source_cap)).limit_length(total_cap)
	return total.length()


func _on_slingshot_mastery_scored(data: Dictionary) -> void:
	var grade := StringName(String(data.get("grade", &"assist")))
	if grade not in [&"great", &"perfect", &"apex"]:
		return
	_record_highlight(&"slingshot", String(grade).to_upper(), float(data.get("score", 0.0)), data.get("position", _player_position()))


func _on_near_miss_velocity_gained(_target: Node, amount: float) -> void:
	_record_highlight(&"near_miss", "NEAR MISS", clampf(amount / 220.0, 0.2, 1.0), _player_position())


func _on_recovery_opportunity_resolved(opportunity_id: StringName, data: Dictionary) -> void:
	if not bool(data.get("success", false)):
		return
	var label := String(opportunity_id).replace("_", " ").to_upper()
	_record_highlight(&"recovery", label, 1.0, data.get("resolved_position", _player_position()))


func _on_horizon_escape_scored(data: Dictionary) -> void:
	_record_highlight(&"horizon_escape", "HORIZON ESCAPE", float(data.get("intensity", 1.0)), _player_position())


func _record_highlight(kind: StringName, label: String, strength: float, position_value: Variant) -> void:
	if _captured or not enabled:
		return
	var position: Vector2 = position_value if position_value is Vector2 else _player_position()
	_highlights.append({
		"time": _run_clock,
		"position": position,
		"kind": kind,
		"label": label,
		"strength": clampf(strength, 0.0, 1.0),
	})
	while _highlights.size() > maximum_highlights:
		_highlights.remove_at(0)


func _player_position() -> Vector2:
	return _player.global_position if _is_recordable_player(_player) else Vector2.ZERO


func _on_death_lesson_generated(_lesson: String) -> void:
	if _captured or not enabled:
		return
	_capture_sample(true)
	var snapshot := _build_snapshot()
	_captured = true
	if RunProgress != null:
		if RunProgress.has_method("set_last_gravity_ghost_replay"):
			RunProgress.call("set_last_gravity_ghost_replay", snapshot)
		else:
			RunProgress.arena_flags["gravity_ghost_replay"] = snapshot
	gravity_ghost_captured.emit(snapshot.duplicate(true))


func _build_snapshot() -> Dictionary:
	var positions := PackedVector2Array()
	var times := PackedFloat32Array()
	var speeds := PackedFloat32Array()
	var danger := PackedFloat32Array()
	var projectile_pressure := PackedFloat32Array()
	var enemy_pressure := PackedFloat32Array()
	var health_pressure := PackedFloat32Array()
	var gravity_pressure := PackedFloat32Array()
	var chronological: Array[Dictionary] = []
	var first_index := (_write_index - _sample_count + _sample_capacity) % _sample_capacity if _sample_capacity > 0 else 0
	for offset in range(_sample_count):
		var sample := _samples[(first_index + offset) % _sample_capacity]
		if not sample.is_empty():
			chronological.append(sample)
	if chronological.is_empty():
		return {}

	var first_time := float(chronological[0].get("time", 0.0))
	var peak_speed := 0.0
	var peak_danger := 0.0
	var peak_danger_time := 0.0
	var peak_sample: Dictionary = {}
	var total_distance := 0.0
	var previous_position: Vector2 = chronological[0].get("position", Vector2.ZERO)
	for sample in chronological:
		var position: Vector2 = sample.get("position", previous_position)
		var speed := float(sample.get("speed", 0.0))
		var sample_time := float(sample.get("time", first_time)) - first_time
		var sample_danger := float(sample.get("danger", 0.0))
		positions.append(position)
		times.append(sample_time)
		speeds.append(speed)
		danger.append(sample_danger)
		projectile_pressure.append(float(sample.get("projectile_pressure", 0.0)))
		enemy_pressure.append(float(sample.get("enemy_pressure", 0.0)))
		health_pressure.append(float(sample.get("health_pressure", 0.0)))
		gravity_pressure.append(float(sample.get("gravity_pressure", 0.0)))
		peak_speed = maxf(peak_speed, speed)
		if sample_danger >= peak_danger:
			peak_danger = sample_danger
			peak_danger_time = sample_time
			peak_sample = sample
		total_distance += previous_position.distance_to(position)
		previous_position = position

	var incidents := _build_incident_markers(chronological, first_time, peak_sample, peak_danger, peak_danger_time)
	var dominant_pressure := _dominant_pressure_kind(peak_sample)
	var replay_highlights: Array[Dictionary] = []
	for highlight in _highlights:
		var event_time := float(highlight.get("time", 0.0))
		if event_time < first_time:
			continue
		var entry := highlight.duplicate(true)
		entry["time"] = event_time - first_time
		replay_highlights.append(entry)

	return {
		"version": 2,
		"duration": float(times[times.size() - 1]) if not times.is_empty() else 0.0,
		"positions": positions,
		"times": times,
		"speeds": speeds,
		"danger": danger,
		"projectile_pressure": projectile_pressure,
		"enemy_pressure": enemy_pressure,
		"health_pressure": health_pressure,
		"gravity_pressure": gravity_pressure,
		"highlights": replay_highlights,
		"incidents": incidents,
		"peak_speed": peak_speed,
		"peak_danger": peak_danger,
		"peak_danger_time": peak_danger_time,
		"dominant_pressure": String(dominant_pressure),
		"incident_summary": _incident_summary(dominant_pressure, peak_danger, peak_danger_time, incidents.size()),
		"distance": total_distance,
		"wave": int(RunProgress.wave_index if RunProgress != null else 0),
	}


func _build_incident_markers(
	chronological: Array[Dictionary],
	first_time: float,
	peak_sample: Dictionary,
	peak_danger: float,
	peak_danger_time: float
) -> Array[Dictionary]:
	var incidents: Array[Dictionary] = []
	var last_times: Dictionary = {}
	for sample in chronological:
		var rel_time := float(sample.get("time", first_time)) - first_time
		var position: Vector2 = sample.get("position", _player_position())
		_try_add_incident(incidents, last_times, &"health", "HULL CRITICAL", float(sample.get("health_pressure", 0.0)), 0.66, rel_time, position)
		_try_add_incident(incidents, last_times, &"gravity", "GRAVITY SPIKE", float(sample.get("gravity_pressure", 0.0)), 0.7, rel_time, position)
		_try_add_incident(incidents, last_times, &"projectiles", "PROJECTILE DENSITY", float(sample.get("projectile_pressure", 0.0)), 0.62, rel_time, position)
		_try_add_incident(incidents, last_times, &"enemies", "HOSTILE ENCIRCLEMENT", float(sample.get("enemy_pressure", 0.0)), 0.64, rel_time, position)
		if incidents.size() >= maximum_incident_markers:
			break
	if incidents.is_empty() and peak_danger > 0.28 and not peak_sample.is_empty():
		var peak_position: Vector2 = peak_sample.get("position", _player_position())
		incidents.append({
			"time": peak_danger_time,
			"position": peak_position,
			"kind": &"overall",
			"label": "PEAK PRESSURE",
			"pressure": peak_danger,
		})
	return incidents


func _try_add_incident(
	incidents: Array[Dictionary],
	last_times: Dictionary,
	kind: StringName,
	label: String,
	pressure: float,
	threshold: float,
	rel_time: float,
	position: Vector2
) -> void:
	if pressure < threshold or incidents.size() >= maximum_incident_markers:
		return
	var last_time := float(last_times.get(kind, -999.0))
	if rel_time - last_time < incident_marker_cooldown:
		return
	last_times[kind] = rel_time
	incidents.append({
		"time": rel_time,
		"position": position,
		"kind": kind,
		"label": label,
		"pressure": clampf(pressure, 0.0, 1.0),
	})


func _dominant_pressure_kind(sample: Dictionary) -> StringName:
	if sample.is_empty():
		return &"overall"
	var best_kind := &"overall"
	var best_value := -1.0
	for kind in [&"projectiles", &"enemies", &"health", &"gravity"]:
		var key := _pressure_sample_key(kind)
		var value := float(sample.get(key, 0.0))
		if value > best_value:
			best_value = value
			best_kind = kind
	return best_kind


func _pressure_sample_key(kind: StringName) -> String:
	match kind:
		&"projectiles":
			return "projectile_pressure"
		&"enemies":
			return "enemy_pressure"
		&"health":
			return "health_pressure"
		&"gravity":
			return "gravity_pressure"
	return "danger"


func _incident_summary(kind: StringName, peak_danger: float, peak_time: float, incident_count: int) -> String:
	return "%s %d%% @ %.1fs // %d INCIDENTS" % [
		_pressure_label(kind),
		int(round(peak_danger * 100.0)),
		peak_time,
		incident_count,
	]


func _pressure_label(kind: StringName) -> String:
	match kind:
		&"projectiles":
			return "PROJECTILES"
		&"enemies":
			return "HOSTILES"
		&"health":
			return "HULL"
		&"gravity":
			return "GRAVITY"
	return "PRESSURE"
