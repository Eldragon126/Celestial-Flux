extends Node2D
class_name OrbitalTrajectoryPredictor

## Orbital Trajectory Prediction System
## Projects curved trajectories under gravity influence
## Shows slingshot paths, orbital previews, and future collision forecasting
## Player should feel: "I can see the future geometry."

@export_node_path("CharacterBody2D") var player_path: NodePath = ^"../Player"
@export var prediction_steps: int = 60
@export var time_step: float = 0.016
@export var max_prediction_distance: float = 2000.0
@export var gravity_groups: Array[StringName] = [&"Objects_With_Gravity", &"planets"]
@export var show_prediction_line: bool = true
@export var prediction_color: Color = Color(0.0, 0.9, 1.0, 0.6)
@export var danger_color: Color = Color(1.0, 0.3, 0.0, 0.8)
@export var safe_color: Color = Color(0.0, 1.0, 0.5, 0.4)
@export var line_width: float = 2.0
@export var show_collision_warnings: bool = true
@export var minimum_curve_display: float = 50.0

var _player: CharacterBody2D = null
var _prediction_points: Array[Vector2] = []
var _prediction_dangers: Array[Dictionary] = []
var _gravity_sources: Array[Node2D] = []
var _closest_approach_distance: float = INF
var _predicted_collisions: Array[Dictionary] = []

signal trajectory_updated(points: Array[Vector2], dangers: Array[Dictionary])
signal collision_warning_predicted(collision_info: Dictionary)
signal slingshot_opportunity_detected(opportunity: Dictionary)

func _ready() -> void:
	_resolve_player()
	_refresh_gravity_sources()
	set_process(true)

func _process(_delta: float) -> void:
	if _player == null:
		_resolve_player()
		return
	
	_update_gravity_sources()
	_calculate_trajectory()
	
	if show_prediction_line:
		queue_redraw()

func _resolve_player() -> void:
	_player = get_node_or_null(player_path) as CharacterBody2D
	if _player == null:
		var found = get_tree().get_first_node_in_group("Player")
		if found != null:
			_player = found as CharacterBody2D

func _update_gravity_sources() -> void:
	_gravity_sources.clear()
	for group_name in gravity_groups:
		for source in get_tree().get_nodes_in_group(group_name):
			var source_2d = source as Node2D
			if source_2d != null and source_2d != _player:
				_gravity_sources.append(source_2d)

func _refresh_gravity_sources() -> void:
	_update_gravity_sources()

func _calculate_trajectory() -> void:
	if _player == null:
		return
	
	_prediction_points.clear()
	_prediction_dangers.clear()
	_predicted_collisions.clear()
	_closest_approach_distance = INF
	
	var current_pos = _player.global_position
	var current_vel = _player.velocity.copy()
	
	var total_dist = 0.0
	var min_distance_to_source = INF
	var nearest_source: Node2D = null
	
	for i in range(prediction_steps):
		var gravity_accel = _calculate_gravity_at_position(current_pos)
		
		# Semi-implicit Euler integration for stability
		current_vel += gravity_accel * time_step
		current_pos += current_vel * time_step
		
		total_dist += current_vel.length() * time_step
		
		_prediction_points.append(current_pos)
		
		# Check distance to gravity sources for slingshot opportunities
		for source in _gravity_sources:
			if not is_instance_valid(source):
				continue
			
			var dist = current_pos.distance_to(source.global_position)
			
			if dist < min_distance_to_source:
				min_distance_to_source = dist
				nearest_source = source
			
			# Detect potential collision
			if show_collision_warnings:
				var source_radius = _estimate_source_radius(source)
				if dist < source_radius + 20.0:
					var collision_info = {
						"step": i,
						"position": current_pos,
						"source": source,
						"time": float(i) * time_step,
						"velocity": current_vel
					}
					_predicted_collisions.append(collision_info)
					collision_warning_predicted.emit(collision_info)
		
		# Stop if we've gone too far
		if total_dist > max_prediction_distance:
			break
	
	_closest_approach_distance = min_distance_to_source
	
	# Detect slingshot opportunities
	if nearest_source != null and min_distance_to_source < 400.0 and min_distance_to_source > 80.0:
		var slingshot_info = {
			"source": nearest_source,
			"distance": min_distance_to_source,
			"optimal_point": _prediction_points[min(_prediction_points.size() - 1, int(min_distance_to_source / (current_vel.length() * time_step + 0.001)))]
		}
		slingshot_opportunity_detected.emit(slingshot_info)
	
	trajectory_updated.emit(_prediction_points, _prediction_dangers)

func _calculate_gravity_at_position(pos: Vector2) -> Vector2:
	var total_gravity = Vector2.ZERO
	
	for source in _gravity_sources:
		if not is_instance_valid(source):
			continue
		
		var offset = source.global_position - pos
		var raw_distance = offset.length()
		
		if raw_distance < 10.0:
			raw_distance = 10.0
		
		var direction = offset.normalized()
		
		# Get mass from source
		var mass: float = 100.0
		if source.has_method("get"):
			var m = source.get("mass")
			if typeof(m) == TYPE_FLOAT or typeof(m) == TYPE_INT:
				mass = float(m)
		
		# Inverse square law
		var strength = 400.0 * mass / (raw_distance * raw_distance)
		total_gravity += direction * strength
	
	return total_gravity

func _estimate_source_radius(source: Node2D) -> float:
	# Try to get radius from various common properties
	if source.has_method("get"):
		var radius = source.get("radius")
		if radius != null and typeof(radius) in [TYPE_FLOAT, TYPE_INT]:
			return float(radius)
		
		var scale = source.get("scale")
		if scale != null and typeof(scale) == TYPE_VECTOR2:
			return max(scale.x, scale.y) * 20.0
	
	return 30.0  # Default fallback

func _draw() -> void:
	if not show_prediction_line or _prediction_points.size() < 2:
		return
	
	# Draw prediction curve with color gradient based on danger
	for i in range(1, _prediction_points.size()):
		var p1 = _prediction_points[i - 1]
		var p2 = _prediction_points[i]
		
		# Convert to local coordinates for drawing
		var local_p1 = to_local(p1)
		var local_p2 = to_local(p2)
		
		# Color based on proximity to danger
		var t = float(i) / float(_prediction_points.size())
		var base_color = prediction_color
		
		# Check if this segment is near a predicted collision
		for collision in _predicted_collisions:
			var collision_step = int(collision["step"])
			if abs(i - collision_step) < 3:
				base_color = danger_color
				break
		
		# Fade out at end
		var alpha = 1.0 - (t * 0.7)
		var final_color = Color(base_color.r, base_color.g, base_color.b, base_color.a * alpha)
		
		draw_line(local_p1, local_p2, final_color, line_width)
	
	# Draw start point
	draw_circle(to_local(_player.global_position), 4.0, safe_color)
	
	# Draw predicted collision points
	if show_collision_warnings:
		for collision in _predicted_collisions:
			var local_collision = to_local(collision["position"])
			draw_circle(local_collision, 8.0, danger_color)
			draw_circle(local_collision, 6.0, Color(1.0, 1.0, 1.0, 0.8))

func get_predicted_position(steps_ahead: int) -> Vector2:
	if steps_ahead < 0 or steps_ahead >= _prediction_points.size():
		return _player.global_position if _player else global_position
	return _prediction_points[steps_ahead]

func get_predicted_velocity(steps_ahead: int) -> Vector2:
	if steps_ahead < 1 or steps_ahead >= _prediction_points.size():
		return _player.velocity if _player else Vector2.ZERO
	
	var p1 = _prediction_points[steps_ahead - 1]
	var p2 = _prediction_points[steps_ahead]
	return (p2 - p1) / time_step

func get_closest_approach_distance() -> float:
	return _closest_approach_distance

func has_predicted_collision() -> bool:
	return _predicted_collisions.size() > 0

func get_next_predicted_collision() -> Dictionary:
	if _predicted_collisions.is_empty():
		return {}
	return _predicted_collisions[0]

func clear_prediction() -> void:
	_prediction_points.clear()
	_prediction_dangers.clear()
	_predicted_collisions.clear()
	queue_redraw()
