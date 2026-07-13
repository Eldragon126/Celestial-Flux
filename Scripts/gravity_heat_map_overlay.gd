extends Node2D
class_name GravityHeatMapOverlay

@export_category("Overlay Settings")
@export var enabled_on_start: bool = false
@export var enable_toggle: bool = true
@export var toggle_key: Key = KEY_F10
@export var refresh_interval: float = 0.13
@export var screen_margin_world: float = 200.0

@export_group("Grid & Performance")
@export var sample_columns: int = 34
@export var sample_rows: int = 22
@export var max_gravity_sources: int = 6
@export var gravity_softener: float = 64.0
@export var max_sample_cells: int = 760
@export var gradient_draw_stride: int = 3
@export var max_contour_segments: int = 760
@export var max_gradient_vectors: int = 72

@export_group("Visuals & Telemetry")
@export var contour_levels: Array[float] = [0.15, 0.30, 0.45, 0.65, 0.85]
@export var low_gravity_color: Color = Color(1.0, 1.0, 1.0, 0.686)
@export var mid_gravity_color: Color = Color(0.0, 0.592, 1.0, 0.863)
@export var high_gravity_color: Color = Color(1.0, 0.0, 0.471, 1.0)
@export var gradient_vector_length: float = 38.0
@export var gradient_alpha: float = 0.4
@export var contour_line_width: float = 2.0

@export_group("Golden Slingshot Line")
@export var show_golden_slingshot_line: bool = true
## The optimal radius to orbit a planet (in pixels).
@export var optimal_slingshot_radius: float = 240.0 
@export var golden_line_color: Color = Color(1.0, 0.82, 0.18, 1.0)
@export var golden_line_width: float = 4.0
@export var golden_line_steps: int = 60

var _player: Node2D = null
var _gravity_sources: Array[Node2D] = []
var _source_buffer: Array[Node2D] = []
var _sample_positions := PackedVector2Array()
var _sample_gradients := PackedVector2Array()
var _sample_heat := PackedFloat32Array()
var _sample_field_heat := PackedFloat32Array()
var _active_columns: int = 1
var _active_rows: int = 1

# Stability variables to stop the screen from flashing/glitching
var _stable_max_potential: float = 1.0
var _stable_max_strength: float = 1.0

var _golden_path := PackedVector2Array()
var _elapsed: float = 0.0
var _visible_world_rect := Rect2(Vector2.ZERO, Vector2.ONE)
var _cell_size := Vector2.ONE
var _field_potential: float = 0.0
var _field_gradient: Vector2 = Vector2.ZERO
var _drawn_contour_segments: int = 0
var _drawn_gradient_vectors: int = 0

func _ready() -> void:
	add_to_group("gravity_heat_map_overlay")
	top_level = true
	z_as_relative = false
	global_position = Vector2.ZERO
	z_index = 100 # Moved up to ensure it renders over everything
	visible = enabled_on_start
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if not enable_toggle:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == toggle_key:
			visible = not visible
			if visible:
				_elapsed = refresh_interval # Force immediate refresh
			else:
				queue_redraw()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not visible:
		return
	
	_elapsed += delta
	if _elapsed >= refresh_interval:
		_elapsed = 0.0
		_refresh_heat_map()

func _refresh_heat_map() -> void:
	_resolve_player()
	_update_visible_world_rect()
	_refresh_sources()
	_calculate_stable_bounds() # New function to prevent glitchy color popping
	_rebuild_samples()
	_rebuild_golden_slingshot_line()
	queue_redraw()

func _resolve_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	_player = get_tree().get_first_node_in_group("Player") as Node2D

func _update_visible_world_rect() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var screen_rect := viewport.get_visible_rect()
	var transform := viewport.get_canvas_transform().affine_inverse()
	
	var tl: Vector2 = transform * screen_rect.position
	var br: Vector2 = transform * (screen_rect.position + screen_rect.size)
	
	_visible_world_rect = Rect2(tl, br - tl).grow(screen_margin_world)
	
	# Fallback if camera math fails
	if _visible_world_rect.size.x <= 1.0:
		var center := _player.global_position if _player else Vector2.ZERO
		_visible_world_rect = Rect2(center - Vector2(1280.0, 720.0), Vector2(2560.0, 1440.0))
		
	_update_active_grid()
	_cell_size = Vector2(
		_visible_world_rect.size.x / float(maxi(_active_columns - 1, 1)),
		_visible_world_rect.size.y / float(maxi(_active_rows - 1, 1))
	)


func _update_active_grid() -> void:
	var columns := maxi(sample_columns, 4)
	var rows := maxi(sample_rows, 4)
	var cells := columns * rows
	if cells > max_sample_cells:
		var scale := sqrt(float(max_sample_cells) / float(cells))
		columns = maxi(4, int(floor(float(columns) * scale)))
		rows = maxi(4, int(floor(float(rows) * scale)))
	_active_columns = columns
	_active_rows = rows

func _refresh_sources() -> void:
	_gravity_sources.clear()
	var center := _visible_world_rect.get_center()

	var seen := {}
	for group_name in [&"Objects_With_Gravity", &"planets"]:
		_source_buffer.clear()
		if RuntimeRegistry != null:
			RuntimeRegistry.fill_group(group_name, _source_buffer, max_gravity_sources * 3)
		else:
			for value in get_tree().get_nodes_in_group(group_name):
				var source_value := value as Node2D
				if source_value != null:
					_source_buffer.append(source_value)
		for source in _source_buffer:
			if source == null or not is_instance_valid(source) or source == _player:
				continue
			if absf(_source_mass(source)) <= 0.001:
				continue
			var id := source.get_instance_id()
			if not seen.has(id):
				seen[id] = true
				_gravity_sources.append(source)

	# Sort by proximity to camera center and limit to max_sources for performance
	_gravity_sources.sort_custom(func(a, b): 
		return a.global_position.distance_squared_to(center) < b.global_position.distance_squared_to(center)
	)
	if _gravity_sources.size() > max_gravity_sources:
		_gravity_sources.resize(max_gravity_sources)

func _calculate_stable_bounds() -> void:
	# To stop screen flashing, we calculate the theoretical max gravity based on planet masses
	# instead of what is randomly on the screen.
	_stable_max_potential = 0.001
	_stable_max_strength = 0.001
	
	for source in _gravity_sources:
		var mass := absf(_source_mass(source))
		var radius := maxf(_source_radius(source), gravity_softener)
		
		# Theoretical max potential at the surface of the planet
		var surface_potential := mass / radius
		var surface_strength := mass / (radius * radius)
		
		if surface_potential > _stable_max_potential:
			_stable_max_potential = surface_potential
		if surface_strength > _stable_max_strength:
			_stable_max_strength = surface_strength

func _rebuild_samples() -> void:
	_sample_positions.clear()
	_sample_gradients.clear()
	_sample_heat.clear()
	_sample_field_heat.clear()
	
	for y in range(_active_rows):
		for x in range(_active_columns):
			var pos := _sample_position(x, y)
			_sample_field_at(pos)
			var potential := _field_potential
			var gradient := _field_gradient
			
			# Use stable bounds for smooth, non-glitchy heat mapping
			var heat := clampf(potential / _stable_max_potential, 0.0, 1.0)
			var field_heat := clampf(gradient.length() / _stable_max_strength, 0.0, 1.0)
			
			_sample_positions.append(pos)
			_sample_gradients.append(gradient)
			_sample_heat.append(heat)
			_sample_field_heat.append(field_heat)

func _sample_position(x: int, y: int) -> Vector2:
	return _visible_world_rect.position + Vector2(float(x) * _cell_size.x, float(y) * _cell_size.y)

func _sample_field_at(pos: Vector2) -> void:
	_field_potential = 0.0
	_field_gradient = Vector2.ZERO

	for source in _gravity_sources:
		var mass := absf(_source_mass(source))
		var r := pos - source.global_position
		var dist_squared := maxf(r.length_squared(), gravity_softener * gravity_softener)
		var dist := sqrt(dist_squared)
		
		_field_potential += mass / dist
		# F = G * (m1 * m2) / r^2. Vector direction is towards the source.
		_field_gradient += -r.normalized() * (mass / dist_squared)

func _rebuild_golden_slingshot_line() -> void:
	_golden_path.clear()
	if not show_golden_slingshot_line or not _player or not is_instance_valid(_player):
		return
		
	var best_source = _best_slingshot_source()
	if not best_source:
		return
		
	var center = best_source.global_position
	
	# Instead of a glitchy Euler integration from the player, draw the pure math orbit
	# at the optimal radius (e.g., 256 pixels)
	var steps := maxi(golden_line_steps, 16)
	for i in range(steps + 1):
		var angle = (float(i) / float(steps)) * TAU
		var point = center + Vector2(cos(angle), sin(angle)) * optimal_slingshot_radius
		_golden_path.append(point)

func _best_slingshot_source() -> Node2D:
	var best: Node2D = null
	var min_dist := INF
	
	for source in _gravity_sources:
		var dist = _player.global_position.distance_squared_to(source.global_position)
		if dist < min_dist:
			min_dist = dist
			best = source
	return best

func _draw() -> void:
	if not visible or _sample_positions.is_empty():
		return
		
	_draw_contours()
	_draw_gradient_vectors()
	_draw_golden_slingshot_line()

func _draw_contours() -> void:
	_drawn_contour_segments = 0
	for level in contour_levels:
		for y in range(_active_rows - 1):
			for x in range(_active_columns - 1):
				if _drawn_contour_segments >= max_contour_segments:
					return
				_draw_contour_cell(x, y, level)

func _draw_contour_cell(x: int, y: int, level: float) -> void:
	var corners := [
		_sample_index(x, y), _sample_index(x + 1, y),
		_sample_index(x + 1, y + 1), _sample_index(x, y + 1)
	]
	
	var crossings: Array[Vector2] = []
	_add_crossing(crossings, corners[0], corners[1], level)
	_add_crossing(crossings, corners[1], corners[2], level)
	_add_crossing(crossings, corners[2], corners[3], level)
	_add_crossing(crossings, corners[3], corners[0], level)
	
	if crossings.size() == 2:
		var color = _heat_color(level)
		color.a = _safe_alpha(0.46, 0.46)
		draw_line(to_local(crossings[0]), to_local(crossings[1]), color, contour_line_width, true)
		_drawn_contour_segments += 1
	elif crossings.size() == 4:
		var color = _heat_color(level)
		color.a = _safe_alpha(0.46, 0.46)
		draw_line(to_local(crossings[0]), to_local(crossings[1]), color, contour_line_width, true)
		_drawn_contour_segments += 1
		if _drawn_contour_segments >= max_contour_segments:
			return
		draw_line(to_local(crossings[2]), to_local(crossings[3]), color, contour_line_width, true)
		_drawn_contour_segments += 1

func _add_crossing(out_points: Array[Vector2], a: int, b: int, level: float) -> void:
	if a < 0 or b < 0:
		return
	var ah: float = _sample_heat[a]
	var bh: float = _sample_heat[b]
	if (ah < level and bh < level) or (ah >= level and bh >= level):
		return
	var t := clampf((level - ah) / (bh - ah), 0.0, 1.0)
	out_points.append(_sample_positions[a].lerp(_sample_positions[b], t))

func _draw_gradient_vectors() -> void:
	_drawn_gradient_vectors = 0
	var stride := maxi(gradient_draw_stride, 2)
	for y in range(0, _active_rows, stride):
		for x in range(0, _active_columns, stride):
			if _drawn_gradient_vectors >= max_gradient_vectors:
				return
			var index := _sample_index(x, y)
			if index < 0:
				continue
			var strength: float = _sample_field_heat[index]
			if strength < 0.05: continue # Don't draw tiny useless lines
				
			var gradient: Vector2 = _sample_gradients[index]
			var dir := gradient.normalized()
			var length := lerpf(10.0, gradient_vector_length, strength)
			var pos: Vector2 = _sample_positions[index]
			
			var end_pos = pos + dir * length
			var color = Color(0.6, 0.8, 1.0, _safe_alpha(gradient_alpha * strength * 1.55, gradient_alpha))
			
			draw_line(to_local(pos), to_local(end_pos), color, 1.5, true)
			_drawn_gradient_vectors += 1

func _draw_golden_slingshot_line() -> void:
	if _golden_path.size() < 2: return
	
	# Draw the optimal orbit path
	var glow := Color(golden_line_color.r, golden_line_color.g, golden_line_color.b, _safe_alpha(0.2, 0.22))
	var path_color := Color(golden_line_color.r, golden_line_color.g, golden_line_color.b, _safe_alpha(golden_line_color.a, 0.72))
	for i in range(1, _golden_path.size()):
		var a = _golden_path[i - 1]
		var b = _golden_path[i]
		draw_line(to_local(a), to_local(b), glow, golden_line_width * 2.5, true)
		draw_line(to_local(a), to_local(b), path_color, golden_line_width, true)

	# Draw a vector from player to the closest point on the golden path to guide them
	if _player and is_instance_valid(_player):
		var p_pos = _player.global_position
		var closest = _golden_path[0]
		var min_d = p_pos.distance_squared_to(closest)
		for pt in _golden_path:
			var d = p_pos.distance_squared_to(pt)
			if d < min_d:
				min_d = d
				closest = pt
		
		# Draw the guidance line
		draw_line(to_local(p_pos), to_local(closest), Color(1.0, 1.0, 1.0, _safe_alpha(0.592, 0.64)), 2.0, true)
		draw_circle(to_local(closest), 6.0, path_color)

func _sample_index(x: int, y: int) -> int:
	if x < 0 or x >= _active_columns or y < 0 or y >= _active_rows:
		return -1
	var index := y * _active_columns + x
	return index if index >= 0 and index < _sample_positions.size() else -1

func _heat_color(heat: float) -> Color:
	if heat < 0.5:
		return low_gravity_color.lerp(mid_gravity_color, heat * 2.0)
	return mid_gravity_color.lerp(high_gravity_color, (heat - 0.5) * 2.0)


func _safe_alpha(alpha: float, hard_cap: float) -> float:
	if Settings != null and Settings.has_method("world_visual_alpha"):
		return Settings.world_visual_alpha(alpha, hard_cap)
	if Settings != null and Settings.has_method("flash_alpha"):
		return minf(Settings.flash_alpha(alpha), hard_cap)
	return minf(alpha, hard_cap)

func _source_mass(source: Node) -> float:
	return _numeric_property(source, &"mass", 1000.0)

func _source_radius(source: Node) -> float:
	return _numeric_property(source, &"radius", 128.0)


func _numeric_property(source: Node, property_name: StringName, fallback: float) -> float:
	if source == null or not is_instance_valid(source):
		return fallback
	var value: Variant = source.get(property_name)
	if value is float or value is int:
		return float(value)
	return fallback
