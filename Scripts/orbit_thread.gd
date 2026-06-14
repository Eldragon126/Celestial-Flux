extends Node2D
class_name OrbitThread

signal thread_disabled(thread: OrbitThread, reason: StringName)

const ANCHOR_SCRIPT := preload("res://Scripts/orbit_thread_anchor.gd")
const THREAD_TARGET_GROUPS: Array[StringName] = [&"Player", &"enemies", &"wave_enemy", &"bosses", &"Projectiles", &"enemy_projectiles", &"player_projectiles"]

@export var thread_duration: float = 5.4
@export var telegraph_time: float = 0.95
@export var pull_strength: float = 760.0
@export var max_affected_bodies: int = 28
@export var anchor_health: float = 34.0
@export var effect_width: float = 82.0

var anchor_a_position: Vector2 = Vector2.ZERO
var anchor_b_position: Vector2 = Vector2.RIGHT * 360.0

var _age: float = 0.0
var _active: bool = false
var _disabled: bool = false
var _line: Line2D = null
var _telegraph_line: Line2D = null
var _anchor_a: OrbitThreadAnchor = null
var _anchor_b: OrbitThreadAnchor = null
var _targets: Array[Node2D] = []
var _query_seen_ids: Dictionary = {}


func configure(
	start_position: Vector2,
	end_position: Vector2,
	new_duration: float,
	new_telegraph_time: float,
	new_pull_strength: float,
	new_max_affected_bodies: int,
	new_anchor_health: float
) -> void:
	anchor_a_position = start_position
	anchor_b_position = end_position
	thread_duration = maxf(new_duration, 0.5)
	telegraph_time = maxf(new_telegraph_time, 0.1)
	pull_strength = new_pull_strength
	max_affected_bodies = maxi(new_max_affected_bodies, 1)
	anchor_health = maxf(new_anchor_health, 1.0)


func _ready() -> void:
	_build_thread_nodes()
	set_process(true)
	set_physics_process(true)


func _exit_tree() -> void:
	_disabled = true


func _process(delta: float) -> void:
	if _disabled:
		return
	_age += delta
	if not _anchors_valid():
		disable_thread(&"anchor_broken")
		return
	if not _active and _age >= telegraph_time:
		_active = true
	if _age >= telegraph_time + thread_duration:
		disable_thread(&"expired")
		return
	_update_visuals(delta)


func _physics_process(delta: float) -> void:
	if _disabled or not _active:
		return
	_apply_thread_pull(delta)


func disable_thread(reason: StringName) -> void:
	if _disabled:
		return
	_disabled = true
	thread_disabled.emit(self, reason)
	queue_free()


func _build_thread_nodes() -> void:
	_line = Line2D.new()
	_line.name = "ActiveOrbitThread"
	_line.z_index = 22
	_line.antialiased = true
	_line.width = 5.0
	_line.default_color = Settings.apply_readability_color(Color(0.1, 0.92, 1.0, 0.0))
	_line.points = PackedVector2Array([anchor_a_position, anchor_b_position])
	add_child(_line)

	_telegraph_line = Line2D.new()
	_telegraph_line.name = "OrbitThreadTelegraph"
	_telegraph_line.z_index = 23
	_telegraph_line.antialiased = true
	_telegraph_line.width = 3.0
	_telegraph_line.default_color = Settings.apply_readability_color(Color(1.0, 0.72, 0.2, 0.34))
	_telegraph_line.points = PackedVector2Array([anchor_a_position, anchor_b_position])
	add_child(_telegraph_line)

	_anchor_a = ANCHOR_SCRIPT.new() as OrbitThreadAnchor
	_anchor_a.name = "OrbitThreadAnchorA"
	_anchor_a.configure(anchor_health, Color(0.12, 0.95, 1.0, 1.0))
	add_child(_anchor_a)
	_anchor_a.global_position = anchor_a_position
	_anchor_a.anchor_destroyed.connect(_on_anchor_destroyed)

	_anchor_b = ANCHOR_SCRIPT.new() as OrbitThreadAnchor
	_anchor_b.name = "OrbitThreadAnchorB"
	_anchor_b.configure(anchor_health, Color(0.12, 0.95, 1.0, 1.0))
	add_child(_anchor_b)
	_anchor_b.global_position = anchor_b_position
	_anchor_b.anchor_destroyed.connect(_on_anchor_destroyed)


func _update_visuals(delta: float) -> void:
	var start_position := _anchor_a.global_position
	var end_position := _anchor_b.global_position
	if _line != null:
		_line.points = PackedVector2Array([start_position, end_position])
	if _telegraph_line != null:
		_telegraph_line.points = PackedVector2Array([start_position, end_position])

	var telegraph_ratio := clampf(_age / maxf(telegraph_time, 0.001), 0.0, 1.0)
	var active_ratio := clampf((_age - telegraph_time) / maxf(thread_duration, 0.001), 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.026)
	if _telegraph_line != null:
		_telegraph_line.visible = not _active
		_telegraph_line.width = 2.0 + telegraph_ratio * 5.0
		_telegraph_line.default_color = Settings.apply_readability_color(Color(1.0, 0.72, 0.2, Settings.world_visual_alpha(0.14 + 0.32 * maxf(telegraph_ratio, pulse), 0.34)))
	if _line != null:
		_line.visible = _active
		_line.width = 5.0 + pulse * 3.2
		var fade := 1.0 - active_ratio
		_line.default_color = Settings.apply_readability_color(Color(0.12, 0.94, 1.0, Settings.world_visual_alpha(0.22 + 0.22 * pulse, 0.36) * fade))

	var direction := (end_position - start_position).normalized()
	if direction.length_squared() > 0.001:
		if _anchor_a != null:
			_anchor_a.rotation = direction.angle()
		if _anchor_b != null:
			_anchor_b.rotation = direction.angle() + PI
	rotation += delta * 0.0


func _apply_thread_pull(delta: float) -> void:
	if not _anchors_valid():
		return
	var start_position := _anchor_a.global_position
	var end_position := _anchor_b.global_position
	var center := (start_position + end_position) * 0.5
	var thread_length := start_position.distance_to(end_position)
	var query_radius := thread_length * 0.5 + effect_width
	_fill_targets_in_radius(THREAD_TARGET_GROUPS, center, query_radius, max_affected_bodies, true, _targets)
	var direction := (end_position - start_position).normalized()
	if direction.length_squared() <= 0.001:
		return
	for body in _targets:
		if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
			continue
		if body == _anchor_a or body == _anchor_b:
			continue
		var closest := _closest_point_on_segment(body.global_position, start_position, end_position)
		var offset := body.global_position - closest
		var distance := offset.length()
		if distance > effect_width:
			continue
		var falloff := 1.0 - clampf(distance / maxf(effect_width, 1.0), 0.0, 1.0)
		var side_sign := signf(direction.cross(offset))
		if side_sign == 0.0:
			side_sign = 1.0
		var sideways := direction.orthogonal() * side_sign
		var toward_line := -offset.normalized() if distance > 0.001 else Vector2.ZERO
		var impulse := (sideways * 0.62 + direction * 0.26 + toward_line * 0.34) * pull_strength * falloff * delta
		CombatStatus.add_velocity(body, impulse)
		body.set_meta(&"orbit_thread_bend", Time.get_ticks_msec() * 0.001 + 0.22)


func _fill_targets_in_radius(
	groups: Array[StringName],
	center: Vector2,
	radius: float,
	limit: int,
	include_player: bool,
	out_targets: Array[Node2D]
) -> void:
	out_targets.clear()
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_targets_in_radius(groups, center, radius, limit, include_player, out_targets)
		return
	var radius_squared := radius * radius
	var max_count := maxi(limit, 0)
	_query_seen_ids.clear()
	for group_name in groups:
		for node in get_tree().get_nodes_in_group(group_name):
			if max_count > 0 and out_targets.size() >= max_count:
				return
			var body := node as Node2D
			if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
				continue
			if not include_player and body.is_in_group("Player"):
				continue
			var id := body.get_instance_id()
			if _query_seen_ids.has(id):
				continue
			_query_seen_ids[id] = true
			if body.global_position.distance_squared_to(center) <= radius_squared:
				out_targets.append(body)


func _anchors_valid() -> bool:
	return (
		_anchor_a != null
		and _anchor_b != null
		and is_instance_valid(_anchor_a)
		and is_instance_valid(_anchor_b)
		and not _anchor_a.is_queued_for_deletion()
		and not _anchor_b.is_queued_for_deletion()
	)


func _on_anchor_destroyed(_anchor: OrbitThreadAnchor) -> void:
	disable_thread(&"anchor_destroyed")


func _closest_point_on_segment(point: Vector2, start_position: Vector2, end_position: Vector2) -> Vector2:
	var segment := end_position - start_position
	var length_squared := segment.length_squared()
	if length_squared <= 0.001:
		return start_position
	var t := clampf((point - start_position).dot(segment) / length_squared, 0.0, 1.0)
	return start_position + segment * t
