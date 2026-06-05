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
	_player = MultiplayerTargeting.nearest_player(global_position, get_tree())
	_build_body()
	_build_health()
	_build_timer()

func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = MultiplayerTargeting.nearest_player(global_position, get_tree())
		return

	var direction = (_player.global_position - global_position).normalized()
	if direction != Vector2.ZERO:
		rotation = direction.angle()

func take_damage(amount: float) -> void:
	if _health != null:
		_health.take_damage(amount)

func _build_body() -> void:
	var base := get_node_or_null("TurretBasePolygon") as Polygon2D
	if base == null:
		base = Polygon2D.new()
		base.name = "TurretBasePolygon"
		base.color = Color(0.52, 0.14, 0.28, 1.0)
		add_child(base)
	if base.polygon.is_empty():
		base.polygon = PackedVector2Array([
			Vector2(-30.0, -30.0),
			Vector2(18.0, -24.0),
			Vector2(34.0, 0.0),
			Vector2(18.0, 24.0),
			Vector2(-30.0, 30.0),
			Vector2(-18.0, 0.0),
		])

	var barrel := get_node_or_null("SniperBarrelPolygon") as Polygon2D
	if barrel == null:
		barrel = Polygon2D.new()
		barrel.name = "SniperBarrelPolygon"
		barrel.color = Color(0.0, 0.88, 0.98, 1.0)
		add_child(barrel)
	if barrel.polygon.is_empty():
		barrel.polygon = PackedVector2Array([
			Vector2(8.0, -6.0),
			Vector2(92.0, -4.0),
			Vector2(108.0, 0.0),
			Vector2(92.0, 4.0),
			Vector2(8.0, 6.0),
		])

	if not has_node("CollisionPolygon2D"):
		var collision = CollisionPolygon2D.new()
		collision.name = "CollisionPolygon2D"
		collision.polygon = base.polygon
		add_child(collision)

	_charge_particles = get_node_or_null("ChargeParticles") as GPUParticles2D
	if _charge_particles == null:
		_charge_particles = GPUParticles2D.new()
		_charge_particles.name = "ChargeParticles"
		_charge_particles.position = Vector2(96.0, 0.0)
		_charge_particles.amount = 50
		_charge_particles.lifetime = 0.6
		_charge_particles.one_shot = true
		_charge_particles.explosiveness = 1.0
		_charge_particles.emitting = false
		add_child(_charge_particles)
	if _charge_particles.process_material == null:
		_charge_particles.process_material = _make_charge_material()

func _build_health() -> void:
	_health = get_node_or_null("HealthComponent") as HealthComponent
	if _health == null:
		_health = HealthComponent.new()
		_health.name = "HealthComponent"
		add_child(_health)
	_health.max_health = max_health
	if not _health.died.is_connected(_on_died):
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
		_player = MultiplayerTargeting.nearest_player(global_position, get_tree())
	if _player == null or not is_instance_valid(_player):
		return

	var distance = global_position.distance_to(_player.global_position)
	if distance < min_range or distance > max_range:
		return

	# Check global bullet cap before spawning
	if not BulletManager.can_spawn_bullet():
		return

	var direction = (_player.global_position - global_position).normalized()
	var bullet = ENEMY_BULLET_SCENE.instantiate()
	bullet.global_position = global_position + direction * 108.0
	bullet.global_rotation = direction.angle()
	if bullet.has_method("configure_launch"):
		bullet.call("configure_launch", direction, projectile_speed, self)
	elif bullet.get("initial_speed") != null:
		bullet.set("initial_speed", projectile_speed)
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
