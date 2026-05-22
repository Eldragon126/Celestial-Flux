# ProjectileTrajectoryVisualizer.gd
extends Node2D
class_name ProjectileTrajectoryVisualizer

## Visualizes the future trajectory of a projectile (RigidBody2D child)

@export var prediction_steps: int = 110
@export var time_step: float = 0.014
@export var max_distance: float = 3200.0

@export var line_color: Color = Color(0.0, 0.85, 1.0, 0.75)
@export var danger_color: Color = Color(1.0, 0.35, 0.1, 0.95)
@export var line_width: float = 2.3

@export var gravity_groups: Array[StringName] = [&"Objects_With_Gravity", &"planets"]

var _projectile: RigidBody2D
var _points: Array[Vector2] = []

func _ready() -> void:
	top_level = true  # Draw in world space
	_projectile = get_parent() as RigidBody2D
	
	if _projectile == null:
		push_warning("ProjectileTrajectoryVisualizer must be a direct child of a RigidBody2D (the projectile)")
		set_process(false)
		return
	
	set_process(true)

func _process(_delta: float) -> void:
	if not is_instance_valid(_projectile):
		queue_free()
		return
	
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
		vel *= 0.975  # stability damping
		pos += vel * time_step
		
		travelled += vel.length() * time_step
		_points.append(pos)
		
		if travelled > max_distance or vel.length() < 10.0:
			break

func _calculate_gravity(pos: Vector2) -> Vector2:
	var total = Vector2.ZERO
	
	for group_name in gravity_groups:
		for source in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(source) or not (source is Node2D):
				continue
			
			var offset = source.global_position - pos
			var dist = offset.length()
			if dist < 1.0:
				continue
			
			var effective_dist = max(dist, 45.0)
			var mass = 100.0
			var m = source.get("mass")
			if m is float or m is int:
				mass = float(m)
			
			var strength = 220.0 * mass / (effective_dist * effective_dist)
			total += offset.normalized() * strength
	
	return total

func _draw() -> void:
	if _points.size() < 2:
		return
	
	for i in range(1, _points.size()):
		var a = to_local(_points[i-1])
		var b = to_local(_points[i])
		
		var t = float(i) / float(_points.size())
		var alpha = 1.0 - t * 0.65
		var col = danger_color if i < 25 else line_color
		
		draw_line(a, b, Color(col.r, col.g, col.b, alpha * col.a), line_width)
