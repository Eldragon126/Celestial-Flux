extends RigidBody2D

var direction_of_rigidbody: Vector2 = Vector2.ZERO
var force_of_rigidbody: float = 0.0
var is_body_entered: bool = false

@onready var collision_shape: CircleShape2D = $Area2D/CollisionShape2D.shape

func _ready() -> void:
	if GravityGoverner.DEBUG:
		print("Projectile pickup EXISTS")

	collision_shape.radius = randi_range(140, 340)

	apply_central_impulse(
		Vector2(
			randi_range(-60, 60),
			randi_range(-60, 60)
		)
	)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") or body is CharacterBody2D:
		var direction: Vector2 = (body.global_position - global_position).normalized()
		var force: float = 30.0

		apply_central_impulse(direction * force)

		direction_of_rigidbody = direction
		force_of_rigidbody = force
		is_body_entered = true

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player") or body is CharacterBody2D:
		var direction: Vector2 = (body.global_position - global_position).normalized()
		var force: float = 50.0

		apply_central_impulse(direction * force)

		direction_of_rigidbody = direction
		force_of_rigidbody = force
		is_body_entered = false

func _physics_process(delta: float) -> void:
	pass
