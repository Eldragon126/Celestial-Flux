extends CPUParticles2D

# One-shot impact sparks. Tune amount, gradient, and velocity in the inspector.


func _ready() -> void:
	call_deferred("_start_burst")


func _start_burst() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	emitting = true
	await get_tree().create_timer(lifetime + 0.25).timeout
	queue_free()
