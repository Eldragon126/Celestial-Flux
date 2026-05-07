extends CPUParticles2D

# One-shot impact sparks for projectile collisions.

func _ready() -> void:
    amount = 36
    lifetime = 0.38
    one_shot = true
    explosiveness = 0.86
    randomness = 0.42
    local_coords = false
    direction = Vector2.LEFT
    spread = 82.0
    gravity = Vector2.ZERO
    initial_velocity_min = 120.0
    initial_velocity_max = 420.0
    angular_velocity_min = -160.0
    angular_velocity_max = 160.0
    damping_min = 80.0
    damping_max = 180.0
    scale_amount_min = 1.6
    scale_amount_max = 4.4

    var gradient = Gradient.new()
    gradient.set_color(0, Color(1.0, 0.88, 0.26, 1.0))
    gradient.set_color(1, Color(0.0, 0.86, 1.0, 0.0))
    color_ramp = gradient

    emitting = true
    await get_tree().create_timer(lifetime + 0.25).timeout
    queue_free()
