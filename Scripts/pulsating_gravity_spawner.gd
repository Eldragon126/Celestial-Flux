extends StaticBody2D

@export var radius: float = 60.0
@export var pulsating_gravity_field: PackedScene = preload("res://Nodes/pulsating_gravity_field.tscn")

@onready var timer: Timer = $Timer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# Tracks time to animate our waves
var time_passed: float = 0.0

func _ready() -> void:
	_setup_collision()
	
	if timer:
		timer.wait_time = randf_range(5.0, 10.0)
		timer.start()

# --- OPTIMIZATION & VISUALS ---

func _process(delta: float) -> void:
	time_passed += delta
	# Tells Godot to continuously redraw our growing waves
	queue_redraw()

func _setup_collision() -> void:
	# Still using the highly optimized CircleShape2D
	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = radius

func _draw() -> void:
	# Draw the filled base circle
	var base_color = Color(0.0, 0.207, 0.207, 0.502) 
	draw_circle(Vector2.ZERO, radius, base_color)
	
	# --- CONCENTRIC GROWING WAVES ---
	var wave_count: int = 3
	var wave_speed: float = 1.0
	var wave_spread: float = radius * 0.8 # How far out the waves travel before vanishing
	
	for i in range(wave_count):
		# Creates a looping phase value from 0.0 to 1.0 for each wave
		var phase = fmod(time_passed * wave_speed + (float(i) / wave_count), 1.0)
		
		# The wave grows outward from the base radius
		var current_radius = radius + (phase * wave_spread)
		
		# The wave fades out into transparency as it gets larger
		var wave_alpha = 1.0 - phase
		var wave_color = Color(0.0, 0.5, 0.5, wave_alpha)
		
		# Draw the expanding wave ring
		draw_arc(Vector2.ZERO, current_radius, 0, TAU, 32, wave_color, 2.0)

# --- LOGIC ---

func _on_timer_timeout() -> void:
	if pulsating_gravity_field:
		var inst = pulsating_gravity_field.instantiate()
		inst.global_position = global_position
		get_tree().current_scene.call_deferred("add_child", inst)
	
	timer.wait_time = randf_range(5.0, 10.0)
	timer.start()
