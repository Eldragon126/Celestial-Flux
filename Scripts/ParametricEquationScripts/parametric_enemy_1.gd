extends RapierCharacterBody2D

# =========================================
# PARAMETRIC ENEMY: DRIFTING ORBITRON
# =========================================

var dt: float = 0.0
var total_time: float = 0.0
var player: Node2D

# =========================================
# SPACE PHYSICS SETTINGS
# =========================================
@export var A: float = 250.0  # Increased radius so it has room to drift
@export var B: float = 180.0

@export var a: float = 2.0
@export var b: float = 1.0

@export var equation_speed: float = 1.0

# Physics tuning for space inertia
@export var max_speed: float = 500.0
@export var engine_thrust: float = 1200.0  # How hard it pulls toward the pattern
@export var space_friction: float = 2.0    # Simulates slight dampening/thruster counter-burn

func _ready() -> void:
	player = get_tree().get_first_node_in_group("Player")


func _physics_process(delta: float) -> void:
	total_time += delta 
	dt = fmod(dt + delta * equation_speed, TAU) 
	
	# =========================
	# PHASE CHANGES
	# =========================
	if total_time > 150:
		A = 280; B = 100; a = 5; b = 2
	elif total_time > 100:
		A = 150; B = 250; a = 3; b = 2
	elif total_time > 70:
		A = 300; B = 120; a = 4; b = 3
	elif total_time > 40:
		A = 200; B = 200; a = 3; b = 2
	elif total_time > 20:
		A = 250; B = 150; a = 2; b = 1

	if total_time > 200.0:
		queue_free()
		return

	# =========================
	# THE "ANCHOR" POSITION
	# =========================
	var x = A * sin(a * dt)
	var y = B * cos(b * dt)

	var anchor_position: Vector2
	if player != null:
		anchor_position = player.global_position + Vector2(x, y)
	else:
		anchor_position = Vector2(x, y)

	# =========================
	# TRUE SPACE INERTIA PHYSICS
	# =========================
	# 1. Find direction to the moving pattern anchor
	var to_anchor = anchor_position - global_position
	var distance = to_anchor.length()

	if distance > 5.0:
		# 2. Apply a continuous thrust acceleration toward the pattern
		var thrust_direction = to_anchor.normalized()
		velocity += thrust_direction * engine_thrust * delta
	
	# 3. Apply space friction so it doesn't orbit infinitely or overshoot wildly
	velocity -= velocity * space_friction * delta

	# 4. Clamp to max speed so it doesn't accelerate into hyperspace
	velocity = velocity.limit_length(max_speed)

	move_and_slide()

	#if velocity.length() > 10:
	#	rotation = lerp(rotation, velocity.angle(), 0.1)
	
func take_damage(amount: float) -> void:
	if has_node("HealthComponent"):
		$HealthComponent.take_damage(amount)

func _on_health_component_died() -> void:
	queue_free()


func _on_health_component_health_changed(current_health: Variant, max_health: Variant) -> void:
	print("Health Changed")
