extends Node2D
class_name GravityVisualizationComponent

## Gravity Visualization System for ORBITRON: VECTORFALL
## Makes gravity FEELABLE before visible - Physics Dread implementation
## Particles bend first, audio pitch lowers, stars distort, bullets curve unnaturally,
## UI subtly warps, motion trails deform

@export_node_path("Node2D") var target_path: NodePath = ^"../Player"
@export var gravity_group: StringName = &"Objects_With_Gravity"
@export var fallback_gravity_group: StringName = &"planets"
@export var visualization_mode: int = 0  # 0=Minimal, 1=Stylized, 2=Cinematic
@export var enable_field_lines: bool = true
@export var field_line_count: int = 12
@export var field_line_length: float = 150.0
@export var field_line_segments: int = 20
@export var field_line_color: Color = Color(0.3, 0.6, 1.0, 0.4)
@export var enable_well_distortion: bool = true
@export var distortion_radius_base: float = 300.0
@export var distortion_strength: float = 0.15
@export var enable_particle_trails: bool = true
@export var trail_spawn_rate: float = 0.05
@export var trail_lifetime: float = 1.2
@export var trail_color: Color = Color(0.0, 0.9, 1.0, 0.5)
@export var enable_ui_warp: bool = false
@export var warp_intensity: float = 0.08
@export var max_visualization_distance: float = 800.0

var _target: Node2D = null
var _gravity_sources: Array[Node2D] = []
var _field_gradients: Array[Vector2] = []
var _trail_particles: Array[Dictionary] = []
var _trail_spawn_timer: float = 0.0
var _local_gravity_vectors: Dictionary = {}
var _distortion_center: Vector2 = Vector2.ZERO
var _total_field_strength: float = 0.0

signal gravity_field_updated(field_data: Dictionary)
signal distortion_applied(center: Vector2, strength: float)

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
	
	if enable_field_lines or enable_well_distortion:
		queue_redraw()
	
	# Emit data for external systems (audio, shaders, etc.)
	_emit_field_data()

func _resolve_target() -> void:
	_target = get_node_or_null(target_path) as Node2D
	if _target == null:
		var found = get_tree().get_first_node_in_group("Player")
		if found != null:
			_target = found as Node2D

func _update_gravity_sources() -> void:
	_gravity_sources.clear()
	
	for group_name in [gravity_group, fallback_gravity_group]:
		if String(group_name).is_empty():
			continue
		
		for source in get_tree().get_nodes_in_group(group_name):
			var source_2d = source as Node2D
			if source_2d != null and source_2d != _target:
				_gravity_sources.append(source_2d)

func _calculate_field() -> void:
	_field_gradients.clear()
	_local_gravity_vectors.clear()
	_total_field_strength = 0.0
	_distortion_center = Vector2.ZERO
	
	if _target == null:
		return
	
	var weighted_position_sum = Vector2.ZERO
	var total_weight = 0.0
	
	# Sample points around target for field visualization
	var sample_radius = max_visualization_distance
	var samples_per_source = max(3, field_line_count / max(1, _gravity_sources.size()))
	
	for source in _gravity_sources:
		if not is_instance_valid(source):
			continue
		
		var source_pos = source.global_position
		var offset = source_pos - _target.global_position
		var distance = offset.length()
		
		if distance > max_visualization_distance or distance < 10.0:
			continue
		
		# Get mass
		var mass: float = 100.0
		if source.has_method("get"):
			var m = source.get("mass")
			if typeof(m) in [TYPE_FLOAT, TYPE_INT]:
				mass = float(m)
		
		# Calculate gravitational influence
		var direction = offset.normalized()
		var strength = 500.0 * mass / (distance * distance)
		
		_field_gradients.append({
			"source": source,
			"position": source_pos,
			"direction": direction,
			"strength": strength,
			"distance": distance
		})
		
		_total_field_strength += strength
		weighted_position_sum += source_pos * strength
		total_weight += strength
	
	# Calculate center of distortion
	if total_weight > 0.0:
		_distortion_center = weighted_position_sum / total_weight
	
	# Store for external access
	_local_gravity_vectors["center"] = _distortion_center
	_local_gravity_vectors["total_strength"] = _total_field_strength

func _update_trails(delta: float) -> void:
	if not enable_particle_trails or _target == null:
		return
	
	_trail_spawn_timer += delta
	
	if _trail_spawn_timer >= trail_spawn_rate:
		_trail_spawn_timer = 0.0
		_spawn_trail_particle()
	
	# Update existing particles
	for i in range(_trail_particles.size() - 1, -1, -1):
		var particle = _trail_particles[i]
		particle["lifetime"] -= delta
		
		# Apply gravity to particle
		var gravity_accel = _calculate_gravity_at_position(particle["position"])
		particle["velocity"] += gravity_accel * delta
		particle["position"] += particle["velocity"] * delta
		
		if particle["lifetime"] <= 0.0:
			_trail_particles.remove_at(i)

func _spawn_trail_particle() -> void:
	if _target == null:
		return
	
	_trail_particles.append({
		"position": _target.global_position,
		"velocity": Vector2(randf_range(-30, 30), randf_range(-30, 30)),
		"lifetime": trail_lifetime,
		"age": 0.0
	})

func _calculate_gravity_at_position(pos: Vector2) -> Vector2:
	var total_gravity = Vector2.ZERO
	
	for gradient in _field_gradients:
		var offset = gradient["position"] - pos
		var distance = offset.length()
		
		if distance < 10.0:
			distance = 10.0
		
		var direction = offset.normalized()
		var strength = gradient["strength"] * (100.0 / (distance * distance + 100.0))
		
		total_gravity += direction * strength
	
	return total_gravity

func _draw() -> void:
	if _target == null:
		return
	
	if enable_field_lines and visualization_mode > 0:
		_draw_field_lines()
	
	if enable_well_distortion and visualization_mode > 0:
		_draw_distortion_overlay()
	
	if enable_particle_trails:
		_draw_trail_particles()

func _draw_field_lines() -> void:
	for gradient in _field_gradients:
		var source_pos = to_local(gradient["position"])
		var strength = gradient["strength"]
		var distance = gradient["distance"]
		
		# Skip if too far
		if distance > max_visualization_distance:
			continue
		
		# Draw curved field lines emanating from source
		for i in range(field_line_count / max(1, _gravity_sources.size())):
			var angle = (PI * 2.0 / field_line_count) * i + Time.get_ticks_msec() * 0.0005
			var start_dir = Vector2(cos(angle), sin(angle))
			
			var points: Array[Vector2] = [to_local(gradient["position"])]
			var current_pos = gradient["position"]
			var current_dir = start_dir
			
			for segment in range(field_line_segments):
				# Curve toward target based on gravity
				var to_target = (_target.global_position - current_pos).normalized()
				current_dir = current_dir.lerp(to_target, distortion_strength * 0.3)
				
				current_pos += current_dir * (field_line_length / field_line_segments)
				points.append(to_local(current_pos))
			
			# Draw with fade based on strength
			var alpha = clamp(strength / 10.0, 0.1, 0.6)
			var line_color = Color(field_line_color.r, field_line_color.g, field_line_color.b, alpha)
			
			for j in range(points.size() - 1):
				draw_line(points[j], points[j + 1], line_color, 1.5)

func _draw_distortion_overlay() -> void:
	if _gravity_sources.is_empty():
		return
	
	# Draw subtle lensing effect around gravity wells
	for gradient in _field_gradients:
		var local_pos = to_local(gradient["position"])
		var distance = gradient["distance"]
		var strength = gradient["strength"]
		
		if distance > distortion_radius_base * 2.0:
			continue
		
		# Multiple rings for distortion effect
		var ring_count = 3
		for ring in range(ring_count):
			var radius = (distance / max_visualization_distance) * distortion_radius_base * (1.0 + ring * 0.3)
			var alpha = distortion_strength * (1.0 - float(ring) / ring_count) * 0.3
			var color = Color(0.3, 0.5, 1.0, alpha)
			
			draw_arc(local_pos, radius, 0, PI * 2, 32, color, 2.0, true)

func _draw_trail_particles() -> void:
	for particle in _trail_particles:
		var local_pos = to_local(particle["position"])
		var age_ratio = 1.0 - (particle["lifetime"] / trail_lifetime)
		var alpha = trail_color.a * (1.0 - age_ratio) * 0.6
		
		var color = Color(trail_color.r, trail_color.g, trail_color.b, alpha)
		var size = lerp(4.0, 1.0, age_ratio)
		
		draw_circle(local_pos, size, color)

func _emit_field_data() -> void:
	var field_data = {
		"center": _distortion_center,
		"total_strength": _total_field_strength,
		"source_count": _gravity_sources.size(),
		"max_strength_direction": Vector2.ZERO if _field_gradients.is_empty() else _field_gradients[0]["direction"],
		"average_distance": _calculate_average_distance()
	}
	
	gravity_field_updated.emit(field_data)
	
	if _total_field_strength > 0.5:
		distortion_applied.emit(_distortion_center, minf(_total_field_strength * 0.1, 1.0))

func _calculate_average_distance() -> float:
	if _field_gradients.is_empty():
		return INF
	
	var total = 0.0
	for gradient in _field_gradients:
		total += gradient["distance"]
	
	return total / _field_gradients.size()

func get_gravity_direction() -> Vector2:
	if _field_gradients.is_empty():
		return Vector2.ZERO
	return _field_gradients[0]["direction"]

func get_gravity_strength() -> float:
	return _total_field_strength

func get_nearest_source() -> Node2D:
	if _field_gradients.is_empty():
		return null
	return _field_gradients[0]["source"]

func get_distortion_center() -> Vector2:
	return _distortion_center

func get_field_gradient_at(position: Vector2) -> Vector2:
	return _calculate_gravity_at_position(position)
