# ProjectileTrajectoryVisualizer.gd
extends Node2D
class_name ProjectileTrajectoryVisualizer

## Visualizes the future trajectory of a projectile (RigidBody2D child)

@export var prediction_steps: int = 110
@export var time_step: float = 0.014
@export var max_distance: float = 3200.0

@export var line_color: Color = Color(0.0, 0.85, 1.0, 0.75)
@export var danger_color: Color = Color(1.0, 0.35, 0.1, 0.95)
@export var line_width: float = 3.0

@export var gravity_groups: Array[StringName] = [&"Objects_With_Gravity", &"planets"]
@export var source_refresh_interval: float = 0.08
@export var max_gravity_sources: int = 4

var _projectile: RigidBody2D
var _points: Array[Vector2] = []
var _gravity_sources: Array[Node2D] = []
var _source_refresh_elapsed: float = 999.0

func _ready() -> void:
	top_level = true  # Draw in world space
	_projectile = get_parent() as RigidBody2D
	
	if _projectile == null:
		push_warning("ProjectileTrajectoryVisualizer must be a direct child of a RigidBody2D (the projectile)")
		set_process(false)
		return
	
	set_process(true)

func _process(delta: float) -> void:
	if not is_instance_valid(_projectile):
		queue_free()
		return
	
	_source_refresh_elapsed += delta
	if _source_refresh_elapsed >= maxf(source_refresh_interval, 0.02):
		_source_refresh_elapsed = 0.0
		_refresh_gravity_sources()
	_simulate_path()
	queue_redraw()

func _simulate_path() -> void:
	_points.clear()
	
	var pos: Vector2 = _projectile.global_position
	var vel: Vector2 = _projectile.linear_velocity
	var travelled: float = 0.0
	
	for i in range(prediction_steps):
		var accel = _calculate_gravity(pos)
		
		vel += accel * time_step
		pos += vel * time_step
		
		travelled += vel.length() * time_step
		_points.append(pos)
		
		if travelled > max_distance or vel.length() < 10.0:
			break

func _calculate_gravity(pos: Vector2) -> Vector2:
	var total = Vector2.ZERO
	
	var gravity_constant = _projectile.get("gravity_constant")
	var min_dist = _projectile.get("min_grav_dist")
	var pull_radius = _projectile.get("gravity_pull_radius")
	var constant_value := float(gravity_constant) if gravity_constant is float or gravity_constant is int else 200.0
	var min_dist_value := float(min_dist) if min_dist is float or min_dist is int else 50.0
	var radius_value := float(pull_radius) if pull_radius is float or pull_radius is int else 2000.0

	for source in _gravity_sources:
		if not is_instance_valid(source):
			continue
		var offset = source.global_position - pos
		var dist = offset.length()
		if dist < 1.0 or dist > radius_value:
			continue

		var effective_dist = max(dist, min_dist_value)
		var mass = 100.0
		var m = source.get("mass")
		if m is float or m is int:
			mass = float(m)

		var strength = constant_value * mass / (effective_dist * effective_dist)
		total += offset.normalized() * strength

	return total


func _refresh_gravity_sources() -> void:
	_gravity_sources.clear()
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_nearest_gravity_sources(
			_projectile.global_position,
			_gravity_sources,
			max_gravity_sources,
			0.0,
			_projectile
		)
		_filter_ignored_sources()
		return

	var seen := {}
	for group_name in gravity_groups:
		for source_value in get_tree().get_nodes_in_group(group_name):
			var source := source_value as Node2D
			if source == null or not is_instance_valid(source) or _should_ignore_source(source):
				continue
			var id := source.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			_gravity_sources.append(source)
			if _gravity_sources.size() >= max_gravity_sources:
				return


func _filter_ignored_sources() -> void:
	for index in range(_gravity_sources.size() - 1, -1, -1):
		var source := _gravity_sources[index]
		if source == null or not is_instance_valid(source) or _should_ignore_source(source):
			_gravity_sources.remove_at(index)


func _should_ignore_source(source: Node2D) -> bool:
	if source == null or not is_instance_valid(source) or source.is_queued_for_deletion():
		return true
	if source == _projectile or source.is_in_group("Player") or source.is_in_group("player_projectiles"):
		return true
	return false

func _draw() -> void:
	if _points.size() < 2:
		return
	
	for i in range(1, _points.size()):
		var a = to_local(_points[i-1])
		var b = to_local(_points[i])
		
		var t = float(i) / float(_points.size())
		var alpha = 1.0 - t * 0.65
		var col = danger_color if i > _points.size() - 18 else line_color
		
		draw_line(a, b, Color(col.r, col.g, col.b, alpha * col.a), line_width)
		if i % 10 == 0:
			draw_circle(b, line_width * 0.62, Color(line_color.r, line_color.g, line_color.b, alpha * 0.45))
