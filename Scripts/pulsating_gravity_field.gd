extends StaticBody2D

@export var base_mass: float = 300000.0
@export var base_radius: float = 10.0
@export var base_how_big: float = 1000.0

var t: float = 0.0
var mass: float
var rand_factor: float
var radius: float
var how_big: float
var oscillation: float = 0.0

# Cache the nodes so we don't search the scene tree every frame
@onready var big_sphere: Polygon2D = $BigSphere
@onready var small_sphere: Polygon2D = $SmallSphere

# Pre-calculate target fade colors
var big_fade_target := Color(0.059, 0.933, 0.933, 0.0)
var small_fade_target := Color(0.0, 0.208, 0.208, 0.0)

func _ready() -> void:
	add_to_group("planets")
	add_to_group("Objects_With_Gravity")
	
	radius = base_radius * randf_range(0.4, 2.0)
	how_big = base_how_big * randf_range(0.4, 2.0)
	rand_factor = randf_range(0.5, 4.0)
	mass = base_mass * rand_factor
	
	# Generate base circles with a radius of 1.0 ONCE.
	_generate_unit_circle(big_sphere, 32)
	_generate_unit_circle(small_sphere, 32)

# A single, reusable function that builds a normalized (radius 1.0) circle
func _generate_unit_circle(polygon_node: Polygon2D, points_nb: int) -> void:
	if not polygon_node: 
		return
	
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()

	for i in range(points_nb):
		var angle := TAU * float(i) / float(points_nb) - PI / 2.0
		var dir := Vector2(cos(angle), sin(angle))

		points.push_back(dir) # Radius is strictly 1.0 here
		uvs.push_back((dir + Vector2.ONE) * 0.5)

	polygon_node.polygon = points
	polygon_node.uv = uvs

func _process(delta: float) -> void:
	t += delta * 100.0
	oscillation += delta
	
	if oscillation >= TAU:
		oscillation -= TAU # Subtracting instead of resetting to 0 ensures perfect loops
		
	if t > how_big:
		queue_free()
		return # Stop processing once freed
	
	# Handle Colors
	if t > (how_big - 100.0):
		# Exponential decay interpolation directly from the current color
		big_sphere.color = big_sphere.color.lerp(big_fade_target, delta * 5.0)
		small_sphere.color = small_sphere.color.lerp(small_fade_target, delta * 5.0)
	else:
		big_sphere.color = Color(0.059, 0.933, 0.933, 0.5 * sin(oscillation) + 0.5)
		small_sphere.color = Color(0.0, 0.207, 0.207, 0.502)
	
	# Scale the spheres rather than rebuilding their polygons
	var current_big_radius := radius + t
	var current_small_radius := (radius / 3.0) + (1.05 * t)
	
	big_sphere.scale = Vector2(current_big_radius, current_big_radius)
	small_sphere.scale = Vector2(current_small_radius, current_small_radius)
	
	mass = base_mass * rand_factor * sin(oscillation)
