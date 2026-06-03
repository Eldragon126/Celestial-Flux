extends Node2D
class_name ProjectileAimPredictor

# ============================================================
# VISUAL SETTINGS
# ============================================================
@export var prediction_steps: int = 140
@export var substeps: int = 3
@export var line_width: float = 3.0
@export var ghost_count: int = 4
@export var ghost_amplitude: float = 18.0
@export var ghost_frequency: float = 2.2
@export var ghost_speed: float = 6.0

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
@export var gravity_source_refresh_interval: float = 0.08

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
	
	_gravity_refresh_elapsed += unscaled_delta
	if _gravity_refresh_elapsed >= maxf(gravity_source_refresh_interval, 0.02):
		_gravity_refresh_elapsed = 0.0
		_update_gravity_sources()
	_simulate()
	queue_redraw()   # Always try to redraw


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

		# Collision
		for p in get_tree().get_nodes_in_group("planets"):
			var planet := p as Node2D
			if planet == null or not is_instance_valid(planet): continue
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
	
	# ONLY draw when time is normal (not paused and not in dilation)
	if not is_equal_approx(Engine.time_scale, 1.0):
		return

	# Ghost pulsing fields
	for g in range(ghost_count):
		var phase := float(g) / float(ghost_count) * PI * 2.0
		for i in range(1, _points.size()):
			var p0 := _points[i - 1]
			var p1 := _points[i]
			var dir := (p1 - p0).normalized()
			var normal := Vector2(-dir.y, dir.x)
			
			var dist_phase := float(i) * ghost_frequency
			var pulse := sin(_time * ghost_speed + dist_phase + phase)
			
			var offset := normal * pulse * ghost_amplitude * (1.0 - float(i) / float(_points.size()))
			
			var a := to_local(p0 + offset)
			var b := to_local(p1 + offset)
			
			var fade := ghost_color.a * (2.0 - float(i) / float(_points.size()))
			draw_line(a, b, Color(ghost_color.r, ghost_color.g, ghost_color.b, fade), line_width * 0.7)

	# Main line
	for i in range(1, _points.size()):
		var a := to_local(_points[i - 1])
		var b := to_local(_points[i])
		var t := float(i) / float(_points.size())
		
		var col := prediction_color
		if i > _points.size() - 20:
			col = danger_color
		
		draw_line(a, b, Color(col.r, col.g, col.b, (1.0 - t) * col.a), line_width)

	draw_circle(to_local(_points[0]), 8.5, Color(0.42, 1.0, 0.92, 0.72))
