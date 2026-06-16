extends Node2D

@export var MASS_POINT: PackedScene = preload("res://Nodes/mass_point.tscn")

# --- WAVE MATH SETTINGS ---
@export var active: bool = true
@export var base_radius: float = 60.0
@export var number_of_points: int = 28
@export var max_active_groups: int = 3
@export var max_expansion_scale: float = 8.0
@export var expansion_speed: float = 1.0
@export var wave_frequency: float = 5.0
@export var wave_amplitude: float = 30.0
@export var spawn_interval: float = 1.85
@export var run_lifetime_seconds: float = 30.0
@export var max_physics_points_per_group: int = 8
@export var physics_update_interval: float = 0.05
@export var visual_update_interval: float = 0.033

# --- PHYSICS SETTINGS ---
@export var base_mass: float = 120000.0

# --- VISUAL SETTINGS ---
@export var base_color := Color(0.0, 0.207, 0.207, 0.502)
@export var wave_line_color := Color(0.0, 0.8, 0.8, 1.0)
@export var point_color := Color(1.0, 1.0, 1.0, 0.8)

var point_groups: Array = []
var _point_pool: Array[Node2D] = []
var base_polygon_points: PackedVector2Array
var _base_dirs: PackedVector2Array
var _base_angles: PackedFloat32Array
var time_passed: float = 0.0
var time_since_last_spawn: float = 0.0
var _lifetime_elapsed: float = 0.0
var _deterministic_key: StringName = &""
var _physics_elapsed: float = 999.0
var _visual_elapsed: float = 999.0

func _ready() -> void:
	add_to_group("gravity_wave_maker")
	add_to_group("run_hazard")
	_generate_base_shape()
	
	if not base_polygon_points.is_empty():
		_spawn_wave_group()

func configure_deterministic(_seed: int, key: StringName = &"") -> void:
	_deterministic_key = key

func _generate_base_shape() -> void:
	base_polygon_points.clear()
	_base_dirs.clear()
	_base_angles.clear()
	var point_count := maxi(number_of_points, 6)
	for i in range(point_count):
		var angle := (float(i) / float(point_count)) * TAU
		var dir := Vector2(cos(angle), sin(angle))
		_base_angles.append(angle)
		_base_dirs.append(dir)
		base_polygon_points.append(dir * base_radius)

func _process(delta: float) -> void:
	if not active:
		return
	time_passed += delta
	_lifetime_elapsed += delta
	if run_lifetime_seconds > 0.0 and _lifetime_elapsed >= run_lifetime_seconds:
		_release_all_points()
		queue_free()
		return
	time_since_last_spawn += delta
	
	if time_since_last_spawn >= spawn_interval:
		_spawn_wave_group()
		time_since_last_spawn = 0.0

	_physics_elapsed += delta
	_visual_elapsed += delta
	if _physics_elapsed < maxf(physics_update_interval, 0.016):
		return

	var step_delta := _physics_elapsed
	_physics_elapsed = 0.0
	var groups_to_remove := []
	for group in point_groups:
		group["expansion"] = float(group.get("expansion", 0.1)) + expansion_speed * step_delta
		group["phase"] = clampf((float(group.get("expansion", 0.1)) - 0.1) / maxf(max_expansion_scale - 0.1, 0.1), 0.0, 1.0)

		if float(group.get("expansion", 0.1)) > max_expansion_scale:
			groups_to_remove.append(group)
			_release_group_points(group)
			continue

		_update_group_points(group)

	for group in groups_to_remove:
		point_groups.erase(group)

	if _visual_elapsed >= maxf(visual_update_interval, 0.016):
		_visual_elapsed = 0.0
		queue_redraw()

# --- OPTIMIZATION & VISUALS ---

func _draw() -> void:
	draw_circle(Vector2.ZERO, base_radius, base_color)
	
	for group in point_groups:
		var current_alpha := 1.0 - float(group.get("phase", 0.0))
		
		var line_color := wave_line_color
		line_color.a = current_alpha
		var dot_color := point_color
		dot_color.a = current_alpha
		
		var current_positions: PackedVector2Array = group.get("visual_positions", PackedVector2Array())
		for point in current_positions:
			draw_circle(point, 1.65, dot_color)
		
		if current_positions.size() > 1:
			var closed_positions := current_positions.duplicate()
			closed_positions.append(current_positions[0])
			draw_polyline(closed_positions, line_color, 1.7, true)

# --- LOGIC ---

func _spawn_wave_group() -> void:
	if max_active_groups > 0 and point_groups.size() >= max_active_groups:
		return
	var new_group := {
		"expansion": 0.1,
		"phase": 0.0,
		"nodes": [],
		"indices": [],
		"visual_positions": PackedVector2Array(),
	}

	var visual_positions := PackedVector2Array()
	visual_positions.resize(base_polygon_points.size())
	new_group["visual_positions"] = visual_positions

	var physics_count := clampi(max_physics_points_per_group, 1, base_polygon_points.size())
	var step := maxf(float(base_polygon_points.size()) / float(physics_count), 1.0)
	var nodes: Array = []
	var indices: Array = []
	for point_index in range(physics_count):
		var shape_index := mini(int(round(float(point_index) * step)) % base_polygon_points.size(), base_polygon_points.size() - 1)
		var pt_instance := _acquire_mass_point()
		if pt_instance == null:
			continue
		nodes.append(pt_instance)
		indices.append(shape_index)
	new_group["nodes"] = nodes
	new_group["indices"] = indices

	point_groups.append(new_group)
	_update_group_points(new_group)


func _update_group_points(group: Dictionary) -> void:
	var expansion := float(group.get("expansion", 0.1))
	var phase := float(group.get("phase", 0.0))
	var visual_positions: PackedVector2Array = group.get("visual_positions", PackedVector2Array())
	if visual_positions.size() != base_polygon_points.size():
		visual_positions.resize(base_polygon_points.size())

	for i in range(base_polygon_points.size()):
		visual_positions[i] = _wave_position_for_index(i, expansion)
	group["visual_positions"] = visual_positions

	var nodes: Array = group.get("nodes", [])
	var indices: Array = group.get("indices", [])
	var active_mass := base_mass * (1.0 - phase)
	for i in range(mini(nodes.size(), indices.size())):
		var pt := nodes[i] as Node2D
		if pt == null or not is_instance_valid(pt) or pt.is_queued_for_deletion():
			continue
		var shape_index := int(indices[i])
		pt.position = visual_positions[shape_index]
		if pt.get("mass") != null:
			pt.set("mass", active_mass)


func _wave_position_for_index(index: int, expansion: float) -> Vector2:
	var safe_index := clampi(index, 0, _base_dirs.size() - 1)
	var theta := float(_base_angles[safe_index])
	var radius := base_radius * expansion
	var wave_offset := wave_amplitude * sin(wave_frequency * theta - time_passed * 4.0)
	return _base_dirs[safe_index] * maxf(0.1, radius + wave_offset)


func _acquire_mass_point() -> Node2D:
	var point: Node2D = null
	while not _point_pool.is_empty() and point == null:
		var candidate = _point_pool.pop_back()
		if candidate != null and is_instance_valid(candidate) and not candidate.is_queued_for_deletion():
			point = candidate
	if point == null:
		point = MASS_POINT.instantiate() as Node2D
		if point == null:
			return null
		add_child(point)
	elif point.get_parent() == null:
		add_child(point)
	if point.has_method("set_gravity_active"):
		point.call("set_gravity_active", true)
	else:
		point.add_to_group("Objects_With_Gravity")
		point.add_to_group("planets")
	if point.get("mass") != null:
		point.set("mass", base_mass)
	return point


func _release_group_points(group: Dictionary) -> void:
	var nodes: Array = group.get("nodes", [])
	for pt_value in nodes:
		var pt := pt_value as Node2D
		if pt == null or not is_instance_valid(pt) or pt.is_queued_for_deletion():
			continue
		if pt.has_method("set_gravity_active"):
			pt.call("set_gravity_active", false)
		else:
			if pt.is_in_group("Objects_With_Gravity"):
				pt.remove_from_group("Objects_With_Gravity")
			if pt.is_in_group("planets"):
				pt.remove_from_group("planets")
			if RuntimeRegistry != null:
				RuntimeRegistry.unregister_node(pt, &"Objects_With_Gravity")
				RuntimeRegistry.unregister_node(pt, &"planets")
		if pt.get("mass") != null:
			pt.set("mass", 0.0)
		_point_pool.append(pt)
	nodes.clear()
	group["nodes"] = nodes


func _release_all_points() -> void:
	for group in point_groups:
		_release_group_points(group)
	point_groups.clear()
	
