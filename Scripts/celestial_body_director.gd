extends Node2D
class_name CelestialBodyDirector

signal celestial_event_started(event_id: StringName, data: Dictionary)
signal celestial_body_spawned(body: DynamicCelestialBody, data: Dictionary)
signal celestial_body_merged(primary: DynamicCelestialBody, absorbed_id: int, data: Dictionary)
signal celestial_body_split(parent_id: int, children: Array, data: Dictionary)

const DYNAMIC_BODY_SCENE = preload("res://Nodes/dynamic_celestial_body.tscn")

@export var enabled: bool = true
@export var minimum_wave: int = 3
@export var spawn_interval: float = 16.0
@export var min_spawn_interval: float = 7.0
@export var max_active_bodies: int = 9
@export var max_targets_per_field_tick: int = 42
@export var field_tick_interval: float = 0.09
@export var pair_check_interval: float = 0.45
@export var spawn_min_radius: float = 760.0
@export var spawn_max_radius: float = 1600.0

var _player: Node2D = null
var _arena_manager: Node = null
var _wave_director: Node = null
var _time_manager: Node = null
var _resonance_manager: Node = null
var _spawn_timer: float = 6.0
var _field_elapsed: float = 0.0
var _pair_elapsed: float = 999.0
var _sequence: int = 0
var _bodies: Array[DynamicCelestialBody] = []
var _anchors: Array[Dictionary] = []
var _targets: Array[Node2D] = []


func _ready() -> void:
	add_to_group("celestial_body_director")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	call_deferred("_resolve_sources")


func _process(delta: float) -> void:
	if not enabled:
		return
	_resolve_sources()
	_cleanup()
	_update_anchors(delta)
	_spawn_timer -= delta
	_pair_elapsed += delta
	_field_elapsed += delta
	if _spawn_timer <= 0.0:
		_spawn_timer = _next_spawn_interval()
		_try_start_celestial_event()
	if _pair_elapsed >= pair_check_interval:
		_pair_elapsed = 0.0
		_resolve_body_relationships()
	if _field_elapsed >= field_tick_interval:
		var field_delta := _field_elapsed
		_field_elapsed = 0.0
		_apply_celestial_fields(field_delta)


func force_celestial_event(event_id: StringName) -> void:
	_start_event(event_id)


func get_celestial_debug_state() -> Dictionary:
	return {
		"active_bodies": _bodies.size(),
		"anchors": _anchors.size(),
		"next_event": maxf(_spawn_timer, 0.0),
		"wave": _current_wave(),
	}


func _try_start_celestial_event() -> void:
	if _player == null or _current_wave() < minimum_wave:
		return
	if _bodies.size() >= max_active_bodies:
		return
	_start_event(_choose_event())


func _start_event(event_id: StringName) -> void:
	_sequence += 1
	var data := {"event_id": event_id, "wave": _current_wave(), "sequence": _sequence}
	match event_id:
		&"binary_system":
			_spawn_binary_system(data)
		&"rogue_planet":
			_spawn_rogue_planet(data)
		&"wandering_singularity":
			_spawn_wandering_singularity(data)
		&"orbital_structure":
			_spawn_orbital_structure(data)
		_:
			_spawn_rogue_planet(data)
	celestial_event_started.emit(event_id, data)


func _spawn_binary_system(data: Dictionary) -> void:
	var anchor := Node2D.new()
	anchor.name = "DynamicCelestialBarycenter"
	anchor.global_position = _spawn_position()
	add_child(anchor)
	_anchors.append({"node": anchor, "velocity": _orbit_axis().orthogonal() * 36.0, "age": 0.0, "lifetime": 36.0})
	var base_angle := float(data.get("sequence", 0)) * 0.72
	var body_a := _spawn_body(DynamicCelestialBody.BodyKind.PLANET, anchor.global_position, 180000.0, 78.0, 34.0, Vector2.ZERO, anchor, 155.0, base_angle, 0.58)
	var body_b := _spawn_body(DynamicCelestialBody.BodyKind.MOON, anchor.global_position, 94000.0, 48.0, 34.0, Vector2.ZERO, anchor, 155.0, base_angle + PI, -0.58)
	celestial_body_split.emit(anchor.get_instance_id(), [body_a, body_b], {"source": &"binary_system"})


func _spawn_rogue_planet(data: Dictionary) -> void:
	var position := _spawn_position()
	var drift := (_player.global_position - position).normalized().rotated(0.34) * 82.0
	_spawn_body(DynamicCelestialBody.BodyKind.PLANET, position, 210000.0, 86.0, 30.0, drift)


func _spawn_wandering_singularity(data: Dictionary) -> void:
	var position := _spawn_position()
	var drift := _orbit_axis().rotated(0.7) * 74.0
	_spawn_body(DynamicCelestialBody.BodyKind.SINGULARITY, position, 260000.0, 58.0, 24.0, drift)
	if _resonance_manager != null and _resonance_manager.has_method("create_manual_resonance_zone"):
		_resonance_manager.call("create_manual_resonance_zone", position, 280.0, GravityResonanceManager.ZoneType.COMPRESSION, 0.62, 4.0)


func _spawn_orbital_structure(data: Dictionary) -> void:
	var anchor := Node2D.new()
	anchor.name = "DynamicOrbitalStructureAnchor"
	anchor.global_position = _spawn_position()
	add_child(anchor)
	_anchors.append({"node": anchor, "velocity": _orbit_axis() * 24.0, "age": 0.0, "lifetime": 42.0})
	for i in range(3):
		_spawn_body(
			DynamicCelestialBody.BodyKind.ORBITAL_STRUCTURE,
			anchor.global_position,
			68000.0,
			38.0,
			38.0,
			Vector2.ZERO,
			anchor,
			210.0,
			TAU * float(i) / 3.0,
			0.44
		)


func _spawn_body(
	kind: int,
	position: Vector2,
	mass: float,
	radius: float,
	lifetime: float,
	drift: Vector2,
	anchor: Node2D = null,
	orbit_radius: float = 0.0,
	orbit_angle: float = 0.0,
	angular_velocity: float = 0.0
) -> DynamicCelestialBody:
	if _bodies.size() >= max_active_bodies:
		_remove_oldest_body()
	var body := DYNAMIC_BODY_SCENE.instantiate() as DynamicCelestialBody
	body.configure(kind, mass, radius, lifetime, drift, anchor, orbit_radius, orbit_angle, angular_velocity)
	add_child(body)
	body.global_position = position if anchor == null else anchor.global_position + Vector2.RIGHT.rotated(orbit_angle) * orbit_radius
	body.celestial_body_destabilized.connect(Callable(self, "_on_body_destabilized"))
	body.celestial_body_collected.connect(Callable(self, "_on_body_collected"))
	_bodies.append(body)
	celestial_body_spawned.emit(body, body.get_celestial_state())
	return body


func _resolve_body_relationships() -> void:
	for i in range(_bodies.size() - 1, -1, -1):
		var a := _bodies[i]
		if a == null or not is_instance_valid(a) or a.is_queued_for_deletion():
			continue
		for j in range(i - 1, -1, -1):
			var b := _bodies[j]
			if b == null or not is_instance_valid(b) or b.is_queued_for_deletion():
				continue
			var merge_distance := maxf(a.body_radius, b.body_radius) * 0.72
			if a.global_position.distance_to(b.global_position) > merge_distance:
				continue
			var primary := a if absf(a.mass) >= absf(b.mass) else b
			var absorbed := b if primary == a else a
			var absorbed_id := absorbed.get_instance_id()
			primary.absorb_body(absorbed)
			celestial_body_merged.emit(primary, absorbed_id, primary.get_celestial_state())
			return


func _on_body_destabilized(body: DynamicCelestialBody, data: Dictionary) -> void:
	if body == null or not is_instance_valid(body):
		return
	if body.kind == DynamicCelestialBody.BodyKind.SINGULARITY:
		_split_body(body, 2, data)
	elif body.kind == DynamicCelestialBody.BodyKind.PLANET and absf(body.mass) > 260000.0:
		_split_body(body, 2, data)


func _split_body(body: DynamicCelestialBody, count: int, data: Dictionary) -> void:
	var children: Array = []
	var parent_id := body.get_instance_id()
	for i in range(count):
		var angle := TAU * float(i) / float(maxi(count, 1)) + float(_sequence) * 0.19
		var child := _spawn_body(
			DynamicCelestialBody.BodyKind.MOON if body.kind != DynamicCelestialBody.BodyKind.SINGULARITY else DynamicCelestialBody.BodyKind.ANOMALY,
			body.global_position + Vector2.RIGHT.rotated(angle) * body.body_radius,
			body.mass / float(count + 1),
			body.body_radius * 0.48,
			body.lifetime * 0.52,
			Vector2.RIGHT.rotated(angle) * 140.0
		)
		children.append(child)
	_queue_free_if_valid(body)
	celestial_body_split.emit(parent_id, children, data)


func _on_body_collected(body: DynamicCelestialBody, other: Node) -> void:
	if other is DynamicCelestialBody:
		_resolve_body_relationships()


func _apply_celestial_fields(delta: float) -> void:
	if _bodies.is_empty():
		return
	for body in _bodies:
		if body == null or not is_instance_valid(body):
			continue
		_fill_targets(body.global_position, maxf(body.body_radius * 5.2, 360.0))
		for target in _targets:
			if target == body:
				continue
			var offset := body.global_position - target.global_position
			var distance_sq := maxf(offset.length_squared(), body.body_radius * body.body_radius)
			if distance_sq <= 1.0:
				continue
			var direction := offset.normalized()
			var acceleration := direction * 120.0 * body.mass / distance_sq
			if body.kind == DynamicCelestialBody.BodyKind.ANOMALY:
				acceleration = -acceleration
			if body.kind == DynamicCelestialBody.BodyKind.ORBITAL_STRUCTURE:
				acceleration = direction.orthogonal() * acceleration.length()
			CombatStatus.add_velocity(target, acceleration * delta)


func _fill_targets(center: Vector2, radius: float) -> void:
	_targets.clear()
	var groups: Array[StringName] = [&"Player", &"enemies", &"wave_enemy", &"bosses", &"Projectiles", &"enemy_projectiles"]
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_targets_in_radius(groups, center, radius, max_targets_per_field_tick, true, _targets)
		return
	var radius_sq := radius * radius
	for group_name in groups:
		for node in get_tree().get_nodes_in_group(group_name):
			var node_2d := node as Node2D
			if node_2d == null or node_2d.global_position.distance_squared_to(center) > radius_sq:
				continue
			_targets.append(node_2d)
			if _targets.size() >= max_targets_per_field_tick:
				return


func _update_anchors(delta: float) -> void:
	for i in range(_anchors.size() - 1, -1, -1):
		var entry := _anchors[i]
		var node := entry.get("node") as Node2D
		if node == null or not is_instance_valid(node):
			_anchors.remove_at(i)
			continue
		var age := float(entry.get("age", 0.0)) + delta
		var lifetime := float(entry.get("lifetime", 30.0))
		node.global_position += Vector2(entry.get("velocity", Vector2.ZERO)) * delta
		entry["age"] = age
		_anchors[i] = entry
		if age >= lifetime:
			_queue_free_if_valid(node)
			_anchors.remove_at(i)


func _choose_event() -> StringName:
	var events: Array[StringName] = [&"rogue_planet", &"binary_system"]
	if _current_wave() >= 7:
		events.append(&"wandering_singularity")
	if _instability() >= 0.42:
		events.append(&"orbital_structure")
	var seed := int(RunProgress.run_seed if RunProgress != null else 0)
	return events[absi(hash("%d:%d:%d:%d" % [seed, _current_wave(), _sequence, int(_instability() * 1000.0)])) % events.size()]


func _spawn_position() -> Vector2:
	if _player == null:
		return global_position
	var angle := float(absi(hash("%d:%d" % [_sequence, _current_wave()])) % 1000) / 1000.0 * TAU
	var radius := lerpf(spawn_min_radius, spawn_max_radius, clampf(_instability(), 0.0, 1.0))
	return _player.global_position + Vector2.RIGHT.rotated(angle) * radius


func _orbit_axis() -> Vector2:
	if _player == null:
		return Vector2.RIGHT
	var velocity: Variant = _player.get("velocity")
	if velocity is Vector2 and velocity.length_squared() > 1.0:
		return velocity.normalized()
	return Vector2.RIGHT.rotated(float(_sequence) * 0.47)


func _remove_oldest_body() -> void:
	if _bodies.is_empty():
		return
	var body = _bodies.pop_front()
	_queue_free_if_valid(body)


func _cleanup() -> void:
	for i in range(_bodies.size() - 1, -1, -1):
		var body := _bodies[i]
		if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
			_bodies.remove_at(i)


func _queue_free_if_valid(node: Node) -> void:
	if node != null and is_instance_valid(node) and not node.is_queued_for_deletion():
		node.queue_free()


func _next_spawn_interval() -> float:
	return maxf(spawn_interval * lerpf(1.1, 0.52, _instability()), min_spawn_interval)


func _instability() -> float:
	if _arena_manager == null:
		return 0.0
	var value: Variant = _arena_manager.get("instability")
	if value is float or value is int:
		return clampf(float(value), 0.0, 1.0)
	return 0.0


func _current_wave() -> int:
	if _wave_director != null and _wave_director.has_method("get_current_wave"):
		return int(_wave_director.call("get_current_wave"))
	return int(RunProgress.wave_index if RunProgress != null else 0)


func _resolve_sources() -> void:
	var root := get_tree().current_scene
	_player = get_tree().get_first_node_in_group("Player") as Node2D
	if root == null:
		return
	_arena_manager = root.find_child("ArenaDestabilizationManager", true, false)
	_wave_director = root.find_child("WaveDirector", true, false)
	_time_manager = root.find_child("TimeDilationManager", true, false)
	_resonance_manager = root.find_child("GravityResonanceManager", true, false)
