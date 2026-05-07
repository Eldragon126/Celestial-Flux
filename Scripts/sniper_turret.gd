extends StaticBody2D

# Enemy variant: holds position and fires fast shots at long range.

const ENEMY_BULLET_SCENE = preload("res://Nodes/enemy_bullet.tscn")

@export var min_range = 360.0
@export var max_range = 1750.0
@export var fire_interval = 2.25
@export var projectile_speed = 1550.0
@export var max_health = 55.0

var _player: Node = null
var _health: HealthComponent = null
var _timer: Timer
var _charge_particles: GPUParticles2D

func _ready() -> void:
	add_to_group("enemies")
	_player = get_tree().get_first_node_in_group("Player")
	_build_body()
	_build_health()
	_build_timer()

func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("Player")
		return

	var direction = (_player.global_position - global_position).normalized()
	if direction != Vector2.ZERO:
		rotation = direction.angle()

func take_damage(amount: float) -> void:
	if _health != null:
		_health.take_damage(amount)

func _build_body() -> void:
	var base = Polygon2D.new()
	base.name = "TurretBasePolygon"
	base.color = Color(0.52, 0.14, 0.28, 1.0)
	base.polygon = PackedVector2Array([
		Vector2(-30.0, -30.0),
		Vector2(18.0, -24.0),
		Vector2(34.0, 0.0),
		Vector2(18.0, 24.0),
		Vector2(-30.0, 30.0),
		Vector2(-18.0, 0.0),
	])
	add_child(base)

	var barrel = Polygon2D.new()
	barrel.name = "SniperBarrelPolygon"
	barrel.color = Color(0.0, 0.88, 0.98, 1.0)
	barrel.polygon = PackedVector2Array([
		Vector2(8.0, -6.0),
		Vector2(92.0, -4.0),
		Vector2(108.0, 0.0),
		Vector2(92.0, 4.0),
		Vector2(8.0, 6.0),
	])
	add_child(barrel)

	var collision = CollisionPolygon2D.new()
	collision.name = "CollisionPolygon2D"
	collision.polygon = base.polygon
	add_child(collision)

	_charge_particles = GPUParticles2D.new()
	_charge_particles.name = "ChargeParticles"
	_charge_particles.position = Vector2(96.0, 0.0)
	_charge_particles.amount = 50
	_charge_particles.lifetime = 0.6
	_charge_particles.one_shot = true
	_charge_particles.explosiveness = 1.0
	_charge_particles.emitting = false
	_charge_particles.process_material = _make_charge_material()
	add_child(_charge_particles)

func _build_health() -> void:
	_health = HealthComponent.new()
	_health.name = "HealthComponent"
	_health.max_health = max_health
	add_child(_health)
	_health.died.connect(_on_died)

func _build_timer() -> void:
	_timer = Timer.new()
	_timer.name = "FireTimer"
	_timer.wait_time = fire_interval
	_timer.timeout.connect(_try_fire)
	add_child(_timer)
	_timer.start()

func _try_fire() -> void:
	if _player == null or not is_instance_valid(_player):
		return

	var distance = global_position.distance_to(_player.global_position)
	if distance < min_range or distance > max_range:
		return

	var direction = (_player.global_position - global_position).normalized()
	var bullet = ENEMY_BULLET_SCENE.instantiate()
	bullet.global_position = global_position + direction * 108.0
	bullet.apply_impulse(direction * projectile_speed)
	get_parent().call_deferred("add_child", bullet)

	if _charge_particles != null:
		_charge_particles.restart()
		_charge_particles.emitting = true

func _on_died() -> void:
	queue_free()

func _make_charge_material() -> ParticleProcessMaterial:
	var material = ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.direction = Vector3(1.0, 0.0, 0.0)
	material.spread = 12.0
	material.initial_velocity_min = 80.0
	material.initial_velocity_max = 260.0
	material.gravity = Vector3.ZERO
	material.scale_min = 2.0
	material.scale_max = 5.0
	material.color = Color(0.0, 0.9, 1.0, 0.92)
	return material
