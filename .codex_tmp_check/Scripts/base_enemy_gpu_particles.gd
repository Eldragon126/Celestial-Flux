extends GPUParticles2D

@export var detach_cleanup_delay: float = 1.35


func fade_and_free() -> void:
	emitting = false
	await get_tree().create_timer(maxf(detach_cleanup_delay, 0.05)).timeout
	if is_instance_valid(self):
		queue_free()


func _on_finished() -> void:
	queue_free()
