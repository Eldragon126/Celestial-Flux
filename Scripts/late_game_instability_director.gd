extends Node
class_name LateGameInstabilityDirector
## Capped impossible-physics events for late-game collapse.

signal impossible_event_started(event_id: StringName, data: Dictionary)
signal impossible_event_resolved(event_id: StringName, data: Dictionary)

@export var enabled: bool = true
@export var minimum_wave: int = 26
@export var event_interval: float = 13.0
@export var max_events_per_wave: int = 2
@export var max_targets_per_event: int = 28
@export var event_radius: float = 620.0
@export var resonance_duration: float = 3.2
@export var local_slow_duration: float = 0.7

var _player: Node2D = null
var _arena_manager: Node = null
var _resonance_manager: Node = null
var _time_manager: Node = null
var _wave_director: Node = null
var _current_wave: int = 0
var _timer: float = 0.0
var _events_this_wave: int = 0


func _ready() -> void:
	add_to_group("late_game_instability_director")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_timer = event_interval
	call_deferred("_bootstrap")


func _process(delta: float) -> void:
	if not enabled or _current_wave < minimum_wave:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = _next_interval()
	if _events_this_wave >= max_events_per_wave:
		return
	_events_this_wave += 1
	_start_event(_event_for_wave())


func _bootstrap() -> void:
	_resolve_sources()
	_connect_wave_director()


func _resolve_sources() -> void:
	var root := get_tree().current_scene
	_player = get_tree().get_first_node_in_group("Player") as Node2D
	if root == null:
		return
	_arena_manager = root.find_child("ArenaDestabilizationManager", true, false)
	_resonance_manager = root.find_child("GravityResonanceManager", true, false)
	_time_manager = root.find_child("TimeDilationManager", true, false)
	_wave_director = root.find_child("WaveDirector", true, false)
	if _wave_director != null and _wave_director.has_method("get_current_wave"):
		_current_wave = int(_wave_director.call("get_current_wave"))


func _connect_wave_director() -> void:
	if _wave_director == null:
		return
	_connect_once(_wave_director, &"regular_wave", Callable(self, "_on_wave_started"))
	_connect_once(_wave_director, &"boss_wave", Callable(self, "_on_wave_started"))
	_connect_once(_wave_director, &"wave_cleared", Callable(self, "_on_wave_cleared"))


func _connect_once(source: Node, signal_name: StringName, callable: Callable) -> void:
	if source == null or not source.has_signal(signal_name):
		return
	if not source.is_connected(signal_name, callable):
		source.connect(signal_name, callable)


func _on_wave_started() -> void:
	if _wave_director != null and _wave_director.has_method("get_current_wave"):
		_current_wave = int(_wave_director.call("get_current_wave"))
	_events_this_wave = 0


func _on_wave_cleared(wave: int) -> void:
	_current_wave = wave
	_events_this_wave = 0


func _start_event(event_id: StringName) -> void:
	_resolve_sources()
	var data := {
		"event_id": event_id,
		"wave": _current_wave,
		"position": _event_center(),
		"radius": event_radius,
	}
	impossible_event_started.emit(event_id, data)
	match event_id:
		&"resonance_overfold":
			_spawn_overfold(data)
		&"temporal_splinter":
			_apply_temporal_splinter(data)
		&"gravity_braid":
			_apply_gravity_braid(data)
		_:
			_spawn_collapse_lane(data)
	impossible_event_resolved.emit(event_id, data)


func _spawn_overfold(data: Dictionary) -> void:
	var center: Vector2 = data.get("position", Vector2.ZERO)
	_create_zone(center, 360.0, GravityResonanceManager.ZoneType.HARMONIC_ORBIT, 0.72)
	_create_zone(center + Vector2.RIGHT * 260.0, 260.0, GravityResonanceManager.ZoneType.INVERSION, 0.58)
	_create_zone(center - Vector2.RIGHT * 260.0, 260.0, GravityResonanceManager.ZoneType.TEMPORAL_SCAR, 0.62)


func _apply_temporal_splinter(data: Dictionary) -> void:
	if _time_manager == null or not _time_manager.has_method("apply_local_slow_to_target"):
		return
	var center: Vector2 = data.get("position", Vector2.ZERO)
	var affected := 0
	for target in _nearby_targets(center, event_radius):
		_time_manager.call("apply_local_slow_to_target", target, 0.42, local_slow_duration)
		affected += 1
		if affected >= max_targets_per_event:
			return


func _apply_gravity_braid(_data: Dictionary) -> void:
	if _arena_manager == null or not _arena_manager.has_method("force_arena_event"):
		return
	_arena_manager.call("force_arena_event", &"tide_slipstream")
	_arena_manager.call("force_arena_event", &"tide_inversion")


func _spawn_collapse_lane(data: Dictionary) -> void:
	var center: Vector2 = data.get("position", Vector2.ZERO)
	var axis := _player_velocity_axis().orthogonal()
	for step in [-1, 0, 1]:
		_create_zone(
			center + axis * float(step) * 240.0,
			220.0,
			GravityResonanceManager.ZoneType.COMPRESSION,
			0.64
		)


func _create_zone(position: Vector2, radius: float, zone_type: int, intensity: float) -> void:
	if _resonance_manager == null or not _resonance_manager.has_method("create_manual_resonance_zone"):
		return
	_resonance_manager.call(
		"create_manual_resonance_zone",
		position,
		radius,
		zone_type,
		intensity,
		resonance_duration
	)


func _nearby_targets(center: Vector2, radius: float) -> Array[Node]:
	var targets: Array[Node] = []
	var seen := {}
	for group_name in [&"enemies", &"wave_enemy", &"bosses", &"enemy_projectiles"]:
		for node in get_tree().get_nodes_in_group(group_name):
			var node_2d := node as Node2D
			if node_2d == null or seen.has(node.get_instance_id()):
				continue
			if node_2d.global_position.distance_squared_to(center) > radius * radius:
				continue
			seen[node.get_instance_id()] = true
			targets.append(node)
			if targets.size() >= max_targets_per_event:
				return targets
	return targets


func _event_center() -> Vector2:
	if _player == null:
		return Vector2.ZERO
	return _player.global_position + _player_velocity_axis() * 280.0


func _player_velocity_axis() -> Vector2:
	if _player == null:
		return Vector2.RIGHT
	var velocity: Variant = _player.get("velocity")
	if velocity is Vector2 and velocity.length_squared() > 1.0:
		return velocity.normalized()
	return Vector2.RIGHT.rotated(float(_current_wave) * 0.37)


func _event_for_wave() -> StringName:
	var seed_value := int(RunProgress.run_seed if RunProgress != null else 0)
	var roll := absi(int(hash("%d:%d:%d" % [seed_value, _current_wave, _events_this_wave]))) % 4
	var events: Array[StringName] = [
		&"resonance_overfold",
		&"temporal_splinter",
		&"gravity_braid",
		&"collapse_lane",
	]
	return events[roll]


func _next_interval() -> float:
	var pressure := clampf(float(maxi(_current_wave - minimum_wave, 0)) / 10.0, 0.0, 1.0)
	return maxf(event_interval * lerpf(1.1, 0.68, pressure), 5.0)
