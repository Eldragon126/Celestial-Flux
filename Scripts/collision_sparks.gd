extends CPUParticles2D

# One-shot impact sparks. Tune amount, gradient, and velocity in the inspector.


func _ready() -> void:
	emitting = true
	await get_tree().create_timer(lifetime + 0.25).timeout
	queue_free()
