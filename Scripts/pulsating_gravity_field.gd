extends StaticBody2D

@export var base_mass: float = 300000.0
@export var base_radius: float = 10.0
@export var base_how_big: float = 1000.0
@export var oscillation_speed: float = 1.0
@export var minimum_mass_pulse: float = 0.18

var t: float = 0.0
var mass: float
var rand_factor: float
var radius: float
var how_big: float
var oscillation: float = 0.0
var _rng := RandomNumberGenerator.new()
var _has_deterministic_seed: bool = false

# Cache the nodes so we don't search the scene tree every frame
@onready var big_sphere: Polygon2D = $BigSphere
@onready var small_sphere: Polygon2D = $SmallSphere

# Pre-calculate target fade colors
var big_fade_target := Color(0.08, 1.0, 1.0, 0.0)
var small_fade_target := Color(0.0, 0.24, 0.24, 0.0)

func _ready() -> void:
	add_to_group("planets")
	add_to_group("Objects_With_Gravity")
	if not _has_deterministic_seed:
		_rng.randomize()
	if RuntimeRegistry != null:
		RuntimeRegistry.register_node(self, &"planets")
		RuntimeRegistry.register_node(self, &"Objects_With_Gravity")
	
	radius = base_radius * _rng.randf_range(0.4, 2.0)
	how_big = base_how_big * _rng.randf_range(0.4, 2.0)
	rand_factor = _rng.randf_range(0.5, 4.0)
	mass = base_mass * rand_factor
	
	# Generate base circles with a radius of 1.0 ONCE.
	_generate_unit_circle(big_sphere, 32)
	_generate_unit_circle(small_sphere, 32)

func configure_deterministic(seed: int, _key: StringName = &"") -> void:
	_rng.seed = seed
	_has_deterministic_seed = true


func _exit_tree() -> void:
	if RuntimeRegistry != null:
		RuntimeRegistry.unregister_node(self, &"planets")
		RuntimeRegistry.unregister_node(self, &"Objects_With_Gravity")

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
	oscillation += delta * oscillation_speed
	
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
		big_sphere.color = Color(0.08, 1.0, 1.0, 0.58 + 0.36 * sin(oscillation))
		small_sphere.color = Color(0.0, 0.25, 0.25, 0.56)
	
	# Scale the spheres rather than rebuilding their polygons
	var current_big_radius := radius + t
	var current_small_radius := (radius / 3.0) + (1.05 * t)
	
	big_sphere.scale = Vector2(current_big_radius, current_big_radius)
	small_sphere.scale = Vector2(current_small_radius, current_small_radius)
	
	var pulse := minimum_mass_pulse + (1.0 - minimum_mass_pulse) * (0.5 + 0.5 * sin(oscillation))
	mass = base_mass * rand_factor * pulse
