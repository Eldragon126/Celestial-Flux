extends RapierRigidBody2D
@export var A = 30.0
@export var B = 30.0
@export var alpha = 1.0
@export var beta = 1.0
@export var C = 0.0
@export var D = 0.0
@export var speed = 100.0
var dt = 0.0
var timestep = 0
var player : Node2D
func _ready() -> void:
	print("parametric enemy number 3 is ALIVE!")
	player = get_tree().get_first_node_in_group("Player")
	
func _physics_process(delta: float) -> void:
	apply_force((equation(delta)))
	if player != null: apply_force((player.global_position - global_position).normalized() * (global_position - player.global_position).length())
	angular_velocity = linear_velocity.length() / 100
	if linear_velocity.length() >= 2000:
		linear_velocity = lerp(linear_velocity, linear_velocity.normalized() * 2000, 5 * delta)

func equation(delta):
	dt += delta * 10
	if dt > TAU:
		dt = 0.0
		timestep += 1
		
	if timestep > 5:
		timestep = 0


	#Edit all variables here for change
	return Vector2((-A*cos(dt * alpha)+C)* speed ,(-B*sin(dt * beta)+D) * speed)
	
	


func _on_health_component_health_changed(current_health: Variant, max_health: Variant) -> void:
	pass # Replace with function body.


func _on_health_component_died() -> void:
	queue_free()

func take_damage(amount: float) -> void:
	if has_node("HealthComponent"):
		$HealthComponent.take_damage(amount)


func _on_attack_body_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.take_damage(30.0)
