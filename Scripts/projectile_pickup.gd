extends RigidBody2D
var direction_of_rigidbody
var force_of_rigidbody
var is_body_entered = false
func _ready() -> void:
	if GravityGoverner.DEBUG == true: print("Projectile pickup EXISTS")
	$Area2D/CollisionShape2D.shape.radius = randi_range(140,340)
	apply_impulse(Vector2(randi_range(-60,60), randi_range(-60,60)))
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") or body is CharacterBody2D:
		var direction = body.global_position - global_position
		direction = direction.normalized()
		var force = 30
		apply_impulse(direction * force)
		direction_of_rigidbody = direction
		force_of_rigidbody = force
		is_body_entered = true

func _physics_process(delta: float) -> void:
	pass


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player") or body is CharacterBody2D:
		var direction = body.global_position - global_position
		direction = direction.normalized()
		var force = 50
		apply_impulse(direction * force)
		direction_of_rigidbody = direction
		force_of_rigidbody = force
		is_body_entered = false
