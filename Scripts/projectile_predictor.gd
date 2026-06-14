extends Node2D
class_name ProjectileAimPredictor

# ============================================================
# VISUAL SETTINGS
# ============================================================
@export var prediction_steps: int = 110
@export var substeps: int = 2
@export var line_width: float = 3.2
@export var ghost_count: int = 1
@export var ghost_amplitude: float = 10.0
@export var ghost_frequency: float = 2.2
@export var ghost_speed: float = 6.0
@export var prediction_recalculate_interval: float = 0.045
@export var draw_stride: int = 1
@export var max_draw_segments: int = 110
@export var pressure_hide_threshold: int = 196
@export_range(0.8, 1.0, 0.001) var stability_damping: float = 1.0
@export var immediate_danger_segments: int = 25

@export var prediction_color: Color = Color(0.0, 0.88, 1.0, 0.82)
@export var danger_color: Color = Color(1.0, 0.35, 0.1, 0.95)
@export var ghost_color: Color = Color(0.0, 0.6, 1.0, 0.22)
@export var prediction_tracks: Array = []
@export_range(1, 12, 1) var max_prediction_tracks: int = 6
@export_range(1.0, 18.0, 0.5) var impact_marker_radius: float = 5.5
@export_range(1.0, 7.0, 0.1) var track_glow_width_scale: float = 3.6
@export_range(0.25, 1.0, 0.05) var secondary_track_width_scale: float = 0.68

# ============================================================
# PROJECTILE SETTINGS
# ============================================================
@export var projectile_speed: float = 1080.0
@export var gravity_constant: float = 100.0
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
@export var collision_radius: float = 14.0

# ============================================================
# INTERNAL
# ============================================================
var _player: CharacterBody2D
var _points: Array[Vector2] = []
var _track_points: Array = []
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
		_track_points.clear()
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
	_track_points.clear()

	var tracks := _active_prediction_tracks()
	for track_index in range(min(tracks.size(), max_prediction_tracks)):
		var track: Dictionary = tracks[track_index]
		var points := _simulate_track(track)
		if points.size() < 2:
			continue
		_track_points.append({
			"index": track_index,
			"track": track,
			"points": points,
		})

	if _track_points.is_empty():
		return
	var first_points: Array = _track_points[0].get("points", [])
	for point in first_points:
		if point is Vector2:
			_points.append(point)


func _active_prediction_tracks() -> Array:
	var tracks: Array = []
	for value in prediction_tracks:
		if value is Dictionary:
			tracks.append(value)
	if tracks.is_empty():
		tracks.append({
			"direction_offset": 0.0,
			"spawn_offset": spawn_offset,
			"projectile_speed": projectile_speed,
			"gravity_constant": gravity_constant,
			"gravity_radius": gravity_radius,
			"collision_radius": collision_radius,
			"projectile_mass": projectile_mass,
			"prediction_color": prediction_color,
			"danger_color": danger_color,
			"ghost_color": ghost_color,
			"line_width_scale": 1.0,
		})
	return tracks


func _simulate_track(track: Dictionary) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var base_dir := -_player.transform.x.normalized()
	if base_dir.length_squared() <= 0.001:
		base_dir = Vector2.RIGHT
	var dir := base_dir.rotated(float(track.get("direction_offset", 0.0))).normalized()
	if dir.length_squared() <= 0.001:
		dir = base_dir

	var local_spawn := _vector2_from_variant(track.get("spawn_offset_vector", Vector2.ZERO), Vector2.ZERO)
	var spawn_world := base_dir * float(track.get("spawn_offset", spawn_offset))
	if local_spawn.length_squared() > 0.001:
		spawn_world = base_dir * local_spawn.x + base_dir.orthogonal() * local_spawn.y

	var pos := _player.global_position + spawn_world
	var vel := dir * _predicted_launch_speed_for_track(dir, track)
	var step_count = max(1, substeps)
	var step_dt := _dt / float(step_count)
	var sim_time := float(track.get("phase_offset", 0.0))
	var track_mass := maxf(float(track.get("projectile_mass", projectile_mass)), 0.001)
	var track_damping := float(track.get("stability_damping", stability_damping))
	var track_collision_radius := maxf(float(track.get("collision_radius", collision_radius)), 1.0)

	points.append(pos)
	for i in range(prediction_steps):
		for s in range(step_count):
			var accel := _gravity_acceleration_for_track(pos, track, track_mass)
			accel += _weapon_curve_acceleration(vel, dir, track, sim_time, track_mass)
			accel += _rail_acceleration(vel, dir, track)
			vel += accel * step_dt
			vel = _cap_track_velocity(vel, track)
			pos += vel * step_dt
			sim_time += step_dt
		vel *= track_damping

		var collision := _resolve_gravity_source_collision(pos, vel, track_collision_radius)
		if collision.get("hit", false):
			pos = collision.get("position", pos)
			points.append(pos)
			if stop_on_planet_hit:
				return points
			var normal: Vector2 = collision.get("normal", Vector2.ZERO)
			if normal.length_squared() > 0.001:
				vel = vel.bounce(normal) * bounce
				vel *= solver_correction

		points.append(pos)
		if vel.length() < 6.0:
			break
	return points


func _gravity_acceleration_for_track(pos: Vector2, track: Dictionary, track_mass: float) -> Vector2:
	var force := Vector2.ZERO
	var track_gravity := float(track.get("gravity_constant", gravity_constant))
	var track_gravity_radius := float(track.get("gravity_radius", gravity_radius))
	for g in _gravity_sources:
		if not is_instance_valid(g):
			continue
		var offset := g.global_position - pos
		var dist := offset.length()
		if dist < 0.001 or dist > track_gravity_radius:
			continue
		var d = max(dist, min_grav_dist)
		var mass := 100.0
		var m = g.get("mass")
		if m is float or m is int:
			mass = float(m)
		force += offset.normalized() * (track_gravity * mass / (d * d))
	return force / maxf(track_mass, 0.001)


func _weapon_curve_acceleration(vel: Vector2, fallback_dir: Vector2, track: Dictionary, sim_time: float, track_mass: float) -> Vector2:
	var force := float(track.get("weapon_curve_force", 0.0))
	var side := float(track.get("weapon_curve_side", 0.0))
	if absf(force) <= 0.001 or absf(side) <= 0.001:
		return Vector2.ZERO
	var direction := vel.normalized()
	if direction.length_squared() <= 0.001:
		direction = fallback_dir
	var frequency := float(track.get("weapon_curve_frequency", 7.0))
	var pulse := 0.72 + 0.28 * sin(sim_time * frequency)
	return direction.orthogonal() * side * force * pulse / maxf(track_mass, 0.001)


func _rail_acceleration(vel: Vector2, fallback_dir: Vector2, track: Dictionary) -> Vector2:
	var rail_stacks := int(track.get("relativistic_rail_stacks", 0))
	if rail_stacks <= 0:
		return Vector2.ZERO
	var direction := vel.normalized()
	if direction.length_squared() <= 0.001:
		direction = fallback_dir
	var acceleration := float(track.get("relativistic_rail_acceleration", 640.0))
	var multiplier := 1.0 + 0.22 * float(max(rail_stacks - 1, 0))
	return direction * acceleration * multiplier


func _cap_track_velocity(vel: Vector2, track: Dictionary) -> Vector2:
	var rail_stacks := int(track.get("relativistic_rail_stacks", 0))
	if rail_stacks > 0:
		var base_cap := float(track.get("relativistic_rail_speed_cap", 2850.0))
		var cap := base_cap * (1.0 + 0.08 * float(max(rail_stacks - 1, 0)))
		if vel.length() > cap:
			return vel.normalized() * cap
	var curve_force := float(track.get("weapon_curve_force", 0.0))
	if curve_force > 0.001:
		var initial_speed := float(track.get("projectile_speed", projectile_speed))
		var cap := maxf(initial_speed * 1.9, initial_speed + 520.0)
		if vel.length() > cap:
			return vel.normalized() * cap
	return vel


func _resolve_gravity_source_collision(pos: Vector2, _vel: Vector2, track_collision_radius: float) -> Dictionary:
	for planet in _gravity_sources:
		if planet == null or not is_instance_valid(planet):
			continue
		if not planet.is_in_group("planets"):
			continue
		var delta_vec := pos - planet.global_position
		var dist := delta_vec.length()
		var impact_radius := track_collision_radius
		if "consume_radius" in planet:
			impact_radius = maxf(impact_radius, float(planet.get("consume_radius")))
		if dist < impact_radius and dist > 0.001:
			var normal := delta_vec / dist
			return {
				"hit": true,
				"position": planet.global_position + normal * impact_radius,
				"normal": normal,
			}
	return {"hit": false}


func _predicted_launch_speed(direction: Vector2) -> float:
	return _predicted_launch_speed_for_track(direction, {})


func _predicted_launch_speed_for_track(direction: Vector2, track: Dictionary) -> float:
	var speed := projectile_speed
	if track.has("projectile_speed"):
		speed = float(track.get("projectile_speed", projectile_speed))
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
	if _track_points.is_empty():
		return
	if _projectile_pressure >= pressure_hide_threshold:
		return

	for track_data in _track_points:
		if track_data is Dictionary:
			_draw_prediction_track(track_data, _track_points.size())


func _draw_prediction_track(track_data: Dictionary, track_count: int) -> void:
	var raw_points: Array = track_data.get("points", [])
	var track: Dictionary = track_data.get("track", {})
	var track_index := int(track_data.get("index", 0))
	if raw_points.size() < 2:
		return

	var stride := maxi(draw_stride, 1)
	var points: Array[Vector2] = []
	for point in raw_points:
		if point is Vector2:
			points.append(point)
	if points.size() < 2:
		return

	var line_scale := float(track.get("line_width_scale", 1.0))
	if track_count > 1 and track_index > 0:
		line_scale *= secondary_track_width_scale
	var track_width := maxf(1.0, line_width * line_scale)
	var primary_color := _color_from_variant(track.get("prediction_color", prediction_color), prediction_color)
	var danger := _color_from_variant(track.get("danger_color", danger_color), danger_color)
	var ghost := _color_from_variant(track.get("ghost_color", ghost_color), ghost_color)
	var pulse := 0.72 + 0.28 * sin(_time * (5.6 + float(track_index) * 0.4))

	# Animated side echoes make clustered weapons readable without hiding the true arc.
	for g in range(ghost_count):
		var phase := float(g) / float(ghost_count) * PI * 2.0
		var drawn := 0
		for i in range(stride, points.size(), stride):
			if drawn >= max_draw_segments:
				break
			var p0 := points[i - stride]
			var p1 := points[i]
			var dir := (p1 - p0).normalized()
			var normal := Vector2(-dir.y, dir.x)

			var dist_phase := float(i) * ghost_frequency
			var wobble := sin(_time * ghost_speed + dist_phase + phase)

			var offset := normal * wobble * ghost_amplitude * (1.0 - float(i) / float(points.size()))

			var a := to_local(p0 + offset)
			var b := to_local(p1 + offset)

			var fade := _safe_visual_alpha(ghost.a * (1.0 - float(i) / float(points.size())) * 0.72, 0.18)
			draw_line(a, b, Color(ghost.r, ghost.g, ghost.b, fade), track_width * 0.72)
			drawn += 1

	var drawn_glow := 0
	for i in range(stride, points.size(), stride):
		if drawn_glow >= max_draw_segments:
			break
		var a_glow := to_local(points[i - stride])
		var b_glow := to_local(points[i])
		var t_glow := float(i) / float(points.size())
		var glow_color := danger if i <= immediate_danger_segments else primary_color
		draw_line(
			a_glow,
			b_glow,
			Color(glow_color.r, glow_color.g, glow_color.b, _safe_visual_alpha((1.0 - t_glow) * glow_color.a * 0.28, 0.28)),
			track_width * track_glow_width_scale
		)
		drawn_glow += 1

	var drawn_main := 0
	for i in range(stride, points.size(), stride):
		if drawn_main >= max_draw_segments:
			break
		var a := to_local(points[i - stride])
		var b := to_local(points[i])
		var t := float(i) / float(points.size())

		var col := primary_color
		if i <= immediate_danger_segments:
			col = danger

		draw_line(a, b, Color(col.r, col.g, col.b, _safe_visual_alpha((1.0 - t) * col.a, 0.82)), track_width)
		drawn_main += 1

	var end_point := to_local(points[points.size() - 1])
	var ring_color := Color(primary_color.r, primary_color.g, primary_color.b, _safe_visual_alpha(primary_color.a * (0.42 + 0.18 * pulse), 0.5))
	draw_arc(end_point, impact_marker_radius * (1.0 + 0.2 * pulse), 0.0, TAU, 24, ring_color, maxf(1.0, track_width * 0.5), true)
	var slash_dir := Vector2.RIGHT.rotated(_time * 1.6 + float(track_index) * 0.55)
	draw_line(end_point - slash_dir * impact_marker_radius * 1.5, end_point + slash_dir * impact_marker_radius * 1.5, Color(danger.r, danger.g, danger.b, _safe_visual_alpha(danger.a * 0.56, 0.54)), maxf(1.0, track_width * 0.42), true)

	if track_index == 0:
		draw_circle(to_local(points[0]), 8.0 + pulse * 2.5, Color(0.42, 1.0, 0.92, _safe_visual_alpha(0.62, 0.36)))


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


func _color_from_variant(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is Vector3:
		return Color(value.x, value.y, value.z, fallback.a)
	if value is Vector4:
		return Color(value.x, value.y, value.z, value.w)
	return fallback


func _vector2_from_variant(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector3:
		return Vector2(value.x, value.y)
	return fallback
