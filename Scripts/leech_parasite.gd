extends CharacterBody2D

# Enemy variant: sticks to the player and deals timed damage until destroyed.

@export var move_speed := 420.0
@export var max_speed := 720.0
@export var attach_damage := 8.0
@export var damage_interval := 1.5
@export var max_health := 24.0

var _player: Node = null
var _health: HealthComponent = null
var _damage_timer: Timer
var _attached_body: Node2D = null
var _attach_offset := Vector2.ZERO

func _ready() -> void:
	add_to_group("enemies")
	_player = get_tree().get_first_node_in_group("Player")
	_build_body()
	_build_health()
	_build_damage_timer()

func _physics_process(delta: float) -> void:
	if _attached_body != null and is_instance_valid(_attached_body):
		global_position = _attached_body.global_position + _attach_offset.rotated(_attached_body.global_rotation)
		velocity = Vector2.ZERO
		return

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("Player")
		return

	var to_player = (_player.global_position - global_position)
	var desired = to_player.normalized() * move_speed
	velocity = velocity.lerp(desired, clampf(delta * 3.0, 0.0, 1.0)).limit_length(max_speed)
	rotation = velocity.angle() if velocity.length() > 1.0 else rotation
	move_and_slide()

func take_damage(amount: float) -> void:
	if _health != null:
		_health.take_damage(amount)

func _build_body() -> void:
	var body_poly := Polygon2D.new()
	body_poly.name = "ParasitePolygon"
	body_poly.color = Color(0.75, 0.08, 0.42, 1.0)
	body_poly.polygon = PackedVector2Array([
		Vector2(24.0, 0.0),
		Vector2(6.0, 16.0),
		Vector2(-22.0, 10.0),
		Vector2(-34.0, 0.0),
		Vector2(-22.0, -10.0),
		Vector2(6.0, -16.0),
	])
	add_child(body_poly)

	var collision := CollisionPolygon2D.new()
	collision.name = "CollisionPolygon2D"
	collision.polygon = body_poly.polygon
	add_child(collision)

	var bite_area := Area2D.new()
	bite_area.name = "AttachArea"
	bite_area.monitoring = true
	bite_area.body_entered.connect(_on_attach_area_body_entered)
	add_child(bite_area)

	var bite_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 44.0
	bite_shape.shape = circle
	bite_area.add_child(bite_shape)

	var particles := GPUParticles2D.new()
	particles.name = "LeechTrailParticles"
	particles.z_index = -1
	particles.amount = 45
	particles.lifetime = 1.1
	particles.randomness = 0.5
	particles.process_material = _make_trail_material()
	add_child(particles)

func _build_health() -> void:
	_health = HealthComponent.new()
	_health.name = "HealthComponent"
	_health.max_health = max_health
	add_child(_health)
	_health.died.connect(_on_died)

func _build_damage_timer() -> void:
	_damage_timer = Timer.new()
	_damage_timer.name = "LeechDamageTimer"
	_damage_timer.wait_time = damage_interval
	_damage_timer.timeout.connect(_damage_attached_body)
	add_child(_damage_timer)

func _on_attach_area_body_entered(body: Node) -> void:
	if _attached_body != null:
		return
	if not body.is_in_group("Player"):
		return

	_attached_body = body as Node2D
	_attach_offset = global_position - _attached_body.global_position
	_damage_timer.start()
	_damage_attached_body()

func _damage_attached_body() -> void:
	if _attached_body == null or not is_instance_valid(_attached_body):
		_attached_body = null
		_damage_timer.stop()
		return

	if _attached_body.has_method("take_damage"):
		_attached_body.take_damage(attach_damage)

func _on_died() -> void:
	queue_free()

func _make_trail_material() -> ParticleProcessMaterial:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.12, 0.58, 0.72))
	gradient.set_color(1, Color(0.2, 0.9, 1.0, 0.0))

	var texture := GradientTexture1D.new()
	texture.gradient = gradient

	var material := ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.direction = Vector3(-1.0, 0.0, 0.0)
	material.spread = 65.0
	material.initial_velocity_min = 18.0
	material.initial_velocity_max = 96.0
	material.gravity = Vector3.ZERO
	material.scale_min = 2.0
	material.scale_max = 5.0
	material.color_ramp = texture
	return material
