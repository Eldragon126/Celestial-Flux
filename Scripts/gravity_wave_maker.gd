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

# --- PHYSICS SETTINGS ---
@export var base_mass: float = 120000.0

# --- VISUAL SETTINGS ---
@export var base_color := Color(0.0, 0.207, 0.207, 0.502)
@export var wave_line_color := Color(0.0, 0.8, 0.8, 1.0)
@export var point_color := Color(1.0, 1.0, 1.0, 0.8)

var point_groups: Array = []
var base_polygon_points: PackedVector2Array
var time_passed: float = 0.0
var time_since_last_spawn: float = 0.0
var _lifetime_elapsed: float = 0.0
var _deterministic_key: StringName = &""

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
	var point_count := maxi(number_of_points, 6)
	for i in range(point_count):
		var angle = (float(i) / point_count) * TAU
		var x = cos(angle) * base_radius
		var y = sin(angle) * base_radius
		base_polygon_points.append(Vector2(x, y))

func _process(delta: float) -> void:
	if not active:
		return
	time_passed += delta
	_lifetime_elapsed += delta
	if run_lifetime_seconds > 0.0 and _lifetime_elapsed >= run_lifetime_seconds:
		queue_free()
		return
	time_since_last_spawn += delta
	
	if time_since_last_spawn >= spawn_interval:
		_spawn_wave_group()
		time_since_last_spawn = 0.0

	var groups_to_remove := []

	for group in point_groups:
		group["expansion"] = float(group.get("expansion", 0.1)) + expansion_speed * delta
		
		# Calculate the current lifespan phase (0.0 = just spawned, 1.0 = at max expansion)
		group["phase"] = clamp((float(group.get("expansion", 0.1)) - 0.1) / maxf(max_expansion_scale - 0.1, 0.1), 0.0, 1.0)

		# Mark for deletion if the wave pushes past the max scale
		if float(group.get("expansion", 0.1)) > max_expansion_scale:
			groups_to_remove.append(group)
			var nodes: Array = group.get("nodes", [])
			for pt in nodes:
				if is_instance_valid(pt):
					pt.queue_free()
			continue

		# Apply math and physics to each point
		var nodes: Array = group.get("nodes", [])
		for i in range(nodes.size()):
			var pt := nodes[i] as Node2D
			if pt == null or not is_instance_valid(pt): continue
			
			var base_pos = base_polygon_points[i]
			
			# Polar math for position
			var r = base_pos.length() * float(group.get("expansion", 0.1))
			var theta = base_pos.angle()
			var wave_offset = wave_amplitude * sin(wave_frequency * theta - time_passed * 4.0)
			var current_r = max(0.1, r + wave_offset) 
			
			pt.position = Vector2(current_r * cos(theta), current_r * sin(theta))
			
			# Decay the mass based on the wave's lifespan phase
			if pt.get("mass") != null:
				pt.set("mass", base_mass * (1.0 - float(group.get("phase", 0.0))))

	for group in groups_to_remove:
		point_groups.erase(group)
		
	queue_redraw()

# --- OPTIMIZATION & VISUALS ---

func _draw() -> void:
	draw_circle(Vector2.ZERO, base_radius, base_color)
	
	for group in point_groups:
		# Use the phase calculated in _process to determine alpha
		var current_alpha = 1.0 - float(group.get("phase", 0.0))
		
		var line_color = wave_line_color
		line_color.a = current_alpha
		var dot_color = point_color
		dot_color.a = current_alpha
		
		var current_positions = PackedVector2Array()
		
		var nodes: Array = group.get("nodes", [])
		for pt in nodes:
			var point := pt as Node2D
			if point != null and is_instance_valid(point):
				current_positions.append(point.position)
				draw_circle(point.position, 2.0, dot_color)
		
		if current_positions.size() > 1:
			current_positions.append(current_positions[0])
			draw_polyline(current_positions, line_color, 2.0, true)

# --- LOGIC ---

func _spawn_wave_group() -> void:
	if max_active_groups > 0 and point_groups.size() >= max_active_groups:
		return
	var new_group = {
		"expansion": 0.1,
		"phase": 0.0,
		"nodes": []
	}
	
	for i in range(base_polygon_points.size()):
		var pt_instance = MASS_POINT.instantiate()
		if pt_instance.get("mass") != null:
			pt_instance.set("mass", base_mass)
		add_child(pt_instance)
		new_group.nodes.append(pt_instance)
		
	point_groups.append(new_group)
	
