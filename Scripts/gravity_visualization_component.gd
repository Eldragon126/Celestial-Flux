# gravity_visualization_component.gd
extends Node2D
class_name GravityVisualizationComponent

## Combined & Polished Gravity Visualization
## Shows field lines, distortion rings, and particle trails

@export_node_path("Node2D") var target_path: NodePath = ^"../Player"
@export var gravity_group: StringName = &"Objects_With_Gravity"
@export var fallback_gravity_group: StringName = &"planets"

@export var visualization_mode: int = 2  # 0=Off, 1=Minimal, 2=Full
@export var enable_field_lines: bool = true
@export var field_line_count: int = 16
@export var field_line_length: float = 160.0
@export var field_line_segments: int = 22
@export var field_line_color: Color = Color(0.3, 0.7, 1.0, 0.5)

@export var enable_well_distortion: bool = true
@export var distortion_radius_base: float = 320.0
@export var distortion_strength: float = 0.18

@export var enable_particle_trails: bool = true
@export var trail_spawn_rate: float = 0.04
@export var trail_lifetime: float = 1.1
@export var trail_color: Color = Color(0.0, 0.95, 1.0, 0.6)

@export var max_visualization_distance: float = 1400.0

var _target: Node2D = null
var _gravity_sources: Array[Node2D] = []
var _field_gradients: Array[Dictionary] = []
var _trail_particles: Array[Dictionary] = []
var _trail_spawn_timer: float = 0.0
var _distortion_center: Vector2 = Vector2.ZERO
var _total_field_strength: float = 0.0

func _ready() -> void:
	_resolve_target()
	set_process(true)

func _process(delta: float) -> void:
	if _target == null:
		_resolve_target()
		return
	
	_update_gravity_sources()
	_calculate_field()
	_update_trails(delta)
	
	if visualization_mode > 0:
		queue_redraw()

func _resolve_target() -> void:
	_target = get_node_or_null(target_path) as Node2D
	if _target == null:
		_target = get_tree().get_first_node_in_group("Player") as Node2D

func _update_gravity_sources() -> void:
	_gravity_sources.clear()
	for group_name in [gravity_group, fallback_gravity_group]:
		if group_name == &"":
			continue
		for node in get_tree().get_nodes_in_group(group_name):
			var n = node as Node2D
			if n != null and n != _target and is_instance_valid(n):
				_gravity_sources.append(n)

func _calculate_field() -> void:
	_field_gradients.clear()
	_total_field_strength = 0.0
	_distortion_center = Vector2.ZERO
	
	if _target == null:
		return
	
	var weighted_sum = Vector2.ZERO
	var total_weight = 0.0
	
	for source in _gravity_sources:
		if not is_instance_valid(source):
			continue
			
		var offset = source.global_position - _target.global_position
		var dist_sq = offset.length_squared()
		if dist_sq > max_visualization_distance * max_visualization_distance or dist_sq < 100.0:
			continue
		
		var mass: float = 100.0
		var m = source.get("mass")
		if m != null:
			mass = float(m)
		
		var strength = (mass * 900.0) / dist_sq
		var direction = offset.normalized()
		
		_field_gradients.append({
			"source": source,
			"position": source.global_position,
			"direction": direction,
			"strength": strength,
			"dist_sq": dist_sq
		})
		
		_total_field_strength += strength
		weighted_sum += source.global_position * strength
		total_weight += strength
	
	if total_weight > 0.0:
		_distortion_center = weighted_sum / total_weight

func _update_trails(delta: float) -> void:
	if not enable_particle_trails:
		return
	
	_trail_spawn_timer += delta
	if _trail_spawn_timer >= trail_spawn_rate:
		_trail_spawn_timer = 0.0
		_spawn_trail_particle()
	
	for i in range(_trail_particles.size() - 1, -1, -1):
		var p = _trail_particles[i]
		p["lifetime"] -= delta
		if p["lifetime"] <= 0.0:
			_trail_particles.remove_at(i)
			continue
		
		var accel = _calculate_gravity_at_position(p["position"])
		p["velocity"] += accel * delta
		p["position"] += p["velocity"] * delta

func _spawn_trail_particle() -> void:
	if _target == null:
		return
	_trail_particles.append({
		"position": _target.global_position,
		"velocity": Vector2(randf_range(-45, 45), randf_range(-45, 45)),
		"lifetime": trail_lifetime
	})

func _calculate_gravity_at_position(pos: Vector2) -> Vector2:
	var total = Vector2.ZERO
	for g in _field_gradients:
		var offset = g["position"] - pos
		var d = max(offset.length(), 30.0)
		total += offset.normalized() * (g["strength"] * 80.0 / (d * d))
	return total

func _draw() -> void:
	if _target == null or visualization_mode == 0:
		return
	
	if enable_field_lines:
		_draw_field_lines()
	if enable_well_distortion:
		_draw_distortion()
	if enable_particle_trails:
		_draw_particles()

func _draw_field_lines() -> void:
	for g in _field_gradients:
		var start = to_local(g["position"])
		var current = g["position"]
		var dir = g["direction"]
		var strength = g["strength"]
		
		var points: Array[Vector2] = [start]
		
		for s in range(field_line_segments):
			var to_target = (_target.global_position - current).normalized()
			dir = dir.lerp(to_target, 0.085)
			current += dir * (field_line_length / field_line_segments)
			points.append(to_local(current))
		
		var alpha = clamp(strength / 12.0, 0.12, 0.65)
		var c = Color(field_line_color.r, field_line_color.g, field_line_color.b, alpha)
		
		for i in range(points.size() - 1):
			draw_line(points[i], points[i+1], c, 1.8)

func _draw_distortion() -> void:
	for g in _field_gradients:
		var p = to_local(g["position"])
		var dist = sqrt(g["dist_sq"])
		if dist > distortion_radius_base * 2.2:
			continue
			
		for ring in range(3):
			var radius = dist * 0.6 + ring * 28.0
			var alpha = distortion_strength * (1.0 - ring * 0.3)
			draw_arc(p, radius, 0, TAU, 28, Color(0.4, 0.7, 1.0, alpha * 0.25), 3.0)

func _draw_particles() -> void:
	for p in _trail_particles:
		var pos = to_local(p["position"])
		var t = p["lifetime"] / trail_lifetime
		var size = lerp(5.0, 1.5, 1.0 - t)
		draw_circle(pos, size, Color(trail_color.r, trail_color.g, trail_color.b, t * trail_color.a * 0.9))
