extends Node
class_name GravityComponent

@export_node_path("CharacterBody2D") var target_path: NodePath = ^".."
@export var gravity_group: StringName = &"Objects_With_Gravity"
@export var fallback_gravity_group: StringName = &"planets"
@export var gravity_constant: float = 300.0
@export var min_gravity_distance: float = 50.0
@export var max_gravity_distance: float = 0.0
@export var max_sources: int = 4
@export var mass_property: StringName = &"mass"
@export var fallback_mass: float = 0.0
@export var auto_apply: bool = true
@export var move_target_after_gravity: bool = false
@export var refresh_sources_each_frame: bool = false
@export var refresh_interval: float = 0.35
@export var run_before_target: bool = true

var latest_acceleration: Vector2 = Vector2.ZERO
var closest_source: Node2D = null
var closest_distance: float = INF

var _target: CharacterBody2D = null
var _gravity_sources: Array[Node2D] = []
var _source_refresh_elapsed = 0.0
var _missing_target_warned = false

func _ready() -> void:
	_resolve_target()

	if _target == null:
		set_physics_process(false)
		return

	refresh_sources()
	set_physics_process(auto_apply)

	if _target != null and run_before_target:
		process_priority = _target.process_priority - 1

func _physics_process(delta: float) -> void:
	_source_refresh_elapsed += delta

	if auto_apply:
		apply_gravity(delta)

		if move_target_after_gravity and _target != null:
			_target.move_and_slide()

func refresh_sources() -> void:
	if not is_inside_tree():
		return

	_gravity_sources.clear()
	if RuntimeRegistry != null and _target != null:
		RuntimeRegistry.fill_nearest_gravity_sources(
			_target.global_position,
			_gravity_sources,
			max_sources,
			max_gravity_distance,
			_target
		)
	else:
		var seen: Dictionary = {}
		for group_name in [gravity_group, fallback_gravity_group]:
			if String(group_name).is_empty():
				continue
			for source in get_tree().get_nodes_in_group(group_name):
				if source == null or not is_instance_valid(source):
					continue
				var source_2d := source as Node2D
				if source_2d == null or source_2d.is_queued_for_deletion():
					continue
				var id := source_2d.get_instance_id()
				if seen.has(id):
					continue
				seen[id] = true
				_gravity_sources.append(source_2d)

	_source_refresh_elapsed = 0.0

func calculate_gravity() -> Vector2:
	if _target == null:
		_resolve_target()

	if _target == null:
		return Vector2.ZERO

	if refresh_sources_each_frame or _source_refresh_elapsed >= refresh_interval:
		refresh_sources()

	latest_acceleration = Vector2.ZERO
	closest_source = null
	closest_distance = INF

	_refresh_nearest_sources_if_needed()

	for source in _gravity_sources:
		if not is_instance_valid(source):
			continue

		var source_2d := source as Node2D

		if source_2d == null:
			continue
		if source_2d == _target:
			continue

		var offset = source_2d.global_position - _target.global_position
		var raw_distance = offset.length()

		if max_gravity_distance > 0.0 and raw_distance > max_gravity_distance:
			continue

		var distance: float = max(raw_distance, min_gravity_distance)
		var mass: float = _get_source_mass(source_2d)

		if distance <= 0.0 or mass <= 0.0:
			continue

		if distance < closest_distance:
			closest_distance = distance
			closest_source = source_2d

		var direction = offset.normalized()
		var strength: float = gravity_constant * mass / (distance * distance)
		latest_acceleration += direction * strength

	return latest_acceleration

func apply_gravity(delta: float) -> Vector2:
	var acceleration = calculate_gravity()

	if _target != null:
		_target.velocity += acceleration * delta

	return acceleration

func get_target_body() -> CharacterBody2D:
	if _target == null:
		_resolve_target()

	return _target

func set_gravity_sources(sources: Array[Node2D]) -> void:
	_gravity_sources = sources
	_source_refresh_elapsed = 0.0

func _resolve_target() -> void:
	_target = get_node_or_null(target_path) as CharacterBody2D

	if _target == null and not _missing_target_warned:
		_missing_target_warned = true
		push_warning("%s needs a CharacterBody2D at target_path." % name)

func _get_source_mass(source: Node) -> float:
	var value: Variant = source.get(mass_property)

	if value == null:
		return fallback_mass

	var value_type: int = typeof(value)

	if value_type == TYPE_FLOAT or value_type == TYPE_INT:
		return float(value)

	return fallback_mass

func _refresh_nearest_sources_if_needed() -> void:
	if _target == null:
		_gravity_sources.clear()
		return
	if refresh_sources_each_frame or _source_refresh_elapsed >= refresh_interval:
		refresh_sources()
