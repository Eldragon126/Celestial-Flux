extends Node2D

@export var MASS_POINT: PackedScene = preload("res://Nodes/mass_point.tscn")

# --- WAVE MATH SETTINGS ---
@export var base_radius: float = 60.0
@export var number_of_points: int = 40 # Slightly fewer points for optimization
@export var max_expansion_scale: float = 12.0 # 3x bigger expansion
@export var expansion_speed: float = 0.8
@export var wave_frequency: float = 5.0
@export var wave_amplitude: float = 30.0
@export var spawn_interval: float = 1.0

# --- PHYSICS SETTINGS ---
@export var base_mass: float = 10000.0 # The starting mass of your points

# --- VISUAL SETTINGS ---
@export var base_color := Color(0.0, 0.207, 0.207, 0.502)
@export var wave_line_color := Color(0.0, 0.8, 0.8, 1.0)
@export var point_color := Color(1.0, 1.0, 1.0, 0.8)

var point_groups: Array = []
var base_polygon_points: PackedVector2Array
var time_passed: float = 0.0
var time_since_last_spawn: float = 0.0

func _ready() -> void:
	_generate_base_shape()
	
	if not base_polygon_points.is_empty():
		_spawn_wave_group()

func _generate_base_shape() -> void:
	base_polygon_points.clear()
	for i in range(number_of_points):
		var angle = (float(i) / number_of_points) * TAU
		var x = cos(angle) * base_radius
		var y = sin(angle) * base_radius
		base_polygon_points.append(Vector2(x, y))

func _process(delta: float) -> void:
	time_passed += delta
	time_since_last_spawn += delta
	
	if time_since_last_spawn >= spawn_interval:
		_spawn_wave_group()
		time_since_last_spawn = 0.0

	var groups_to_remove := []

	for group in point_groups:
		group.expansion += expansion_speed * delta
		
		# Calculate the current lifespan phase (0.0 = just spawned, 1.0 = at max expansion)
		group.phase = clamp((group.expansion - 0.1) / (max_expansion_scale - 0.1), 0.0, 1.0)

		# Mark for deletion if the wave pushes past the max scale
		if group.expansion > max_expansion_scale:
			groups_to_remove.append(group)
			for pt in group.nodes:
				if is_instance_valid(pt):
					pt.queue_free()
			continue

		# Apply math and physics to each point
		for i in range(group.nodes.size()):
			var pt = group.nodes[i]
			if not is_instance_valid(pt): continue
			
			var base_pos = base_polygon_points[i]
			
			# Polar math for position
			var r = base_pos.length() * group.expansion
			var theta = base_pos.angle()
			var wave_offset = wave_amplitude * sin(wave_frequency * theta - time_passed * 4.0)
			var current_r = max(0.1, r + wave_offset) 
			
			pt.position = Vector2(current_r * cos(theta), current_r * sin(theta))
			
			# Decay the mass based on the wave's lifespan phase
			if "mass" in pt:
				pt.mass = base_mass * (1.0 - group.phase)

	for group in groups_to_remove:
		point_groups.erase(group)
		
	queue_redraw()

# --- OPTIMIZATION & VISUALS ---

func _draw() -> void:
	draw_circle(Vector2.ZERO, base_radius, base_color)
	
	for group in point_groups:
		# Use the phase calculated in _process to determine alpha
		var current_alpha = 1.0 - group.phase
		
		var line_color = wave_line_color
		line_color.a = current_alpha
		var dot_color = point_color
		dot_color.a = current_alpha
		
		var current_positions = PackedVector2Array()
		
		for pt in group.nodes:
			if is_instance_valid(pt):
				current_positions.append(pt.position)
				draw_circle(pt.position, 2.0, dot_color)
		
		if current_positions.size() > 1:
			current_positions.append(current_positions[0])
			draw_polyline(current_positions, line_color, 2.0, true)

# --- LOGIC ---

func _spawn_wave_group() -> void:
	var new_group = {
		"expansion": 0.1,
		"phase": 0.0,
		"nodes": []
	}
	
	for i in range(base_polygon_points.size()):
		var pt_instance = MASS_POINT.instantiate()
		add_child(pt_instance)
		new_group.nodes.append(pt_instance)
		
	point_groups.append(new_group)
	
