extends Node2D
class_name ProjectileAimPredictor

# ============================================================
# VISUAL SETTINGS
# ============================================================
@export var prediction_steps: int = 110
@export var substeps: int = 2
@export var line_width: float = 2.3
@export var ghost_count: int = 0
@export var ghost_amplitude: float = 10.0
@export var ghost_frequency: float = 2.2
@export var ghost_speed: float = 6.0
@export var prediction_recalculate_interval: float = 0.045
@export var draw_stride: int = 1
@export var max_draw_segments: int = 110
@export var pressure_hide_threshold: int = 128
@export_range(0.8, 1.0, 0.001) var stability_damping: float = 0.975
@export var immediate_danger_segments: int = 25

@export var prediction_color: Color = Color(0.0, 0.85, 1.0, 0.75)
@export var danger_color: Color = Color(1.0, 0.35, 0.1, 0.95)
@export var ghost_color: Color = Color(0.0, 0.6, 1.0, 0.22)

# ============================================================
# PROJECTILE SETTINGS
# ============================================================
@export var projectile_speed: float = 1080.0
@export var gravity_constant: float = 200.0
@export var min_grav_dist: float = 50.0
@export var gravity_radius: float = 2000.0
@export var max_gravity_sources: int = 4
@export var spawn_offset: float = 70.0
@export var projectile_mass: float = 0.25
@export var gravity_source_refresh_interval: float = 0.12

@export var friction: float = 0.5
@export var bounce: float = 0.5
@export var solver_correction: float = 1.0
@export var stop_on_planet_hit: bool = true
@export var collision_radius: float = 68.5

# ============================================================
# INTERNAL
# ============================================================
var _player: CharacterBody2D
var _points: Array[Vector2] = []
var _gravity_sources: Array[Node2D] = []
var _dt: float
var _time := 0.0
var _gravity_refresh_elapsed: float = 999.0
var _simulate_elapsed: float = 999.0
var _projectile_pressure: int = 0

func _ready() -> void:
	top_level = true
	_player = get_parent() as CharacterBody2D
	_dt = 1.0 / Engine.physics_ticks_per_second
	process_mode = Node.PROCESS_MODE_ALWAYS


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	
	var unscaled_delta = delta / maxf(Engine.time_scale, 0.001)
	_time += unscaled_delta
	_simulate_elapsed += unscaled_delta
	
	_gravity_refresh_elapsed += unscaled_delta
	if _gravity_refresh_elapsed >= maxf(gravity_source_refresh_interval, 0.02):
		_gravity_refresh_elapsed = 0.0
		_update_gravity_sources()
	if _simulate_elapsed < maxf(prediction_recalculate_interval, 0.02):
		return
	_simulate_elapsed = 0.0
	_projectile_pressure = _projectile_pressure_count()
	if _projectile_pressure >= pressure_hide_threshold:
		_points.clear()
	else:
		_simulate()
	queue_redraw()


func _update_gravity_sources() -> void:
	_gravity_sources.clear()
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_nearest_gravity_sources(
			_player.global_position,
			_gravity_sources,
			max_gravity_sources,
			gravity_radius,
			_player
		)
		_filter_ignored_sources()
		return

	var seen := {}
	for group_name in [&"Objects_With_Gravity", &"planets"]:
		for n in get_tree().get_nodes_in_group(group_name):
			var node := n as Node2D
			if node == null or not is_instance_valid(node) or _should_ignore_source(node):
				continue
			var id := node.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			_gravity_sources.append(node)
	_gravity_sources.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(_player.global_position) < b.global_position.distance_squared_to(_player.global_position)
	)
	if max_gravity_sources > 0 and _gravity_sources.size() > max_gravity_sources:
		_gravity_sources.resize(max_gravity_sources)


func _filter_ignored_sources() -> void:
	for index in range(_gravity_sources.size() - 1, -1, -1):
		var source := _gravity_sources[index]
		if source == null or not is_instance_valid(source) or _should_ignore_source(source):
			_gravity_sources.remove_at(index)


func _should_ignore_source(source: Node2D) -> bool:
	if source == null or not is_instance_valid(source) or source.is_queued_for_deletion():
		return true
	if source == _player or source.is_in_group("Player") or source.is_in_group("player_projectiles"):
		return true
	if source.is_ancestor_of(_player):
		return true
	return false


func _simulate() -> void:
	_points.clear()
	var dir := -_player.transform.x.normalized()
	var pos := _player.global_position + dir * spawn_offset
	var vel := dir * _predicted_launch_speed(dir)
	var step_dt := _dt / float(substeps)

	for i in range(prediction_steps):
		for s in range(substeps):
			var force := Vector2.ZERO
			for g in _gravity_sources:
				if not is_instance_valid(g): continue
				var offset := g.global_position - pos
				var dist := offset.length()
				if dist < 0.001 or dist > gravity_radius: continue
				
				var d = max(dist, min_grav_dist)
				var mass := 100.0
				var m = g.get("mass")
				if m is float or m is int:
					mass = float(m)
				
				force += offset.normalized() * (gravity_constant * mass / (d * d))

			var accel := force / maxf(projectile_mass, 0.001)
			vel += accel * step_dt
			pos += vel * step_dt
		vel *= stability_damping

		# Collision uses the same cached nearest sources as gravity so the
		# predictor cannot scan every planet on every simulated step.
		for planet in _gravity_sources:
			if planet == null or not is_instance_valid(planet): continue
			if not planet.is_in_group("planets"): continue
			var delta_vec := pos - planet.global_position
			var dist := delta_vec.length()
			if dist < collision_radius and dist > 0.001:
				var normal = delta_vec / dist
				pos = planet.global_position + normal * collision_radius
				_points.append(pos)
				if stop_on_planet_hit:
					return
				vel = vel.bounce(normal) * bounce
				vel *= solver_correction

		_points.append(pos)
		if vel.length() < 6.0:
			break


func _predicted_launch_speed(direction: Vector2) -> float:
	var speed := projectile_speed
	var momentum_component := _player.get_node_or_null("MomentumCombatComponent")
	if momentum_component == null:
		return speed
	var inherit_value: Variant = momentum_component.get("projectile_velocity_inherit")
	var max_value: Variant = momentum_component.get("projectile_max_inherited_speed")
	if not (inherit_value is float or inherit_value is int) or not (max_value is float or max_value is int):
		return speed
	var inherited := minf(maxf(_player.velocity.dot(direction), 0.0) * float(inherit_value), float(max_value))
	return speed + inherited


func _draw() -> void:
	if _points.size() < 2:
		return
	if _projectile_pressure >= pressure_hide_threshold:
		return
	
	# Ghost pulsing fields
	var stride := maxi(draw_stride, 1)
	for g in range(ghost_count):
		var phase := float(g) / float(ghost_count) * PI * 2.0
		var drawn := 0
		for i in range(stride, _points.size(), stride):
			if drawn >= max_draw_segments:
				break
			var p0 := _points[i - stride]
			var p1 := _points[i]
			var dir := (p1 - p0).normalized()
			var normal := Vector2(-dir.y, dir.x)
			
			var dist_phase := float(i) * ghost_frequency
			var pulse := sin(_time * ghost_speed + dist_phase + phase)
			
			var offset := normal * pulse * ghost_amplitude * (1.0 - float(i) / float(_points.size()))
			
			var a := to_local(p0 + offset)
			var b := to_local(p1 + offset)
			
			var fade := _safe_visual_alpha(ghost_color.a * (1.0 - float(i) / float(_points.size())) * 0.72, 0.16)
			draw_line(a, b, Color(ghost_color.r, ghost_color.g, ghost_color.b, fade), line_width * 0.7)
			drawn += 1

	# Main line
	var drawn_main := 0
	for i in range(stride, _points.size(), stride):
		if drawn_main >= max_draw_segments:
			break
		var a := to_local(_points[i - stride])
		var b := to_local(_points[i])
		var t := float(i) / float(_points.size())
		
		var col := prediction_color
		if i <= immediate_danger_segments:
			col = danger_color
		
		draw_line(a, b, Color(col.r, col.g, col.b, _safe_visual_alpha((1.0 - t) * col.a, 0.82)), line_width)
		drawn_main += 1

	draw_circle(to_local(_points[0]), 7.0, Color(0.42, 1.0, 0.92, _safe_visual_alpha(0.5, 0.34)))


func _projectile_pressure_count() -> int:
	if RuntimeRegistry != null:
		return RuntimeRegistry.get_count(&"Projectiles")
	return get_tree().get_nodes_in_group("Projectiles").size()


func _safe_visual_alpha(alpha: float, cap: float) -> float:
	if Settings != null and Settings.has_method("world_visual_alpha"):
		return Settings.world_visual_alpha(alpha, cap)
	if Settings != null and Settings.has_method("flash_alpha"):
		return minf(Settings.flash_alpha(alpha), cap)
	return minf(alpha, cap)
