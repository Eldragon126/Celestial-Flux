extends Node2D
class_name ArenaInstabilityDirector

signal arena_instability_event_telegraphed(event_id: StringName, data: Dictionary)
signal arena_instability_event_started(event_id: StringName, data: Dictionary)
signal arena_instability_event_ended(event_id: StringName, data: Dictionary)

const TIDE_POCKET_SCENE = preload("res://Nodes/gravity_tide_pocket.tscn")

const EVENT_DEFINITIONS: Array[Dictionary] = [
	{"id": &"gravity_tide", "display": "GRAVITY TIDE", "min": 0.14, "radius": 420.0, "duration": 5.2, "telegraph": 1.1, "zone_type": 0},
	{"id": &"resonance_storm", "display": "RESONANCE STORM", "min": 0.28, "radius": 520.0, "duration": 4.4, "telegraph": 1.25, "zone_type": 4},
	{"id": &"slipstream_surge", "display": "SLIPSTREAM SURGE", "min": 0.22, "radius": 480.0, "duration": 4.8, "telegraph": 0.95, "zone_type": 1},
	{"id": &"momentum_inversion", "display": "MOMENTUM INVERSION", "min": 0.42, "radius": 460.0, "duration": 2.4, "telegraph": 1.35, "zone_type": 2},
	{"id": &"collapsing_orbit_lane", "display": "ORBIT LANE COLLAPSE", "min": 0.52, "radius": 560.0, "duration": 5.0, "telegraph": 1.2, "zone_type": 4},
	{"id": &"spacetime_fracture", "display": "SPACETIME FRACTURE", "min": 0.62, "radius": 500.0, "duration": 4.6, "telegraph": 1.45, "zone_type": 3},
]

@export var enabled: bool = true
@export var update_interval: float = 0.25
@export var base_event_interval: float = 12.5
@export var min_event_interval: float = 4.8
@export var minimum_wave: int = 2
@export var max_active_events: int = 3
@export var max_targets_per_event: int = 32
@export var spawn_min_radius: float = 420.0
@export var spawn_max_radius: float = 1180.0

var _player: Node2D = null
var _wave_director: Node = null
var _arena_manager: Node = null
var _resonance_manager: Node = null
var _scar_manager: Node = null
var _time_manager: Node = null
var _elapsed: float = 999.0
var _event_timer: float = 4.0
var _sequence: int = 0
var _active_events: Array[Dictionary] = []
var _target_buffer: Array[Node2D] = []
var _rng := RandomNumberGenerator.new()
var _hud_canvas: CanvasLayer = null
var _notice_label: Label = null


func _ready() -> void:
	add_to_group("arena_instability_director")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.seed = int(RunProgress.run_seed if RunProgress != null and RunProgress.run_seed != 0 else Time.get_ticks_msec())
	_build_hud_notice()
	call_deferred("_resolve_sources")


func _process(delta: float) -> void:
	if not enabled:
		return
	_elapsed += delta
	_event_timer -= delta
	_update_active_events(delta)
	_update_hud_notice(delta)
	if _elapsed >= maxf(update_interval, 0.05):
		_elapsed = 0.0
		_resolve_sources()
	if _event_timer <= 0.0:
		_event_timer = _next_interval()
		_try_schedule_event()


func force_instability_event(event_id: StringName) -> void:
	var definition := _definition_for_id(event_id)
	if definition.is_empty():
		return
	_schedule_definition(definition)


func get_instability_director_state() -> Dictionary:
	return {
		"active_events": _active_events.size(),
		"next_event": maxf(_event_timer, 0.0),
		"instability": _instability(),
		"wave": _current_wave(),
	}


func _try_schedule_event() -> void:
	if _player == null or _current_wave() < minimum_wave:
		return
	if _active_events.size() >= max_active_events:
		return
	var definition := _choose_definition()
	if definition.is_empty():
		return
	_schedule_definition(definition)


func _schedule_definition(definition: Dictionary) -> void:
	_sequence += 1
	var center := _event_center()
	var event := {
		"id": StringName(definition.get("id", &"gravity_tide")),
		"display": String(definition.get("display", "INSTABILITY")),
		"center": center,
		"radius": float(definition.get("radius", 420.0)),
		"duration": float(definition.get("duration", 4.0)),
		"telegraph": float(definition.get("telegraph", 1.0)),
		"age": 0.0,
		"started": false,
		"zone_type": int(definition.get("zone_type", 0)),
		"sequence": _sequence,
		"visual": _create_telegraph_visual(center, float(definition.get("radius", 420.0)), _color_for_event(StringName(definition.get("id", &"gravity_tide")))),
	}
	_active_events.append(event)
	_set_notice("%s IN %.1fs" % [String(event["display"]), float(event["telegraph"])], _color_for_event(StringName(event["id"])))
	arena_instability_event_telegraphed.emit(StringName(event["id"]), _event_payload(event))


func _update_active_events(delta: float) -> void:
	for i in range(_active_events.size() - 1, -1, -1):
		var event := _active_events[i]
		var age := float(event.get("age", 0.0)) + delta
		var telegraph := maxf(float(event.get("telegraph", 1.0)), 0.0)
		var duration := maxf(float(event.get("duration", 3.0)), 0.1)
		_update_telegraph_visual(event, age, telegraph, duration, delta)
		if not bool(event.get("started", false)) and age >= telegraph:
			event["started"] = true
			_execute_event(event)
			arena_instability_event_started.emit(StringName(event["id"]), _event_payload(event))
		event["age"] = age
		_active_events[i] = event
		if age >= telegraph + duration:
			_free_event_visual(event)
			arena_instability_event_ended.emit(StringName(event["id"]), _event_payload(event))
			_active_events.remove_at(i)


func _event_payload(event: Dictionary) -> Dictionary:
	return {
		"id": StringName(event.get("id", &"gravity_tide")),
		"display": String(event.get("display", "INSTABILITY")),
		"center": event.get("center", global_position),
		"radius": float(event.get("radius", 420.0)),
		"duration": float(event.get("duration", 4.0)),
		"telegraph": float(event.get("telegraph", 1.0)),
		"age": float(event.get("age", 0.0)),
		"started": bool(event.get("started", false)),
		"zone_type": int(event.get("zone_type", 0)),
		"sequence": int(event.get("sequence", 0)),
	}


func _execute_event(event: Dictionary) -> void:
	var event_id := StringName(event.get("id", &"gravity_tide"))
	match event_id:
		&"gravity_tide":
			_spawn_tide(event, GravityTidePocket.TideMode.COMPRESSION)
		&"resonance_storm":
			_create_resonance_cluster(event)
		&"slipstream_surge":
			_spawn_tide(event, GravityTidePocket.TideMode.SLIPSTREAM)
			_create_lane_zones(event, GravityResonanceManager.ZoneType.SLIPSTREAM)
		&"momentum_inversion":
			_create_zone(event, GravityResonanceManager.ZoneType.INVERSION)
			_apply_momentum_inversion(event)
		&"collapsing_orbit_lane":
			_create_lane_zones(event, GravityResonanceManager.ZoneType.HARMONIC_ORBIT)
		&"spacetime_fracture":
			_create_zone(event, GravityResonanceManager.ZoneType.TEMPORAL_SCAR)
			_create_fracture_scar(event)
		_:
			_create_zone(event, int(event.get("zone_type", 0)))


func _spawn_tide(event: Dictionary, mode: int) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var pocket := TIDE_POCKET_SCENE.instantiate()
	if pocket.has_method("configure"):
		pocket.call(
			"configure",
			mode,
			float(event.get("radius", 420.0)) * 0.72,
			float(event.get("duration", 4.0)),
			lerpf(620.0, 1180.0, _instability())
		)
	root.add_child(pocket)
	var pocket_2d := pocket as Node2D
	if pocket_2d != null:
		pocket_2d.global_position = event.get("center", global_position)


func _create_resonance_cluster(event: Dictionary) -> void:
	var center: Vector2 = event.get("center", global_position)
	var radius := float(event.get("radius", 500.0))
	for i in range(3):
		var angle := TAU * float(i) / 3.0 + float(event.get("sequence", 0)) * 0.31
		var zone_type = [GravityResonanceManager.ZoneType.COMPRESSION, GravityResonanceManager.ZoneType.SLIPSTREAM, GravityResonanceManager.ZoneType.HARMONIC_ORBIT][i]
		_create_manual_zone(center + Vector2.RIGHT.rotated(angle) * radius * 0.32, radius * 0.52, zone_type, 0.58 + _instability() * 0.26, float(event.get("duration", 4.0)))


func _create_lane_zones(event: Dictionary, zone_type: int) -> void:
	var center: Vector2 = event.get("center", global_position)
	var axis := _player_axis()
	var radius := float(event.get("radius", 500.0))
	for offset_index in [-1, 0, 1]:
		_create_manual_zone(center + axis * float(offset_index) * radius * 0.42, radius * 0.34, zone_type, 0.52 + _instability() * 0.3, float(event.get("duration", 4.0)))


func _create_zone(event: Dictionary, zone_type: int) -> void:
	_create_manual_zone(
		event.get("center", global_position),
		float(event.get("radius", 420.0)) * 0.58,
		zone_type,
		0.58 + _instability() * 0.26,
		float(event.get("duration", 4.0))
	)


func _create_manual_zone(position: Vector2, radius: float, zone_type: int, intensity: float, duration: float) -> void:
	if _resonance_manager != null and _resonance_manager.has_method("create_manual_resonance_zone"):
		_resonance_manager.call("create_manual_resonance_zone", position, radius, zone_type, intensity, duration)


func _create_fracture_scar(event: Dictionary) -> void:
	if _scar_manager == null or not _scar_manager.has_method("create_gravity_scar"):
		return
	_scar_manager.call(
		"create_gravity_scar",
		event.get("center", global_position),
		float(event.get("radius", 420.0)) * 0.68,
		GravityScarManager.ScarType.TEMPORAL_RIP,
		0.62 + _instability() * 0.26,
		float(event.get("duration", 4.0)) + 8.0,
		&"arena_instability"
	)


func _apply_momentum_inversion(event: Dictionary) -> void:
	var center: Vector2 = event.get("center", global_position)
	var radius := float(event.get("radius", 420.0))
	_fill_targets(center, radius)
	for target in _target_buffer:
		var velocity := _body_velocity(target)
		if velocity.length_squared() <= 1.0:
			continue
		CombatStatus.add_velocity(target, -velocity.normalized() * minf(velocity.length() * 0.46, 620.0))
		if _time_manager != null and _time_manager.has_method("apply_local_slow_to_target") and not target.is_in_group("Player"):
			_time_manager.call("apply_local_slow_to_target", target, 0.72, 0.42)


func _fill_targets(center: Vector2, radius: float) -> void:
	_target_buffer.clear()
	var groups: Array[StringName] = [&"Player", &"enemies", &"wave_enemy", &"bosses", &"Projectiles", &"enemy_projectiles"]
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_targets_in_radius(groups, center, radius, max_targets_per_event, true, _target_buffer)
		return
	var radius_sq := radius * radius
	for group_name in groups:
		for node in get_tree().get_nodes_in_group(group_name):
			var node_2d := node as Node2D
			if node_2d == null or node_2d.is_queued_for_deletion():
				continue
			if node_2d.global_position.distance_squared_to(center) <= radius_sq:
				_target_buffer.append(node_2d)
				if _target_buffer.size() >= max_targets_per_event:
					return


func _choose_definition() -> Dictionary:
	var value := _instability()
	var candidates: Array[Dictionary] = []
	for definition in EVENT_DEFINITIONS:
		if value >= float(definition.get("min", 0.0)):
			candidates.append(definition)
	if candidates.is_empty():
		return {}
	var seed := int(RunProgress.run_seed if RunProgress != null else 0)
	var index := absi(hash("%d:%d:%d:%d" % [seed, _current_wave(), _sequence, int(value * 1000.0)])) % candidates.size()
	return candidates[index]


func _definition_for_id(event_id: StringName) -> Dictionary:
	for definition in EVENT_DEFINITIONS:
		if StringName(definition.get("id", &"")) == event_id:
			return definition
	return {}


func _event_center() -> Vector2:
	if _player == null:
		return global_position
	var axis := _player_axis()
	var side := axis.orthogonal() * (1.0 if (_sequence % 2) == 0 else -1.0)
	var distance := lerpf(spawn_min_radius, spawn_max_radius, clampf(_instability(), 0.0, 1.0))
	return _player.global_position + axis * distance * 0.6 + side * distance * 0.32


func _player_axis() -> Vector2:
	if _player == null:
		return Vector2.RIGHT
	var velocity := _body_velocity(_player)
	if velocity.length_squared() > 1.0:
		return velocity.normalized()
	return -_player.transform.x.normalized()


func _body_velocity(body: Node) -> Vector2:
	var velocity: Variant = body.get("velocity")
	if velocity is Vector2:
		return velocity
	var linear_velocity: Variant = body.get("linear_velocity")
	if linear_velocity is Vector2:
		return linear_velocity
	return Vector2.ZERO


func _next_interval() -> float:
	var pressure := clampf(_instability(), 0.0, 1.0)
	return maxf(base_event_interval * lerpf(1.15, 0.48, pressure), min_event_interval)


func _instability() -> float:
	if _arena_manager == null or not is_instance_valid(_arena_manager):
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
	_wave_director = root.find_child("WaveDirector", true, false)
	_arena_manager = root.find_child("ArenaDestabilizationManager", true, false)
	_resonance_manager = root.find_child("GravityResonanceManager", true, false)
	_scar_manager = root.find_child("GravityScarManager", true, false)
	_time_manager = root.find_child("TimeDilationManager", true, false)


func _create_telegraph_visual(center: Vector2, radius: float, color: Color) -> Dictionary:
	var root := Node2D.new()
	root.name = "ArenaInstabilityTelegraph"
	root.global_position = center
	root.z_index = 24
	add_child(root)

	var ring := Line2D.new()
	ring.name = "InstabilityRing"
	ring.closed = true
	ring.antialiased = true
	ring.width = 2.8
	ring.default_color = Color(color.r, color.g, color.b, 0.62)
	ring.points = _circle_points(56, radius)
	root.add_child(ring)

	var axis := Line2D.new()
	axis.name = "InstabilityAxis"
	axis.antialiased = true
	axis.width = 2.2
	axis.default_color = Color.WHITE
	axis.modulate.a = 0.5
	axis.points = PackedVector2Array([Vector2(-radius, 0.0), Vector2(radius, 0.0)])
	root.add_child(axis)
	return {"root": root, "ring": ring, "axis": axis, "radius": radius}


func _update_telegraph_visual(event: Dictionary, age: float, telegraph: float, duration: float, delta: float) -> void:
	var visual: Dictionary = event.get("visual", {})
	var root := visual.get("root") as Node2D
	if root == null or not is_instance_valid(root):
		return
	var t := clampf(age / maxf(telegraph + duration, 0.1), 0.0, 1.0)
	var telegraph_t := clampf(age / maxf(telegraph, 0.1), 0.0, 1.0)
	root.rotation += delta * lerpf(0.3, 1.4, _instability())
	root.modulate.a = minf(1.0, telegraph_t * 1.4) * pow(1.0 - t, 0.58)
	var ring := visual.get("ring") as Line2D
	if ring != null:
		ring.width = lerpf(1.6, 4.4, sin(age * 7.0) * 0.5 + 0.5)


func _free_event_visual(event: Dictionary) -> void:
	var visual: Dictionary = event.get("visual", {})
	var root := visual.get("root") as Node
	if root != null and is_instance_valid(root) and not root.is_queued_for_deletion():
		root.queue_free()


func _build_hud_notice() -> void:
	_hud_canvas = CanvasLayer.new()
	_hud_canvas.name = "ArenaInstabilityHUD"
	_hud_canvas.layer = 67
	add_child(_hud_canvas)
	_notice_label = Label.new()
	_notice_label.name = "ArenaInstabilityNotice"
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.offset_left = -260.0
	_notice_label.offset_right = 260.0
	_notice_label.offset_top = 146.0
	_notice_label.offset_bottom = 174.0
	_notice_label.anchor_left = 0.5
	_notice_label.anchor_right = 0.5
	_notice_label.text = ""
	_notice_label.modulate.a = 0.0
	_hud_canvas.add_child(_notice_label)


func _set_notice(text: String, color: Color) -> void:
	if _notice_label == null:
		return
	_notice_label.text = text
	_notice_label.modulate = Color(color.r, color.g, color.b, 1.0)


func _update_hud_notice(delta: float) -> void:
	if _notice_label == null or _notice_label.text.is_empty():
		return
	_notice_label.modulate.a = move_toward(_notice_label.modulate.a, 0.0, delta * 0.38)
	if _notice_label.modulate.a <= 0.02:
		_notice_label.text = ""


func _color_for_event(event_id: StringName) -> Color:
	match event_id:
		&"slipstream_surge":
			return Color(0.28, 1.0, 0.78, 1.0)
		&"momentum_inversion":
			return Color(1.0, 0.34, 0.16, 1.0)
		&"spacetime_fracture":
			return Color(0.78, 0.38, 1.0, 1.0)
		&"collapsing_orbit_lane":
			return Color(1.0, 0.82, 0.26, 1.0)
		&"resonance_storm":
			return Color(0.52, 0.86, 1.0, 1.0)
	return Color(0.3, 0.76, 1.0, 1.0)


func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(maxi(count, 3)):
		var angle := TAU * float(i) / float(maxi(count, 3))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
